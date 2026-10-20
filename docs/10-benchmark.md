# Kế hoạch đo hiệu năng

## Bộ dữ liệu

- Tối thiểu 100.000 đơn hàng.
- Hàng trăm hoặc hàng nghìn sản phẩm, biến thể, khách hàng và nhiều cấp danh mục.
- Dữ liệu do trình sinh tạo ra phải dùng seed cố định.

## Quy trình

1. Chạy làm nóng trước nếu phù hợp.
2. Chạy mỗi truy vấn nhiều lần.
3. Ghi trung vị và các chỉ số phân tán cần thiết.
4. Chạy `EXPLAIN ANALYZE` cho phiên bản cơ sở và phiên bản đã tối ưu.
5. Ghi lại các thay đổi về chỉ mục/lược đồ giữa hai phiên bản.

Không kết luận hiệu năng chỉ từ một lần chạy. Báo cáo phải ghi rõ môi trường, kích thước dữ liệu và điều kiện thực nghiệm.
