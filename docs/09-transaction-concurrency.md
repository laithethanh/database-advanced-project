# Thực nghiệm giao dịch và xử lý đồng thời

## Kịch bản T01: checkout thành công

1. `START TRANSACTION`.
2. Khóa/cập nhật nguyên tử tồn kho cho các cặp người bán/biến thể cần mua.
3. Tạo order và order items với snapshot giá.
4. Khóa các promotion theo `promotion_id` tăng dần, tính giảm cho từng mã, cộng dồn và cap tại subtotal.
5. Tạo payment `SUCCESS` cho checkout demo; shipment được tạo ở bước fulfillment riêng.
6. Cập nhật cart.
7. `COMMIT`.

Kết quả mong đợi: không có đơn hàng dở dang; tồn kho và đơn hàng nhất quán.

## T02: lỗi giữa chừng

Sau khi tạo order nhưng trước bước cuối, cố tình phát sinh lỗi. `ROLLBACK` phải loại bỏ toàn bộ thay đổi của transaction.

Kết quả mong đợi: không còn đơn hàng mồ côi và tồn kho không bị trừ một phần.

## T03: hai phiên kết nối cùng mua SKU cuối

Session A và B cùng checkout một variant với available quantity nhỏ hơn tổng nhu cầu. Dùng row lock hoặc atomic conditional update.

Kết quả mong đợi: tối đa một giao dịch hợp lệ được commit; phiên còn lại phải thất bại/rollback khi tồn kho không đủ.

## T04: state transition

Thử `PENDING_PAYMENT → SHIPPED` và `DELIVERED → PROCESSING`.

Expected: bị từ chối.

## Mức cô lập và deadlock

Ưu tiên lock inventory theo thứ tự `(seller_id, variant_id)` tăng dần để giảm deadlock khi một order chứa nhiều dòng. Promotion cũng được khóa theo `promotion_id` tăng dần trước khi tăng `used_count`. Checkout chỉ lock và trừ tồn của seller được chọn; ghi nhận isolation level và execution evidence trong báo cáo.
