-- Prepare T03 last-stock contention on a fresh sample database.
USE ecommerce_advanced;
INSERT INTO account(email,password_hash,full_name,phone) VALUES
 ('concurrent01@example.test','demo-hash','Concurrent One','0900000101'),
 ('concurrent02@example.test','demo-hash','Concurrent Two','0900000102');
INSERT INTO customer(account_id,customer_code)
 SELECT account_id,CASE email WHEN 'concurrent01@example.test' THEN 'CUS2001' ELSE 'CUS2002' END FROM account
 WHERE email IN ('concurrent01@example.test','concurrent02@example.test');
SET @seller_id := (SELECT account_id FROM seller WHERE seller_code='SEL0001');
SET @variant_id := (SELECT variant_id FROM product_variant WHERE sku='SKU-DEMO-001');
UPDATE inventory SET quantity_on_hand=1,reserved_quantity=0 WHERE seller_id=@seller_id AND variant_id=@variant_id;
INSERT INTO cart(customer_id,status) SELECT account_id,'ACTIVE' FROM customer WHERE customer_code IN ('CUS2001','CUS2002');
INSERT INTO cart_item(cart_id,seller_id,variant_id,quantity)
SELECT c.cart_id,@seller_id,@variant_id,1 FROM cart c JOIN customer cu ON cu.account_id=c.customer_id WHERE cu.customer_code IN ('CUS2001','CUS2002');
SELECT cu.customer_code,c.cart_id,ci.quantity,i.quantity_on_hand-i.reserved_quantity AS available_stock
FROM cart c JOIN customer cu ON cu.account_id=c.customer_id JOIN cart_item ci ON ci.cart_id=c.cart_id
JOIN inventory i ON i.seller_id=ci.seller_id AND i.variant_id=ci.variant_id WHERE cu.customer_code IN ('CUS2001','CUS2002');
