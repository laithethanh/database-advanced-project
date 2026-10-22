# Phần việc của Phạm Thành Danh — code và bằng chứng

Bản tự viết của Danh cho các phần: generator, SQL động/SQL Injection, SQL nhúng, benchmark.
Trên nhánh `dev-danh`, ba file `data/generator/generate_data.py`, `app/dynamic_search.py`, `app/embedded_sql.py`
**thay cho bản trước đó trên `main`**. Lưu ý khi gộp: `tests/test_dynamic_search.py` trên `main` đang gọi hàm
`build_search_sql` của bản cũ nên cần cập nhật theo bản mới (hàm `tao_cau_tim_kiem`); báo cáo và slide cũng đang
mô tả bản cũ. Việc giữ bản nào hoặc gộp ra sao do nhóm quyết định khi review Pull Request.

Tất cả chạy trên database `ecommerce_advanced` dựng bằng `sql/01`→`05` của `main`, MySQL 8.4.11, Python 3.15, PyMySQL 1.2.3.
Các script hỏi mật khẩu MySQL lúc chạy (không lưu mật khẩu trong file).

| Phần | Code | Lệnh chạy (từ thư mục gốc) | Bằng chứng | Kết quả chính |
|---|---|---|---|---|
| Generator ≥100.000 đơn | `data/generator/generate_data.py` | `python data/generator/generate_data.py --customers 10000 --sellers 100 --products 1000 --orders 100000` | `data/benchmark/20261022-danh-win/metadata.md` | 100.000 đơn, 200.176 dòng hàng, 89.920 thanh toán, 12.423 đánh giá trong 492,9 s; mọi đơn đi đúng luật trigger; **tái lập**: reset rồi chạy lại cùng seed cho dữ liệu giống hệt đến từng dòng (so bằng dấu vân tay CRC32) |
| SQL động + SQL Injection | `app/dynamic_search.py` | `python app/dynamic_search.py` | `report/appendix/danh/sql-injection-demo.txt` | Bản ghép chuỗi bị lộ 2.502 sản phẩm / 10.102 tài khoản; bản tham số + whitelist: 0 dòng, chặn 2/2 chèn ORDER BY |
| SQL nhúng (cursor) | `app/embedded_sql.py` | `python app/embedded_sql.py` | `report/appendix/danh/embedded-sql-demo.txt` | Giỏ hàng → duyệt cursor → checkout vượt kho bị rollback (trước = sau) → checkout hợp lệ PAID, kho 20→18 |
| Benchmark trước/sau index | `data/benchmark/run_benchmark.py` | `python data/benchmark/run_benchmark.py` | `data/benchmark/20261022-danh-win/benchmark-results.md`, `benchmark-analysis.md` | B3 nhanh ~305 lần, B2 5,5 lần, B1 1,6 lần, đối chứng B4 không đổi; ghi chậm +8% |

Lưu ý: generator của Danh tạo dữ liệu khác generator trên `main` (khác locale Faker, phân bố trạng thái, mã SKU…),
nên số liệu hai bên không so sánh trực tiếp từng con số mà chỉ so xu hướng.
