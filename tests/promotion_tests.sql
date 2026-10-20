-- Kiểm thử áp dụng nhiều mã giảm giá trên một đơn.
-- Chạy trên cơ sở dữ liệu mẫu MỚI sau khi đã nạp 01_schema, 02_constraints, 03_seed_small, 04_functions, 05_triggers.
USE ecommerce_advanced;

-- Fixture: hai mã cho kịch bản cộng dồn bình thường.
INSERT INTO promotion(code,name,promotion_type,discount_value,min_order_amount,max_discount,start_at,end_at,status,usage_limit)
VALUES
  ('T10K','Test fixed 10k','FIXED',10000,0,NULL,UTC_TIMESTAMP()-INTERVAL 1 DAY,UTC_TIMESTAMP()+INTERVAL 1 DAY,'ACTIVE',100),
  ('T10P','Test percent 10','PERCENT',10,0,50000,UTC_TIMESTAMP()-INTERVAL 1 DAY,UTC_TIMESTAMP()+INTERVAL 1 DAY,'ACTIVE',100);

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
INSERT INTO promotion(code,name,promotion_type,discount_value,min_order_amount,max_discount,start_at,end_at,status,usage_limit)
VALUES
  ('T60A','Test cap A','FIXED',60000,0,NULL,UTC_TIMESTAMP()-INTERVAL 1 DAY,UTC_TIMESTAMP()+INTERVAL 1 DAY,'ACTIVE',100),
  ('T60B','Test cap B','FIXED',60000,0,NULL,UTC_TIMESTAMP()-INTERVAL 1 DAY,UTC_TIMESTAMP()+INTERVAL 1 DAY,'ACTIVE',100);

-- Tạo giỏ ACTIVE mới cho cùng khách hàng sau khi giỏ cũ đã CHECKED_OUT.
INSERT INTO cart(customer_id,status)
SELECT account_id,'ACTIVE' FROM customer WHERE customer_code='CUS0001';
INSERT INTO cart_item(cart_id,seller_id,variant_id,quantity)
SELECT c.cart_id,i.seller_id,v.variant_id,1
FROM cart c
JOIN product_variant v ON v.sku='SKU-DEMO-001'
JOIN inventory i ON i.variant_id=v.variant_id
WHERE c.customer_id=(SELECT account_id FROM customer WHERE customer_code='CUS0001')
  AND c.status='ACTIVE'
  AND i.seller_id=(SELECT account_id FROM seller WHERE seller_code='SEL0001');

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

SELECT code,used_count FROM promotion WHERE code IN ('T10K','T10P','T60A','T60B') ORDER BY code;

-- Bất biến: mọi đơn phải có discount_total bằng tổng order_promotion.
SELECT COUNT(*) AS invalid_order_discounts
FROM orders o
WHERE o.discount_total<>(SELECT COALESCE(SUM(discount_amount),0) FROM order_promotion op WHERE op.order_id=o.order_id);

-- Các trường hợp dự kiến thất bại, chạy riêng từng câu trên cơ sở dữ liệu mẫu mới:
-- 1) Mã trùng trong cùng một lần gọi.
-- CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code='CUS0001'),'A','0900000001','HCM',0,'T10K,T10K',@x);
-- 2) Mã thứ hai không tồn tại: rollback, không tạo order, không tăng used_count.
-- CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code='CUS0001'),'A','0900000001','HCM',0,'T10K,NO-SUCH',@x);
-- 3) Quá 5 mã.
-- CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code='CUS0001'),'A','0900000001','HCM',0,'A,B,C,D,E,F',@x);
-- 4) Thêm promotion vào đơn đã PAID: phải bị trigger từ chối.
-- INSERT INTO order_promotion(order_id,promotion_id,discount_amount,promotion_code_snapshot) VALUES(@order_a,(SELECT promotion_id FROM promotion WHERE code='T10K'),1,'T10K');
