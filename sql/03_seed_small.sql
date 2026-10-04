USE ecommerce_advanced;

INSERT INTO account (email, password_hash, full_name, phone) VALUES
('customer01@example.test', 'demo-hash', 'Nguyen Van A', '0900000001'),
('seller01@example.test', 'demo-hash', 'Tran Van B', '0900000002');

INSERT INTO customer (account_id, customer_code)
SELECT account_id, 'CUS0001' FROM account WHERE email = 'customer01@example.test';

INSERT INTO seller (account_id, seller_code, shop_name, shop_status)
SELECT account_id, 'SEL0001', 'Shop Demo', 'ACTIVE' FROM account WHERE email = 'seller01@example.test';

INSERT INTO category (name, slug) VALUES ('Điện tử', 'dien-tu');
INSERT INTO warehouse (code, name) VALUES ('WH-HCM-01', 'Kho TP.HCM');

INSERT INTO product (seller_id, category_id, name, slug, status)
SELECT s.account_id, c.category_id, 'Sản phẩm Demo', 'san-pham-demo', 'ACTIVE'
FROM seller s CROSS JOIN category c
WHERE s.seller_code = 'SEL0001' AND c.slug = 'dien-tu';

INSERT INTO product_variant (product_id, sku, color, size, price)
SELECT product_id, 'SKU-DEMO-001', 'Black', 'M', 100000
FROM product WHERE slug = 'san-pham-demo';

INSERT INTO inventory (warehouse_id, variant_id, quantity_on_hand, reserved_quantity, reorder_level)
SELECT w.warehouse_id, v.variant_id, 100, 0, 10
FROM warehouse w CROSS JOIN product_variant v
WHERE w.code = 'WH-HCM-01' AND v.sku = 'SKU-DEMO-001';
