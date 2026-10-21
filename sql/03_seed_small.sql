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
