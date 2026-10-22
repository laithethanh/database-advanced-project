# Dữ liệu khởi tạo

Lưu các tệp dữ liệu mẫu nhỏ, có thể tái lập, tại đây khi chúng được tách riêng khỏi các script SQL.

Hiện tại seed nhỏ nằm ngay trong `sql/03_seed_small.sql` (chưa tách file):

- Phạm vi: vài dòng cho mỗi bảng, chạy trên database mẫu `ecommerce_advanced`.
- Mục đích: fixture cho `tests/*.sql` (`CUS0001`, `SEL0001`, `SKU-DEMO-001`), demo trong `app/`, và chạy Q01–Q25 trên dữ liệu nhỏ.
- Không dùng cho đo hiệu năng: bộ dữ liệu lớn do `data/generator/generate_data.py` sinh trên database benchmark riêng.
