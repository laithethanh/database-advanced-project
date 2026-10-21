-- Kiểm thử áp dụng nhiều mã giảm giá trên một đơn.
-- Chạy sau 01_schema, 02_constraints, 03_seed_small, 04_functions, 05_triggers
-- và tests/constraint_tests.sql (để có sẵn thủ tục test_expect_error).
USE ecommerce_advanced;

-- Fixture: hai mã cho kịch bản cộng dồn bình thường. Idempotent để chạy lại được.
INSERT INTO promotion(code,name,promotion_type,discount_value,min_order_amount,max_discount,start_at,end_at,status,usage_limit,used_count)
VALUES
  ('T10K','Test fixed 10k','FIXED',10000,0,NULL,UTC_TIMESTAMP()-INTERVAL 1 DAY,UTC_TIMESTAMP()+INTERVAL 1 DAY,'ACTIVE',100,0),
  ('T10P','Test percent 10','PERCENT',10,0,50000,UTC_TIMESTAMP()-INTERVAL 1 DAY,UTC_TIMESTAMP()+INTERVAL 1 DAY,'ACTIVE',100,0)
ON DUPLICATE KEY UPDATE status='ACTIVE',usage_limit=100,used_count=0,
  start_at=UTC_TIMESTAMP()-INTERVAL 1 DAY,end_at=UTC_TIMESTAMP()+INTERVAL 1 DAY;

-- Bảo đảm khách hàng có một giỏ ACTIVE chứa đúng một dòng hàng hợp lệ.
INSERT INTO cart(customer_id,status)
SELECT c.account_id,'ACTIVE' FROM customer c
WHERE c.customer_code='CUS0001'
  AND NOT EXISTS (SELECT 1 FROM cart x WHERE x.customer_id=c.account_id AND x.status='ACTIVE');

INSERT INTO cart_item(cart_id,seller_id,variant_id,quantity)
SELECT c.cart_id,i.seller_id,i.variant_id,1
FROM cart c
JOIN product_variant v ON v.sku='SKU-DEMO-001'
JOIN inventory i ON i.variant_id=v.variant_id AND i.seller_id=(SELECT account_id FROM seller WHERE seller_code='SEL0001')
WHERE c.customer_id=(SELECT account_id FROM customer WHERE customer_code='CUS0001')
  AND c.status='ACTIVE'
  AND NOT EXISTS (SELECT 1 FROM cart_item ci WHERE ci.cart_id=c.cart_id AND ci.seller_id=i.seller_id AND ci.variant_id=i.variant_id);

-- Kịch bản A: đơn 100000 dùng T10K + T10P, phí ship 30000.
-- Kỳ vọng: 2 dòng order_promotion (10000 + 10000), discount_total=20000, grand_total=110000.
CALL sp_checkout(
  (SELECT account_id FROM customer WHERE customer_code='CUS0001'),
  'Nguyen Van A','0900000001','HCM',30000,'T10K,T10P',@order_a);

SELECT @order_a AS order_id_a,
       (SELECT COUNT(*) FROM order_promotion WHERE order_id=@order_a) AS promo_rows,
       (SELECT COALESCE(SUM(discount_amount),0) FROM order_promotion WHERE order_id=@order_a) AS promo_sum,
       (SELECT discount_total FROM orders WHERE order_id=@order_a) AS order_discount_total,
       (SELECT grand_total FROM orders WHERE order_id=@order_a) AS order_grand_total;

-- Fixture: hai mã cố định 60000 để kiểm tra cap tại subtotal.
INSERT INTO promotion(code,name,promotion_type,discount_value,min_order_amount,max_discount,start_at,end_at,status,usage_limit,used_count)
VALUES
  ('T60A','Test cap A','FIXED',60000,0,NULL,UTC_TIMESTAMP()-INTERVAL 1 DAY,UTC_TIMESTAMP()+INTERVAL 1 DAY,'ACTIVE',100,0),
  ('T60B','Test cap B','FIXED',60000,0,NULL,UTC_TIMESTAMP()-INTERVAL 1 DAY,UTC_TIMESTAMP()+INTERVAL 1 DAY,'ACTIVE',100,0)
ON DUPLICATE KEY UPDATE status='ACTIVE',usage_limit=100,used_count=0,
  start_at=UTC_TIMESTAMP()-INTERVAL 1 DAY,end_at=UTC_TIMESTAMP()+INTERVAL 1 DAY;

