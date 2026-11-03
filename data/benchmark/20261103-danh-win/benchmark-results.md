# Benchmark trước/sau khi thêm index

Chạy lúc 03/11/2026 18:40, tổng thời gian 44 giây. Mỗi truy vấn làm nóng 3 lần, đo 7 lần, lấy **trung vị** (thời gian tính cả gửi truy vấn và nhận kết quả về Python).

## Môi trường

| Thuộc tính | Giá trị |
|---|---|
| MySQL | 8.4.11 |
| Muc co lap | REPEATABLE-READ |
| innodb_buffer_pool_size | 134,217,728 byte |
| He dieu hanh | Windows-11-10.0.26300-SP0 |
| Python | 3.15.0 |
| Faker | 40.43.0 |
| PyMySQL | 2.2.8 |
| So don (orders) | 100000 |
| So dong hang (order_item) | 200294 |
| So thanh toan (payment) | 89861 |

## Kết quả thời gian

| Mã | Truy vấn | Index thử nghiệm | Trước (ms) | Sau (ms) | Nhanh hơn | Plan sau có dùng index mới? | Số dòng |
|---|---|---|---|---|---|---|---|
| B1 | Top 10 san pham theo doanh thu (quet toan bo don) | idx_bench_oi_variant_order_total | 1.575,52 | 929,90 | 1.7x | Có | 10 |
| B2 | Doanh thu theo ngay trong thang 03/2026 (bang payment) | idx_bench_payment_status_paid | 38,97 | 4,38 | 8.9x | Có | 31 |
| B3 | Tra cuu don theo so dien thoai nguoi nhan (cham soc khach hang) | idx_bench_orders_recipient_phone | 32,83 | 0,14 | 237.7x | Có | 1 |
| B4 | 10 don gan nhat cua 1 khach (doi chung: da co index san) | (không thêm — đối chứng) | 0,29 | 0,20 | 1.4x | — | 9 |

Chi tiết từng lần đo (ms):

- B1 trước: 1.644,68, 1.570,90, 1.575,52, 1.606,70, 1.551,69, 1.573,78, 1.584,27
- B1 sau: 944,68, 929,90, 890,97, 923,75, 942,26, 896,66, 936,57
- B2 trước: 39,03, 38,13, 38,97, 38,96, 47,38, 28,23, 41,24
- B2 sau: 4,38, 4,09, 3,90, 6,25, 4,82, 3,95, 4,49
- B3 trước: 36,09, 28,46, 30,70, 32,83, 41,11, 40,14, 27,29
- B3 sau: 0,19, 0,15, 0,14, 0,14, 0,13, 0,14, 0,13
- B4 trước: 0,28, 0,25, 0,25, 0,70, 0,36, 0,29, 0,30
- B4 sau: 0,20, 0,20, 0,19, 0,19, 0,81, 0,48, 0,27

## Cái giá của index

| Bảng | Dung lượng index trước | Sau khi thêm | Tăng thêm |
|---|---|---|---|
| order_item | 39.072 KB | 47.824 KB | +8.752 KB |
| payment | 6.176 KB | 9.776 KB | +3.600 KB |
| orders | 13.408 KB | 17.008 KB | +3.600 KB |

Thời gian tạo index: B1 829,41 ms, B2 290,95 ms, B3 456,69 ms.

Chi phí ghi: chép 89,861 dòng `payment` sang bảng tạm (trung vị 3 lần) — không có index thử nghiệm **1.930,82 ms**, có index **2.180,97 ms** (**+13%**).

Index thử nghiệm đã được xóa sau khi đo.
Kế hoạch thực thi nguyên văn: `explain-baseline.txt`, `explain-optimized.txt`.
