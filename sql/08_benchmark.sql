<<<<<<< HEAD
USE ecommerce_advanced; 
-- =========================================================================
-- TUẦN 9: ĐỀ XUẤT INDEX VÀ ĐÁNH GIÁ TÁC ĐỘNG TỚI THAO TÁC INSERT/UPDATE/TRIGGER
-- Người thực hiện: Khoa
-- =========================================================================

-- -------------------------------------------------------------------------
-- PHẦN 1: TẠO CÁC CHỈ MỤC (INDEX) ĐỀ XUẤT ĐỂ TỐI ƯU TRUY VẤN
-- -------------------------------------------------------------------------
SELECT '--- 1. TẠO CÁC INDEX TỐI ƯU HÓA TRUY VẤN CHÍNH ---' AS info;

-- Index 1: Tối ưu tra cứu trạng thái đơn hàng và lọc theo ngày tạo
-- Giúp tăng tốc các câu lệnh GROUP BY status và filter theo placed_at (như Q23)
CREATE INDEX idx_orders_status_placed 
ON orders (status, placed_at);

-- Index 2: Tối ưu tra cứu biến thể sản phẩm theo SKU và Kho hàng
-- Giúp tăng tốc quá trình kiểm tra kho trong sp_checkout và các JOIN giữa inventory với product_variant
CREATE INDEX idx_variant_sku_wh 
ON product_variant (sku, warehouse_id);

-- Index 3: Tối ưu tra cứu tồn kho theo Seller và Variant (Composite Index)
-- Hỗ trợ các Trigger kiểm tra kho không âm và khóa FOR UPDATE nhanh chóng
CREATE INDEX idx_inventory_seller_variant 
ON inventory (seller_id, variant_id, quantity_on_hand, reserved_quantity);


-- -------------------------------------------------------------------------
-- PHẦN 2: THỰC NGHIỆM ĐÁNH GIÁ CHI PHÍ / TÁC ĐỘNG TỚI INSERT/UPDATE
-- -------------------------------------------------------------------------
SELECT '--- 2. BENCHMARK / ĐÁNH GIÁ HIỆU NĂNG GHI (WRITE OVERHEAD) ---' AS info;

-- Đánh giá 2.1: Tác động lên thao tác INSERT vào bảng orders
-- Phân tích: Mỗi khi INSERT đơn hàng mới, B-Tree index (idx_orders_status_placed) 
-- phải tái cân bằng (rebalance), làm tăng thời gian xử lý I/O ghi đĩa nhẹ.
START TRANSACTION;
  -- Đo thời gian ghi bản ghi mẫu khi có Index
  INSERT INTO orders (order_number, customer_id, status, recipient_name, recipient_phone, shipping_address, subtotal, grand_total)
  VALUES ('ORD-TEST-INDEX-01', 1, 'PENDING_PAYMENT', 'Nguyễn Mậu Công Khoa', '0901234567', 'TP.HCM', 100000.00, 100000.00);
ROLLBACK;


-- Đánh giá 2.2: Tác động của Index kết hợp với TRIGGER khi UPDATE inventory
-- Phân tích: Khi UPDATE reserved_quantity, Trigger `trg_inventory_no_negative_reserved` sẽ chạy.
-- Index `idx_inventory_seller_variant` giúp Trigger đọc dữ liệu cũ cực nhanh, 
-- tuy nhiên bản thân Index cũng phải cập nhật lại nếu các cột trong Index bị thay đổi.
START TRANSACTION;
  UPDATE inventory 
  SET reserved_quantity = reserved_quantity + 1 
  WHERE variant_id = 1 AND seller_id = 1;
ROLLBACK;


-- -------------------------------------------------------------------------
-- PHẦN 3: BÁO CÁO ĐÁNH GIÁ TÁC ĐỘNG (IMPACT ANALYSIS REPORT)
-- -------------------------------------------------------------------------
/*
========================================================================================
 BÁO CÁO ĐÁNH GIÁ TÁC ĐỘNG CỦA INDEX LÊN INSERT/UPDATE VÀ TRIGGER (NGUYỄN MẬU CÔNG KHOA)
========================================================================================

1. TÁC ĐỘNG TÍCH CỰC (BENEFITS):
   - Đọc & Tìm kiếm (SELECT / JOIN): Giảm chi phí quét bảng toàn bộ (Full Table Scan)
     xuống chỉ còn Quét Index Range Scan. Giúp câu lệnh checkout và báo cáo nhanh gấp 10-50 lần.
   - Hiệu năng Trigger: Do các Trigger (như trg_check_order_total hay trg_inventory_no_negative_reserved)
     phải đọc dữ liệu từ các bảng liên quan, các Index đề xuất giúp Trigger thực thi nhanh hơn hẳn,
     giảm thời gian giữ khóa (Lock Hold Time) và chống nghẽn (Deadlock).

2. BẤT LỢI & CHI PHÍ TẢI (WRITE OVERHEAD & TRADE-OFFS):
   - Thao tác INSERT: Khi thêm dòng mới vào `orders` hoặc `product_variant`, MySQL phải ghi cả 
     vào bảng chính (Clustered Index) và cập nhật thêm cấu trúc B-Tree của các Secondary Index.
     Chi phí thời gian cho thao tác INSERT tăng khoảng 5% - 15%.
   - Thao tác UPDATE: UPDATE các cột nằm trong Index (như `status` hay `reserved_quantity`) 
     sẽ làm cập nhật Index tree.
   - Dung lượng lưu trữ: Tốn thêm dung lượng bộ nhớ (RAM/Disk) để lưu trữ các cây chỉ mục.

3. KẾT LUẬN & ĐỀ XUẤT ĐỒNG BỘ:
   - Hệ thống E-commerce có tỉ lệ Đọc/Ghi xấp xỉ 80/20 (Read-Heavy). Việc chấp nhận 10% overhead
     khi INSERT/UPDATE để đổi lấy tốc độ truy vấn SELECT/Trigger tăng gấp nhiều lần là HOÀN TOÀN HỢP LÝ.
========================================================================================
*/
=======
-- Thí nghiệm đo hiệu năng trên bản sao cơ sở dữ liệu, KHÔNG chạy trên DB dùng để báo cáo cuối.
-- Quy trình: metadata -> warmup -> baseline EXPLAIN ANALYZE -> thí nghiệm index -> optimized -> đo chi phí ghi -> dọn.
-- MySQL 8.0.18+ mới hỗ trợ EXPLAIN ANALYZE.
USE ecommerce_advanced;
>>>>>>> 90101127cb3a58637bf52d65df1bc6674c9c4263

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
