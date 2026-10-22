# Hướng dẫn chạy cơ sở dữ liệu, lưu bằng chứng và bàn giao

## Dựng môi trường sạch

Dùng MySQL 8.0.18 trở lên (bắt buộc để dùng `EXPLAIN ANALYZE`) và một cơ sở dữ liệu dùng riêng cho thử nghiệm. Từ thư mục gốc repository, chạy theo đúng thứ tự:

```powershell
pip install -r requirements.txt
mysql -u <user> -p < sql/01_schema.sql
mysql -u <user> -p < sql/02_constraints.sql
mysql -u <user> -p < sql/03_seed_small.sql
mysql -u <user> -p < sql/04_functions.sql
mysql -u <user> -p < sql/05_triggers.sql
mysql -u <user> -p < tests/constraint_tests.sql
mysql -u <user> -p < tests/promotion_tests.sql
mysql -u <user> -p < tests/order_tests.sql
python -m unittest tests.test_dynamic_search -v
mysql -u <user> -p < sql/06_queries.sql
mysql -u <user> -p < sql/07_recursive.sql
```

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

## Dữ liệu lớn và đo hiệu năng

1. Tạo một cơ sở dữ liệu sạch khác bằng các script 01, 02, 04 và 05 (bỏ qua `03_seed_small.sql` vì dữ liệu mẫu nhỏ không dùng để đo); sao chép `.env.example` thành `.env` và nạp các giá trị vào shell, tuyệt đối không commit tệp này.
2. Chạy `pip install -r data/generator/requirements.txt`.
3. Chạy `python data/generator/generate_data.py --orders 100000 --seed 20261003`.
4. Chạy `sql/08_benchmark.sql`; với mỗi truy vấn được chọn, chạy làm nóng 3 lần và đo thời gian 5 lần. Lưu kế hoạch thô và tính trung vị.
5. Mỗi lần chỉ thêm một chỉ mục thử nghiệm trong bản sao cơ sở dữ liệu, chạy lại cùng khối lượng công việc, rồi ghi dung lượng chỉ mục và chi phí INSERT/UPDATE. Không báo cáo kết quả phỏng đoán.

Lưu `metadata.md`, kết quả `EXPLAIN ANALYZE` nguyên bản, thời gian và kết quả `SHOW INDEX` tại `data/benchmark/<YYYYMMDD>-<machine>/`; mỗi lần chạy tạo một thư mục riêng, không ghi đè kết quả cũ.

## Kiểm thử hai phiên kết nối cùng mua lượng hàng cuối

Chạy `mysql -u <user> -p < tests/concurrency_setup.sql` trên **cơ sở dữ liệu mẫu mới tạo** (tệp này idempotent, chạy lại được). Tình huống này dùng đúng fixture của seed nhỏ (`SEL0001`, `SKU-DEMO-001`) nên database phải đã nạp `03_seed_small.sql`.
Sau đó mở hai cửa sổ terminal:

```powershell
# Terminal A (giữ khóa dòng inventory trong 6 giây)
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

Kết quả mong đợi: một session phải chờ khóa dòng `inventory`, session còn lại nhận `insufficient inventory` → không oversell.
Ghi lại kết quả ở cả hai terminal cùng các dòng cuối trong `inventory`, `orders`, `payment` vào `report/appendix/tests/<run-date>/`. Khôi phục cơ sở dữ liệu kiểm thử sau khi thử nghiệm xong.

## Bằng chứng nhóm cần cung cấp

Thời gian thực tế, kế hoạch thực thi, thời gian chờ khóa, ảnh chụp, kết quả chạy ObjectDB và thông báo lỗi riêng của hệ quản trị phụ thuộc vào môi trường MySQL/ObjectDB. Repository không bịa các kết quả này; hãy thu thập bằng chứng bằng các lệnh phía trên.

## Bằng chứng hiện có

- Benchmark và generator ngày 22/10: `data/benchmark/20261022-danh-win/` (`metadata.md`, `benchmark-results.md`, `benchmark-analysis.md`, `explain-baseline.txt`, `explain-optimized.txt`).
- Demo SQL động/SQL nhúng ngày 22/10: `report/appendix/danh/` (`sql-injection-demo.txt`, `embedded-sql-demo.txt`, ảnh chụp terminal).
- Kết quả test SQL, concurrency và Q01–Q25 của các lần chạy cũ đã được dọn; mỗi lần chạy lại tạo thư mục mới theo run-date.

Còn thiếu: output ObjectDB/OQL và ảnh chụp màn hình cho bài demo.
