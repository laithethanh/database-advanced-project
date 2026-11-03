-- Dựng lại database ecommerce_advanced SẠCH, KHÔNG nạp seed nhỏ — chuẩn bị chạy generator 100.000 đơn.
-- Sau script này chạy:
--   python data/generator/generate_data.py --customers 10000 --sellers 100 --products 1000 --orders 100000 --seed 20261003
-- CẢNH BÁO: xóa toàn bộ dữ liệu hiện có trong ecommerce_advanced.
--
-- Chạy từ THƯ MỤC GỐC repo (các lệnh SOURCE dùng đường dẫn tương đối):
--   mysql --default-character-set=utf8mb4 -u root -p -e "source data/generator/reset_bench_db.sql"
-- (dùng được cả trong cmd lẫn PowerShell; PowerShell cần thêm & và dấu nháy quanh đường dẫn mysql.exe)
-- hoặc trong mysql>:  SOURCE data/generator/reset_bench_db.sql;
DROP DATABASE IF EXISTS ecommerce_advanced;
SOURCE sql/01_schema.sql;
SOURCE sql/02_constraints.sql;
SOURCE sql/04_functions.sql;
SOURCE sql/05_triggers.sql;
SELECT 'database sach da dung lai (khong seed), san sang chay generator' AS ket_qua,
       (SELECT COUNT(*) FROM ecommerce_advanced.customer) AS so_khach,
       (SELECT COUNT(*) FROM ecommerce_advanced.orders) AS so_don;
