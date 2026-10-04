USE ecommerce_advanced;

-- T01 checkout success
-- T02 failure + rollback
-- T03 two-session last-stock contention
-- T04 invalid order state transition
-- Chi tiết kịch bản: docs/09-transaction-concurrency.md

-- T01 success (fresh database + 03_seed_small.sql):
-- SET @order_id = NULL;
-- CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code='CUS0001'),'Nguyen Van A','0900000001','HCM',30000,NULL,@order_id);
-- SELECT @order_id AS order_id;

-- T02 insufficient stock must rollback the whole transaction:
-- Put more quantity in the demo cart than all warehouses can supply, then CALL sp_checkout(...).
-- Expected: ERROR 'insufficient inventory'; order count and inventory remain unchanged.

-- T03 concurrency:
-- Prepare one variant with quantity_on_hand=1 and two ACTIVE carts containing quantity=1.
-- Run CALL sp_checkout(...) from two independent MySQL sessions at the same time.
-- Expected: exactly one succeeds; the other fails; final available stock is never negative.

-- T04 invalid state transition:
-- UPDATE orders SET status='DELIVERED' WHERE order_id=@order_id;
-- Expected: ERROR 'invalid order status transition'.

-- T05 mid-transaction rollback:
-- Use an invalid promotion code in sp_checkout. Expected: no order/payment/cart-status/inventory
-- changes remain after the procedure raises the error.
