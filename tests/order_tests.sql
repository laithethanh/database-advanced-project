-- Order tests; run after 04_functions.sql and 05_triggers.sql on a freshly seeded DB.
USE ecommerce_advanced;
SELECT o.order_id,o.status,o.subtotal,o.discount_total,o.shipping_fee,o.grand_total,SUM(oi.line_total) AS item_sum
FROM orders o JOIN order_item oi ON oi.order_id=o.order_id GROUP BY o.order_id,o.status,o.subtotal,o.discount_total,o.shipping_fee,o.grand_total
HAVING o.subtotal<>SUM(oi.line_total) OR o.grand_total<>o.subtotal-o.discount_total+o.shipping_fee;
-- Expected failure cases, executed separately:
-- UPDATE orders SET status='SHIPPED' WHERE order_id=(SELECT order_id FROM (SELECT MIN(order_id) AS order_id FROM orders) x);
-- UPDATE orders SET grand_total=-1 WHERE order_id=(SELECT order_id FROM (SELECT MIN(order_id) AS order_id FROM orders) x);
-- INSERT INTO payment(order_id,provider,amount,status) VALUES(1,'TEST',1,'SUCCESS');
-- UPDATE order_item SET quantity=2 WHERE order_id=(SELECT order_id FROM (SELECT MIN(order_id) AS order_id FROM orders WHERE status='PAID') x) LIMIT 1;
-- CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code='CUS0001'),'A','0900000001','HCM',-1,NULL,@x);
-- CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code='CUS0001'),'A','0900000001','HCM',0,'INVALID-CODE',@x);
