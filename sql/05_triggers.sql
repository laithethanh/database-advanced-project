USE ecommerce_advanced;
DELIMITER $$
DROP TRIGGER IF EXISTS trg_product_validate_seller_category$$
DROP TRIGGER IF EXISTS trg_product_validate_seller_category_update$$
DROP TRIGGER IF EXISTS trg_product_variant_validate_product$$
DROP TRIGGER IF EXISTS trg_cart_item_validate_variant$$
DROP TRIGGER IF EXISTS trg_inventory_no_negative_reserved$$
DROP TRIGGER IF EXISTS trg_inventory_no_negative_reserved_update$$
DROP TRIGGER IF EXISTS trg_order_item_validate$$
DROP TRIGGER IF EXISTS trg_order_item_validate_update$$
DROP TRIGGER IF EXISTS trg_order_validate_insert$$
DROP TRIGGER IF EXISTS trg_order_validate_update$$
DROP TRIGGER IF EXISTS trg_order_item_after_insert$$
DROP TRIGGER IF EXISTS trg_order_item_after_update$$
DROP TRIGGER IF EXISTS trg_order_item_after_delete$$
DROP TRIGGER IF EXISTS trg_category_no_cycle_insert$$
DROP TRIGGER IF EXISTS trg_category_no_cycle_update$$
DROP TRIGGER IF EXISTS trg_review_validate$$
DROP TRIGGER IF EXISTS trg_review_validate_update$$

CREATE TRIGGER trg_product_validate_seller_category BEFORE INSERT ON product FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1 FROM seller WHERE account_id=NEW.seller_id AND shop_status='ACTIVE') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='product seller must be ACTIVE'; END IF;
  IF NOT EXISTS (SELECT 1 FROM category WHERE category_id=NEW.category_id AND status='ACTIVE') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='product category must be ACTIVE'; END IF;
END$$
CREATE TRIGGER trg_product_validate_seller_category_update BEFORE UPDATE ON product FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1 FROM seller WHERE account_id=NEW.seller_id AND shop_status='ACTIVE') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='product seller must be ACTIVE'; END IF;
  IF NOT EXISTS (SELECT 1 FROM category WHERE category_id=NEW.category_id AND status='ACTIVE') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='product category must be ACTIVE'; END IF;
END$$
CREATE TRIGGER trg_product_variant_validate_product BEFORE INSERT ON product_variant FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1 FROM product p JOIN seller s ON s.account_id=p.seller_id WHERE p.product_id=NEW.product_id AND p.status='ACTIVE' AND s.shop_status='ACTIVE') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='variant product must be ACTIVE and owned by an ACTIVE seller'; END IF;
END$$
CREATE TRIGGER trg_cart_item_validate_variant BEFORE INSERT ON cart_item FOR EACH ROW
BEGIN
  IF NEW.quantity<=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='cart item quantity must be positive'; END IF;
  IF NOT EXISTS (SELECT 1 FROM product_variant v JOIN product p ON p.product_id=v.product_id JOIN seller s ON s.account_id=p.seller_id WHERE v.variant_id=NEW.variant_id AND v.status='ACTIVE' AND p.status='ACTIVE' AND s.shop_status='ACTIVE') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='cart item variant is not sellable'; END IF;
  IF NOT EXISTS (SELECT 1 FROM cart WHERE cart_id=NEW.cart_id AND status='ACTIVE') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='items can only be added to an ACTIVE cart'; END IF;
END$$
CREATE TRIGGER trg_inventory_no_negative_reserved BEFORE INSERT ON inventory FOR EACH ROW
BEGIN IF NEW.reserved_quantity>NEW.quantity_on_hand THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='reserved quantity cannot exceed on-hand quantity'; END IF; END$$
CREATE TRIGGER trg_inventory_no_negative_reserved_update BEFORE UPDATE ON inventory FOR EACH ROW
BEGIN IF NEW.reserved_quantity>NEW.quantity_on_hand THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='reserved quantity cannot exceed on-hand quantity'; END IF; END$$
CREATE TRIGGER trg_order_item_validate BEFORE INSERT ON order_item FOR EACH ROW
BEGIN
  IF NEW.quantity<=0 OR NEW.unit_price<0 OR NEW.line_discount<0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid order item values'; END IF;
  SET NEW.line_total=GREATEST(0,NEW.quantity*NEW.unit_price-NEW.line_discount);
END$$
CREATE TRIGGER trg_order_item_validate_update BEFORE UPDATE ON order_item FOR EACH ROW
BEGIN
  IF NEW.quantity<=0 OR NEW.unit_price<0 OR NEW.line_discount<0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid order item values'; END IF;
  SET NEW.line_total=GREATEST(0,NEW.quantity*NEW.unit_price-NEW.line_discount);
END$$
CREATE TRIGGER trg_order_validate_insert BEFORE INSERT ON orders FOR EACH ROW
BEGIN
  IF NEW.grand_total<>NEW.subtotal-NEW.discount_total+NEW.shipping_fee THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='grand_total formula is invalid'; END IF;
  IF NEW.subtotal<>0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='new order subtotal must start at zero'; END IF;
