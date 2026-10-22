-- Kiểm thử ràng buộc tự động: mỗi CALL dưới đây phải trả về PASS.
-- Chạy trên database mẫu mới dựng: 01, 02, 03, 04, 05.
-- 03_seed_small.sql cung cấp fixture: CUS0001, SEL0001, SKU-DEMO-001.
USE ecommerce_advanced;

DROP PROCEDURE IF EXISTS test_expect_error;
DELIMITER $$
CREATE PROCEDURE test_expect_error(IN p_name VARCHAR(120), IN p_sql TEXT)
BEGIN
  DECLARE v_error INT DEFAULT 0;
  DECLARE v_state CHAR(5) DEFAULT '00000';
  DECLARE v_message TEXT;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_state=RETURNED_SQLSTATE, v_message=MESSAGE_TEXT;
      SET v_error=1;
    END;
    SET @test_sql=p_sql;
    PREPARE test_stmt FROM @test_sql;
    EXECUTE test_stmt;
    DEALLOCATE PREPARE test_stmt;
  END;
  IF v_error=0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='test case unexpectedly succeeded';
  END IF;
  SELECT p_name AS test_name,v_state AS error_sqlstate,v_message AS error_message,'PASS' AS result;
END$$
DELIMITER ;

CALL test_expect_error('blank account email',
  'INSERT INTO account(email,password_hash,full_name) VALUES('''',''hash'',''Blank'')');
CALL test_expect_error('negative variant price',
  'INSERT INTO product_variant(warehouse_id,product_id,sku,color,size,price) VALUES(1,1,''BAD-NEG'',''x'',''x'',-1)');
CALL test_expect_error('duplicate variant sku',
  'INSERT INTO product_variant(warehouse_id,product_id,sku,color,size,price) VALUES(1,1,''SKU-DEMO-001'',''x'',''x'',1)');
CALL test_expect_error('unknown product category',
  'INSERT INTO product(category_id,name,slug,status) VALUES(999999,''bad'',''bad-fk-product'',''ACTIVE'')');
CALL test_expect_error('reserved exceeds on hand',
  'UPDATE inventory SET reserved_quantity=quantity_on_hand+1 WHERE seller_id=(SELECT account_id FROM seller WHERE seller_code=''SEL0001'') AND variant_id=(SELECT variant_id FROM product_variant WHERE sku=''SKU-DEMO-001'')');
CALL test_expect_error('second active cart',
  'INSERT INTO cart(customer_id,status) SELECT account_id,''ACTIVE'' FROM customer WHERE customer_code=''CUS0001''');

INSERT INTO address(customer_id,recipient_name,phone,line1,city,province,is_default)
SELECT account_id,'Nguyen Van A','0900000001','So 1','HCM','HCM',TRUE
FROM customer WHERE customer_code='CUS0001';
CALL test_expect_error('second default address',
  'INSERT INTO address(customer_id,recipient_name,phone,line1,city,province,is_default) SELECT account_id,''Nguyen Van A'',''0900000001'',''So 2'',''HCM'',''HCM'',TRUE FROM customer WHERE customer_code=''CUS0001''');

-- Các bất biến phải trả về 0 sau khi chạy các test trên.
SELECT COUNT(*) AS invalid_inventory FROM inventory WHERE reserved_quantity>quantity_on_hand;
SELECT COUNT(*) AS invalid_order_totals FROM orders o
WHERE o.subtotal<>(SELECT COALESCE(SUM(line_total),0) FROM order_item oi WHERE oi.order_id=o.order_id);
SELECT COUNT(*) AS invalid_order_discounts FROM orders o
WHERE o.discount_total<>(SELECT COALESCE(SUM(discount_amount),0) FROM order_promotion op WHERE op.order_id=o.order_id);
SELECT COUNT(*) AS invalid_grand_totals FROM orders o
WHERE o.grand_total<>o.subtotal-o.discount_total+o.shipping_fee;
SELECT COUNT(*) AS invalid_line_totals FROM order_item oi
WHERE oi.line_total<>oi.quantity*oi.unit_price-oi.line_discount;
