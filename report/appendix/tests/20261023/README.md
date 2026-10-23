# Bằng chứng chạy thực nghiệm ngày 23/10/2026

Môi trường: MySQL 8.4.11, Python 3.13.2, PyMySQL 2.2.8, Faker 39.1.0, Windows 11.

## Dựng database mẫu và kiểm thử SQL

- `00_drop.txt` → `05_triggers.txt`: dựng lại database `ecommerce_advanced` bằng `01_schema.sql`, `02_constraints.sql`, `03_seed_small.sql`, `04_functions.sql`, `05_triggers.sql`.
- `10_constraint_tests.txt`: 7/7 case PASS; 5 bất biến đều trả `0`.
- `11_promotion_tests.txt`: kịch bản A đúng `promo_sum=20000`, `grand_total=110000`; kịch bản B đúng `promo_sum=100000`, `grand_total=30000`; 4 case lỗi PASS.
- `12_order_tests.txt`: 7/7 case PASS; `orders_before=orders_after=3`, `stock_before=stock_after=18`, `promotion_used_count=1`, `ORDER_DATA_OK=0`.
- `13_transaction_tests.txt`: T01 tạo đơn `PAID` với `subtotal=100000`, `grand_total=130000`, `item_sum=100000`; T05 giữ nguyên số điện thoại `0900000001`.
- `14_python_unittest.txt`: 6/6 test PASS.
- `15_security_tests.txt`: file `tests/security_tests.sql` chỉ là mô tả; phần kiểm thử thực tế nằm ở unittest.
- `20_concurrency_setup.txt`, `21_concurrency_two_sessions.txt`: bản chạy T03 ngày 23/10 với script cũ. Session B chờ khóa 4,08 giây rồi **thành công**, tạo order `6` PAID; tồn kho còn `0`; CUS2001 không có đơn PAID. Không oversell nhưng log này không chứng minh được "một session thất bại". Script hiện tại đã được sửa để A checkout đầy đủ; cần chạy lại theo `docs/15` và lưu log mới.
- `67_manual_t04_t06.txt`: T04 `PAID → DELIVERED` và `DELIVERED → PROCESSING` đều bị từ chối; T06 dùng `GIAM10,NO-SUCH-COUPON` bị từ chối, `orders` và tồn kho không đổi, `used_count` của GIAM10 không đổi.
- `70_concurrency_manual_setup.txt`, `71_concurrency_manual_two_sessions.txt`: kiểm tra bổ sung T03. Session A khóa dòng và lấy đơn vị cuối, session B chờ 2,07 giây rồi nhận `ERROR 1644 insufficient inventory`. Đây là bằng chứng không oversell khi session A thực sự tiêu thụ đơn vị cuối.

## Dữ liệu lớn và benchmark

- `40_generator_100k.txt`: sinh 100.000 đơn, 200.329 dòng hàng, 89.908 payment, 12.465 review; thời gian 1.016 giây.
- `50_benchmark_run.txt`: chạy `--warmup 3 --runs 7`, hoàn tất và đã xóa index thử nghiệm.
- Kết quả đầy đủ: `data/benchmark/20261023-004420-DESKTOP-97LS755/`.
- B1 `3.297,26 → 2.074,29 ms` (1,6×); B2 `97,69 → 14,69 ms` (6,7×); B3 `88,69 → 0,82 ms` (108,5×); B4 đối chứng `1,27 → 1,22 ms`.
- Chi phí ghi: `4.449,21 → 5.251,58 ms` (+18%).

## Truy vấn và ứng dụng

- `../../queries/20261023/06_queries_100k.txt`: Q01–Q17, Q21A, Q21B, Q22–Q25 trên 100.000 đơn.
- `../../queries/20261023/07_recursive_100k.txt`: Q18–Q20 trên 100.000 đơn.
- `../../danh/20261023/dynamic-search.txt`: demo SQL động và SQL Injection.
- `../../danh/20261023/embedded-sql.txt`: demo SQL nhúng; rollback khi vượt tồn kho và checkout thành công.

## Chưa chạy

- ObjectDB/OQL: máy có Java 25 nhưng không có ObjectDB/JPA harness hoặc file JAR ObjectDB trong repo.
- `sql/08_benchmark.sql`: chỉ là bản tham chiếu; benchmark chuẩn đã chạy bằng `data/benchmark/run_benchmark.py`.
