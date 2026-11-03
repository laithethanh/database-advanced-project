-- Dựng lại DATABASE MẪU ecommerce_advanced từ đầu, CÓ nạp seed nhỏ (fixture CUS0001, SEL0001, SKU-DEMO-001).
-- Dùng cho: tests/*.sql, sql/09_transaction_tests.sql, demo trên dữ liệu nhỏ.
-- CẢNH BÁO: xóa toàn bộ dữ liệu hiện có trong ecommerce_advanced (kể cả bộ 100.000 đơn nếu đang có).
--
-- Chạy từ THƯ MỤC GỐC repo (các lệnh SOURCE dùng đường dẫn tương đối):
--   mysql --default-character-set=utf8mb4 -u root -p -e "source data/seed/reset_sample_db.sql"
-- (dùng được cả trong cmd lẫn PowerShell; PowerShell cần thêm & và dấu nháy quanh đường dẫn mysql.exe)
-- hoặc trong mysql>:  SOURCE data/seed/reset_sample_db.sql;
DROP DATABASE IF EXISTS ecommerce_advanced;
SOURCE sql/01_schema.sql;
SOURCE sql/02_constraints.sql;
SOURCE sql/03_seed_small.sql;
SOURCE sql/04_functions.sql;
SOURCE sql/05_triggers.sql;
SELECT 'database mau da dung lai (co seed nho)' AS ket_qua,
       (SELECT COUNT(*) FROM ecommerce_advanced.customer) AS so_khach,
       (SELECT COUNT(*) FROM ecommerce_advanced.orders) AS so_don;
