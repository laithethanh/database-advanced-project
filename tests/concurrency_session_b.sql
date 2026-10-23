-- Session B của kịch bản T03 (tranh mua lượng hàng cuối cùng).
-- Chạy SAU khi tests/concurrency_setup.sql, trong terminal B, KHOẢNG 2 GIÂY sau khi bắt đầu session A.
--
-- mysql -u <user> -p ecommerce_advanced < tests/concurrency_session_b.sql
--
-- Kết quả mong đợi:
-- 1. Lời gọi bị BLOCK khoảng 4 giây cho tới khi session A COMMIT.
-- 2. Sau đó nhận ERROR 1644 'insufficient inventory'; transaction B rollback.
-- 3. Không tạo order/payment cho B; CUS2001 có đúng 1 order PAID; kho còn 0.
--
-- MySQL client dừng khi gặp lỗi 1644 nên các SELECT cuối file có thể không chạy;
-- dùng query xác nhận riêng trong docs/15.

CALL sp_checkout(
  (SELECT account_id FROM customer WHERE customer_code = 'CUS2002'),
  'Concurrent Two', '0900000102', 'HCM', 0, NULL, @order_b
);

SELECT @order_b AS order_b,
       (SELECT status FROM orders WHERE order_id = @order_b) AS order_status,
       (SELECT COUNT(*) FROM payment WHERE order_id = @order_b) AS payment_rows;

-- Trạng thái tồn kho sau cuộc tranh chấp
SELECT i.quantity_on_hand AS stock,
       (SELECT COUNT(*) FROM orders o JOIN customer c ON c.account_id = o.customer_id
         WHERE c.customer_code = 'CUS2001' AND o.status = 'PAID') AS cus2001_paid_orders
FROM inventory i
JOIN product_variant v ON v.variant_id = i.variant_id
JOIN seller s ON s.account_id = i.seller_id
WHERE v.sku = 'SKU-DEMO-001' AND s.seller_code = 'SEL0001';
