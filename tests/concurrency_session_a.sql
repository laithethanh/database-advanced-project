-- Session A của kịch bản T03 (tranh mua lượng hàng cuối cùng).
-- Chạy SAU khi tests/concurrency_setup.sql, trong terminal A.
-- Giữ khóa dòng inventory 6 giây để session B phải chờ, rồi hoàn tác để nhìn rõ
-- hiệu ứng tranh chấp (session B sẽ thành công khi khoá được nhả).
--
-- mysql -u <user> -p ecommerce_advanced < tests/concurrency_session_a.sql

START TRANSACTION;

SELECT i.quantity_on_hand AS locked_stock
FROM inventory i
JOIN product_variant v ON v.variant_id = i.variant_id
JOIN seller s ON s.account_id = i.seller_id
WHERE v.sku = 'SKU-DEMO-001' AND s.seller_code = 'SEL0001'
FOR UPDATE;

SELECT SLEEP(6) AS hold_lock_seconds;

COMMIT;

SELECT 'session A: released the lock' AS session_a;
