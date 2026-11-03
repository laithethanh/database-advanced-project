# Hướng dẫn tái lập thực nghiệm

## Mục tiêu

Thành viên mới có thể tạo cơ sở dữ liệu từ đầu, nạp dữ liệu mẫu nhỏ, chạy kiểm thử, tạo bộ dữ liệu lớn và đo hiệu năng chỉ bằng tài liệu trong repository.

## Thứ tự thực hiện

```text
1. cài dependency: pip install -r requirements.txt
2. tạo database/schema: sql/01_schema.sql
3. áp dụng ràng buộc: sql/02_constraints.sql
4. nạp dữ liệu mẫu nhỏ: sql/03_seed_small.sql (chỉ dùng cho database mẫu)
5. tạo function/procedure: sql/04_functions.sql
6. tạo trigger: sql/05_triggers.sql
7. chạy constraint_tests.sql, promotion_tests.sql, order_tests.sql
8. chạy sql/06_queries.sql và sql/07_recursive.sql
9. tạo database benchmark riêng: 01 → 02 → 04 → 05 → generator
10. chạy `python data/benchmark/run_benchmark.py --warmup 3 --runs 7`
11. chạy thử nghiệm transaction/concurrency trên 2 phiên kết nối
```

Bước 3–6 phải chạy đúng thứ tự vì trigger và thủ tục giả định các cột/ràng buộc đã tồn tại. Không chạy generator trên database đã có đơn hàng; phải drop database và dựng lại từ đầu trước mỗi lần chạy để bảo đảm dữ liệu tái lập.

Hai nguồn dữ liệu dùng cho hai mục đích khác nhau, không trộn vào cùng một database:

| Nguồn | Phạm vi | Database |
|---|---|---|
| `sql/03_seed_small.sql` | Dữ liệu mẫu nhỏ: fixture cho `tests/*.sql`, demo, chạy Q01–Q25 trên dữ liệu nhỏ | `ecommerce_advanced` (database mẫu) |
| `data/generator/generate_data.py` | Dữ liệu lớn 100.000 đơn cho benchmark và kiểm chứng query | database benchmark riêng, **không** nạp seed nhỏ (lần 22/10 có nạp seed nhỏ; xem metadata) |

Fixture do seed nhỏ tạo và các file test phụ thuộc vào: `CUS0001` (khách), `SEL0001` (người bán), `SKU-DEMO-001` (biến thể). Generator sinh mã theo namespace riêng (`DCUS*`, `DSEL*`, `DSKU*`) nên **không** thay thế được seed cho mục đích test.

## Lệnh mẫu

```powershell
mysql -u <user> -p < sql/01_schema.sql
mysql -u <user> -p < sql/02_constraints.sql
mysql -u <user> -p < sql/03_seed_small.sql
mysql -u <user> -p < sql/04_functions.sql
mysql -u <user> -p < sql/05_triggers.sql
mysql -u <user> -p < tests/constraint_tests.sql
mysql -u <user> -p < tests/promotion_tests.sql
mysql -u <user> -p < tests/order_tests.sql
mysql -u <user> -p < sql/06_queries.sql
mysql -u <user> -p < sql/07_recursive.sql
```

Database benchmark phải là database sạch riêng. Nếu database đã tồn tại, drop trước khi dựng lại. Chạy `01_schema.sql`, `02_constraints.sql`, `04_functions.sql`, `05_triggers.sql`, sau đó:

```powershell
python data/generator/generate_data.py --customers 10000 --sellers 100 --products 1000 --orders 100000 --seed 20261003
python data/benchmark/run_benchmark.py --warmup 3 --runs 7
```

`sql/08_benchmark.sql` chỉ là bản SQL tham chiếu; không dùng để tạo bằng chứng mới.

## Lệnh rút gọn

