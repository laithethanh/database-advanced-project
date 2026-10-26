-- Tổng quan bộ dữ liệu 100.000 đơn trước khi chạy Q01–Q25 (Phạm Thành Danh, 25/10/2026)
-- Chạy trong mysql client:  SOURCE report/appendix/queries/20261025/tong_quan_du_lieu.sql;
USE ecommerce_advanced;

SELECT VERSION() AS mysql_version, @@transaction_isolation AS isolation_level, NOW() AS thoi_diem;

-- 1. Số dòng các bảng chính (đếm chính xác)
SELECT (SELECT COUNT(*) FROM customer)        AS khach,
       (SELECT COUNT(*) FROM seller)          AS nguoi_ban,
       (SELECT COUNT(*) FROM address)         AS dia_chi,
       (SELECT COUNT(*) FROM category)        AS danh_muc,
       (SELECT COUNT(*) FROM product)         AS san_pham,
       (SELECT COUNT(*) FROM product_variant) AS bien_the,
       (SELECT COUNT(*) FROM inventory)       AS ton_kho;
SELECT (SELECT COUNT(*) FROM orders)          AS don,
       (SELECT COUNT(*) FROM order_item)      AS dong_hang,
       (SELECT COUNT(*) FROM payment)         AS thanh_toan,
       (SELECT COUNT(*) FROM shipment)        AS van_don,
       (SELECT COUNT(*) FROM review)          AS danh_gia,
       (SELECT COUNT(*) FROM promotion)       AS khuyen_mai,
       (SELECT COUNT(*) FROM order_promotion) AS luot_ap_ma,
       (SELECT COUNT(*) FROM cart)            AS gio_hang,
       (SELECT COUNT(*) FROM cart_item)       AS mon_trong_gio;

-- 2. Không có dữ liệu seed nhỏ (phải ra 0)
SELECT (SELECT COUNT(*) FROM customer WHERE customer_code = 'CUS0001') AS seed_khach,
       (SELECT COUNT(*) FROM product_variant WHERE sku = 'SKU-DEMO-001') AS seed_sku;

-- 3. Kiểm tra tính đúng (tất cả phải ra 0)
SELECT
  (SELECT COUNT(*) FROM orders o
    WHERE o.subtotal <> (SELECT COALESCE(SUM(line_total),0) FROM order_item WHERE order_id = o.order_id)) AS don_sai_tien_hang,
  (SELECT COUNT(*) FROM orders o
    WHERE o.discount_total <> (SELECT COALESCE(SUM(discount_amount),0) FROM order_promotion WHERE order_id = o.order_id)) AS don_sai_tien_giam,
  (SELECT COUNT(*) FROM payment p JOIN orders o ON o.order_id = p.order_id
    WHERE p.status = 'SUCCESS' AND p.amount <> o.grand_total) AS thanh_toan_lech,
  (SELECT COUNT(*) FROM inventory WHERE quantity_on_hand < reserved_quantity) AS ton_kho_am;

-- 4. Phân bố trạng thái đơn
SELECT status, COUNT(*) AS so_don, ROUND(COUNT(*) * 100 / (SELECT COUNT(*) FROM orders), 1) AS phan_tram
FROM orders GROUP BY status ORDER BY so_don DESC;

-- 5. Biến thể theo loại hàng (kiểm tra không còn "Nồi chảo size XL")
SELECT c.name AS loai_hang,
       GROUP_CONCAT(DISTINCT v.size ORDER BY v.size SEPARATOR ', ')  AS cac_bien_the,
       GROUP_CONCAT(DISTINCT p.brand ORDER BY p.brand SEPARATOR ', ') AS thuong_hieu,
       MIN(v.price) AS gia_thap_nhat, MAX(v.price) AS gia_cao_nhat, COUNT(DISTINCT p.product_id) AS so_san_pham
FROM product p
JOIN category c ON c.category_id = p.category_id
JOIN product_variant v ON v.product_id = p.product_id
GROUP BY c.name ORDER BY c.name;

-- 6. Dấu vân tay dữ liệu (dùng để kiểm chứng tái lập: chạy lại generator cùng seed phải ra y hệt)
SELECT
  (SELECT SUM(grand_total) FROM orders) AS tong_tien,
  (SELECT SUM(CRC32(CONCAT_WS('|', order_number, customer_id, status, grand_total, created_at))) FROM orders) AS van_tay_don,
  (SELECT SUM(CRC32(CONCAT_WS('|', order_id, seller_id, variant_id, quantity, line_total))) FROM order_item) AS van_tay_dong_hang,
  (SELECT SUM(CRC32(CONCAT_WS('|', email, full_name, phone))) FROM account WHERE email LIKE 'khach%') AS van_tay_khach;
