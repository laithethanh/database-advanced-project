# Hướng dẫn chạy cơ sở dữ liệu, lưu bằng chứng và bàn giao

## Dựng môi trường sạch

Dùng MySQL 8.0.18 trở lên (bắt buộc để dùng `EXPLAIN ANALYZE`) và một cơ sở dữ liệu dùng riêng cho thử nghiệm. Từ thư mục gốc repository, chạy theo đúng thứ tự:

```powershell
pip install -r requirements.txt
mysql -u <user> -p -e "DROP DATABASE IF EXISTS ecommerce_advanced;"
mysql -u <user> -p < sql/01_schema.sql
mysql -u <user> -p < sql/02_constraints.sql
mysql -u <user> -p < sql/03_seed_small.sql
mysql -u <user> -p < sql/04_functions.sql
mysql -u <user> -p < sql/05_triggers.sql
mysql -u <user> -p < tests/constraint_tests.sql
mysql -u <user> -p < tests/promotion_tests.sql
mysql -u <user> -p < tests/order_tests.sql
mysql -u <user> -p < sql/09_transaction_tests.sql
python -m unittest tests.test_dynamic_search -v
mysql -u <user> -p < sql/06_queries.sql
mysql -u <user> -p < sql/07_recursive.sql
```

Trên Windows thêm `--default-character-set=utf8mb4` vào mọi lệnh `mysql` (ví dụ `mysql --default-character-set=utf8mb4 -u <user> -p < sql/07_recursive.sql`); thiếu tùy chọn này, tên tiếng Việt bị lỗi `?` và truy vấn cây danh mục báo `ERROR 1366`.

Lệnh rút gọn cho cùng quy trình: `mysql --default-character-set=utf8mb4 -u <user> -p -e "source data/seed/reset_sample_db.sql"` dựng lại database mẫu (01 → 05), còn `python tests/regression/run_regression.py` tự dựng lại database mẫu, chạy toàn bộ test (kể cả T03 hai phiên) và lưu log vào `report/appendix/tests/<YYYYMMDD>/` cùng bảng tóm tắt `tests/regression/<YYYY-MM-DD>.md` (xem `tests/regression/README.md`).

`sql/01_schema.sql` là tệp lược đồ chuẩn, không chỉnh sửa trong phạm vi dự án. Giữ thứ tự schema → constraints → seed → function/procedure → trigger → test để mọi đối tượng phụ thuộc đã tồn tại trước khi được gọi.

`sql/03_seed_small.sql` chỉ nạp **dữ liệu mẫu nhỏ** (vài dòng cho mỗi bảng) vào database mẫu `ecommerce_advanced`: đây là fixture cho `tests/*.sql` (`CUS0001`, `SEL0001`, `SKU-DEMO-001`), dữ liệu cho demo và cho các truy vấn Q01–Q25 chạy trên dữ liệu nhỏ. Database đo hiệu năng là database **khác, sạch**, không nạp file seed này (xem mục "Dữ liệu lớn và đo hiệu năng").

`tests/constraint_tests.sql` tạo thủ tục trợ giúp `test_expect_error`, vì vậy phải chạy **trước** `tests/promotion_tests.sql` và `tests/order_tests.sql`. Ba tệp test này đều idempotent ở mức fixture nên có thể chạy lại trên cùng cơ sở dữ liệu mẫu.

`tests/promotion_tests.sql` tạo promotion và gọi checkout với nhiều mã, nên chỉ chạy trên cơ sở dữ liệu mẫu mới (đã nạp `03_seed_small.sql`: cần `CUS0001`, `SEL0001`, `SKU-DEMO-001`). Ví dụ gọi trực tiếp: `CALL sp_checkout(<customer_id>,'A','0900000001','HCM',30000,'X,Y',@order_id);` (tối đa 5 mã, cách nhau bởi dấu phẩy).

Kết quả mong đợi của từng nhóm test:

