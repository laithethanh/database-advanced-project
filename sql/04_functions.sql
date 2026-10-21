USE ecommerce_advanced;
DELIMITER $$
DROP FUNCTION IF EXISTS fn_promotion_discount$$
DROP PROCEDURE IF EXISTS sp_checkout$$
DROP PROCEDURE IF EXISTS sp_seller_ranking$$

CREATE FUNCTION fn_promotion_discount(
  p_subtotal DECIMAL(15,2), p_type VARCHAR(20), p_value DECIMAL(15,2), p_max_discount DECIMAL(15,2)
) RETURNS DECIMAL(15,2) DETERMINISTIC
BEGIN
  DECLARE v_discount DECIMAL(15,2) DEFAULT 0;
  IF p_subtotal<0 OR p_value<0 THEN RETURN 0; END IF;
  IF p_type='PERCENT' THEN SET v_discount=p_subtotal*p_value/100;
  ELSEIF p_type='FIXED' THEN SET v_discount=p_value; END IF;
  IF p_max_discount IS NOT NULL AND v_discount>p_max_discount THEN SET v_discount=p_max_discount; END IF;
  IF v_discount>p_subtotal THEN SET v_discount=p_subtotal; END IF;
  RETURN v_discount;
END$$

-- p_promotion_codes: danh sách mã cách nhau bởi dấu phẩy, tối đa 5 mã (ví dụ 'X,Y').
-- Mỗi mã được tính độc lập trên base đủ điều kiện của nó; tổng giảm bị cap tại subtotal
-- và phân bổ tuần tự theo promotion_id tăng dần để SUM(order_promotion) = orders.discount_total.
CREATE PROCEDURE sp_checkout(
  IN p_customer_id BIGINT UNSIGNED,
  IN p_recipient_name VARCHAR(150),
  IN p_recipient_phone VARCHAR(30),
  IN p_shipping_address VARCHAR(600),
  IN p_shipping_fee DECIMAL(15,2),
  IN p_promotion_codes VARCHAR(255),
  OUT p_order_id BIGINT UNSIGNED
)
SQL SECURITY INVOKER
BEGIN
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_cart_id BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_variant_id BIGINT UNSIGNED;
  DECLARE v_seller_id BIGINT UNSIGNED;
  DECLARE v_qty INT UNSIGNED;
  DECLARE v_price DECIMAL(15,2);
  DECLARE v_product_id BIGINT UNSIGNED;
  DECLARE v_product_name VARCHAR(255);
  DECLARE v_sku VARCHAR(80);
  DECLARE v_subtotal DECIMAL(15,2) DEFAULT 0;
  DECLARE v_discount_total DECIMAL(15,2) DEFAULT 0;
  DECLARE v_discount DECIMAL(15,2) DEFAULT 0;
  DECLARE v_applied DECIMAL(15,2) DEFAULT 0;
  DECLARE v_promo_base DECIMAL(15,2) DEFAULT 0;
  DECLARE v_order_number VARCHAR(40);
  DECLARE v_promotion_id BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_promotion_type VARCHAR(20);
  DECLARE v_promotion_value DECIMAL(15,2);
  DECLARE v_promotion_max DECIMAL(15,2);
  DECLARE v_promotion_min DECIMAL(15,2);
  DECLARE v_promotion_status VARCHAR(20);
  DECLARE v_start DATETIME;
  DECLARE v_end DATETIME;
  DECLARE v_usage_limit INT UNSIGNED;
  DECLARE v_usage_count INT DEFAULT 0;
  DECLARE v_scope_count INT DEFAULT 0;
  DECLARE v_available BIGINT DEFAULT NULL;
  DECLARE v_item_count INT DEFAULT 0;
  DECLARE v_invalid_items INT DEFAULT 0;
  DECLARE v_code VARCHAR(50);
  DECLARE v_rest VARCHAR(255);
  DECLARE v_code_count INT DEFAULT 0;

  -- Khóa các dòng hàng theo thứ tự (seller_id, variant_id) để giảm deadlock.
  DECLARE cur_items CURSOR FOR
    SELECT ci.variant_id,ci.seller_id,ci.quantity,v.price,p.product_id,p.name,v.sku
    FROM cart_item ci JOIN product_variant v ON v.variant_id=ci.variant_id JOIN product p ON p.product_id=v.product_id
    WHERE ci.cart_id=v_cart_id ORDER BY ci.seller_id,ci.variant_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done=1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF p_customer_id IS NULL OR NOT EXISTS (SELECT 1 FROM customer WHERE account_id=p_customer_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='customer does not exist';
  END IF;
  IF p_shipping_fee IS NULL OR p_shipping_fee<0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid shipping fee'; END IF;
  IF p_recipient_name IS NULL OR CHAR_LENGTH(TRIM(p_recipient_name))=0
     OR p_recipient_phone IS NULL OR CHAR_LENGTH(TRIM(p_recipient_phone))=0
     OR p_shipping_address IS NULL OR CHAR_LENGTH(TRIM(p_shipping_address))=0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='recipient and shipping address are required';
  END IF;
  IF p_promotion_codes IS NOT NULL AND CHAR_LENGTH(p_promotion_codes)>255 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='promotion code list is too long';
  END IF;

  -- Chuẩn hóa danh sách mã trước khi mở transaction.
  IF p_promotion_codes IS NOT NULL AND TRIM(p_promotion_codes)<>'' THEN
    DROP TEMPORARY TABLE IF EXISTS tmp_promo;
    CREATE TEMPORARY TABLE tmp_promo(
      seq INT AUTO_INCREMENT PRIMARY KEY,
      code VARCHAR(50) NOT NULL,
      promotion_id BIGINT UNSIGNED NULL
    );
    SET v_rest=TRIM(p_promotion_codes);
    code_loop: WHILE CHAR_LENGTH(v_rest)>0 DO
      SET v_code=TRIM(SUBSTRING_INDEX(v_rest,',',1));
      IF v_code<>'' THEN
        IF CHAR_LENGTH(v_code)>50 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='promotion code is too long'; END IF;
        INSERT INTO tmp_promo(code) VALUES(v_code);
        SET v_code_count=v_code_count+1;
      END IF;
      IF LOCATE(',',v_rest)=0 THEN LEAVE code_loop; END IF;
      SET v_rest=SUBSTRING(v_rest,LOCATE(',',v_rest)+1);
    END WHILE;
    IF v_code_count>5 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='too many promotion codes'; END IF;
    IF v_code_count>0 THEN
      IF EXISTS(SELECT 1 FROM tmp_promo GROUP BY code HAVING COUNT(*)>1) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='duplicate promotion code'; END IF;
      UPDATE tmp_promo t JOIN promotion p ON p.code=t.code SET t.promotion_id=p.promotion_id;
      IF EXISTS(SELECT 1 FROM tmp_promo WHERE promotion_id IS NULL) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='promotion code not found'; END IF;
    END IF;
  END IF;

  START TRANSACTION;
  SELECT c.cart_id INTO v_cart_id FROM cart c WHERE c.customer_id=p_customer_id AND c.status='ACTIVE' ORDER BY c.cart_id LIMIT 1 FOR UPDATE;
  IF v_cart_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='customer has no ACTIVE cart'; END IF;
  SELECT COUNT(*) INTO v_item_count FROM cart_item WHERE cart_id=v_cart_id;
  IF v_item_count=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='cannot checkout an empty cart'; END IF;
  SELECT COUNT(*) INTO v_invalid_items
  FROM cart_item ci
  JOIN product_variant v ON v.variant_id=ci.variant_id
  JOIN product p ON p.product_id=v.product_id
  JOIN warehouse w ON w.warehouse_id=v.warehouse_id
  JOIN seller s ON s.account_id=ci.seller_id
  WHERE ci.cart_id=v_cart_id
    AND NOT (v.status='ACTIVE' AND p.status='ACTIVE' AND w.status='ACTIVE' AND s.shop_status='ACTIVE');
  IF v_invalid_items>0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='cart contains a variant that is no longer sellable'; END IF;

  SET v_order_number=CONCAT('ORD-',DATE_FORMAT(UTC_TIMESTAMP(),'%Y%m%d%H%i%s'),'-',SUBSTRING(REPLACE(UUID(),'-',''),1,12));
  INSERT INTO orders(order_number,customer_id,status,recipient_name,recipient_phone,shipping_address,subtotal,discount_total,shipping_fee,grand_total,placed_at)
  VALUES(v_order_number,p_customer_id,'PENDING_PAYMENT',p_recipient_name,p_recipient_phone,p_shipping_address,0,0,p_shipping_fee,p_shipping_fee,UTC_TIMESTAMP());
  SET p_order_id=LAST_INSERT_ID();

  SET v_done=0;
  OPEN cur_items;
  item_loop: LOOP
    FETCH cur_items INTO v_variant_id,v_seller_id,v_qty,v_price,v_product_id,v_product_name,v_sku;
    IF v_done=1 THEN LEAVE item_loop; END IF;
    SET v_available=NULL;
    SELECT quantity_on_hand-reserved_quantity INTO v_available
    FROM inventory
    WHERE seller_id=v_seller_id AND variant_id=v_variant_id
    FOR UPDATE;
    IF v_available IS NULL OR v_available<v_qty THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='insufficient inventory';
    END IF;
    UPDATE inventory SET quantity_on_hand=quantity_on_hand-v_qty
    WHERE seller_id=v_seller_id AND variant_id=v_variant_id AND quantity_on_hand-reserved_quantity>=v_qty;
    IF ROW_COUNT()<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='inventory changed concurrently; checkout aborted'; END IF;
    INSERT INTO order_item(order_id,seller_id,variant_id,product_name_snapshot,sku_snapshot,unit_price,quantity,line_discount,line_total)
    VALUES(p_order_id,v_seller_id,v_variant_id,v_product_name,v_sku,v_price,v_qty,0,v_qty*v_price);
    SET v_subtotal=v_subtotal+v_qty*v_price;
  END LOOP;
  CLOSE cur_items;

  IF v_code_count>0 THEN
    BEGIN
      DECLARE v_promo_done INT DEFAULT 0;
      DECLARE cur_promos CURSOR FOR
        SELECT p.promotion_id,p.promotion_type,p.discount_value,p.max_discount,p.min_order_amount,
               p.status,p.start_at,p.end_at,p.usage_limit,p.used_count,t.code
        FROM tmp_promo t JOIN promotion p ON p.promotion_id=t.promotion_id
        ORDER BY p.promotion_id FOR UPDATE;
      DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_promo_done=1;
      OPEN cur_promos;
      promo_loop: LOOP
        FETCH cur_promos INTO v_promotion_id,v_promotion_type,v_promotion_value,v_promotion_max,
          v_promotion_min,v_promotion_status,v_start,v_end,v_usage_limit,v_usage_count,v_code;
        IF v_promo_done=1 THEN LEAVE promo_loop; END IF;
        IF v_promotion_status<>'ACTIVE' OR UTC_TIMESTAMP() NOT BETWEEN v_start AND v_end THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='promotion is not currently active'; END IF;
        IF v_subtotal<v_promotion_min THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='order does not meet promotion minimum'; END IF;
        IF v_usage_limit IS NOT NULL AND v_usage_count>=v_usage_limit THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='promotion usage limit reached'; END IF;
        SELECT COUNT(*) INTO v_scope_count FROM promotion_product WHERE promotion_id=v_promotion_id;
        SELECT v_scope_count+COUNT(*) INTO v_scope_count FROM promotion_category WHERE promotion_id=v_promotion_id;
        IF v_scope_count=0 THEN
          SET v_promo_base=v_subtotal;
        ELSE
          SELECT COALESCE(SUM(oi.line_total),0) INTO v_promo_base
          FROM order_item oi JOIN product_variant v ON v.variant_id=oi.variant_id
          JOIN product p ON p.product_id=v.product_id
          WHERE oi.order_id=p_order_id
            AND (EXISTS(SELECT 1 FROM promotion_product pp WHERE pp.promotion_id=v_promotion_id AND pp.product_id=p.product_id)
              OR EXISTS(SELECT 1 FROM promotion_category pc WHERE pc.promotion_id=v_promotion_id AND pc.category_id=p.category_id));
          IF v_promo_base=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='promotion does not apply to cart items'; END IF;
        END IF;
        SET v_discount=fn_promotion_discount(v_promo_base,v_promotion_type,v_promotion_value,v_promotion_max);
        SET v_applied=LEAST(v_discount,v_subtotal-v_discount_total);
        IF v_applied>0 THEN
          INSERT INTO order_promotion(order_id,promotion_id,discount_amount,promotion_code_snapshot) VALUES(p_order_id,v_promotion_id,v_applied,v_code);
          UPDATE promotion SET used_count=used_count+1
          WHERE promotion_id=v_promotion_id AND (usage_limit IS NULL OR used_count<usage_limit);
          IF ROW_COUNT()<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='promotion usage limit reached'; END IF;
          SET v_discount_total=v_discount_total+v_applied;
        END IF;
      END LOOP;
      CLOSE cur_promos;
    END;
  END IF;

  UPDATE orders SET subtotal=v_subtotal,discount_total=v_discount_total,grand_total=v_subtotal-v_discount_total+p_shipping_fee WHERE order_id=p_order_id;
  INSERT INTO payment(order_id,provider,amount,status,paid_at)
    SELECT order_id,'CHECKOUT',grand_total,'SUCCESS',UTC_TIMESTAMP() FROM orders WHERE order_id=p_order_id;
  UPDATE orders SET status='PAID' WHERE order_id=p_order_id;
  UPDATE cart SET status='CHECKED_OUT' WHERE cart_id=v_cart_id;
  COMMIT;
  DROP TEMPORARY TABLE IF EXISTS tmp_promo;
END$$

CREATE PROCEDURE sp_seller_ranking(IN p_from DATETIME,IN p_to DATETIME,IN p_limit INT)
SQL SECURITY INVOKER
BEGIN
  IF p_from IS NULL OR p_to IS NULL OR p_from>=p_to THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid ranking date range'; END IF;
  IF p_limit IS NULL OR p_limit<=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ranking limit must be positive'; END IF;
  SET @sql=CONCAT(
    'SELECT s.account_id AS seller_id,s.shop_name,COUNT(DISTINCT o.order_id) AS order_count,COALESCE(SUM(CASE WHEN o.order_id IS NOT NULL THEN oi.line_total ELSE 0 END),0) AS revenue ',
    'FROM seller s LEFT JOIN order_item oi ON oi.seller_id=s.account_id LEFT JOIN orders o ON o.order_id=oi.order_id ',
    'AND o.status IN (''PAID'',''PROCESSING'',''SHIPPED'',''DELIVERED'') AND o.created_at>=? AND o.created_at<? ',
    'WHERE s.shop_status=''ACTIVE'' GROUP BY s.account_id,s.shop_name ',
    'ORDER BY revenue DESC,order_count DESC,s.account_id LIMIT ',CAST(p_limit AS UNSIGNED));
  SET @from_at=p_from; SET @to_at=p_to;
  PREPARE stmt FROM @sql; EXECUTE stmt USING @from_at,@to_at; DEALLOCATE PREPARE stmt;
END$$
DELIMITER ;
