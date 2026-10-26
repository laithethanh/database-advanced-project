# Kết quả Q01–Q25 trên dữ liệu 100.000 đơn — 25/10/2026

Người chạy: **Phạm Thành Danh**. Toàn bộ file trong thư mục này là output thật của MySQL client (`TEE`), không chỉnh tay.

## Môi trường

| Thuộc tính | Giá trị |
|---|---|
| Máy | Laptop Windows 11 (`laptop-5p18fulb`) |
| MySQL | Community Server 8.4.11, REPEATABLE-READ |
| Python / thư viện | Python 3.15.0, PyMySQL 1.2.3, Faker 40.43.0 |
| Code | `main` tại commit `9010112` + thay đổi generator (biến thể/thương hiệu/giá theo loại hàng) đẩy cùng thư mục này |
| MySQL client | `mysql --default-character-set=utf8mb4` (bắt buộc, xem mục Lưu ý) |

## Cách dựng dữ liệu

1. Database sạch, **không nạp** `sql/03_seed_small.sql`:
   `DROP DATABASE IF EXISTS ecommerce_advanced; SOURCE 01_schema; 02_constraints; 04_functions; 05_triggers`.
2. Sinh dữ liệu:
   `python data\generator\generate_data.py --customers 10000 --sellers 100 --products 1000 --orders 100000 --seed 20261003`
   — 406,5 giây (ảnh: `generator-100k-terminal.png`).
3. Ghi tổng quan (`tong_quan_du_lieu.sql` → `00_tong_quan_du_lieu.txt`), rồi chạy `sql/06_queries.sql` → `06_queries_100k.txt`
   và `sql/07_recursive.sql` → `07_recursive_100k.txt`.

## Tổng quan bộ dữ liệu (`00_tong_quan_du_lieu.txt`)

| Bảng | Số dòng | Bảng | Số dòng |
|---|---|---|---|
| customer | 10.000 | orders | 100.000 |
| seller | 100 | order_item | 200.294 |
| address | 20.125 | payment | 89.861 |
| category | 22 (3 tầng) | shipment | 44.783 |
| product | 1.000 | review | 12.425 |
| product_variant | 2.511 | promotion / order_promotion | 10 / 25.398 |
| inventory | 3.750 | cart / cart_item | 2.976 / 7.356 |

- Không có dữ liệu seed nhỏ (`CUS0001`, `SKU-DEMO-001` đều 0).
- Kiểm tra tính đúng — **tất cả bằng 0**: đơn sai tiền hàng, đơn sai tiền giảm, thanh toán lệch `grand_total`, tồn kho âm.
- Phân bố trạng thái: PAID 30,2% · DELIVERED 24,8% · SHIPPED 15,2% · PROCESSING 14,9% · CANCELLED 5,2% · PENDING_PAYMENT 5,0% · RETURNED 4,9%.
- Biến thể đúng theo loại hàng: quần áo S/M/L/XL, quần jean 28–32, điện thoại 64/128/256/512GB, nồi chảo 20/24/28cm,
  tranh 30x40/40x60/60x90cm…; iPhone chỉ hãng Apple, giá 15–35 triệu (bảng đầy đủ trong file 00).

## Kiểm chứng tái lập

Dựng lại database sạch và chạy lại generator đúng lệnh trên, so "dấu vân tay" (tổng CRC32 nội dung từng dòng):

| Chỉ số | Lần 1 (19:51) | Lần 2 (20:11) |
|---|---|---|
| tong_tien | 1299341550400.00 | 1299341550400.00 ✅ |
| van_tay_don | 214963667966105 | 214963667966105 ✅ |
| van_tay_dong_hang | 430637245459748 | 430637245459748 ✅ |
| van_tay_khach | 21487872654796 | 21487872654796 ✅ |

Hai lần chạy độc lập cho dữ liệu giống hệt nhau. File `00_tong_quan_du_lieu.txt` trong thư mục là của lần 2.

## Kết quả Q01–Q25 (`06_queries_100k.txt`)

