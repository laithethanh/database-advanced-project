# Lần chạy generator 100.000 đơn — máy của Danh

> Thư mục này lưu bằng chứng thực nghiệm do **Phạm Thành Danh** tự chạy trên máy cá nhân.
> Generator dùng ở đây là **bản tự viết của Danh** (`data/generator/generate_data.py` trên nhánh `dev-danh`),
> thay cho bản generator trước đó trên nhánh `main`.

## Môi trường

| Thuộc tính | Giá trị |
|---|---|
| Thời điểm chạy | 22/10/2026, khoảng 02:29–02:37 (giờ Việt Nam) |
| Máy | Laptop Windows 11 (`laptop-5p18fulb`) |
| DBMS | MySQL Community Server 8.4.11, chạy local, cổng 3306 |
| Python | 3.15.0 |
| Thư viện | PyMySQL 1.2.3, Faker 40.43.0 (locale `vi_VN`) |
| Database | `ecommerce_advanced`, dựng sạch bằng `01_schema` → `02_constraints` → `03_seed_small` → `04_functions` → `05_triggers` (bản SQL mới của nhóm, 32 trigger) |

> Lưu ý tái lập: `requirements.txt` của nhóm ghi `Faker>=30,<40`, máy này đang dùng Faker 40.43.0.
> Faker khác phiên bản có thể sinh tên/địa chỉ khác nhau dù cùng seed, nên khi so sánh giữa các máy
> cần dùng cùng phiên bản Faker.

## Lệnh đã chạy

```text
python data\generator\generate_data.py --customers 10000 --sellers 100 --products 1000 --orders 100000
```

Seed mặc định: `20261003`. Kích thước lô commit: 1.000 đơn/lô.

## Kết quả (in ra từ generator)

| Bảng / chỉ số | Số lượng |
|---|---|
| Khách hàng sinh thêm | 10.000 |
| Người bán | 100 |
| Danh mục | 22 (3 tầng, 13 danh mục lá) |
| Sản phẩm | 1.000 |
| Đơn hàng | 100.000 |
| Dòng hàng (order_item) | 200.176 |
| Thanh toán thành công | 89.920 |
| Đánh giá | 12.423 |
| **Tổng thời gian** | **492,9 giây (≈ 8,2 phút)** |
| Thời gian riêng phần đơn hàng | 488,8 giây (≈ 4,9 ms/đơn) |

Ảnh chụp terminal: `generator-100k-terminal.png` (cùng thư mục).

## Kiểm tra tính đúng và phân bố trạng thái (Workbench, 22/10/2026 ~03:47)

Lúc kiểm tra, database có **100.003 đơn**: 100.000 đơn của generator + 3 đơn tạo bởi các lần chạy demo
`app/embedded_sql.py` (đều ở trạng thái PAID).

| Phép kiểm tra | Kết quả | Ý nghĩa |
|---|---|---|
| `don_sai_tien` | **0** | Không đơn nào có `subtotal` khác tổng `line_total` của các dòng hàng |
| `thanh_toan_lech` | **0** | Không thanh toán nào có `amount` khác `grand_total` của đơn |

Ảnh chụp: `workbench-kiem-tra-dung.png`.

| Trạng thái | Số đơn | Tỉ lệ thực tế | Tỉ lệ thiết kế |
|---|---|---|---|
| PAID | 30.115 (gồm 3 đơn demo) | 30,1% | 30% |
| DELIVERED | 24.949 | 24,9% | 25% |
| SHIPPED | 14.887 | 14,9% | 15% |
| PROCESSING | 14.831 | 14,8% | 15% |
| RETURNED | 5.141 | 5,1% | 5% |
| CANCELLED | 5.079 | 5,1% | 5% |
| PENDING_PAYMENT | 5.001 | 5,0% | 5% |

Ảnh chụp: `workbench-trang-thai-don.png`. Phân bố thực tế khớp tỉ lệ thiết kế trong generator.

## Dung lượng bảng (information_schema.TABLES, 22/10/2026 ~03:53, sau khi chạy benchmark)

| Bảng | TABLE_ROWS (ước tính) | Dữ liệu (MB) |
|---|---|---|
| order_item | 198.992 | 24,6 |
| orders | 98.728 | 21,6 |
| payment | 89.628 | 7,5 |
| shipment | 41.490 | 3,5 |
| account | 10.193 | 1,5 |
| review | 12.220 | 1,5 |
| customer | 10.266 | 0,4 |
| inventory | 3.746 | 0,3 |
| product_variant | 2.502 | 0,2 |
| product | 1.001 | 0,2 |

Các bảng nhỏ còn lại (dữ liệu < 0,1 MB): `seller` 101, `category` 23, `cart_item` 7, `cart` 4, `warehouse` 3; `address`, `promotion`, `promotion_product`, `promotion_category`, `order_promotion` đều 0 dòng (generator chưa sinh địa chỉ và khuyến mãi). Tổng cộng 20 bảng.

Ảnh chụp: `workbench-dung-luong-bang.png` (2 dòng cuối `seller`, `warehouse` bị khuất trong ảnh).

- `TABLE_ROWS` của InnoDB là **số ước tính** từ thống kê, không phải số đếm chính xác
  (ví dụ `orders` ghi 98.728 trong khi `COUNT(*)` = 100.003). Số chính xác xem bảng đếm ở mục trên.
- Cột `index_mb` trong ảnh chụp **chưa được cập nhật** sau khi xóa index thử nghiệm của benchmark
  (order_item 46,7 MB, orders 16,6 MB, payment 9,5 MB trùng với số đo *khi đang có* index thử nghiệm),
  vì thống kê InnoDB chỉ làm mới sau `ANALYZE TABLE`. Dung lượng index **trước** benchmark đã được đo chính xác
  (có chạy `ANALYZE TABLE`) trong `benchmark-results.md`: order_item 39.072 KB, orders 13.376 KB, payment 6.176 KB.

