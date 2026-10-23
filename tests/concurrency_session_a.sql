-- Session A của kịch bản T03 (tranh mua lượng hàng cuối cùng).
-- Chạy SAU khi tests/concurrency_setup.sql, trong terminal A.
-- A thực hiện checkout đầy đủ trong một transaction: khóa giỏ và inventory,
-- trừ kho, tạo order/order_item/payment, chuyển order sang PAID, cập nhật cart.
-- A giữ khóa inventory 6 giây trước khi COMMIT để session B phải chờ.
-- Session B sau đó nhận lỗi 1644 vì available quantity đã bằng 0.
--
-- mysql -u <user> -p ecommerce_advanced < tests/concurrency_session_a.sql

START TRANSACTION;

SET @customer_id := (SELECT account_id FROM customer WHERE customer_code = 'CUS2001');

-- Khóa giỏ ACTIVE của A, cùng thứ tự với sp_checkout.
SELECT c.cart_id
INTO @cart_id
FROM cart c
WHERE c.customer_id = @customer_id AND c.status = 'ACTIVE'
ORDER BY c.cart_id
LIMIT 1
FOR UPDATE;

-- Lấy dòng hàng và khóa inventory của người bán tương ứng.
SELECT i.quantity_on_hand AS locked_stock,
       ci.seller_id,
       ci.variant_id,
       ci.quantity,
       v.price,
       p.name,
       v.sku
INTO @locked_stock, @seller_id, @variant_id, @qty, @price, @product_name, @sku
FROM cart_item ci
JOIN product_variant v ON v.variant_id = ci.variant_id
JOIN product p ON p.product_id = v.product_id
JOIN inventory i ON i.seller_id = ci.seller_id AND i.variant_id = ci.variant_id
WHERE ci.cart_id = @cart_id
ORDER BY ci.seller_id, ci.variant_id
LIMIT 1
FOR UPDATE;

SELECT @locked_stock AS locked_stock;

-- Trừ đúng số lượng trong giỏ; đây là thao tác nguyên tử có điều kiện.
UPDATE inventory
SET quantity_on_hand = quantity_on_hand - @qty
WHERE seller_id = @seller_id
  AND variant_id = @variant_id
  AND quantity_on_hand - reserved_quantity >= @qty;

SELECT ROW_COUNT() AS consumed_rows;

-- Tạo order PENDING_PAYMENT với tổng tiền ban đầu bằng 0.
INSERT INTO orders(
  order_number, customer_id, status, recipient_name, recipient_phone,
  shipping_address, subtotal, discount_total, shipping_fee, grand_total, placed_at
)
VALUES(
  CONCAT('ORD-T03-', DATE_FORMAT(UTC_TIMESTAMP(), '%Y%m%d%H%i%s'), '-',
         SUBSTRING(REPLACE(UUID(), '-', ''), 1, 12)),
  @customer_id, 'PENDING_PAYMENT', 'Concurrent One', '0900000101',
  'HCM', 0, 0, 0, 0, UTC_TIMESTAMP()
);

SET @order_a := LAST_INSERT_ID();

-- Trigger BEFORE INSERT tự tính line_total; trigger AFTER INSERT cập nhật orders.
INSERT INTO order_item(
  order_id, seller_id, variant_id, product_name_snapshot, sku_snapshot,
  unit_price, quantity, line_discount, line_total
)
VALUES(
  @order_a, @seller_id, @variant_id, @product_name, @sku,
  @price, @qty, 0, 0
);

-- Thanh toán và chuyển order sang PAID trong cùng transaction.
INSERT INTO payment(order_id, provider, amount, status, paid_at)
SELECT @order_a, 'CHECKOUT', grand_total, 'SUCCESS', UTC_TIMESTAMP()
FROM orders
WHERE order_id = @order_a;

UPDATE orders SET status = 'PAID' WHERE order_id = @order_a;
UPDATE cart SET status = 'CHECKED_OUT' WHERE cart_id = @cart_id;

SELECT @order_a AS order_a,
       @locked_stock AS stock_before,
       @locked_stock - @qty AS stock_after,
       (SELECT status FROM orders WHERE order_id = @order_a) AS order_status,
       (SELECT grand_total FROM orders WHERE order_id = @order_a) AS grand_total,
       (SELECT COUNT(*) FROM payment WHERE order_id = @order_a AND status = 'SUCCESS') AS payment_rows;

-- Giữ khóa inventory để B phải chờ; sau đó COMMIT.
SELECT SLEEP(6) AS hold_lock_seconds;

COMMIT;

SELECT 'session A: completed checkout and released the lock' AS session_a;
