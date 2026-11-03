# Nhật ký đóng góp — Phạm Thành Danh (Nhóm 7, Đề tài 7)

Phân công (`PHAN_CHIA_OWNER_FILE_NHOM_7.md`): data generator, SQL động/nhúng, SQL Injection/bảo mật, benchmark,
tái lập, kiểm thử hồi quy, tích hợp phụ lục; chương báo cáo về benchmark và SQL Injection.
Làm trên nhánh `dev-danh`, mở PR vào `main`; Lại Thế Thành review và merge.

## Theo thời gian

| Ngày | Việc đã làm | Commit / PR | Bằng chứng |
|---|---|---|---|
| Tuần 6 (trước 22/10) | Cài MySQL 8.4.11, Python, VS Code; dựng database theo `sql/01` → `05`; chạy thử bộ test của nhóm | — | — |
| 22/10 | Viết lại `data/generator/generate_data.py` (≥ 100.000 đơn, seed cố định, mọi đơn đi đúng luật trigger), `app/dynamic_search.py` (ghép chuỗi vs tham số + whitelist), `app/embedded_sql.py` (cursor, commit/rollback, `CALL sp_checkout`), `data/benchmark/run_benchmark.py` (warmup 3, đo 7, trung vị, `EXPLAIN ANALYZE` trước/sau, chi phí ghi, tự xóa index); chạy generator 100.000 đơn, benchmark, demo, kiểm chứng tái lập lần đầu | `8687abd` → PR #3 (merge 22/10, `d8ffee3`) | `data/benchmark/20261022-danh-win/`, `report/appendix/danh/*.txt` |
| 22–23/10 | (Thành chỉnh tiếp sau khi merge: thêm địa chỉ/khuyến mãi vào generator, kiểm tra giá âm trong tìm kiếm, `db_config.py` đọc `.env`; Thành chạy bộ test và benchmark trên máy Thành) | `4b7ad31`, `649c7c2`, `c5ef192` | `report/appendix/tests/20261023/`, `data/benchmark/20261023-004420-DESKTOP-97LS755/` |
| 25/10 | Generator: biến thể, thương hiệu, khoảng giá theo từng loại hàng (`THONG_TIN_LOAI`, có kiểm tra đủ mọi danh mục lá); dựng database sạch, sinh 100.000 đơn, chạy Q01–Q25 và truy vấn đệ quy, ghi tổng quan + dấu vân tay; sinh lại lần 2 và so dấu vân tay (trùng); chạy lại demo SQL động/nhúng; phát hiện Q11 (chia cho tập rỗng, brand `Demo`) và Q20 (slug `dien-tu`) chỉ đúng trên seed nhỏ — gửi Tuấn, nhóm thống nhất giữ nguyên và ghi là hạn chế dữ liệu đầu vào | `098afd1`, `1134497` → PR #4 (merge 26/10, `1b75d36`) | `report/appendix/queries/20261025/`, `report/appendix/danh/20261025/` |
| 03/11 | Sinh lại bộ 100.000 đơn (lần tái lập thứ 3, dấu vân tay trùng 25/10) và chạy benchmark trên đúng bộ dữ liệu của Q01–Q25; ảnh chụp terminal generator, benchmark, demo; biểu đồ benchmark; ghim Faker 40.43.0; script dựng lại database mẫu/database sạch; `tests/security_tests.sql` kiểm thử SQL Injection ngay trong MySQL; `tests/regression/run_regression.py` chạy tự động toàn bộ kiểm thử hồi quy kể cả T03; cập nhật `docs/10`, `docs/11`, `docs/13`, README phụ lục | PR ngày 03/11 từ `dev-danh` | `data/benchmark/20261103-danh-win/`, `tests/regression/2026-11-03.md` + `report/appendix/tests/20261103/` (10/10 đạt) |

## File phụ trách

