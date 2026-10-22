-- LƯU Ý: file này chỉ nạp DỮ LIỆU MẪU NHỎ (vài dòng cho mỗi bảng) dùng làm fixture cho
-- tests/*.sql, cho demo (app/) và để chạy Q01-Q25 trên dữ liệu nhỏ.
-- Dữ liệu làm việc thực tế (100.000 đơn) do data/generator/generate_data.py sinh ra và phải chạy
-- trên MỘT DATABASE RIÊNG; database đó KHÔNG nạp file seed này.
-- Thứ tự chạy trên database mẫu (ecommerce_advanced):
--   01_schema.sql -> 02_constraints.sql -> 03_seed_small.sql -> 04_functions.sql -> 05_triggers.sql
--   -> tests/*.sql -> 06_queries.sql -> 07_recursive.sql
-- Fixture do file này tạo và các file test phụ thuộc: CUS0001, SEL0001, SKU-DEMO-001.

USE ecommerce_advanced;

INSERT INTO account (email, password_hash, full_name, phone) VALUES
('customer01@example.test', 'demo-hash', 'Nguyen Van A', '0900000001'),
('seller01@example.test', 'demo-hash', 'Tran Van B', '0900000002');

INSERT INTO customer (account_id, customer_code)
SELECT account_id, 'CUS0001' FROM account WHERE email = 'customer01@example.test';

INSERT INTO seller (account_id, seller_code, shop_name, shop_status)
SELECT account_id, 'SEL0001', 'Shop Demo', 'ACTIVE'
FROM account WHERE email = 'seller01@example.test';

INSERT INTO category (name, slug)
VALUES ('Dien tu', 'dien-tu');

-- 01_schema.sql đã tạo sẵn WH-HN, WH-DN và WH-HCM.
INSERT INTO product (category_id, name, slug, description, brand, status)
SELECT category_id, 'San pham Demo', 'san-pham-demo', 'Demo catalog item', 'Demo', 'ACTIVE'
FROM category WHERE slug = 'dien-tu';

INSERT INTO product_variant
  (warehouse_id, product_id, sku, color, size, price, compare_at_price, warehouse_quantity, status)
SELECT w.warehouse_id, p.product_id, 'SKU-DEMO-001', 'Black', 'M', 100000, 120000, 100, 'ACTIVE'
FROM warehouse w CROSS JOIN product p
WHERE w.code = 'WH-HCM' AND p.slug = 'san-pham-demo';

-- Tồn kho thuộc về người bán; warehouse_quantity là số lượng tại kho nhà cung cấp.
INSERT INTO inventory (seller_id, variant_id, quantity_on_hand, reserved_quantity, reorder_level)
SELECT s.account_id, v.variant_id, 20, 0, 5
FROM seller s CROSS JOIN product_variant v
WHERE s.seller_code = 'SEL0001' AND v.sku = 'SKU-DEMO-001';

INSERT INTO cart (customer_id, status)
SELECT account_id, 'ACTIVE' FROM customer WHERE customer_code = 'CUS0001';

INSERT INTO cart_item (cart_id, seller_id, variant_id, quantity)
SELECT c.cart_id, i.seller_id, v.variant_id, 1
FROM cart c CROSS JOIN product_variant v JOIN inventory i ON i.variant_id = v.variant_id
WHERE c.status = 'ACTIVE' AND v.sku = 'SKU-DEMO-001'
  AND i.seller_id = (SELECT account_id FROM seller WHERE seller_code = 'SEL0001')
  AND c.customer_id = (SELECT account_id FROM customer WHERE customer_code = 'CUS0001');

-- ===================================================================
-- Bổ sung seed cho 11 bảng còn thiếu (hoàn tất 20/20 bảng)
-- ===================================================================

-- 10. address – Địa chỉ giao hàng mặc định
INSERT INTO address (customer_id, recipient_name, phone, line1, ward, district, city, province, postal_code, is_default)
SELECT account_id, 'Nguyen Van A', '0900000001',
       '123 Nguyen Hue', 'Phuong Ben Nghe', 'Quan 1', 'TP. Ho Chi Minh', 'TP. Ho Chi Minh', '700000', TRUE
FROM customer WHERE customer_code = 'CUS0001';

-- 11. promotion – Hai chương trình khuyến mãi (phần trăm & cố định)
INSERT INTO promotion (code, name, promotion_type, discount_value, min_order_amount, max_discount,
                       start_at, end_at, status, usage_limit, used_count)
VALUES
  ('GIAM10',  'Giam 10 phan tram don hang', 'PERCENT', 10.00,    100000, 15000,
   '2026-01-01 00:00:00', '2026-12-31 23:59:59', 'ACTIVE', 100, 1),
  ('GIAM20K', 'Giam 20K don hang',          'FIXED',   20000.00, 150000, NULL,
   '2026-01-01 00:00:00', '2026-12-31 23:59:59', 'ACTIVE', 50,  0);

-- 12. promotion_product – Gắn GIAM10 cho sản phẩm Demo
INSERT INTO promotion_product (promotion_id, product_id)
SELECT pr.promotion_id, p.product_id
FROM promotion pr CROSS JOIN product p
WHERE pr.code = 'GIAM10' AND p.slug = 'san-pham-demo';

-- 13. promotion_category – Gắn GIAM20K cho danh mục Điện tử
INSERT INTO promotion_category (promotion_id, category_id)
SELECT pr.promotion_id, c.category_id
FROM promotion pr CROSS JOIN category c
WHERE pr.code = 'GIAM20K' AND c.slug = 'dien-tu';

-- 14. orders – Đơn hàng đã giao thành công
--     Tính: đơn giá 100 000 × 2 = 200 000 (subtotal)
--           GIAM10: 10% × 200 000 = 20 000, giới hạn max 15 000 → discount = 15 000
--           Phí ship = 30 000
--           Tổng = 200 000 − 15 000 + 30 000 = 215 000
INSERT INTO orders (order_number, customer_id, status,
                    recipient_name, recipient_phone, shipping_address,
                    subtotal, discount_total, shipping_fee, grand_total, placed_at)
SELECT 'ORD-20260115-0001', cu.account_id, 'DELIVERED',
       'Nguyen Van A', '0900000001',
       '123 Nguyen Hue, Phuong Ben Nghe, Quan 1, TP. Ho Chi Minh',
       200000, 15000, 30000, 215000, '2026-01-15 10:30:00'
FROM customer cu WHERE cu.customer_code = 'CUS0001';

-- 15. order_item – Chi tiết đơn hàng
INSERT INTO order_item (order_id, seller_id, variant_id,
                        product_name_snapshot, sku_snapshot,
                        unit_price, quantity, line_discount, line_total)
SELECT o.order_id, i.seller_id, i.variant_id,
       'San pham Demo', 'SKU-DEMO-001',
       100000, 2, 15000, 185000
FROM orders o
  CROSS JOIN inventory i
  JOIN seller s  ON s.account_id  = i.seller_id
  JOIN product_variant v ON v.variant_id = i.variant_id
WHERE o.order_number = 'ORD-20260115-0001'
  AND s.seller_code  = 'SEL0001'
  AND v.sku          = 'SKU-DEMO-001';

-- 16. order_promotion – Mã khuyến mãi đã áp dụng
INSERT INTO order_promotion (order_id, promotion_id, discount_amount, promotion_code_snapshot)
SELECT o.order_id, pr.promotion_id, 15000, 'GIAM10'
FROM orders o CROSS JOIN promotion pr
WHERE o.order_number = 'ORD-20260115-0001' AND pr.code = 'GIAM10';

-- 17. payment – Thanh toán thành công qua VNPAY
INSERT INTO payment (order_id, provider, transaction_ref, amount, status, paid_at)
SELECT o.order_id, 'VNPAY', 'TXN-VNPAY-00001', 215000, 'SUCCESS', '2026-01-15 10:35:00'
FROM orders o WHERE o.order_number = 'ORD-20260115-0001';

-- 18. shipment – Vận chuyển qua GHN, đã giao
INSERT INTO shipment (order_id, carrier, tracking_number, status, shipped_at, delivered_at)
SELECT o.order_id, 'GHN', 'GHN-TRACK-00001', 'DELIVERED',
       '2026-01-16 08:00:00', '2026-01-18 14:00:00'
FROM orders o WHERE o.order_number = 'ORD-20260115-0001';

-- 19. review – Khách đánh giá 5 sao
INSERT INTO review (product_id, customer_id, order_item_id, rating, title, body, status)
SELECT p.product_id, cu.account_id, oi.order_item_id,
       5, 'San pham tot', 'Chat luong tot, giao hang nhanh, dong goi can than.', 'PUBLISHED'
FROM order_item oi
  JOIN orders o   ON o.order_id   = oi.order_id
  JOIN product p  ON p.slug       = 'san-pham-demo'
  JOIN customer cu ON cu.customer_code = 'CUS0001'
WHERE o.order_number    = 'ORD-20260115-0001'
  AND oi.sku_snapshot   = 'SKU-DEMO-001';
