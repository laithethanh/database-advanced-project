-- Thực hành giao dịch. Chạy phần chuẩn bị một lần, sau đó thực thi các khối được đánh nhãn trong HAI cửa sổ mysql.
USE ecommerce_advanced;
 

<<<<<<< HEAD
-- =========================================================================
-- TUẦN 7: KIỂM TRA TRANSACTION VÀ TEST ROLLBACK KHI GỌI PROCEDURE SP_CHECKOUT
-- Người thực hiện: Khoa
-- =========================================================================

-- 1. CHẨN ĐOÁN & TRẠNG THÁI TRƯỚC KIỂM THỬ (BASELINE)
SELECT '--- KẾT QUẢ BAN ĐẦU ---' AS info;
SELECT variant_id, seller_id, quantity_on_hand, reserved_quantity 
FROM inventory 
WHERE variant_id = 1;

SELECT COUNT(*) AS total_orders_before FROM orders;


-- =========================================================================
-- TEST CASE 1: Test Rollback khi kho không đủ hàng (Insufficient Inventory)
-- Mô tả: Cố tình đặt hàng số lượng lớn vượt quá tồn kho khả dụng.
-- Kỳ vọng: Kích hoạt SIGNAL lỗi, PROCEDURE thực hiện ROLLBACK, 
--          không có đơn hàng mới nào được tạo và số lượng tồn kho giữ nguyên.
-- =========================================================================
SELECT '--- TEST CASE 1: ROLLBACK KHO KHÔNG ĐỦ HÀNG ---' AS info;

-- Chuẩn bị biến hứng kết quả
SET @out_order_id = NULL;

-- Cố tình gọi checkout (nếu gặp lỗi SQLEXCEPTION, procedure sẽ tự ROLLBACK)
CALL sp_checkout(
    1,                        -- p_customer_id
    'Nguyễn Mậu Công Khoa',   -- p_recipient_name
    '0901234567',             -- p_recipient_phone
    'TP. Hồ Chí Minh, Việt Nam', -- p_shipping_address
    30000.00,                 -- p_shipping_fee
    NULL,                     -- p_promotion_code
    @out_order_id
);

-- Xác minh tính toàn vẹn (Assertion):
-- Tổng số đơn hàng KHÔNG được tăng thêm
SELECT COUNT(*) AS total_orders_after_test1 FROM orders;

-- Số lượng tồn kho KHÔNG được thay đổi
SELECT variant_id, seller_id, quantity_on_hand, reserved_quantity 
FROM inventory 
WHERE variant_id = 1;


-- =========================================================================
-- TEST CASE 2: Test Rollback khi áp dụng mã Khuyến mãi không tồn tại
-- Mô tả: Áp dụng mã giảm giá sai 'INVALID_PROMO_2026'.
-- Kỳ vọng: Procedure dừng tại bước kiểm tra mã, ROLLBACK toàn bộ giao dịch.
-- =========================================================================
SELECT '--- TEST CASE 2: ROLLBACK MÃ KHUYẾN MÃI SAI ---' AS info;

SET @out_order_id = NULL;

CALL sp_checkout(
    1,
    'Nguyễn Mậu Công Khoa',
    '0901234567',
    'TP. Hồ Chí Minh, Việt Nam',
    30000.00,
    'INVALID_PROMO_2026',    -- Mã khuyến mãi sai
    @out_order_id
);

-- Xác minh tính toàn vẹn:
SELECT COUNT(*) AS total_orders_after_test2 FROM orders;


-- =========================================================================
-- TEST CASE 3: Test Rollback khi thiếu thông tin giao hàng bắt buộc
-- Mô tả: Truyền NULL vào trường p_recipient_name.
-- Kỳ vọng: Procedure lập tức báo lỗi và ROLLBACK trước khi chèn bất kỳ bản ghi nào.
-- =========================================================================
SELECT '--- TEST CASE 3: ROLLBACK THIẾU THÔNG TIN GIAO HÀNG ---' AS info;

SET @out_order_id = NULL;

CALL sp_checkout(
    1,
    NULL,                     -- Thiếu tên người nhận
    '0901234567',
    'TP. Hồ Chí Minh, Việt Nam',
    30000.00,
    NULL,
    @out_order_id
);

-- Xác minh tính toàn vẹn:
SELECT COUNT(*) AS total_orders_after_test3 FROM orders;
-- T01 checkout success
-- T02 failure + rollback
-- T03 two-session last-stock contention
-- T04 invalid order state transition
-- Chi tiết kịch bản: docs/09-transaction-concurrency.md
=======
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
>>>>>>> 90101127cb3a58637bf52d65df1bc6674c9c4263

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
