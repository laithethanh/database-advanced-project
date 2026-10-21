-- Thực hành giao dịch. Chạy phần chuẩn bị một lần, sau đó thực thi các khối được đánh nhãn trong HAI cửa sổ mysql.
USE ecommerce_advanced;

-- T01: thanh toán thành công giỏ hàng mẫu. Kỳ vọng: một đơn PAID, giỏ hàng CHECKED_OUT,
-- tổng tiền hàng bằng tổng các dòng hàng và tồn kho đã chọn giảm đúng số lượng trong giỏ.
SET @customer_id := (SELECT account_id FROM customer WHERE customer_code='CUS0001');
SET @before_stock := (SELECT i.quantity_on_hand FROM inventory i JOIN product_variant v ON v.variant_id=i.variant_id WHERE v.sku='SKU-DEMO-001' LIMIT 1);
SET @order_id := NULL;
CALL sp_checkout(@customer_id,'Nguyen Van A','0900000001','HCM',30000,NULL,@order_id);
SELECT @order_id AS created_order_id,@before_stock AS stock_before,
       (SELECT subtotal FROM orders WHERE order_id=@order_id) AS subtotal,
       (SELECT grand_total FROM orders WHERE order_id=@order_id) AS grand_total,
       (SELECT SUM(line_total) FROM order_item WHERE order_id=@order_id) AS item_sum;

-- T02: bằng chứng hoàn tác sau khi đã tạo order/trừ kho nằm trong tests/order_tests.sql
-- với mã LIMIT0 đã hết lượt. Kịch bản dưới đây chỉ kiểm tra lỗi sớm trước transaction
-- (mã không tồn tại), nên không đủ chứng minh rollback tồn kho.
-- SELECT COUNT(*) AS orders_before FROM orders;
-- CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code='CUS0001'),'Nguyen Van A','0900000001','HCM',30000,'NO-SUCH-COUPON',@ignored);
-- SELECT COUNT(*) AS orders_after FROM orders;

-- T06: nhiều mã, một mã không hợp lệ. Cả đơn phải rollback: không order, không order_promotion,
-- used_count của mã hợp lệ không tăng. Chạy trên cơ sở dữ liệu mẫu MỚI có ít nhất một mã ACTIVE.
-- CALL sp_checkout((SELECT account_id FROM customer WHERE customer_code='CUS0001'),'Nguyen Van A','0900000001','HCM',30000,'<MA_HOP_LE>,NO-SUCH-COUPON',@ignored);

-- T03 CHUẨN BỊ (cơ sở dữ liệu mẫu mới): tạo hai khách hàng/giỏ hàng cùng tranh mua đúng một đơn vị hàng.
-- Chỉ thực hiện sau T01 hoặc tạo lại giỏ hàng mẫu nếu cần.
-- Đặt một dòng tồn kho thành quantity_on_hand=1, tạo hai giỏ ACTIVE có quantity=1 cho cùng người bán/biến thể.
-- Xem docs/09-transaction-concurrency.md để biết lệnh chạy hai phiên và danh sách bằng chứng cần lưu.

-- T04: vi phạm máy trạng thái. Lỗi kỳ vọng: chuyển trạng thái đơn hàng không hợp lệ.
-- UPDATE orders SET status='DELIVERED' WHERE order_id=@order_id;

-- T05: minh họa savepoint (không làm thay đổi lịch sử nghiệp vụ).
START TRANSACTION;
SAVEPOINT before_note;
UPDATE account SET phone='0999999999' WHERE email='customer01@example.test';
ROLLBACK TO SAVEPOINT before_note;
COMMIT;
SELECT phone AS phone_after_savepoint_rollback FROM account WHERE email='customer01@example.test';