| Nhóm | File |
|---|---|
| Sinh dữ liệu, dựng database | `data/generator/generate_data.py`, `data/generator/reset_bench_db.sql`, `data/seed/reset_sample_db.sql`, `data/seed/README.md`, `requirements.txt`, `data/generator/requirements.txt` |
| SQL động, SQL nhúng, bảo mật | `app/dynamic_search.py`, `app/embedded_sql.py`, `tests/test_dynamic_search.py`, `tests/security_tests.sql` |
| Benchmark | `data/benchmark/run_benchmark.py`, `data/benchmark/README.md`, `data/benchmark/<lần chạy>/`, `docs/10-benchmark.md` |
| Tái lập, hồi quy | `docs/11-reproducibility.md`, `docs/13-experiment-runbook.md`, `tests/regression/README.md`, `tests/regression/run_regression.py`, `tests/regression/<ngày>.md` |
| Phụ lục | `report/appendix/README.md`, `report/appendix/danh/`, `report/appendix/queries/20261025/` |

## Kết quả kiểm chứng chính

- **Tái lập:** cùng lệnh generator và seed `20261003` cho cùng dữ liệu đến từng dòng qua 3 lần chạy độc lập
  (`van_tay_don` 214963667966105, `van_tay_dong_hang` 430637245459748, `van_tay_khach` 21487872654796).
- **Benchmark (03/11):** B3 32,83 → 0,14 ms (237,7×), B2 38,97 → 4,38 ms (8,9×), B1 1.575,52 → 929,90 ms (1,7×),
  B4 đối chứng không đổi; chi phí ghi +13%. Ba lần đo trên hai máy cho cùng xu hướng.
- **SQL Injection:** câu ghép chuỗi lộ toàn bộ 2.511 biến thể và 10.100 tài khoản; câu tham số + whitelist trả 0 dòng.
- **Kiểm thử hồi quy (03/11):** 10/10 bước đạt; T03 session B chờ khóa 4,05 giây rồi nhận `1644`, không oversell.
- **SQL nhúng:** checkout vượt kho bị `1644` và rollback, số đơn và tồn kho trước = sau; checkout hợp lệ tạo đơn `PAID`.

## Vấn đề gặp và cách xử lý

| Vấn đề | Nguyên nhân | Cách xử lý |
|---|---|---|
| Workbench báo lỗi khi chạy `04_functions.sql`, `05_triggers.sql` | Bản Workbench mới không xử lý `DELIMITER` | Chạy bằng mysql client: `mysql ... -e "source sql/04_functions.sql"` |
| Tên tiếng Việt thành `?`, truy vấn cây danh mục lỗi `ERROR 1366` | Client trên Windows dùng bảng mã của console | Luôn mở client với `--default-character-set=utf8mb4` (đã ghi vào docs và script) |
| File kết quả bị lặp nội dung | `TEE` ghi nối thêm vào file cũ | Xóa file cũ trước khi chạy lại |
| Chạy lại benchmark trong ngày ghi đè bằng chứng cũ | Thư mục kết quả đặt theo ngày | `run_benchmark.py` từ chối thư mục đã tồn tại, thêm `--label` |
| Số đơn thành 100.001 sau demo | Demo SQL nhúng tạo thêm đơn | Chạy truy vấn và benchmark trước, demo sau cùng |
| `order_id` thành công là 100002, không phải 100001 | Lần checkout lỗi đã cấp `AUTO_INCREMENT` trước khi rollback | Hành vi bình thường của InnoDB; ghi chú trong README bằng chứng |
| Tìm `Áo` ra "Dao kéo" | Collation `utf8mb4_0900_ai_ci` không phân biệt dấu | Không phải lỗi bảo mật; ghi chú trong báo cáo |
| Q11 trả toàn bộ khách, Q20 trả rỗng trên dữ liệu lớn | Tham số truy vấn chỉ có trong seed nhỏ | Báo Tuấn (owner); nhóm giữ nguyên, diễn giải là hạn chế dữ liệu đầu vào |
| Dữ liệu sinh ra khác giữa máy Danh và máy Thành | Khác phiên bản Faker (40.43.0 / 39.1.0) | Ghim `Faker==40.43.0` trong `requirements.txt` |
