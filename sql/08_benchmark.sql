-- Chỉ dùng cho thí nghiệm đo hiệu năng. KHÔNG chạy trên cơ sở dữ liệu lược đồ chuẩn:
-- Tệp này thêm/xóa các chỉ mục thử nghiệm. Lưu lại đầu ra EXPLAIN ANALYZE của từng lần chạy.
USE ecommerce_advanced;

-- Ghi số lượng bản ghi và phiên bản máy chủ trong data/benchmark/<run>/metadata.md.
SELECT VERSION() AS mysql_version,@@version_comment AS server_comment,@@transaction_isolation AS isolation_level;
SELECT COUNT(*) AS orders_count FROM orders;
SELECT COUNT(*) AS order_items_count FROM order_item;

-- Q01 cơ sở: chạy làm nóng ba lần, sau đó thêm EXPLAIN ANALYZE trước câu SELECT này.
SELECT p.product_id,p.name,SUM(oi.line_total) AS revenue
FROM orders o JOIN order_item oi ON oi.order_id=o.order_id JOIN product_variant v ON v.variant_id=oi.variant_id JOIN product p ON p.product_id=v.product_id
WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') GROUP BY p.product_id,p.name ORDER BY revenue DESC LIMIT 10;

-- Q21A cơ sở: người bán có doanh thu cao nhất trong khoảng ngày. Có thể đổi mốc thời gian nhưng phải giữ giống nhau giữa các lần chạy.
SET @from_at := '2025-01-01 00:00:00'; SET @to_at := '2026-01-01 00:00:00';
SELECT oi.seller_id,SUM(oi.line_total) AS revenue FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') AND o.created_at>=@from_at AND o.created_at<@to_at
GROUP BY oi.seller_id ORDER BY revenue DESC LIMIT 10;

-- Q06 cơ sở: tìm kiếm hàng sắp hết.
SELECT i.seller_id,i.variant_id,i.quantity_on_hand,i.reserved_quantity,i.reorder_level FROM inventory i
WHERE i.quantity_on_hand-i.reserved_quantity<=i.reorder_level;

-- Chỉ mục thử nghiệm (không tự che giấu việc tạo trùng: hãy kiểm tra SHOW INDEX trước).
-- CREATE INDEX idx_order_item_order_seller_total ON order_item(order_id,seller_id,line_total);
-- CREATE INDEX idx_inventory_reorder_lookup ON inventory(seller_id,variant_id,quantity_on_hand,reserved_quantity,reorder_level);
-- CREATE INDEX idx_product_variant_product_price ON product_variant(product_id,status,price);

-- Chạy lại chính xác các truy vấn cơ sở, thêm EXPLAIN ANALYZE trước mỗi truy vấn.
-- Đo riêng chi phí ghi trên BẢN SAO cơ sở dữ liệu, không thực hiện trên lần chạy dùng để báo cáo:
--   đo thời gian INSERT 10.000 dòng order_item trước và sau từng chỉ mục được cân nhắc;
--   ghi DATA_LENGTH + INDEX_LENGTH trong INFORMATION_SCHEMA.TABLES trước/sau.
-- Hoàn tác thủ công lược đồ thử nghiệm sau khi thu thập bằng chứng:
-- DROP INDEX idx_order_item_order_seller_total ON order_item;
-- DROP INDEX idx_inventory_reorder_lookup ON inventory;
-- DROP INDEX idx_product_variant_product_price ON product_variant;
