# Benchmark trước/sau khi thêm index — máy của Danh

Chạy lúc 22/10/2026 02:55, tổng thời gian 44 giây. Mỗi truy vấn làm nóng 3 lần, đo 7 lần, lấy **trung vị** (thời gian tính cả gửi truy vấn và nhận kết quả về Python).

## Môi trường

| Thuộc tính | Giá trị |
|---|---|
| MySQL | 8.4.11 |
| Muc co lap | REPEATABLE-READ |
| innodb_buffer_pool_size | 134,217,728 byte |
| So don (orders) | 100003 |
| So dong hang (order_item) | 200182 |
| So thanh toan (payment) | 89923 |

## Kết quả thời gian

| Mã | Truy vấn | Index thử nghiệm | Trước (ms) | Sau (ms) | Nhanh hơn | Plan sau có dùng index mới? | Số dòng |
|---|---|---|---|---|---|---|---|
| B1 | Top 10 san pham theo doanh thu (quet toan bo don) | idx_bench_oi_variant_order_total | 1.494,68 | 937,74 | 1.6x | Có | 10 |
| B2 | Doanh thu theo ngay trong thang 03/2026 (bang payment) | idx_bench_payment_status_paid | 39,41 | 7,12 | 5.5x | Có | 31 |
| B3 | Tra cuu don theo so dien thoai nguoi nhan (cham soc khach hang) | idx_bench_orders_recipient_phone | 38,11 | 0,12 | 305.1x | Có | 1 |
| B4 | 10 don gan nhat cua 1 khach (doi chung: da co index san) | (không thêm — đối chứng) | 0,39 | 0,55 | 0.7x | — | 10 |

Chi tiết từng lần đo (ms):

- B1 trước: 1.436,66, 1.422,34, 1.614,94, 1.562,00, 1.494,68, 1.408,70, 1.733,36
- B1 sau: 925,15, 1.105,83, 1.221,61, 1.116,13, 936,77, 937,74, 926,48
- B2 trước: 37,90, 38,51, 38,77, 39,41, 40,61, 39,66, 41,46
- B2 sau: 7,12, 5,58, 7,62, 8,84, 6,06, 9,42, 6,74
- B3 trước: 37,42, 36,57, 35,62, 38,35, 38,11, 42,06, 43,21
- B3 sau: 0,12, 0,12, 0,13, 0,13, 0,12, 0,13, 0,12
- B4 trước: 0,45, 0,40, 0,53, 0,39, 0,33, 0,32, 0,31
- B4 sau: 0,95, 0,58, 0,52, 0,55, 0,52, 0,55, 0,32

## Cái giá của index

| Bảng | Dung lượng index trước | Sau khi thêm | Tăng thêm |
|---|---|---|---|
| order_item | 39.072 KB | 47.824 KB | +8.752 KB |
| payment | 6.176 KB | 9.776 KB | +3.600 KB |
| orders | 13.376 KB | 16.976 KB | +3.600 KB |

Thời gian tạo index: B1 1.196,89 ms, B2 316,03 ms, B3 463,64 ms.

Chi phí ghi: chép 89,923 dòng `payment` sang bảng tạm (trung vị 3 lần) — không có index thử nghiệm **1.975,19 ms**, có index **2.136,96 ms** (**+8%**).

Index thử nghiệm đã được xóa sau khi đo.
Kế hoạch thực thi nguyên văn: `explain-baseline.txt`, `explain-optimized.txt`.
