-- Manual negative tests: execute EACH commented statement separately. It must fail.
USE ecommerce_advanced;
-- INSERT INTO product_variant(warehouse_id,product_id,sku,color,size,price) VALUES(1,1,'BAD-NEG','x','x',-1);
-- INSERT INTO account(email,password_hash,full_name) VALUES('','hash','Blank Email');
-- INSERT INTO product_variant(warehouse_id,product_id,sku,color,size,price) VALUES(1,1,'SKU-DEMO-001','x','x',1);
-- INSERT INTO product(category_id,name,slug,status) VALUES(999999,'bad','bad-fk-product','ACTIVE');
-- UPDATE inventory SET reserved_quantity=quantity_on_hand+1 WHERE seller_id=(SELECT account_id FROM seller WHERE seller_code='SEL0001') LIMIT 1;
-- INSERT INTO cart(customer_id,status) SELECT account_id,'ACTIVE' FROM customer WHERE customer_code='CUS0001';
-- Add a first default address, then a second default address for the same customer: the second INSERT must fail.
-- INSERT INTO address(customer_id,recipient_name,phone,line1,city,province,is_default) SELECT account_id,'A','0900000000','line','HCM','HCM',TRUE FROM customer WHERE customer_code='CUS0001';
-- INSERT INTO address(customer_id,recipient_name,phone,line1,city,province,is_default) SELECT account_id,'B','0900000000','line','HCM','HCM',TRUE FROM customer WHERE customer_code='CUS0001';

-- Positive invariant audit: both values must be zero.
SELECT COUNT(*) AS invalid_inventory FROM inventory WHERE reserved_quantity>quantity_on_hand;
SELECT COUNT(*) AS invalid_order_totals FROM orders o WHERE o.subtotal<>(SELECT COALESCE(SUM(line_total),0) FROM order_item oi WHERE oi.order_id=o.order_id);
