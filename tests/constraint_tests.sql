-- Kiểm thử thủ công các trường hợp không hợp lệ: chạy RIÊNG từng câu lệnh đã chú thích. Mỗi câu phải thất bại.
USE ecommerce_advanced;
-- INSERT INTO product_variant(warehouse_id,product_id,sku,color,size,price) VALUES(1,1,'BAD-NEG','x','x',-1);
-- INSERT INTO account(email,password_hash,full_name) VALUES('','hash','Blank Email');
-- INSERT INTO product_variant(warehouse_id,product_id,sku,color,size,price) VALUES(1,1,'SKU-DEMO-001','x','x',1);
-- INSERT INTO product(category_id,name,slug,status) VALUES(999999,'bad','bad-fk-product','ACTIVE');
-- UPDATE inventory SET reserved_quantity=quantity_on_hand+1 WHERE seller_id=(SELECT account_id FROM seller WHERE seller_code='SEL0001') LIMIT 1;
-- INSERT INTO cart(customer_id,status) SELECT account_id,'ACTIVE' FROM customer WHERE customer_code='CUS0001';
-- Thêm địa chỉ mặc định thứ nhất, sau đó thêm địa chỉ mặc định thứ hai cho cùng khách hàng: câu INSERT thứ hai phải thất bại.
-- INSERT INTO address(customer_id,recipient_name,phone,line1,city,province,is_default) SELECT account_id,'A','0900000000','line','HCM','HCM',TRUE FROM customer WHERE customer_code='CUS0001';
-- INSERT INTO address(customer_id,recipient_name,phone,line1,city,province,is_default) SELECT account_id,'B','0900000000','line','HCM','HCM',TRUE FROM customer WHERE customer_code='CUS0001';
-- Thêm promotion vào đơn đã PAID: phải thất bại (trigger chỉ cho ghi khi PENDING_PAYMENT).
-- INSERT INTO order_promotion(order_id,promotion_id,discount_amount,promotion_code_snapshot) SELECT order_id,promotion_id,0,'TEST' FROM orders CROSS JOIN promotion LIMIT 1;

-- Kiểm tra bất biến hợp lệ: cả ba giá trị phải bằng 0.
SELECT COUNT(*) AS invalid_inventory FROM inventory WHERE reserved_quantity>quantity_on_hand;
SELECT COUNT(*) AS invalid_order_totals FROM orders o WHERE o.subtotal<>(SELECT COALESCE(SUM(line_total),0) FROM order_item oi WHERE oi.order_id=o.order_id);
SELECT COUNT(*) AS invalid_order_discounts FROM orders o WHERE o.discount_total<>(SELECT COALESCE(SUM(discount_amount),0) FROM order_promotion op WHERE op.order_id=o.order_id);