Chạy từ thư mục gốc repo. Trên Windows luôn thêm `--default-character-set=utf8mb4`; thiếu tùy chọn này, tên tiếng Việt
bị lỗi `?` và truy vấn cây danh mục báo `ERROR 1366`.

| Mục đích | Lệnh |
|---|---|
| Dựng lại database mẫu (01 → 02 → 03 → 04 → 05) | `mysql --default-character-set=utf8mb4 -u root -p -e "source data/seed/reset_sample_db.sql"` |
| Chạy toàn bộ kiểm thử hồi quy, lưu log | `python tests/regression/run_regression.py` (tự dựng lại database mẫu; xem `tests/regression/README.md`) |
| Dựng lại database sạch cho generator (01 → 02 → 04 → 05) | `mysql --default-character-set=utf8mb4 -u root -p -e "source data/generator/reset_bench_db.sql"` |

Hai script reset đều **xóa** database `ecommerce_advanced` trước khi dựng lại. Trong PowerShell, gọi mysql bằng
`& "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" ...` nếu chưa thêm mysql vào `PATH`.

## Nguyên tắc tái lập

- Không đưa thông tin bí mật vào Git; chỉ lưu `.env.example`. Các script Python tự đọc `.env` ở thư mục gốc; biến môi trường đã đặt trước đó được ưu tiên.
- **Faker được ghim đúng phiên bản `40.43.0`** trong `requirements.txt`: Faker khác phiên bản có thể sinh tên, số điện thoại, địa chỉ khác nhau dù cùng seed, làm dữ liệu (và dấu vân tay) không còn trùng khớp. Luôn cài bằng `pip install -r requirements.txt`.
- Trình sinh dữ liệu nhận seed, số lượng bản ghi và tỷ lệ trạng thái qua tham số.
- Kết quả generator phải có đủ trạng thái `PAID`, `PROCESSING`, `SHIPPED`, `DELIVERED`, `CANCELLED`, `RETURNED`, review và một số dòng tồn kho thấp để Q06/Q09/Q22/Q24 có dữ liệu kiểm chứng.
- Ghi phiên bản MySQL, Python, Faker, PyMySQL, hệ điều hành, seed, quy mô bộ dữ liệu và thời gian chạy vào `data/benchmark/<YYYYMMDD-HHMMSS>-<machine>/metadata.md`; script benchmark tự tạo metadata cho lần chạy mới.
- Không điền kết quả benchmark hoặc ảnh chụp cơ sở dữ liệu nếu chưa thực sự chạy.

## Kiểm chứng tái lập

Sau khi chạy generator trên database sạch (không seed nhỏ) với lệnh chuẩn, mở MySQL client với
`--default-character-set=utf8mb4` và chạy:

```sql
SOURCE report/appendix/queries/20261025/tong_quan_du_lieu.sql;
```

Truy vấn cuối in "dấu vân tay" dữ liệu (tổng `CRC32` nội dung từng dòng của đơn, dòng hàng và khách hàng).
Với `--customers 10000 --sellers 100 --products 1000 --orders 100000 --seed 20261003` và Faker 40.43.0, kết quả phải là:

| Chỉ số | Giá trị kỳ vọng |
|---|---|
| orders / order_item / payment | 100.000 / 200.294 / 89.861 |
| tong_tien | 1299341550400.00 |
| van_tay_don | 214963667966105 |
| van_tay_dong_hang | 430637245459748 |
| van_tay_khach | 21487872654796 |

Các giá trị này đã khớp qua ba lần dựng dữ liệu độc lập (hai lần ngày 25/10, một lần ngày 03/11 — xem
`report/appendix/queries/20261025/README.md` và `data/benchmark/20261103-danh-win/README.md`).
Thời gian chạy generator thay đổi theo tải của máy (406–678 giây) và không ảnh hưởng dữ liệu.
Nếu khác: kiểm tra phiên bản Faker, database có sạch không (không nạp `03_seed_small.sql`, không có đơn từ demo), và tham số generator.