## Kiểm chứng tái lập (22/10/2026, ~04:10–04:27)

**Cách làm:** lấy "dấu vân tay" của dữ liệu lần chạy 1 → xóa sạch database (reset) → chạy lại generator **đúng lệnh cũ,
cùng seed 20261003** từ database trống → lấy lại dấu vân tay và so sánh. Hai lần chạy dùng cùng máy, cùng
MySQL 8.4.11, Python 3.15.0, Faker 40.43.0.

Dấu vân tay = tổng `CRC32` của nội dung từng dòng, chỉ tính 100.000 đơn của generator (`order_number LIKE 'DORD-%'`):

```sql
SELECT
  (SELECT COUNT(*) FROM orders WHERE order_number LIKE 'DORD-%') AS so_don,
  (SELECT SUM(grand_total) FROM orders WHERE order_number LIKE 'DORD-%') AS tong_tien,
  (SELECT SUM(CRC32(CONCAT_WS('|', order_number, customer_id, status, grand_total, created_at)))
     FROM orders WHERE order_number LIKE 'DORD-%') AS van_tay_don,
  (SELECT SUM(CRC32(CONCAT_WS('|', oi.order_id, oi.seller_id, oi.variant_id, oi.quantity, oi.line_total)))
     FROM order_item oi JOIN orders o ON o.order_id = oi.order_id WHERE o.order_number LIKE 'DORD-%') AS van_tay_dong_hang,
  (SELECT SUM(CRC32(CONCAT_WS('|', email, full_name, phone)))
     FROM account WHERE email LIKE 'khach%') AS van_tay_khach;
```

| Chỉ số | Lần 1 | Lần 2 | Khớp |
|---|---|---|---|
| Dòng `[5]` của generator | 100.000 / 200.176 / 89.920 / 12.423 | 100.000 / 200.176 / 89.920 / 12.423 | ✅ |
| so_don | 100000 | 100000 | ✅ |
| tong_tien | 419693297000.00 | 419693297000.00 | ✅ |
| van_tay_don | 214777325796992 | 214777325796992 | ✅ |
| van_tay_dong_hang | 430211237421118 | 430211237421118 | ✅ |
| van_tay_khach | 21487872654796 | 21487872654796 | ✅ |
| Thời gian chạy | 492,9 giây | 636,4 giây | (không cần khớp) |

**Kết luận:** với cùng seed và cùng phiên bản thư viện, `data/generator/generate_data.py` sinh ra dữ liệu **giống hệt nhau đến từng dòng**
(mã đơn, khách, trạng thái, tiền, thời điểm đặt, từng dòng hàng, tên và số điện thoại khách), không chỉ giống số lượng.
Chỉ thời gian chạy khác do tải của máy, không ảnh hưởng tới dữ liệu. Benchmark (chạy trên dữ liệu lần 1) vì vậy
có thể chạy lại trên dữ liệu lần 2 với cùng đầu vào.

Ảnh chụp: `tai-lap-van-tay-lan-1.png`, `tai-lap-generator-lan-2.png`, `tai-lap-van-tay-lan-2.png`.

## Phân bố trạng thái thiết kế trong generator

| Trạng thái cuối | Tỉ lệ |
|---|---|
| PENDING_PAYMENT | 5% |
| CANCELLED (hủy trước khi thanh toán) | 5% |
| PAID | 30% |
| PROCESSING | 15% |
| SHIPPED | 15% |
| DELIVERED | 25% |
| RETURNED | 5% |

Số thanh toán 89.920 ≈ 90% số đơn, khớp với thiết kế (10% đơn chưa thanh toán hoặc hủy).

## Cách generator tuân thủ luật của database

- Đơn mới luôn bắt đầu `PENDING_PAYMENT`, `subtotal = 0` (trigger `trg_order_validate_insert`).
- `subtotal`/`grand_total` do trigger `trg_order_item_after_insert` tự cộng, Python không tự ghi.
- Thanh toán có `amount` đúng bằng `grand_total` (trigger `trg_payment_validate_amount_insert`).
- Trạng thái đơn đi từng bước `PAID → PROCESSING → SHIPPED → DELIVERED → RETURN_REQUESTED → RETURNED`
  (trigger `trg_order_validate_update`), không nhảy cóc.
- Chỉ đánh giá khi đơn `DELIVERED`, mỗi khách một sản phẩm một lần (trigger `trg_review_validate`, UNIQUE).
- Mọi giá trị đi qua tham số `%s` (parameterized query).

## Kiểm tra lại trong database (Workbench)

Đếm trực tiếp trong MySQL sau khi generator chạy xong — khớp hoàn toàn với số generator in ra
(10.001 khách = 1 khách của seed nhỏ + 10.000 khách sinh thêm):

| khach | don | dong_hang | thanh_toan | danh_gia |
|---|---|---|---|---|
| 10.001 | 100.000 | 200.176 | 89.920 | 12.423 |

Ảnh chụp: `workbench-dem-bang.png`.

## Việc còn lại cho bộ bằng chứng này

- [x] Đếm số dòng các bảng chính trong Workbench (xem mục trên).
- [x] Ghi kết quả 2 phép kiểm tra tính đúng (xem mục trên).
- [x] **Kiểm chứng tái lập** (xem mục trên): 2 lần chạy độc lập cho dữ liệu giống hệt nhau.
- [x] Ghi phân bố trạng thái đơn (xem mục trên).
- [x] Ghi dung lượng bảng (xem mục trên; dung lượng index trước benchmark nằm trong `benchmark-results.md`).