END$$
CREATE TRIGGER trg_order_validate_update BEFORE UPDATE ON orders FOR EACH ROW
BEGIN
  IF NEW.grand_total<>NEW.subtotal-NEW.discount_total+NEW.shipping_fee THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='grand_total formula is invalid'; END IF;
  IF NEW.status<>'PENDING_PAYMENT' AND NEW.subtotal<>(SELECT COALESCE(SUM(line_total),0) FROM order_item WHERE order_id=NEW.order_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='order subtotal does not match order items'; END IF;
  IF NOT (NEW.status=OLD.status OR (OLD.status='PENDING_PAYMENT' AND NEW.status IN ('PAID','CANCELLED')) OR (OLD.status='PAID' AND NEW.status IN ('PROCESSING','CANCELLED')) OR (OLD.status='PROCESSING' AND NEW.status IN ('SHIPPED','CANCELLED')) OR (OLD.status='SHIPPED' AND NEW.status IN ('DELIVERED','RETURN_REQUESTED')) OR (OLD.status='DELIVERED' AND NEW.status='RETURN_REQUESTED') OR (OLD.status='RETURN_REQUESTED' AND NEW.status='RETURNED')) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid order status transition'; END IF;
  IF NEW.status IN ('PROCESSING','SHIPPED','DELIVERED','RETURN_REQUESTED','RETURNED') AND NOT EXISTS (SELECT 1 FROM order_item WHERE order_id=NEW.order_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='order must contain at least one item'; END IF;
  IF NEW.status='PAID' AND NOT EXISTS (SELECT 1 FROM payment WHERE order_id=NEW.order_id AND status='SUCCESS') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='order cannot become PAID without successful payment'; END IF;
END$$
CREATE TRIGGER trg_order_item_after_insert AFTER INSERT ON order_item FOR EACH ROW
BEGIN UPDATE orders SET subtotal=(SELECT COALESCE(SUM(line_total),0) FROM order_item WHERE order_id=NEW.order_id), grand_total=subtotal-discount_total+shipping_fee WHERE order_id=NEW.order_id; END$$
CREATE TRIGGER trg_order_item_after_update AFTER UPDATE ON order_item FOR EACH ROW
BEGIN UPDATE orders SET subtotal=(SELECT COALESCE(SUM(line_total),0) FROM order_item WHERE order_id=NEW.order_id), grand_total=subtotal-discount_total+shipping_fee WHERE order_id=NEW.order_id; END$$
CREATE TRIGGER trg_order_item_after_delete AFTER DELETE ON order_item FOR EACH ROW
BEGIN UPDATE orders SET subtotal=(SELECT COALESCE(SUM(line_total),0) FROM order_item WHERE order_id=OLD.order_id), grand_total=subtotal-discount_total+shipping_fee WHERE order_id=OLD.order_id; END$$
CREATE TRIGGER trg_category_no_cycle_insert BEFORE INSERT ON category FOR EACH ROW
BEGIN IF NEW.parent_category_id IS NOT NULL AND NEW.parent_category_id=NEW.category_id THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='category cannot be its own parent'; END IF; END$$
CREATE TRIGGER trg_category_no_cycle_update BEFORE UPDATE ON category FOR EACH ROW
BEGIN
  DECLARE v_parent BIGINT UNSIGNED; DECLARE v_steps INT DEFAULT 0;
  IF NEW.parent_category_id IS NOT NULL THEN
    IF NEW.parent_category_id=NEW.category_id THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='category cannot be its own parent'; END IF;
    SET v_parent=NEW.parent_category_id;
    WHILE v_parent IS NOT NULL AND v_steps<1000 DO
      IF v_parent=NEW.category_id THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='category parent update creates a cycle'; END IF;
      SELECT parent_category_id INTO v_parent FROM category WHERE category_id=v_parent;
      SET v_steps=v_steps+1;
    END WHILE;
  END IF;
END$$
CREATE TRIGGER trg_review_validate BEFORE INSERT ON review FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1 FROM order_item oi JOIN orders o ON o.order_id=oi.order_id JOIN product_variant v ON v.variant_id=oi.variant_id WHERE oi.order_item_id=NEW.order_item_id AND v.product_id=NEW.product_id AND o.customer_id=NEW.customer_id AND o.status='DELIVERED') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='review requires customer purchase of product in a DELIVERED order'; END IF;
END$$
CREATE TRIGGER trg_review_validate_update BEFORE UPDATE ON review FOR EACH ROW
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM order_item oi JOIN orders o ON o.order_id=oi.order_id JOIN product_variant v ON v.variant_id=oi.variant_id
    WHERE oi.order_item_id=NEW.order_item_id AND v.product_id=NEW.product_id AND o.customer_id=NEW.customer_id AND o.status='DELIVERED'
  ) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='review requires customer purchase of product in a DELIVERED order'; END IF;
END$$
DELIMITER ;
