# Kiểm thử hồi quy tự động — 03/11/2026

Người chạy: **Phạm Thành Danh**, lệnh `python tests\regression\run_regression.py` lúc 19:33 (tổng 12 giây).
Mọi file `.txt` trong thư mục do script ghi thẳng từ stdout/stderr của mysql client và Python, không chỉnh tay.
Bảng tóm tắt và chi tiết từng kiểm tra: `tests/regression/2026-11-03.md`. Ảnh terminal: `regression-terminal.png`.

Môi trường: laptop Windows 11 (`laptop-5p18fulb`), MySQL 8.4.11, Python 3.15.0; database mẫu `ecommerce_advanced`
dựng lại bằng `data/seed/reset_sample_db.sql` (01 → 02 → 03 → 04 → 05). Code: `main` tại `3211206` + thay đổi của PR
ngày 03/11 (script hồi quy, `tests/security_tests.sql`, script reset) — chưa commit lúc chạy.

**Kết quả: 10/10 bước đạt.**

| Bước | File log | Kết quả chính | Tiêu chí |
|---|---|---|---|
| 00 | `00_reset_sample_db.txt` | Dựng xong database mẫu (seed: 1 khách, 1 đơn) | — |
| 10 | `10_constraint_tests.txt` | 7/7 case lỗi PASS; 5 truy vấn `invalid_*` đều 0 | R01, R02 |
| 11 | `11_promotion_tests.txt` | Kịch bản A `promo_sum = 20000 = discount_total`, `grand_total = 110000`; B `100000`, `grand_total = 30000`; 4/4 case lỗi PASS; case lỗi không để lại đơn (3 → 3), `used_count` không đổi (4 → 4) | R04 |
| 12 | `12_order_tests.txt` | `FIXTURE_OK`; 7/7 case lỗi PASS; rollback giữ nguyên số đơn (3 → 3) và tồn kho (18 → 18); `ORDER_DATA_OK = 0` | R02, R04, R05 |
| 13 | `13_transaction_tests.txt` | T01 đơn 5: `subtotal = item_sum = 100000`, `grand_total = 130000` (+30.000 ship); T05 số điện thoại vẫn `0900000001` | R03 |
| 14 | `14_python_unittest.txt` | `Ran 6 tests ... OK` | R07, R08 |
| 15 | `15_security_tests.txt` | S1 `' OR '1'='1' -- `: ghép chuỗi trả 1/1 sản phẩm, tham số 0; S2 `UNION SELECT email FROM account`: ghép chuỗi lộ 2/2 tài khoản, tham số 0 | R07 |
| 20, 21 | `20_reset_sample_db.txt`, `21_concurrency_setup.txt` | Database mẫu mới; CUS2001, CUS2002 mỗi người 1 giỏ, tồn kho còn 1 | R06 |
| 22 | `22_concurrency_two_sessions.txt` | Session A tạo đơn 2 `PAID` 100.000đ, kho 1 → 0, COMMIT; session B bắt đầu sau 2 giây, **chờ khóa 4,05 giây** rồi nhận `ERROR 1644 (45000): insufficient inventory`; sau cùng kho 0, CUS2001 có 1 đơn PAID, CUS2002 không có đơn | R06 |

Ghi chú:

- Database mẫu rất nhỏ nên số dòng ở bước 15 nhỏ (1 sản phẩm, 2 tài khoản). Cùng kiểu tấn công trên bộ 100.000 đơn làm lộ
  2.511 biến thể và 10.100 tài khoản: `report/appendix/danh/20261025/dynamic-search.txt`.
- Bước 22 thay cho log T03 cũ `../20261023/21_concurrency_two_sessions.txt` (script cũ, B không bị từ chối) và cho cùng kết luận
  với lần chạy tay `../20261023/71_concurrency_manual_two_sessions.txt`: B bị từ chối `1644`, không oversell.
- R09 cần bộ 100.000 đơn nên không nằm trong script: xem `report/appendix/queries/20261025/`.
