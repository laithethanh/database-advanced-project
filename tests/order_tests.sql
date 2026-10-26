<<<<<<< HEAD
-- Test matrix: success, insufficient stock, mid-transaction failure, invalid state transition.
START TRANSACTION;
-- Khóa dòng tồn kho của sản phẩm có variant_id = 1 để độc quyền xử lý
SELECT variant_id, quantity_on_hand, reserved_quantity 
FROM inventory 
WHERE variant_id = 1 
FOR UPDATE;


-- Mở giao dịch mới và cố gắng cập nhật chính biến thể đang bị Session 1 khóa
START TRANSACTION;
UPDATE inventory 
SET reserved_quantity = reserved_quantity + 1 
WHERE variant_id = 1;
-- Lúc này Session 2 sẽ bị treo (waiting for lock) cho đến khi Session 1 giải phóng.
=======
-- Kiểm thử đơn hàng; chạy sau 04_functions.sql, 05_triggers.sql,
-- tests/constraint_tests.sql và tests/promotion_tests.sql trên database mẫu mới
-- (đã nạp 03_seed_small.sql: cần fixture CUS0001, SEL0001, SKU-DEMO-001).
USE ecommerce_advanced;

SELECT o.order_id,o.status,o.subtotal,o.discount_total,o.shipping_fee,o.grand_total,SUM(oi.line_total) AS item_sum
FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
GROUP BY o.order_id,o.status,o.subtotal,o.discount_total,o.shipping_fee,o.grand_total
HAVING o.subtotal<>SUM(oi.line_total) OR o.grand_total<>o.subtotal-o.discount_total+o.shipping_fee;

SET @paid_order := (SELECT MIN(order_id) FROM orders WHERE status='PAID');
SET @paid_item := (SELECT MIN(order_item_id) FROM order_item WHERE order_id=@paid_order);
SELECT IF(@paid_order IS NULL,'FIXTURE_MISSING: chạy promotion_tests.sql trước','FIXTURE_OK') AS fixture_status;

CALL test_expect_error('jump PAID to DELIVERED',
  CONCAT('UPDATE orders SET status=''DELIVERED'' WHERE order_id=',@paid_order));
CALL test_expect_error('negative order total',
  CONCAT('UPDATE orders SET grand_total=-1 WHERE order_id=',@paid_order));
CALL test_expect_error('successful payment amount mismatch',
  CONCAT('INSERT INTO payment(order_id,provider,amount,status) VALUES(',@paid_order,',''TEST'',1,''SUCCESS'')'));
CALL test_expect_error('paid order item is immutable',
  CONCAT('UPDATE order_item SET quantity=quantity+1 WHERE order_item_id=',@paid_item));
CALL test_expect_error('negative shipping fee',
  'CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code=''CUS0001''),''A'',''0900000001'',''HCM'',-1,NULL,@x)');
CALL test_expect_error('unknown promotion code',
  'CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code=''CUS0001''),''A'',''0900000001'',''HCM'',0,''INVALID-CODE'',@x)');

-- Chuẩn bị fixture: mã khuyến mãi đã hết lượt + một giỏ ACTIVE có sẵn hàng.
-- Các câu này idempotent để có thể chạy lại nhiều lần trên cùng database mẫu.
INSERT INTO promotion(code,name,promotion_type,discount_value,min_order_amount,max_discount,start_at,end_at,status,usage_limit,used_count)
VALUES('LIMIT0','Usage limit reached','FIXED',1000,0,NULL,UTC_TIMESTAMP()-INTERVAL 1 DAY,UTC_TIMESTAMP()+INTERVAL 1 DAY,'ACTIVE',1,1)
ON DUPLICATE KEY UPDATE status='ACTIVE',usage_limit=1,used_count=1,
  start_at=UTC_TIMESTAMP()-INTERVAL 1 DAY,end_at=UTC_TIMESTAMP()+INTERVAL 1 DAY;

INSERT INTO cart(customer_id,status)
SELECT c.account_id,'ACTIVE' FROM customer c
WHERE c.customer_code='CUS0001'
  AND NOT EXISTS (SELECT 1 FROM cart x WHERE x.customer_id=c.account_id AND x.status='ACTIVE');

INSERT INTO cart_item(cart_id,seller_id,variant_id,quantity)
SELECT c.cart_id,i.seller_id,i.variant_id,1
FROM cart c
JOIN inventory i ON i.variant_id=(SELECT variant_id FROM product_variant WHERE sku='SKU-DEMO-001')
WHERE c.customer_id=(SELECT account_id FROM customer WHERE customer_code='CUS0001') AND c.status='ACTIVE'
  AND i.seller_id=(SELECT account_id FROM seller WHERE seller_code='SEL0001')
  AND NOT EXISTS (SELECT 1 FROM cart_item ci WHERE ci.cart_id=c.cart_id AND ci.seller_id=i.seller_id AND ci.variant_id=i.variant_id);

SET @orders_before := (SELECT COUNT(*) FROM orders);
SET @stock_before := (SELECT i.quantity_on_hand FROM inventory i JOIN product_variant v ON v.variant_id=i.variant_id
  WHERE v.sku='SKU-DEMO-001' AND i.seller_id=(SELECT account_id FROM seller WHERE seller_code='SEL0001'));
CALL test_expect_error('promotion limit rollback after stock update',
  'CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code=''CUS0001''),''A'',''0900000001'',''HCM'',0,''LIMIT0'',@x)');
SELECT @orders_before AS orders_before,(SELECT COUNT(*) FROM orders) AS orders_after,
       @stock_before AS stock_before,
       (SELECT i.quantity_on_hand FROM inventory i JOIN product_variant v ON v.variant_id=i.variant_id
        WHERE v.sku='SKU-DEMO-001' AND i.seller_id=(SELECT account_id FROM seller WHERE seller_code='SEL0001')) AS stock_after,
       (SELECT status FROM cart WHERE customer_id=(SELECT account_id FROM customer WHERE customer_code='CUS0001')
        AND status='ACTIVE' LIMIT 1) AS cart_status,
       (SELECT used_count FROM promotion WHERE code='LIMIT0') AS promotion_used_count;

SELECT 'ORDER_DATA_OK' AS check_name,COUNT(*) AS violations
FROM orders o
WHERE o.subtotal<>(SELECT COALESCE(SUM(line_total),0) FROM order_item oi WHERE oi.order_id=o.order_id)
   OR o.grand_total<>o.subtotal-o.discount_total+o.shipping_fee;
>>>>>>> 90101127cb3a58637bf52d65df1bc6674c9c4263
