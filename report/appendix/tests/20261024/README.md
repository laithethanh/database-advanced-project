# Bằng chứng thực nghiệm ngày 24/10/2026

> Trạng thái: **chưa chạy**. Chỉ điền số liệu sau khi có log thật. Không tạo log rỗng hoặc số liệu ước lượng.

## Môi trường

- Máy:
- Hệ điều hành:
- MySQL:
- Python:
- PyMySQL:
- Faker:
- Commit:
- Database:

## File cần tạo

Các file `.txt` dưới đây là output thật, tạo bằng `TEE` của MySQL client hoặc chuyển hướng stdout/stderr. Không tạo file bằng tay.

| Nhóm | File | Nội dung |
|---|---|---|
| Dựng DB mẫu | `00_drop.txt` → `05_triggers.txt` | Drop, schema, constraints, seed, functions, triggers |
| Test SQL | `10_constraint_tests.txt` | 7/7 PASS; 5 bất biến trả `0` |
| Test SQL | `11_promotion_tests.txt` | Kịch bản A/B và 4 case lỗi |
| Test SQL | `12_order_tests.txt` | 7/7 PASS; đơn và tồn kho không đổi sau rollback |
| Test SQL | `13_transaction_tests.txt` | T01/T05 |
| Python | `14_python_unittest.txt` | 6/6 PASS |
| Ghi chú | `15_security_tests.txt` | `security_tests.sql` chỉ là mô tả; test thật ở unittest |
| T03 | `20_concurrency_setup.txt` | Setup: kho còn `1` |
| T03 | `21a_concurrency_session_a.txt` | Session A: checkout `PAID`, `payment_rows=1` |
| T03 | `21b_concurrency_session_b.txt` | Session B: lỗi `1644`, không tạo order |
| T03 | `21c_concurrency_verify.txt` | A `PAID`, B không có order, kho còn `0` |
| Generator | `40_generator_100k.txt` | Thời gian, seed, số dòng |
| Benchmark | `50_benchmark_run.txt` | Log console của benchmark |
| Cleanup | `99_cleanup_drop.txt` | Drop DB thực nghiệm |

Tùy chọn nếu muốn bằng chứng đầy đủ:

- `30`–`34`: log dựng database sạch cho benchmark (`01, 02, 04, 05`).
- `60`–`67`: log chạy lại thủ công T04/T06.
- `70`–`71`: chỉ dùng nếu chạy lại T03 theo cách thủ công; script T03 hiện tại đã được sửa.

## Kết quả

Điền sau khi chạy:

| Hạng mục | Kết quả | Bằng chứng |
|---|---|---|
| Constraint | `[chưa chạy]` | `10_constraint_tests.txt` |
| Promotion | `[chưa chạy]` | `11_promotion_tests.txt` |
| Order | `[chưa chạy]` | `12_order_tests.txt` |
| T01/T05 | `[chưa chạy]` | `13_transaction_tests.txt` |
| Unittest | `[chưa chạy]` | `14_python_unittest.txt` |
| T03 | `[chưa chạy]` | `20`, `21a`–`21c` |
| Generator | `[chưa chạy]` | `40_generator_100k.txt` |
| Benchmark | `[chưa chạy]` | `data/benchmark/20261024-.../` |
| Q01–Q25 | `[chưa chạy]` | `../queries/20261024/` |
| Demo SQL động/nhúng | `[chưa chạy]` | `../danh/20261024/` |

## T03 — kỳ vọng

Script `tests/concurrency_session_a.sql` hiện thực hiện checkout đầy đủ:

1. A khóa cart `ACTIVE` và dòng inventory.
2. A trừ `quantity_on_hand` đi `1`.
3. A tạo order `PENDING_PAYMENT`, `order_item`, payment `SUCCESS`; chuyển order sang `PAID`; cập nhật cart thành `CHECKED_OUT`.
4. A giữ khóa khoảng 6 giây rồi `COMMIT`.

Kỳ vọng:

- A: `locked_stock = 1`, `consumed_rows = 1`, `order_status = PAID`, `grand_total = 100000.00`, `payment_rows = 1`, `stock_after = 0`.
- B: chờ khóa rồi nhận `ERROR 1644 (45000): insufficient inventory`.
- B: không tạo order/payment; `order_b = NULL`, `payment_rows = 0`.
- Tồn kho cuối: `0`; CUS2001 có đúng `1` order PAID.
- Exit code `1` của B là đúng kỳ vọng, không phải lỗi thực nghiệm.

Ghi thêm thời gian B chờ vào `21b_concurrency_session_b.txt`. MySQL client dừng sau lỗi 1644 nên chạy query xác nhận riêng và lưu vào `21c_concurrency_verify.txt`.

## Lệnh gợi ý

Xem quy trình đầy đủ tại `docs/15-experiment-execution-guide.md`; thay mọi đường dẫn `20261023` bằng `20261024`.

Ví dụ ghi log T03:

```sql
TEE report/appendix/tests/20261024/21a_concurrency_session_a.txt;
SOURCE tests/concurrency_session_a.sql;
NOTEE;
```

Sau khi B báo lỗi, chạy query xác nhận và lưu vào `21c_concurrency_verify.txt`:

```sql
SELECT i.quantity_on_hand, i.reserved_quantity
FROM inventory i
JOIN product_variant v ON v.variant_id = i.variant_id
JOIN seller s ON s.account_id = i.seller_id
WHERE v.sku = 'SKU-DEMO-001' AND s.seller_code = 'SEL0001';
```

## Ghi chú

- Thời gian T03:
- Thời gian generator:
- Sai khác so với ngày 23/10:
- Lỗi hoặc lưu ý khi chạy:
