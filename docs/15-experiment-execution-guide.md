# Hướng dẫn chạy thực nghiệm

Tài liệu này dùng cho môi trường Windows/PowerShell 5.1 của dự án. `README.md` và `docs/13-experiment-runbook.md` được giữ nguyên theo yêu cầu; khi chạy trên PowerShell, dùng các lệnh trong tài liệu này thay cho cú pháp `mysql ... < file.sql` (PowerShell 5.1 không hỗ trợ toán tử `<`).

## 1. Phạm vi

Quy trình gồm:

1. Dựng database mẫu và chạy kiểm thử chức năng.
2. Chạy T03 — hai phiên tranh mua đơn vị cuối.
3. Sinh 100.000 đơn, chạy Q01–Q25, benchmark và demo ứng dụng.
4. Lưu bằng chứng, dọn database và kiểm tra trạng thái cuối.

Không thuộc phạm vi tài liệu này:

- ObjectDB/OQL: repo chưa có JAR và harness JPA.
- `sql/08_benchmark.sql`: chỉ là bản tham chiếu; benchmark chuẩn dùng `data/benchmark/run_benchmark.py`.
- `tests/security_tests.sql`: chỉ chứa mô tả; kiểm thử thật nằm ở unittest.

## 2. Chuẩn bị

### 2.1. MySQL

Dùng MySQL 8.0.18 trở lên. Trên máy hiện tại, client không có trong `PATH`; dùng đường dẫn đầy đủ:

```powershell
$MYSQL = 'D:\MySQL\Server\MySQL Server 8.4\bin\mysql.exe'
& $MYSQL --version
```

Kỳ vọng:

```text
mysql.exe Ver 8.4.11 ...
```

Không dùng client MariaDB của XAMPP cho server MySQL 8 vì có thể không hỗ trợ `caching_sha2_password`.

Kiểm tra server:

```powershell
& $MYSQL -u root -p -e "SELECT VERSION();"
```

Không drop database `military_management`. Database thực nghiệm là `ecommerce_advanced`.

### 2.2. Python và biến môi trường

Chạy từ thư mục gốc repo:

```powershell
python --version
python -m pip install -r requirements.txt
```

Tạo `.env` từ `.env.example` và điền thông tin thật:

```text
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=ecommerce_advanced
DB_USER=root
DB_PASSWORD=<mật-khẩu-của-bạn>
```

Không commit `.env`. Các script Python tự đọc file này.

### 2.3. Thư mục bằng chứng

Repo đang ignore `*.log`; dùng `.txt` hoặc `.md` cho bằng chứng muốn commit.

```powershell
New-Item -ItemType Directory -Force `
  report\appendix\tests\20261023, `
  report\appendix\queries\20261023, `
  report\appendix\danh\20261023
```

Có thể dùng thư mục theo ngày chạy thực tế; không ghi đè kết quả cũ.

## 3. Pha 1 — Database mẫu và kiểm thử chức năng

### 3.1. Dựng database mẫu

Mở client MySQL từ thư mục gốc repo:

```powershell
& $MYSQL -u root -p
```

Trong cửa sổ `mysql>`:

```sql
DROP DATABASE IF EXISTS ecommerce_advanced;
SOURCE sql/01_schema.sql;
SOURCE sql/02_constraints.sql;
SOURCE sql/03_seed_small.sql;
SOURCE sql/04_functions.sql;
SOURCE sql/05_triggers.sql;
```

Phải drop database trước vì `sql/01_schema.sql` không idempotent.

`sql/03_seed_small.sql` chỉ dùng cho database mẫu và các test cần fixture `CUS0001`, `SEL0001`, `SKU-DEMO-001`. Không nạp file này cho database benchmark.

Có thể lưu output bằng:

```sql
TEE report/appendix/tests/20261023/00_setup.txt;
SOURCE sql/01_schema.sql;
SOURCE sql/02_constraints.sql;
SOURCE sql/03_seed_small.sql;
SOURCE sql/04_functions.sql;
SOURCE sql/05_triggers.sql;
NOTEE;
```

### 3.2. Chạy kiểm thử SQL

Thứ tự bắt buộc: constraint trước, rồi promotion/order; `constraint_tests.sql` tạo procedure `test_expect_error`.

```sql
TEE report/appendix/tests/20261023/10_constraint_tests.txt;
SOURCE tests/constraint_tests.sql;
NOTEE;

TEE report/appendix/tests/20261023/11_promotion_tests.txt;
SOURCE tests/promotion_tests.sql;
NOTEE;

TEE report/appendix/tests/20261023/12_order_tests.txt;
SOURCE tests/order_tests.sql;
NOTEE;