| Tệp | Kết quả phải đạt |
|---|---|
| `tests/constraint_tests.sql` | Mọi `CALL test_expect_error` trả về `PASS`; các truy vấn bất biến trả về 0 |
| `tests/promotion_tests.sql` | Kịch bản A: `promo_sum=20000`, `order_discount_total=20000`, `order_grand_total=110000`; kịch bản B: `promo_sum=100000`, `order_grand_total=30000`; các case lỗi trả `PASS` |
| `tests/order_tests.sql` | `fixture_status=FIXTURE_OK`; các case lỗi trả `PASS`; `orders_after=orders_before`, `stock_after=stock_before`, `promotion_used_count=1`; `ORDER_DATA_OK` có 0 vi phạm |
| `sql/09_transaction_tests.sql` | T01 tạo đơn `PAID` có tổng tiền khớp dòng hàng; T05 giữ nguyên số điện thoại sau rollback savepoint. T03 dùng bộ `tests/concurrency_setup.sql` + `concurrency_session_a.sql` + `concurrency_session_b.sql`, chạy 2 terminal hoặc tự động bằng `tests/regression/run_regression.py`; T04/T06 chạy thủ công. |
| `tests/security_tests.sql` | S1 (`' OR '1'='1' -- `) và S2 (`UNION SELECT email FROM account`) đều `PASS`: câu ghép chuỗi bị khai thác, câu `PREPARE ... USING` trả 0 dòng. Chỉ đọc dữ liệu, chạy được trên cả database mẫu lẫn database 100.000 đơn |

## Dữ liệu lớn và đo hiệu năng

1. Tạo một cơ sở dữ liệu sạch khác bằng các script 01, 02, 04 và 05 (bỏ qua `03_seed_small.sql` vì dữ liệu mẫu nhỏ không dùng để đo); nếu database đã tồn tại thì drop trước. Lệnh rút gọn: `mysql --default-character-set=utf8mb4 -u <user> -p -e "source data/generator/reset_bench_db.sql"`. Sao chép `.env.example` thành `.env` và điền thông tin kết nối; các script Python tự đọc tệp này, tuyệt đối không commit `.env`.
2. Chạy `pip install -r data/generator/requirements.txt`.
3. Chạy `python data/generator/generate_data.py --customers 10000 --sellers 100 --products 1000 --orders 100000 --seed 20261003`.
4. Chạy `python data/benchmark/run_benchmark.py --warmup 3 --runs 7`; script tự chạy baseline, tạo index thử nghiệm, đo optimized, đo chi phí ghi, dọn index và ghi bằng chứng.
5. Mỗi lần chỉ thêm một chỉ mục thử nghiệm trong bản sao cơ sở dữ liệu, chạy lại cùng khối lượng công việc, rồi ghi dung lượng chỉ mục và chi phí INSERT/UPDATE. Không báo cáo kết quả phỏng đoán.

Lưu `metadata.md`, kết quả `EXPLAIN ANALYZE` nguyên bản, thời gian và kết quả `SHOW INDEX` tại `data/benchmark/<YYYYMMDD-HHMMSS>-<machine>/`; mỗi lần chạy tạo một thư mục riêng, không ghi đè kết quả cũ. Lần chạy 22/10 có nạp thêm seed nhỏ trước generator; các lần sau dùng database sạch không seed.

`sql/08_benchmark.sql` chỉ là bản SQL tham chiếu; script tạo bằng chứng hiện hành là `data/benchmark/run_benchmark.py`.

## Kiểm thử hai phiên kết nối cùng mua lượng hàng cuối

Chạy `mysql -u <user> -p < tests/concurrency_setup.sql` trên **cơ sở dữ liệu mẫu mới tạo** (tệp này idempotent, chạy lại được). Tình huống này dùng đúng fixture của seed nhỏ (`SEL0001`, `SKU-DEMO-001`) nên database phải đã nạp `03_seed_small.sql`.
Sau đó mở hai cửa sổ terminal:

