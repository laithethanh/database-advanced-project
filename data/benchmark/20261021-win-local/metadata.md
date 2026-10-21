# 00 — Metadata môi trường đo hiệu năng

## Máy chủ

| Thuộc tính | Giá trị |
|---|---|
| DBMS | MySQL Community Server 8.4.11 (Windows, service `MySQL84`) |
| Mức cô lập | REPEATABLE-READ |
| `innodb_buffer_pool_size` | 134.217.728 byte (128 MB) |
| `max_connections` | 151 |
| `information_schema_stats_expiry` | 0 (ép lấy số liệu storage tức thời) |

## Cơ sở dữ liệu đo

| Thuộc tính | Giá trị |
|---|---|
| Database đo | `ecommerce_bench` (bản sao riêng, không phải DB báo cáo) |
| Cách dựng | `sql/01_schema.sql` → `02_constraints.sql` → `04_functions.sql` → `05_triggers.sql` (bỏ qua seed nhỏ) |
| Generator | `python data/generator/generate_data.py --orders 100000 --seed 20261003` |
| Thời gian sinh dữ liệu | 6,5 phút (100 batch × 1.000 đơn) |
| Số đơn hàng | 100.000 |
| Số dòng order_item | 199.916 |
| Số payment | 95.231 |
| Số review | 20.000 |
| Số biến thể / dòng inventory | 2.000 / 6.000 |
| Khách hàng / người bán | 10.000 / 100 |

## Phân bố trạng thái đơn hàng

| Trạng thái | Số đơn |
|---|---|
| PAID | 52.784 |
| DELIVERED | 19.249 |
| SHIPPED | 9.643 |
| PROCESSING | 9.563 |
| CANCELLED | 4.769 |
| RETURNED | 3.992 |

## Dung lượng bảng (trước thí nghiệm index)

| Bảng | Số dòng ước tính | DATA_LENGTH | INDEX_LENGTH |
|---|---|---|---|
| inventory | 6.000 | 1.589.248 | 180.224 |
| order_item | 198.465 | 25.755.648 | 36.831.232 |
| orders | 99.008 | 18.399.232 | 14.761.984 |
| product_variant | 2.000 | 196.608 | 458.752 |

## Kiểm tra bất biến trên dữ liệu 100.000 đơn

Kết quả `q25-invariant-check.sql`: **0 vi phạm** (đối chiếu subtotal/grand_total/discount_total/line_total,
tồn kho âm, mismatch thanh toán, review không hợp lệ).