| Truy vấn | Số dòng | Thời gian | Ghi chú |
|---|---|---|---|
| Q01 Top 10 sản phẩm theo doanh thu | 10 | 1,57 s | Cả 10 đều là iPhone (giá cao nhất) |
| Q02 Doanh thu từng người bán | 100 | 1,29 s | |
| Q03 Người bán chưa bán được gì | 0 | 0,21 s | Mọi người bán đều có doanh thu |
| Q04 Khách chưa có đơn đã thanh toán | 2 | 0,12 s | |
| Q05 SKU chưa từng bán | 0 | 0,03 s | |
| Q06 Tồn kho dưới ngưỡng | 206 | 0,00 s | |
| Q07 Khách mua ≥ 3 SKU khác nhau | 9.973 | 0,74 s | |
| Q08 SKU giá trên trung bình danh mục | 1.244 | 1,43 s | |
| Q09 Khách vừa mua vừa đánh giá | 12.425 | 0,41 s | Khớp số review |
| Q10 Người bán không bán gì trong nhánh danh mục | 0 | 0,00 s | |
| Q11 Phép chia theo thương hiệu | **10.000** | 4,16 s | **Cần sửa — xem bên dưới** |
| Q12 Người bán đạt ngưỡng doanh thu | 100 | 1,24 s | |
| Q13 Danh mục không có sản phẩm trực tiếp | 9 | 0,00 s | Đúng 3 danh mục tầng 1 + 6 tầng 2 |
| Q14 Top 3 SKU mỗi danh mục | 39 | 1,93 s | 13 danh mục lá × 3 |
| Q15 Xếp hạng người bán | 100 | 1,36 s | |
| Q16 Doanh thu theo tháng (LAG) | 12 | 0,84 s | 10/2025 – 09/2026 |
| Q17 Doanh thu trượt 30 ngày | 365 | 0,79 s | |
| Q21A Top người bán, tổng hợp trực tiếp | 10 | 1,10 s | |
| Q21B Cùng kết quả, tổng hợp trước | 10 | 0,83 s | Nhanh hơn Q21A (1 lần đo, chỉ tham khảo) |
| Q22 Khách có tỷ lệ trả hàng > 20% | 3.125 | 0,20 s | |
| Q23 Hiệu quả khuyến mãi | 10 | 0,13 s | DGIAM30 giảm nhiều nhất (420,2 triệu) |
| Q24 Sản phẩm nhiều biến thể, tồn kho thấp | 0 | 0,02 s | |
| Q25 Phát hiện vi phạm bất biến | **0** | 1,63 s | **Không có vi phạm** |

Truy vấn đệ quy (`07_recursive_100k.txt`): cây danh mục 22 dòng với độ sâu và đường dẫn đầy đủ; doanh thu theo nhánh
22 dòng (Điện tử 985,2 tỷ, trong đó iPhone 661,7 tỷ); **2 truy vấn cuối trả rỗng — xem bên dưới**.

## Vấn đề phát hiện (gửi Tuấn — owner `sql/06_queries.sql`, `sql/07_recursive.sql`)

1. **Q11 trả về toàn bộ 10.000 khách.** `@brand_name := 'Demo'` chỉ có trong seed nhỏ. Trên dữ liệu lớn không có SKU nào
   của thương hiệu này nên `NOT EXISTS` bên trong luôn đúng ("chia cho tập rỗng") → mọi khách đều "đã mua hết".
   Đề xuất: chọn thương hiệu có trên dữ liệu lớn (vd. thương hiệu có ít SKU nhất) và chặn trường hợp tập SKU rỗng.
2. **Hai truy vấn cuối của `07_recursive.sql` trả rỗng.** `@leaf_category_id` lấy theo `slug='dien-tu'`, chỉ có trong
   seed nhỏ; generator đặt slug dạng `dcat-xxx`. Đề xuất: chọn danh mục theo điều kiện có trên cả hai bộ dữ liệu
   (vd. một danh mục lá bất kỳ có sản phẩm).

## Lưu ý khi chạy lại

- **Phải mở MySQL client với `--default-character-set=utf8mb4`.** Trên Windows, client mặc định theo bảng mã của console:
  lần chạy đầu không có tùy chọn này làm tên tiếng Việt thành `?` và truy vấn cây danh mục lỗi
  `ERROR 1366 Incorrect string value ... for column 'display_path'`.
- `TEE` **ghi nối thêm** vào file; xóa file cũ trước khi chạy lại.
- Chạy Q01–Q25 **trước** các demo: demo SQL nhúng tạo thêm đơn, làm số liệu không còn đúng 100.000 đơn.