TEE report/appendix/tests/20261023/13_transaction_tests.txt;
SOURCE sql/09_transaction_tests.sql;
NOTEE;
```

Kỳ vọng:

- Constraint: 7/7 case `PASS`; 5 bất biến trả `0`.
- Promotion: kịch bản A `promo_sum=20000`, `grand_total=110000`; kịch bản B `promo_sum=100000`, `grand_total=30000`; 4 case lỗi `PASS`.
- Order: 7/7 case `PASS`; số đơn và tồn kho không đổi sau rollback; `ORDER_DATA_OK=0`.
- `sql/09`: T01 tạo đơn `PAID` có tổng tiền khớp; T05 giữ nguyên số điện thoại sau rollback savepoint.
- T03/T04/T06 không tự chạy trong `sql/09`; thực hiện thủ công.

### 3.3. Test Python và demo trên database mẫu

```powershell
python -m unittest tests.test_dynamic_search -v
```

Kỳ vọng: 6/6 `PASS`.

Chạy Q01–Q25 trên database mẫu:

```sql
TEE report/appendix/queries/20261023/sample_queries.txt;
SOURCE sql/06_queries.sql;
SOURCE sql/07_recursive.sql;
NOTEE;
```

Chạy demo:

```powershell
python app\dynamic_search.py
python app\embedded_sql.py --customer CUS0001
```

`embedded_sql.py` mặc định dùng `DCUS000001`, chỉ có trong dữ liệu generator. Với database mẫu phải truyền `--customer CUS0001`.

## 4. T03 — Hai phiên tranh mua đơn vị cuối

### 4.1. Chuẩn bị dữ liệu

Database phải là database mẫu mới, đã nạp `03_seed_small.sql`.

```sql
SOURCE tests/concurrency_setup.sql;
```

Kiểm tra setup phải trả về hai khách hàng `CUS2001`, `CUS2002`, mỗi người có giỏ chứa đúng 1 đơn vị, available stock bằng `1`.

### 4.2. Chạy hai phiên

Mở **hai terminal** riêng và kết nối đúng database:

```powershell
# Terminal A
& $MYSQL -u root -p ecommerce_advanced
```

```powershell
# Terminal B
& $MYSQL -u root -p ecommerce_advanced
```

Trong terminal A:

```sql
TEE report/appendix/tests/20261023/70_concurrency_a.txt;
SOURCE tests/concurrency_session_a.sql;
NOTEE;
```

Trong terminal B, chạy sau khi A bắt đầu khoảng 2 giây:

```sql
TEE report/appendix/tests/20261023/71_concurrency_b.txt;
SOURCE tests/concurrency_session_b.sql;
NOTEE;
```

`tests/concurrency_session_a.sql` hiện thực hiện checkout đầy đủ trong một transaction:

1. Khóa cart `ACTIVE` và dòng inventory.
2. Trừ `quantity_on_hand` đi 1 trong cùng transaction.
3. Tạo order `PENDING_PAYMENT`, `order_item`, payment `SUCCESS`; chuyển order sang `PAID`; cập nhật cart thành `CHECKED_OUT`.
4. Giữ khóa khoảng 6 giây rồi `COMMIT`.

Vì vậy A là một giao dịch checkout hợp lệ; B phải chờ khóa rồi thất bại.

### 4.3. Kết quả mong đợi

Session A:

- `locked_stock = 1`.
- `consumed_rows = 1`.
- `order_status = PAID`.
- `grand_total = 100000.00`.
- `payment_rows = 1`.
- `stock_after = 0`.
- `hold_lock_seconds = 0` sau khi `SLEEP`.
- `session_a = session A: completed checkout and released the lock`.

Session B:

- Chờ khoảng 4 giây.
- Nhận `ERROR 1644 (45000): insufficient inventory`.
- Không tạo order/payment cho B (`order_b = NULL` nếu kiểm tra).
- `stock = 0`.
- `cus2001_paid_orders = 1`.

MySQL client dừng khi gặp lỗi 1644 nên các `SELECT` cuối trong session B có thể không chạy. Chạy query xác nhận riêng:

```sql
SELECT o.order_id, o.status, o.grand_total,
       (SELECT COUNT(*) FROM payment p WHERE p.order_id = o.order_id AND p.status = 'SUCCESS') AS payment_rows
FROM orders o
JOIN customer c ON c.account_id = o.customer_id
WHERE c.customer_code = 'CUS2001';

