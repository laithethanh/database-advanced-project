# Phần việc của Phạm Thành Danh — code và bằng chứng

Vai trò trong nhóm 7: data generator, SQL động/SQL Injection, SQL nhúng, benchmark, tái lập, kiểm thử hồi quy và tích hợp
phụ lục. Nhật ký theo ngày, commit và PR: `nhat-ky-dong-gop.md`.

Môi trường chạy bằng chứng: laptop Windows 11 (`laptop-5p18fulb`), MySQL 8.4.11, Python 3.15.0, Faker 40.43.0.
Kết nối MySQL đọc từ `.env` qua `db_config.py` (không lưu mật khẩu trong code hay log).

| Phần | Code | Lệnh chạy (từ thư mục gốc) | Bằng chứng chính | Kết quả chính |
|---|---|---|---|---|
| Generator ≥ 100.000 đơn | `data/generator/generate_data.py` | `python data/generator/generate_data.py --customers 10000 --sellers 100 --products 1000 --orders 100000 --seed 20261003` | `report/appendix/queries/20261025/README.md`, `data/benchmark/20261103-danh-win/README.md` | 100.000 đơn, 200.294 dòng hàng, 89.861 thanh toán, 12.425 đánh giá; biến thể/thương hiệu/giá theo loại hàng; **3 lần sinh cùng seed cho cùng dấu vân tay** (25/10 hai lần, 03/11) |
| SQL động + SQL Injection | `app/dynamic_search.py`, `tests/test_dynamic_search.py`, `tests/security_tests.sql` | `python app/dynamic_search.py` | `20261025/dynamic-search.txt`, `.png` | Ghép chuỗi: lộ 2.511 biến thể (`OR 1=1`) và 10.100 tài khoản (`UNION`); tham số + whitelist: 0 dòng, chặn 2/2 lần chèn ORDER BY |
| SQL nhúng (cursor) | `app/embedded_sql.py` | `python app/embedded_sql.py` | `20261025/embedded-sql.txt`, `.png` | Giỏ → duyệt cursor → đặt vượt kho bị `1644` và rollback (trước = sau) → checkout hợp lệ `PAID`, kho 59 → 57 |
| Benchmark trước/sau index | `data/benchmark/run_benchmark.py` | `python data/benchmark/run_benchmark.py --label <tên>` | `data/benchmark/20261103-danh-win/` | B3 237,7×, B2 8,9×, B1 1,7×, đối chứng B4 không đổi; ghi chậm +13%; biểu đồ `benchmark-chart.png` |
| Dựng lại database | `data/seed/reset_sample_db.sql`, `data/generator/reset_bench_db.sql` | `mysql --default-character-set=utf8mb4 -u root -p -e "source <file>"` | — | Database mẫu (01 → 05) hoặc database sạch cho generator (01, 02, 04, 05) |
| Kiểm thử hồi quy tự động | `tests/regression/run_regression.py` | `python tests/regression/run_regression.py` | `tests/regression/2026-11-03.md`, `report/appendix/tests/20261103/` | 10/10 bước đạt (R01–R08, kể cả T03 hai phiên và `tests/security_tests.sql`) |

## Các thư mục trong `danh/`

| Thư mục / file | Ngày | Nội dung |
|---|---|---|
| `20261025/` | 25/10 (ảnh 03/11) | **Bản chính**: demo SQL động và SQL nhúng trên bộ 100.000 đơn của Q01–Q25 |
| `20261023/` | 23/10 | Cùng hai demo, Thành chạy trên máy Thành |
| `sql-injection-demo.txt`, `embedded-sql-demo.txt`, `embedded-sql-demo.png` | 22/10 | Lần chạy đầu với bản generator đầu (100.003 đơn, có lẫn seed nhỏ) — giữ để đối chiếu |

Số liệu của lần 22/10 khác bản chính vì dữ liệu khác (generator bản đầu); xu hướng giống nhau.
