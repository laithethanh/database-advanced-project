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

CREATE PROCEDURE sp_checkout(
  IN p_customer_id BIGINT UNSIGNED,
  IN p_recipient_name VARCHAR(150),
  IN p_recipient_phone VARCHAR(30),
  IN p_shipping_address VARCHAR(600),
  IN p_shipping_fee DECIMAL(15,2),
  IN p_promotion_code VARCHAR(50),
  OUT p_order_id BIGINT UNSIGNED
)
SQL SECURITY INVOKER
BEGIN
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_cart_id BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_variant_id BIGINT UNSIGNED;
  DECLARE v_qty INT UNSIGNED;
  DECLARE v_price DECIMAL(15,2);
  DECLARE v_product_id BIGINT UNSIGNED;
  DECLARE v_product_name VARCHAR(255);
  DECLARE v_sku VARCHAR(80);
  DECLARE v_subtotal DECIMAL(15,2) DEFAULT 0;
  DECLARE v_discount DECIMAL(15,2) DEFAULT 0;
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
  DECLARE v_available INT DEFAULT 0;
  DECLARE v_take INT DEFAULT 0;
  DECLARE v_warehouse_id BIGINT UNSIGNED;
  DECLARE v_remaining INT UNSIGNED;
  DECLARE v_item_count INT DEFAULT 0;
  DECLARE v_invalid_items INT DEFAULT 0;

  DECLARE cur_items CURSOR FOR
    SELECT ci.variant_id,ci.quantity,v.price,p.product_id,p.name,v.sku
    FROM cart_item ci JOIN product_variant v ON v.variant_id=ci.variant_id JOIN product p ON p.product_id=v.product_id
    WHERE ci.cart_id=v_cart_id ORDER BY ci.variant_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done=1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF p_shipping_fee IS NULL OR p_shipping_fee<0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid shipping fee'; END IF;
  IF p_recipient_name IS NULL OR p_recipient_phone IS NULL OR p_shipping_address IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='recipient and shipping address are required'; END IF;

  START TRANSACTION;
  SELECT c.cart_id INTO v_cart_id FROM cart c WHERE c.customer_id=p_customer_id AND c.status='ACTIVE' ORDER BY c.cart_id LIMIT 1 FOR UPDATE;
  IF v_cart_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='customer has no ACTIVE cart'; END IF;
  SELECT COUNT(*) INTO v_item_count FROM cart_item WHERE cart_id=v_cart_id;
  IF v_item_count=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='cannot checkout an empty cart'; END IF;
  SELECT COUNT(*) INTO v_invalid_items
  FROM cart_item ci
  JOIN product_variant v ON v.variant_id=ci.variant_id
  JOIN product p ON p.product_id=v.product_id
  JOIN seller s ON s.account_id=p.seller_id
  WHERE ci.cart_id=v_cart_id
    AND NOT (v.status='ACTIVE' AND p.status='ACTIVE' AND s.shop_status='ACTIVE');
  IF v_invalid_items>0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='cart contains a variant that is no longer sellable'; END IF;

  SET v_order_number=CONCAT('ORD-',DATE_FORMAT(UTC_TIMESTAMP(),'%Y%m%d%H%i%s'),'-',LPAD(FLOOR(RAND()*1000000),6,'0'));
  INSERT INTO orders(order_number,customer_id,status,recipient_name,recipient_phone,shipping_address,subtotal,discount_total,shipping_fee,grand_total,placed_at)
  VALUES(v_order_number,p_customer_id,'PENDING_PAYMENT',p_recipient_name,p_recipient_phone,p_shipping_address,0,0,p_shipping_fee,p_shipping_fee,UTC_TIMESTAMP());
  SET p_order_id=LAST_INSERT_ID();

  SET v_done=0;
  OPEN cur_items;
  item_loop: LOOP
    FETCH cur_items INTO v_variant_id,v_qty,v_price,v_product_id,v_product_name,v_sku;
    IF v_done=1 THEN LEAVE item_loop; END IF;
    SET v_remaining=v_qty;
    BEGIN
      DECLARE v_stock_done INT DEFAULT 0;
      DECLARE cur_stock CURSOR FOR
        SELECT warehouse_id,quantity_on_hand-reserved_quantity
        FROM inventory WHERE variant_id=v_variant_id AND quantity_on_hand>reserved_quantity
        ORDER BY warehouse_id FOR UPDATE;
      DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_stock_done=1;
      OPEN cur_stock;
      stock_loop: LOOP
        FETCH cur_stock INTO v_warehouse_id,v_available;
        IF v_stock_done=1 OR v_remaining=0 THEN LEAVE stock_loop; END IF;
        SET v_take=LEAST(v_remaining,v_available);
        UPDATE inventory SET quantity_on_hand=quantity_on_hand-v_take
        WHERE warehouse_id=v_warehouse_id AND variant_id=v_variant_id AND quantity_on_hand-reserved_quantity>=v_take;
        IF ROW_COUNT()<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='inventory changed concurrently; checkout aborted'; END IF;
        SET v_remaining=v_remaining-v_take;
      END LOOP;
      CLOSE cur_stock;
    END;
    IF v_remaining>0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='insufficient inventory'; END IF;
    INSERT INTO order_item(order_id,variant_id,product_name_snapshot,sku_snapshot,unit_price,quantity,line_discount,line_total)
    VALUES(p_order_id,v_variant_id,v_product_name,v_sku,v_price,v_qty,0,v_qty*v_price);
    SET v_subtotal=v_subtotal+v_qty*v_price;
  END LOOP;
  CLOSE cur_items;

  IF p_promotion_code IS NOT NULL AND p_promotion_code<>'' THEN
    SELECT promotion_id,promotion_type,discount_value,max_discount,min_order_amount,status,start_at,end_at,usage_limit
    INTO v_promotion_id,v_promotion_type,v_promotion_value,v_promotion_max,v_promotion_min,v_promotion_status,v_start,v_end,v_usage_limit
    FROM promotion WHERE code=p_promotion_code FOR UPDATE;
    IF v_promotion_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='promotion code not found'; END IF;
    IF v_promotion_status<>'ACTIVE' OR UTC_TIMESTAMP() NOT BETWEEN v_start AND v_end THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='promotion is not currently active'; END IF;
    IF v_subtotal<v_promotion_min THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='order does not meet promotion minimum'; END IF;
    IF v_usage_limit IS NOT NULL THEN
      SELECT COUNT(*) INTO v_usage_count FROM order_promotion WHERE promotion_id=v_promotion_id;
      IF v_usage_count>=v_usage_limit THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='promotion usage limit reached'; END IF;
    END IF;
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
  END IF;

  UPDATE orders SET subtotal=v_subtotal,discount_total=v_discount,grand_total=v_subtotal-v_discount+p_shipping_fee WHERE order_id=p_order_id;
  IF v_promotion_id IS NOT NULL THEN
    INSERT INTO order_promotion(order_id,promotion_id,discount_amount,promotion_code_snapshot) VALUES(p_order_id,v_promotion_id,v_discount,p_promotion_code);
  END IF;
  INSERT INTO payment(order_id,provider,amount,status,paid_at)
    SELECT order_id,'CHECKOUT',grand_total,'SUCCESS',UTC_TIMESTAMP() FROM orders WHERE order_id=p_order_id;
  UPDATE orders SET status='PAID' WHERE order_id=p_order_id;
  UPDATE cart SET status='CHECKED_OUT' WHERE cart_id=v_cart_id;
  COMMIT;