SELECT i.quantity_on_hand, i.reserved_quantity
FROM inventory i
JOIN product_variant v ON v.variant_id = i.variant_id
JOIN seller s ON s.account_id = i.seller_id
WHERE v.sku = 'SKU-DEMO-001' AND s.seller_code = 'SEL0001';
```

## 5. Pha 2 — Dữ liệu 100.000 đơn và benchmark

### 5.1. Dựng database sạch

Trong `mysql>`:

```sql
DROP DATABASE IF EXISTS ecommerce_advanced;
SOURCE sql/01_schema.sql;
SOURCE sql/02_constraints.sql;
SOURCE sql/04_functions.sql;
SOURCE sql/05_triggers.sql;
```

Không nạp `sql/03_seed_small.sql`.

### 5.2. Sinh dữ liệu

```powershell
python data\generator\generate_data.py `
  --customers 10000 `
  --sellers 100 `
  --products 1000 `
  --orders 100000 `
  --seed 20261003
```

Thời gian tham khảo trên máy hiện tại: khoảng 17 phút. Faker hiện tại là 39.1.0; số dòng phụ có thể khác nếu đổi phiên bản.

Kiểm tra:

```sql
SELECT COUNT(*) AS orders FROM orders;
SELECT COUNT(*) AS order_items FROM order_item;
SELECT COUNT(*) AS payments FROM payment;
```

Kỳ vọng tối thiểu: `orders = 100000`.

### 5.3. Chạy Q01–Q25 trên dữ liệu lớn

```sql
TEE report/appendix/queries/20261023/06_queries_100k.txt;
SOURCE sql/06_queries.sql;
NOTEE;

TEE report/appendix/queries/20261023/07_recursive_100k.txt;
SOURCE sql/07_recursive.sql;
NOTEE;
```

Q01–Q25 phải chạy đủ; Q25 phải trả về 0 dòng vi phạm.

### 5.4. Benchmark

```powershell
python data\benchmark\run_benchmark.py --warmup 3 --runs 7
```

Script sẽ tự động:

- Kiểm tra tối thiểu 100.000 đơn và `order_id = 50000`.
- Đo baseline.
- Tạo index thử nghiệm.
- Đo optimized.
- Đo chi phí ghi.
- Xóa index trong `finally`.
- Ghi bằng chứng vào `data/benchmark/<timestamp>-<machine>/`.

Sau khi chạy, kiểm tra:

- `metadata.md`
- `benchmark-results.md`
- `explain-baseline.txt`
- `explain-optimized.txt`
- Không còn index `idx_bench_*`.

Kết quả tham khảo ngày 23/10: `data/benchmark/20261023-004420-DESKTOP-97LS755/`.

### 5.5. Demo trên dữ liệu lớn

```powershell
python app\dynamic_search.py
python app\embedded_sql.py
```

`dynamic_search.py` demo cả truy vấn không an toàn và parameterized. `embedded_sql.py` thử mua vượt tồn kho, nhận lỗi, rollback, rồi checkout thành công.

## 6. Bằng chứng và dọn dẹp

### 6.1. Vị trí bằng chứng

- Test SQL, transaction, concurrency: `report/appendix/tests/<run-date>/`.
- Q01–Q25: `report/appendix/queries/<run-date>/`.
- Demo SQL động/nhúng: `report/appendix/danh/<run-date>/`.
- Benchmark: `data/benchmark/<timestamp>-<machine>/`.

Dùng `.txt` hoặc `.md`; không dùng `.log` nếu muốn commit.

### 6.2. Dọn database

Sau khi lưu bằng chứng:

```sql
DROP DATABASE IF EXISTS ecommerce_advanced;
SHOW DATABASES;
```

Kỳ vọng còn lại:

```text
information_schema
military_management
mysql
performance_schema
sys
```

Không drop `military_management`. Xóa file cấu hình tạm chứa mật khẩu nếu có; giữ `.env` local nhưng không commit.

## 7. Checklist

- [ ] MySQL 8.4.11 đang chạy, đúng client.
- [ ] `.env` đã cấu hình, không bị commit.
- [ ] Database mẫu dựng đúng thứ tự 01 → 05.
- [ ] Constraint/promotion/order/transaction test đạt kỳ vọng.
- [ ] Unittest 6/6 PASS.
- [ ] T03: A trừ kho, B nhận lỗi `1644`, kho còn 0.
- [ ] Generator tạo đủ 100.000 đơn.
- [ ] Q01–Q25 chạy đủ, Q25 không vi phạm.
- [ ] Benchmark hoàn tất, không còn index `idx_bench_*`.
- [ ] Demo SQL động/nhúng chạy đúng.
- [ ] Bằng chứng được lưu dưới dạng `.txt`/`.md`.
- [ ] `ecommerce_advanced` đã drop; `military_management` còn nguyên.
