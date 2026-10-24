-- Test matrix: success, insufficient stock, mid-transaction failure, invalid state transition.
START TRANSACTION;
-- Khóa dòng tồn kho của sản phẩm có variant_id = 1 để độc quyền xử lý
SELECT variant_id, quantity_on_hand, reserved_quantity 
FROM inventory 
WHERE variant_id = 1 
FOR UPDATE;


-- Mở giao dịch mới và cố gắng cập nhật chính biến thể đang bị Session 1 khóa
START TRANSACTION;
UPDATE inventory 
SET reserved_quantity = reserved_quantity + 1 
WHERE variant_id = 1;
-- Lúc này Session 2 sẽ bị treo (waiting for lock) cho đến khi Session 1 giải phóng.