# Danh mục kiểm thử hồi quy

Chạy trên cơ sở dữ liệu mẫu vừa dựng theo thứ tự: `tests/constraint_tests.sql`, `tests/promotion_tests.sql`, `tests/order_tests.sql`, `sql/09_transaction_tests.sql`, sau đó chạy `python -m unittest tests.test_dynamic_search -v` và `tests/security_tests.sql`. Với T03, dựng lại cơ sở dữ liệu sạch, chạy `concurrency_setup.sql` rồi mở hai terminal chạy `concurrency_session_a.sql` và `concurrency_session_b.sql`. Tiêu chí đạt:

| ID | Kết quả mong đợi |
|---|---|
| R01 | Giá âm, SKU trùng, vi phạm FK và giữ chỗ vượt tồn kho đều bị từ chối. |
| R02 | Q25 và các truy vấn kiểm tra bất biến phải trả về 0 dòng/0 số lượng vi phạm. |
| R03 | Đặt hàng hợp lệ commit một đơn PAID có tổng tiền bằng tổng các dòng hàng. |
| R04 | Mã giảm giá không hợp lệ và tồn kho không đủ khiến toàn bộ thay đổi khi thanh toán bị rollback. |
| R05 | Chuyển trạng thái đơn hàng/giao hàng không hợp lệ bị từ chối; hủy đơn chỉ hoàn tồn kho người bán một lần. |
| R06 | T03 chỉ cho phép một trong hai giao dịch mua lượng hàng cuối cùng thành công. |
| R07 | Dữ liệu đầu vào tìm kiếm động vẫn được truyền dưới dạng tham số; giá trị ngoài whitelist bị từ chối trước khi chạy SQL. `tests/security_tests.sql`: câu ghép chuỗi bị payload `OR 1=1`/`UNION` khai thác, câu `PREPARE ... USING` trả 0 dòng. |
| R08 | `python -m unittest tests.test_dynamic_search -v` chạy 6 test và tất cả PASS. |
| R09 | Generator tạo đủ trạng thái, review, tồn kho thấp; Q06/Q09/Q22/Q24 có dữ liệu kiểm chứng. |

Tạo `tests/regression/<run-date>.md`, ghi phiên bản MySQL, phiên bản script, đạt/trượt, nguyên văn lỗi và liên kết ảnh chụp terminal. Không commit thông tin xác thực hoặc bộ dữ liệu thô dung lượng lớn.

## Chạy tự động

```text
python tests/regression/run_regression.py
```

Chạy từ thư mục gốc repo, cần file `.env` (xem `.env.example`). Script làm đúng các bước ở trên, kể cả T03: mở session A,
chờ 2 giây rồi mở session B, đo thời gian B phải chờ khóa và kiểm tra lại tồn kho/đơn hàng sau cùng.

| Bước | Nội dung | Tiêu chí |
|---|---|---|
| 00 | `data/seed/reset_sample_db.sql` — xóa và dựng lại database mẫu (01 → 05) | — |
| 10 | `tests/constraint_tests.sql`: 7 case PASS, 5 truy vấn `invalid_*` = 0 | R01, R02 |
| 11 | `tests/promotion_tests.sql`: 4 case PASS, `promo_sum` khớp `discount_total`, case lỗi không để lại đơn | R04 |
| 12 | `tests/order_tests.sql`: 7 case PASS, `FIXTURE_OK`, rollback giữ nguyên số đơn và tồn kho, `ORDER_DATA_OK = 0` | R02, R04, R05 |
| 13 | `sql/09_transaction_tests.sql`: T01 đơn PAID có tổng tiền khớp dòng hàng; T05 savepoint giữ nguyên số điện thoại | R03 |
| 14 | `python -m unittest tests.test_dynamic_search -v`: 6 test OK | R07, R08 |
| 15 | `tests/security_tests.sql`: S1, S2 PASS | R07 |
| 20–22 | Dựng lại database mẫu, `concurrency_setup.sql`, chạy song song session A/B: A commit, B nhận `ERROR 1644 insufficient inventory` sau khi chờ khóa, tồn kho 0, CUS2001 có 1 đơn PAID, CUS2002 không có đơn | R06 |

Kết quả:

- `report/appendix/tests/<YYYYMMDD>/NN_<bước>.txt` — stdout/stderr nguyên văn và exit code của từng bước.
- `tests/regression/<YYYY-MM-DD>.md` — bảng đạt/trượt, phiên bản MySQL/Python, commit, chi tiết từng kiểm tra.
- Thư mục hoặc file đã tồn tại thì tự thêm hậu tố `-2`, `-3`… — không ghi đè lần chạy cũ.
- Mã thoát 0 nếu tất cả đạt, 1 nếu có bước trượt.

Tùy chọn: `--yes` (không hỏi xác nhận), `--skip-concurrency` (bỏ T03), `--label <tên>` (đặt tên thư mục log).
Nếu không tìm thấy `mysql`, đặt biến `MYSQL_BIN` trỏ tới `mysql.exe`.

**Cảnh báo:** script xóa database `ecommerce_advanced`. Chạy sau khi đã lưu xong mọi bằng chứng trên bộ 100.000 đơn;
muốn có lại bộ đó thì chạy `data/generator/reset_bench_db.sql` rồi generator. R09 không nằm trong script vì cần bộ
100.000 đơn — xem `report/appendix/queries/20261025/`.

## Các lần chạy

| Ngày | Tóm tắt | Log | Kết quả |
|---|---|---|---|
| 03/11/2026 | `2026-11-03.md` | `report/appendix/tests/20261103/` (kèm `regression-terminal.png`) | 10/10 bước đạt; T03: B chờ khóa 4,05 giây rồi nhận `1644` |

Mật khẩu đọc từ `.env` và chỉ ghi vào một file cấu hình tạm (`--defaults-extra-file`) bị xóa ngay khi script kết thúc,
nên không hiện trên dòng lệnh hay trong log.