-- Tạo lại giỏ ACTIVE cho cùng khách hàng sau khi giỏ của kịch bản A đã CHECKED_OUT.
INSERT INTO cart(customer_id,status)
SELECT c.account_id,'ACTIVE' FROM customer c
WHERE c.customer_code='CUS0001'
  AND NOT EXISTS (SELECT 1 FROM cart x WHERE x.customer_id=c.account_id AND x.status='ACTIVE');

INSERT INTO cart_item(cart_id,seller_id,variant_id,quantity)
SELECT c.cart_id,i.seller_id,i.variant_id,1
FROM cart c
JOIN product_variant v ON v.sku='SKU-DEMO-001'
JOIN inventory i ON i.variant_id=v.variant_id AND i.seller_id=(SELECT account_id FROM seller WHERE seller_code='SEL0001')
WHERE c.customer_id=(SELECT account_id FROM customer WHERE customer_code='CUS0001')
  AND c.status='ACTIVE'
  AND NOT EXISTS (SELECT 1 FROM cart_item ci WHERE ci.cart_id=c.cart_id AND ci.seller_id=i.seller_id AND ci.variant_id=i.variant_id);

-- Kịch bản B: subtotal 100000, hai mã 60000 mỗi mã.
-- Kỳ vọng: phân bổ tuần tự 60000 + 40000, discount_total=100000, grand_total=30000 (chỉ còn phí ship).
CALL sp_checkout(
  (SELECT account_id FROM customer WHERE customer_code='CUS0001'),
  'Nguyen Van A','0900000001','HCM',30000,'T60A,T60B',@order_b);

SELECT @order_b AS order_id_b,
       (SELECT COUNT(*) FROM order_promotion WHERE order_id=@order_b) AS promo_rows,
       (SELECT COALESCE(SUM(discount_amount),0) FROM order_promotion WHERE order_id=@order_b) AS promo_sum,
       (SELECT discount_total FROM orders WHERE order_id=@order_b) AS order_discount_total,
       (SELECT grand_total FROM orders WHERE order_id=@order_b) AS order_grand_total;

-- Các trường hợp phải thất bại (dùng test_expect_error để bắt lỗi và tiếp tục).
SET @orders_before_fail := (SELECT COUNT(*) FROM orders);
SET @used_before_fail := (SELECT COALESCE(SUM(used_count),0) FROM promotion WHERE code IN ('T10K','T10P','T60A','T60B'));
SET @carts_before_fail := (SELECT COUNT(*) FROM cart WHERE customer_id=(SELECT account_id FROM customer WHERE customer_code='CUS0001') AND status='ACTIVE');

CALL test_expect_error('duplicate promotion code in one checkout',
  'CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code=''CUS0001''),''A'',''0900000001'',''HCM'',0,''T10K,T10K'',@x)');
CALL test_expect_error('unknown promotion code in list',
  'CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code=''CUS0001''),''A'',''0900000001'',''HCM'',0,''T10K,NO-SUCH'',@x)');
CALL test_expect_error('more than five promotion codes',
  'CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code=''CUS0001''),''A'',''0900000001'',''HCM'',0,''A,B,C,D,E,F'',@x)');
CALL test_expect_error('promotion cannot be attached to a paid order',
  'INSERT INTO order_promotion(order_id,promotion_id,discount_amount,promotion_code_snapshot) VALUES(@order_a,(SELECT promotion_id FROM promotion WHERE code=''T10K''),1,''T10K'')');

-- Sau các lỗi trên: không có đơn mới, used_count không đổi, số giỏ ACTIVE không đổi.
SELECT @orders_before_fail AS orders_before,(SELECT COUNT(*) FROM orders) AS orders_after,
       @used_before_fail AS used_before,(SELECT COALESCE(SUM(used_count),0) FROM promotion WHERE code IN ('T10K','T10P','T60A','T60B')) AS used_after,
       @carts_before_fail AS active_carts_before,
       (SELECT COUNT(*) FROM cart WHERE customer_id=(SELECT account_id FROM customer WHERE customer_code='CUS0001') AND status='ACTIVE') AS active_carts_after;

SELECT code,used_count FROM promotion WHERE code IN ('T10K','T10P','T60A','T60B') ORDER BY code;

-- Bất biến: mọi đơn phải có discount_total bằng tổng order_promotion.
SELECT COUNT(*) AS invalid_order_discounts
FROM orders o
WHERE o.discount_total<>(SELECT COALESCE(SUM(discount_amount),0) FROM order_promotion op WHERE op.order_id=o.order_id);
