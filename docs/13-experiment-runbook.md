# Hướng dẫn chạy cơ sở dữ liệu, lưu bằng chứng và bàn giao

## Dựng môi trường sạch

Dùng MySQL 8.0.18 trở lên (bắt buộc để dùng `EXPLAIN ANALYZE`) và một cơ sở dữ liệu dùng riêng cho thử nghiệm. Từ thư mục gốc repository, chạy theo đúng thứ tự:

```powershell
mysql -u <user> -p < sql/01_schema.sql
mysql -u <user> -p < sql/02_constraints.sql
mysql -u <user> -p < sql/03_seed_small.sql
mysql -u <user> -p < sql/04_functions.sql
mysql -u <user> -p < sql/05_triggers.sql
mysql -u <user> -p < tests/constraint_tests.sql
mysql -u <user> -p < tests/promotion_tests.sql
mysql -u <user> -p < sql/06_queries.sql
mysql -u <user> -p < sql/07_recursive.sql
```

`sql/01_schema.sql` là tệp lược đồ chuẩn, không chỉnh sửa trong phạm vi dự án. Phải nạp các script trigger và function **sau** dữ liệu mẫu nhỏ, vì các quy tắc kiểm tra sẽ từ chối chính xác những dòng danh mục chưa hoàn chỉnh trong giai đoạn khởi tạo.

`tests/promotion_tests.sql` tạo promotion và gọi checkout với nhiều mã, nên chỉ chạy trên cơ sở dữ liệu mẫu mới. Ví dụ gọi trực tiếp: `CALL sp_checkout(<customer_id>,'A','0900000001','HCM',30000,'X,Y',@order_id);` (tối đa 5 mã, cách nhau bởi dấu phẩy).

## Dữ liệu lớn và đo hiệu năng

1. Tạo một cơ sở dữ liệu sạch khác bằng các script 01, 02 và 05 (bỏ qua `03_seed_small.sql`); sao chép `.env.example` thành `.env` và nạp các giá trị vào shell, tuyệt đối không commit tệp này.
2. Chạy `pip install -r data/generator/requirements.txt`.
3. Chạy `python data/generator/generate_data.py --orders 100000 --seed 20261003`.
4. Chạy `sql/08_benchmark.sql`; với mỗi truy vấn được chọn, chạy làm nóng 3 lần và đo thời gian 5 lần. Lưu kế hoạch thô và tính trung vị.
5. Mỗi lần chỉ thêm một chỉ mục thử nghiệm trong bản sao cơ sở dữ liệu, chạy lại cùng khối lượng công việc, rồi ghi dung lượng chỉ mục và chi phí INSERT/UPDATE. Không báo cáo kết quả phỏng đoán.

Lưu `metadata.md`, kết quả `EXPLAIN ANALYZE` nguyên bản, thời gian và kết quả `SHOW INDEX` tại `data/benchmark/<YYYYMMDD>-<machine>/`.

## Kiểm thử hai phiên kết nối cùng mua lượng hàng cuối

Chạy `mysql -u <user> -p < tests/concurrency_setup.sql` trên **cơ sở dữ liệu mẫu mới tạo**. Sau đó thực thi gần như đồng thời trong hai cửa sổ terminal:

```sql
-- Terminal A                         -- Terminal B
CALL sp_checkout(                     CALL sp_checkout(
  (SELECT account_id FROM customer      (SELECT account_id FROM customer
   WHERE customer_code='CUS2001'),       WHERE customer_code='CUS2002'),
  'Concurrent One','0900000101',       'Concurrent Two','0900000102',
  'HCM',0,NULL,@order_a);              'HCM',0,NULL,@order_b);
SELECT @order_a;                       SELECT @order_b;
```

Thủ tục khóa các dòng tồn kho bằng `FOR UPDATE` và dùng câu lệnh cập nhật có điều kiện, vì vậy chỉ một lời gọi được commit. Ghi lại kết quả ở cả hai terminal cùng các dòng cuối trong `inventory`, `orders`, `payment`. Khôi phục cơ sở dữ liệu kiểm thử sau khi thử nghiệm xong.

## Bằng chứng nhóm cần cung cấp

Thời gian thực tế, kế hoạch thực thi, thời gian chờ khóa, ảnh chụp, kết quả chạy ObjectDB và thông báo lỗi riêng của hệ quản trị phụ thuộc vào môi trường MySQL/ObjectDB. Repository không bịa các kết quả này; hãy thu thập bằng chứng bằng các lệnh phía trên.
