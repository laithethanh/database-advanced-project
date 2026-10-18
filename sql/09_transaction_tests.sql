-- Transaction lab. Run setup once, then execute the labelled blocks in TWO mysql clients.
USE ecommerce_advanced;

-- T01: checkout success on the sample cart. Expected: one PAID order, cart CHECKED_OUT,
-- order subtotal equals sum(items), and selected inventory falls by cart quantity.
SET @customer_id := (SELECT account_id FROM customer WHERE customer_code='CUS0001');
SET @before_stock := (SELECT i.quantity_on_hand FROM inventory i JOIN product_variant v ON v.variant_id=i.variant_id WHERE v.sku='SKU-DEMO-001' LIMIT 1);
SET @order_id := NULL;
CALL sp_checkout(@customer_id,'Nguyen Van A','0900000001','HCM',30000,NULL,@order_id);
SELECT @order_id AS created_order_id,@before_stock AS stock_before,
       (SELECT subtotal FROM orders WHERE order_id=@order_id) AS subtotal,
       (SELECT grand_total FROM orders WHERE order_id=@order_id) AS grand_total,
       (SELECT SUM(line_total) FROM order_item WHERE order_id=@order_id) AS item_sum;

-- T02: rollback evidence. On a FRESH sample database, call checkout with an invalid coupon.
-- Before and after counts must match. The CALL is expected to raise error and stop the client;
-- run the after SELECT in a new statement/client.
-- SELECT COUNT(*) AS orders_before FROM orders;
-- CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code='CUS0001'),'Nguyen Van A','0900000001','HCM',30000,'NO-SUCH-COUPON',@ignored);
-- SELECT COUNT(*) AS orders_after FROM orders;

-- T03 SETUP (fresh sample DB): create two customers/carts that contend for exactly one unit.
-- Perform this only after T01 or recreate the sample cart as needed.
-- Set an inventory row to quantity_on_hand=1, create two ACTIVE carts with quantity=1 for that same seller/variant.
-- See docs/09-transaction-concurrency.md for the exact two-session commands and evidence checklist.

-- T04: state machine violation. Expected error: invalid order status transition.
-- UPDATE orders SET status='DELIVERED' WHERE order_id=@order_id;

-- T05: savepoint demonstration (does not alter business history).
START TRANSACTION;
SAVEPOINT before_note;
UPDATE account SET phone='0999999999' WHERE email='customer01@example.test';
ROLLBACK TO SAVEPOINT before_note;
COMMIT;
SELECT phone AS phone_after_savepoint_rollback FROM account WHERE email='customer01@example.test';
