-- Thí nghiệm đo hiệu năng trên bản sao cơ sở dữ liệu, KHÔNG chạy trên DB dùng để báo cáo cuối.
-- Quy trình: metadata -> warmup -> baseline EXPLAIN ANALYZE -> thí nghiệm index -> optimized -> đo chi phí ghi -> dọn.
-- MySQL 8.0.18+ mới hỗ trợ EXPLAIN ANALYZE.
USE ecommerce_advanced;

-- 0. Buộc MySQL lấy số liệu storage tức thời thay vì dùng cache của information_schema.
SET SESSION information_schema_stats_expiry = 0;

-- 1. Ghi nhận môi trường và quy mô dữ liệu.
SELECT VERSION() AS mysql_version,@@version_comment AS server_comment,
       @@transaction_isolation AS isolation_level,
       @@innodb_buffer_pool_size AS buffer_pool_size,
       @@max_connections AS max_connections;
SELECT COUNT(*) AS orders_count FROM orders;
SELECT COUNT(*) AS order_items_count FROM order_item;
SELECT table_name,table_rows,data_length,index_length
FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name IN ('orders','order_item','product_variant','inventory')
ORDER BY table_name;

-- 2. Làm nóng cache ba lần trước khi đo.
SELECT p.product_id,p.name,SUM(oi.line_total) AS revenue
FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
JOIN product_variant v ON v.variant_id=oi.variant_id JOIN product p ON p.product_id=v.product_id
WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED')
GROUP BY p.product_id,p.name ORDER BY revenue DESC LIMIT 10;
SELECT p.product_id,p.name,SUM(oi.line_total) AS revenue
FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
JOIN product_variant v ON v.variant_id=oi.variant_id JOIN product p ON p.product_id=v.product_id
WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED')
GROUP BY p.product_id,p.name ORDER BY revenue DESC LIMIT 10;
SELECT p.product_id,p.name,SUM(oi.line_total) AS revenue
FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
JOIN product_variant v ON v.variant_id=oi.variant_id JOIN product p ON p.product_id=v.product_id
WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED')
GROUP BY p.product_id,p.name ORDER BY revenue DESC LIMIT 10;

-- 3. Baseline: lưu nguyên văn output của ba câu EXPLAIN ANALYZE.
EXPLAIN ANALYZE
SELECT p.product_id,p.name,SUM(oi.line_total) AS revenue
FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
JOIN product_variant v ON v.variant_id=oi.variant_id JOIN product p ON p.product_id=v.product_id
WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED')
GROUP BY p.product_id,p.name ORDER BY revenue DESC LIMIT 10;

SET @from_at := '2025-01-01 00:00:00';
SET @to_at := '2026-01-01 00:00:00';
EXPLAIN ANALYZE
SELECT oi.seller_id,SUM(oi.line_total) AS revenue
FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED')
  AND o.created_at>=@from_at AND o.created_at<@to_at
GROUP BY oi.seller_id ORDER BY revenue DESC LIMIT 10;

EXPLAIN ANALYZE
SELECT i.seller_id,i.variant_id,i.quantity_on_hand,i.reserved_quantity,i.reorder_level
FROM inventory i
WHERE i.quantity_on_hand-i.reserved_quantity<=i.reorder_level;

-- 4. Thí nghiệm chỉ mục. Chạy riêng trên DB sao lưu, kiểm tra SHOW INDEX trước khi tạo.
-- Ghi kết quả tối ưu cả khi trình tối ưu KHÔNG chọn chỉ mục mới: kết luận "không cải thiện"
-- cũng là một kết quả hợp lệ và phải được báo cáo trung thực.
-- CREATE INDEX idx_order_item_order_seller_total ON order_item(order_id,seller_id,line_total);
-- CREATE INDEX idx_inventory_reorder_lookup ON inventory(seller_id,variant_id,quantity_on_hand,reserved_quantity,reorder_level);
-- CREATE INDEX idx_product_variant_product_price ON product_variant(product_id,status,price);

-- 5. Optimized: chạy lại đúng ba truy vấn sau khi đã tạo index.
EXPLAIN ANALYZE
SELECT p.product_id,p.name,SUM(oi.line_total) AS revenue
FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
JOIN product_variant v ON v.variant_id=oi.variant_id JOIN product p ON p.product_id=v.product_id
WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED')
GROUP BY p.product_id,p.name ORDER BY revenue DESC LIMIT 10;

EXPLAIN ANALYZE
SELECT oi.seller_id,SUM(oi.line_total) AS revenue
FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED')
  AND o.created_at>=@from_at AND o.created_at<@to_at
GROUP BY oi.seller_id ORDER BY revenue DESC LIMIT 10;

EXPLAIN ANALYZE
SELECT i.seller_id,i.variant_id,i.quantity_on_hand,i.reserved_quantity,i.reorder_level
FROM inventory i
WHERE i.quantity_on_hand-i.reserved_quantity<=i.reorder_level;

-- 6. Đo dung lượng sau thí nghiệm (đã bật information_schema_stats_expiry=0 ở bước 0).
SELECT table_name,table_rows,data_length,index_length
FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name IN ('orders','order_item','product_variant','inventory')
ORDER BY table_name;

-- 7. Đo chi phí ghi: so sánh thời gian INSERT khi chưa có và đã có chỉ mục thử nghiệm.
-- Bảng sao không mang theo trigger nên phép đo chỉ phản ánh chi phí ghi do chỉ mục.
-- CREATE TABLE order_item_bench LIKE order_item;
-- INSERT INTO order_item_bench(order_id,seller_id,variant_id,product_name_snapshot,sku_snapshot,unit_price,quantity,line_discount,line_total)
--   SELECT o.order_id,oi.seller_id,oi.variant_id,oi.product_name_snapshot,oi.sku_snapshot,oi.unit_price,oi.quantity,oi.line_discount,oi.line_total
--   FROM orders o JOIN order_item oi ON oi.order_id=o.order_id LIMIT 10000;
-- -- đo lại: DROP TABLE order_item_bench; CREATE TABLE order_item_bench LIKE order_item;
-- -- tạo index trên bảng sao rồi lặp lại phép INSERT trên, so sánh thời gian.
-- Lặp tối thiểu 5 lần và lấy trung vị.

-- 8. Dọn chỉ mục thử nghiệm sau khi đã lưu output.
-- DROP INDEX idx_order_item_order_seller_total ON order_item;
-- DROP INDEX idx_inventory_reorder_lookup ON inventory;
-- DROP INDEX idx_product_variant_product_price ON product_variant;
-- DROP TABLE IF EXISTS order_item_bench;
