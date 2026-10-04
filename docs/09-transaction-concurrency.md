# Transaction và concurrency lab

## Kịch bản T01: checkout thành công

1. `START TRANSACTION`.
2. Lock/atomic update inventory cho các variant cần mua.
3. Tạo order và order items với snapshot giá.
4. Tính promotion/discount.
5. Tạo payment pending và shipment pending theo policy.
6. Cập nhật cart.
7. `COMMIT`.

Expected: không có order dở dang, inventory và order nhất quán.

## T02: lỗi giữa chừng

Sau khi tạo order nhưng trước bước cuối, cố tình phát sinh lỗi. `ROLLBACK` phải loại bỏ toàn bộ thay đổi của transaction.

Expected: không còn order mồ côi và inventory không bị trừ một phần.

## T03: hai session mua SKU cuối

Session A và B cùng checkout một variant với available quantity nhỏ hơn tổng nhu cầu. Dùng row lock hoặc atomic conditional update.

Expected: tối đa một lượng hợp lệ được commit; session còn lại phải fail/rollback khi không đủ stock.

## T04: state transition

Thử `PENDING_PAYMENT → SHIPPED` và `DELIVERED → PROCESSING`.

Expected: bị từ chối.

## Isolation và deadlock

Ưu tiên lock inventory theo thứ tự `variant_id` tăng dần để giảm deadlock khi một order chứa nhiều SKU. Ghi nhận isolation level và execution evidence trong báo cáo.
