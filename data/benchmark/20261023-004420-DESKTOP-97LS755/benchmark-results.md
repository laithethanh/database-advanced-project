# Benchmark trước/sau khi thêm index

Chạy lúc 23/10/2026 00:44, tổng thời gian 95 giây. Mỗi truy vấn làm nóng 3 lần, đo 7 lần, lấy **trung vị** (thời gian tính cả gửi truy vấn và nhận kết quả về Python).

## Môi trường

| Thuộc tính | Giá trị |
|---|---|
| MySQL | 8.4.11 |
| Muc co lap | REPEATABLE-READ |
| innodb_buffer_pool_size | 134,217,728 byte |
| He dieu hanh | Windows-11-10.0.26200-SP0 |
| Python | 3.13.2 |
| Faker | 39.1.0 |
| PyMySQL | 2.2.8 |
| So don (orders) | 100000 |
| So dong hang (order_item) | 200329 |
| So thanh toan (payment) | 89908 |

## Kết quả thời gian

| Mã | Truy vấn | Index thử nghiệm | Trước (ms) | Sau (ms) | Nhanh hơn | Plan sau có dùng index mới? | Số dòng |
|---|---|---|---|---|---|---|---|
| B1 | Top 10 san pham theo doanh thu (quet toan bo don) | idx_bench_oi_variant_order_total | 3.297,26 | 2.074,29 | 1.6x | Có | 10 |
| B2 | Doanh thu theo ngay trong thang 03/2026 (bang payment) | idx_bench_payment_status_paid | 97,69 | 14,69 | 6.7x | Có | 31 |
| B3 | Tra cuu don theo so dien thoai nguoi nhan (cham soc khach hang) | idx_bench_orders_recipient_phone | 88,69 | 0,82 | 108.5x | Có | 1 |
| B4 | 10 don gan nhat cua 1 khach (doi chung: da co index san) | (không thêm — đối chứng) | 1,27 | 1,22 | 1.0x | — | 9 |

Chi tiết từng lần đo (ms):

- B1 trước: 3.412,79, 3.175,87, 3.350,32, 3.697,03, 3.297,26, 3.119,05, 3.145,92
- B1 sau: 2.073,29, 2.088,73, 2.043,69, 2.095,06, 1.997,62, 2.074,29, 2.103,65
- B2 trước: 91,61, 92,52, 98,21, 97,69, 99,99, 141,96, 68,66
- B2 sau: 14,69, 18,13, 15,27, 16,99, 11,58, 12,13, 14,38
- B3 trước: 88,69, 96,46, 91,77, 88,48, 92,07, 87,16, 86,64
- B3 sau: 1,44, 1,41, 0,75, 0,82, 0,62, 0,60, 0,97
- B4 trước: 1,52, 1,31, 1,25, 1,27, 1,66, 1,27, 1,22
- B4 sau: 1,50, 1,09, 0,80, 1,05, 1,22, 1,81, 1,46

## Cái giá của index

| Bảng | Dung lượng index trước | Sau khi thêm | Tăng thêm |
|---|---|---|---|
| order_item | 39.072 KB | 47.824 KB | +8.752 KB |
| payment | 6.176 KB | 9.776 KB | +3.600 KB |
| orders | 13.440 KB | 17.040 KB | +3.600 KB |

Thời gian tạo index: B1 1.706,52 ms, B2 581,38 ms, B3 898,10 ms.

Chi phí ghi: chép 89,908 dòng `payment` sang bảng tạm (trung vị 3 lần) — không có index thử nghiệm **4.449,21 ms**, có index **5.251,58 ms** (**+18%**).

Index thử nghiệm đã được xóa sau khi đo.
Kế hoạch thực thi nguyên văn: `explain-baseline.txt`, `explain-optimized.txt`.
