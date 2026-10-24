USE ecommerce_advanced;
 

 USE ecommerce_advanced;

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