END$$

CREATE PROCEDURE sp_seller_ranking(IN p_from DATETIME,IN p_to DATETIME,IN p_limit INT)
SQL SECURITY INVOKER
BEGIN
  IF p_from IS NULL OR p_to IS NULL OR p_from>=p_to THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid ranking date range'; END IF;
  IF p_limit IS NULL OR p_limit<=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ranking limit must be positive'; END IF;
  SET @sql=CONCAT(
    'SELECT s.account_id AS seller_id,s.shop_name,COUNT(DISTINCT o.order_id) AS order_count,COALESCE(SUM(oi.line_total),0) AS revenue ',
    'FROM seller s LEFT JOIN product p ON p.seller_id=s.account_id LEFT JOIN product_variant v ON v.product_id=p.product_id ',
    'LEFT JOIN order_item oi ON oi.variant_id=v.variant_id LEFT JOIN orders o ON o.order_id=oi.order_id ',
    'AND o.status IN (''PAID'',''PROCESSING'',''SHIPPED'',''DELIVERED'') AND o.created_at>=? AND o.created_at<? ',
    'WHERE s.shop_status=''ACTIVE'' GROUP BY s.account_id,s.shop_name ',
    'ORDER BY revenue DESC,order_count DESC,s.account_id LIMIT ',CAST(p_limit AS UNSIGNED));
  SET @from_at=p_from; SET @to_at=p_to;
  PREPARE stmt FROM @sql; EXECUTE stmt USING @from_at,@to_at; DEALLOCATE PREPARE stmt;
END$$
DELIMITER ;
