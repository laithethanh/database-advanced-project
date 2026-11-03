# Dữ liệu khởi tạo

Lưu các tệp dữ liệu mẫu nhỏ, có thể tái lập, tại đây khi chúng được tách riêng khỏi các script SQL.

Hiện tại seed nhỏ nằm ngay trong `sql/03_seed_small.sql` (chưa tách file):

- Phạm vi: vài dòng cho mỗi bảng, chạy trên database mẫu `ecommerce_advanced`.
- Mục đích: fixture cho `tests/*.sql` (`CUS0001`, `SEL0001`, `SKU-DEMO-001`), demo trong `app/`, và chạy Q01–Q25 trên dữ liệu nhỏ.
- Không dùng cho đo hiệu năng: bộ dữ liệu lớn do `data/generator/generate_data.py` sinh trên database benchmark riêng.

## Dựng lại database mẫu

`reset_sample_db.sql` xóa `ecommerce_advanced` rồi chạy lần lượt `sql/01_schema.sql` → `02_constraints.sql` →
`03_seed_small.sql` → `04_functions.sql` → `05_triggers.sql`. Chạy từ thư mục gốc repo:

```text
mysql --default-character-set=utf8mb4 -u root -p -e "source data/seed/reset_sample_db.sql"
```

Dòng cuối in `database mau da dung lai (co seed nho)` cùng số khách và số đơn của seed.
`tests/regression/run_regression.py` dùng đúng script này trước khi chạy kiểm thử.

Database sạch không seed (cho generator 100.000 đơn): `data/generator/reset_bench_db.sql`.