```powershell
# Terminal A (checkout đầy đủ: order PAID, giữ khóa 6 giây)
mysql -u <user> -p ecommerce_advanced < tests/concurrency_session_a.sql
# Terminal B, chạy khoảng 2 giây sau khi bắt đầu Terminal A
mysql -u <user> -p ecommerce_advanced < tests/concurrency_session_b.sql
```

Kịch bản thủ công tương đương:

```sql
-- Terminal A                         -- Terminal B
CALL sp_checkout(                     CALL sp_checkout(
  (SELECT account_id FROM customer      (SELECT account_id FROM customer
   WHERE customer_code='CUS2001'),       WHERE customer_code='CUS2002'),
  'Concurrent One','0900000101',       'Concurrent Two','0900000102',
  'HCM',0,NULL,@order_a);              'HCM',0,NULL,@order_b);
SELECT @order_a;                       SELECT @order_b;
```

Kết quả mong đợi: A checkout thành công với order `PAID` và payment `SUCCESS`; B chờ khóa dòng `inventory` rồi nhận `insufficient inventory`; tồn kho `0`; không oversell.
`python tests/regression/run_regression.py` chạy đúng kịch bản này tự động (B bắt đầu sau A 2 giây) và ghi log vào `22_concurrency_two_sessions.txt`.
Nếu chạy tay, ghi lại kết quả ở cả hai terminal cùng các dòng cuối trong `inventory`, `orders`, `payment` vào `report/appendix/tests/<run-date>/`. Khôi phục cơ sở dữ liệu kiểm thử sau khi thử nghiệm xong.

## Bằng chứng nhóm cần cung cấp

Thời gian thực tế, kế hoạch thực thi, thời gian chờ khóa, ảnh chụp, kết quả chạy ObjectDB và thông báo lỗi riêng của hệ quản trị phụ thuộc vào môi trường MySQL/ObjectDB. Repository không bịa các kết quả này; hãy thu thập bằng chứng bằng các lệnh phía trên.

## Bằng chứng hiện có

- Benchmark chính ngày 03/11 trên đúng bộ dữ liệu của Q01–Q25: `data/benchmark/20261103-danh-win/` (`README.md`, `metadata.md`, `benchmark-results.md`, `explain-*.txt`, `00_tong_quan_du_lieu.txt`, biểu đồ `benchmark-chart.png`, ảnh terminal). Hai lần đo đối chiếu: `20261022-danh-win/`, `20261023-004420-DESKTOP-97LS755/` (xem `data/benchmark/README.md`).
- Test SQL, transaction và Python ngày 23/10: `report/appendix/tests/20261023/`.
- Kiểm thử hồi quy tự động ngày 03/11: `tests/regression/2026-11-03.md`, log `report/appendix/tests/20261103/` — 10/10 bước đạt, gồm `tests/security_tests.sql` và T03 hai phiên (B chờ khóa 4,05 giây rồi nhận `ERROR 1644`; kho 0; CUS2002 không có đơn).
- Kết quả Q01–Q25 trên 100.000 đơn ngày 25/10: `report/appendix/queries/20261025/` (kèm kiểm chứng tái lập bằng dấu vân tay; lần 03/11 cho cùng dấu vân tay).
- Demo SQL động/SQL nhúng ngày 25/10: `report/appendix/danh/20261025/` (kèm ảnh chụp terminal).
- T03 lần chạy tay 23/10: `report/appendix/tests/20261023/70_concurrency_manual_setup.txt`, `71_concurrency_manual_two_sessions.txt` (B chờ khóa rồi nhận `ERROR 1644`).
- ObjectDB/OQL ngày 02/11: `report/appendix/objectdb/20261102/oql-output.md` (16/16 PASS).
- Nhật ký đóng góp phần của Danh: `report/appendix/danh/nhat-ky-dong-gop.md`.

Lưu ý T03: `tests/concurrency_session_a.sql` checkout đầy đủ trong transaction: khóa cart + inventory, tạo order/order_item/payment, chuyển `PAID`, cart `CHECKED_OUT`, giữ khóa 6 giây. B gọi `sp_checkout` và nhận `1644`, xác minh A `PAID`, B không có order, kho `0`.
