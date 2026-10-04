# Benchmark plan

## Dataset

- Tối thiểu 100.000 orders.
- Hàng trăm/nghìn products, variants, customers và nhiều category levels.
- Dữ liệu generator có seed cố định.

## Protocol

1. Chạy warm-up nếu phù hợp.
2. Chạy mỗi query nhiều lần.
3. Ghi median và phân tán cần thiết.
4. Chạy `EXPLAIN ANALYZE` cho baseline và optimized.
5. Ghi index/schema thay đổi giữa hai phiên.

Không suy luận hiệu năng từ thời gian của một lần chạy. Kết quả báo cáo phải ghi môi trường, kích thước dữ liệu và điều kiện chạy.
