# Danh mục kiểm thử hồi quy

Chạy trên cơ sở dữ liệu mẫu vừa dựng theo thứ tự: `constraint_tests.sql`, `order_tests.sql`, `09_transaction_tests.sql`, sau đó dựng lại cơ sở dữ liệu sạch và chạy `concurrency_setup.sql` cho T03. Tiêu chí đạt:

| ID | Kết quả mong đợi |
|---|---|
| R01 | Giá âm, SKU trùng, vi phạm FK và giữ chỗ vượt tồn kho đều bị từ chối. |
| R02 | Q25 và các truy vấn kiểm tra bất biến phải trả về 0 dòng/0 số lượng vi phạm. |
| R03 | Đặt hàng hợp lệ commit một đơn PAID có tổng tiền bằng tổng các dòng hàng. |
| R04 | Mã giảm giá không hợp lệ và tồn kho không đủ khiến toàn bộ thay đổi khi thanh toán bị rollback. |
| R05 | Chuyển trạng thái đơn hàng/giao hàng không hợp lệ bị từ chối; hủy đơn chỉ hoàn tồn kho người bán một lần. |
| R06 | T03 chỉ cho phép một trong hai giao dịch mua lượng hàng cuối cùng thành công. |
| R07 | Dữ liệu đầu vào tìm kiếm động vẫn được truyền dưới dạng tham số; giá trị ngoài whitelist bị từ chối trước khi chạy SQL. |

Tạo `tests/regression/<run-date>.md`, ghi phiên bản MySQL, phiên bản script, đạt/trượt, nguyên văn lỗi và liên kết ảnh chụp terminal. Không commit thông tin xác thực hoặc bộ dữ liệu thô dung lượng lớn.
