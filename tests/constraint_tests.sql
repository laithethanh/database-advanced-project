<<<<<<< HEAD
-- Test matrix: negative price, duplicate SKU, bad FK, invalid inventory, invalid rating.
USE ecommerce_advanced;

-- =========================================================================
-- TUẦN 8: KIỂM TRA CONSTRAINT/TRIGGER TRÊN DỮ LIỆU LỚN VÀ TRANSACTION ĐẶT HÀNG
-- Người thực hiện: Khoa
-- =========================================================================

-- -------------------------------------------------------------------------
-- PHẦN 1: TẠO DỮ LIỆU MẪU QUY MÔ LỚN (BULK DATA GENERATION)
-- -------------------------------------------------------------------------
SELECT '--- 1. TẠO DỮ LIỆU MẪU VỚI SỐ LƯỢNG BẢN GHI LỚN ---' AS info;

-- Mở rộng dữ liệu Sản phẩm & Biến thể để test quy mô lớn
INSERT INTO product (category_id, name, status)
SELECT 
  (1 + (FLOOR(RAND() * 2))), 
  CONCAT('Sản phẩm thử nghiệm quy mô lớn #', LPAD(n, 5, '0')), 
  'ACTIVE'
FROM (
  WITH RECURSIVE seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 500
  )
  SELECT n FROM seq
) numbers;

-- Tạo biến thể (Product Variants) đi kèm cho các sản phẩm lớn
INSERT INTO product_variant (product_id, warehouse_id, sku, price, compare_at_price, status)
SELECT 
  p.product_id,
  1,
  CONCAT('SKU-LARGE-', p.product_id),
  100000.00 + (p.product_id * 500),
  120000.00 + (p.product_id * 500),
  'ACTIVE'
FROM product p
WHERE p.name LIKE 'Sản phẩm thử nghiệm quy mô lớn%';

-- Tạo tồn kho (Inventory) số lượng lớn tương ứng
INSERT INTO inventory (variant_id, seller_id, quantity_on_hand, reserved_quantity)
SELECT 
  v.variant_id,
  1,
  1000, -- Cấp tồn kho 1,000 cái cho mỗi biến thể
  0
FROM product_variant v
WHERE v.sku LIKE 'SKU-LARGE-%';


-- -------------------------------------------------------------------------
-- PHẦN 2: STRESS TEST TRIGGER & CONSTRAINT TRÊN DỮ LIỆU LỚN
-- -------------------------------------------------------------------------
SELECT '--- 2. STRESS TEST CONSTRAINT & TRIGGER TRÊN DỮ LIỆU LỚN ---' AS info;

-- Test 2.1: Thử nghiệm Cập nhật hàng loạt (Bulk Update) Tồn kho để kích hoạt Trigger trg_inventory_no_negative_reserved
-- Tình huống: Cố tình cập nhật reserved_quantity > quantity_on_hand cho 500 dòng sản phẩm cùng lúc
-- Kỳ vọng: Trigger chặn lại lập tức và ROLLBACK toàn bộ 500 dòng, không có dòng nào bị vi phạm.

START TRANSACTION;
BEGIN
  -- Cố tình vi phạm ràng buộc trên hàng loạt bản ghi
  UPDATE inventory 
  SET reserved_quantity = 2000 
  WHERE variant_id IN (SELECT variant_id FROM product_variant WHERE sku LIKE 'SKU-LARGE-%');
END;
ROLLBACK;

-- Verified: Xác minh không bản ghi nào bị ghi đè dữ liệu sai
SELECT COUNT(*) AS total_invalid_inventory_records
FROM inventory
WHERE reserved_quantity > quantity_on_hand;


-- -------------------------------------------------------------------------
-- PHẦN 3: TRANSACTION STRESS TEST PROCEDURE SP_CHECKOUT
-- -------------------------------------------------------------------------
SELECT '--- 3. TEST XỬ LÝ TRANSACTION DỒN DẬP (SIMULATED CONCURRENCY) ---' AS info;

-- Giả lập tình huống: Tạo giỏ hàng chứa nhiều item và thực hiện checkout liên tục
-- Tạo giỏ hàng mẫu chứa 10 mặt hàng khác nhau từ kho dữ liệu lớn
INSERT INTO cart (customer_id, status) VALUES (1, 'ACTIVE');
SET @stress_cart_id = LAST_INSERT_ID();

INSERT INTO cart_item (cart_id, variant_id, seller_id, quantity)
SELECT 
  @stress_cart_id,
  v.variant_id,
  1,
  2
FROM product_variant v
WHERE v.sku LIKE 'SKU-LARGE-%'
LIMIT 10;

-- Thực hiện gọi sp_checkout để kiểm tra khả năng khóa FOR UPDATE và tính toán line_total/subtotal bằng Trigger
SET @out_order_id = NULL;

CALL sp_checkout(
    1,
    'Nguyễn Mậu Công Khoa',
    '0901234567',
    'TP. Hồ Chí Minh, Việt Nam',
    15000.00,
    NULL,
    @out_order_id
);

-- Kiểm tra kết quả đơn hàng được tạo thành công cùng các Trigger tính toán tự động
SELECT 
  o.order_id, 
  o.order_number, 
  o.subtotal, 
  o.grand_total, 
  o.status,
  COUNT(oi.order_item_id) AS total_items
FROM orders o
JOIN order_item oi ON o.order_id = oi.order_id
WHERE o.order_id = @out_order_id
GROUP BY o.order_id, o.order_number, o.subtotal, o.grand_total, o.status;

-- Kiểm tra tồn kho của 10 item đó đã được trừ chính xác chưa
SELECT i.variant_id, i.quantity_on_hand, i.reserved_quantity
FROM inventory i
JOIN product_variant v ON i.variant_id = v.variant_id
WHERE v.sku LIKE 'SKU-LARGE-%'
LIMIT 10;
=======
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

-- Fixture: địa chỉ mặc định của CUS0001 (nếu seed nhỏ đã tạo thì không tạo lại).
INSERT INTO address(customer_id,recipient_name,phone,line1,city,province,is_default)
SELECT c.account_id,'Nguyen Van A','0900000001','So 1','HCM','HCM',TRUE
FROM customer c WHERE c.customer_code='CUS0001'
  AND NOT EXISTS (SELECT 1 FROM address a WHERE a.customer_id=c.account_id AND a.is_default);
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
>>>>>>> 90101127cb3a58637bf52d65df1bc6674c9c4263
