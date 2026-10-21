# 03 — Chi phí ghi (INSERT) khi thêm chỉ mục thử nghiệm

Phép đo dùng bảng sao `order_item_bench` (tạo bằng `CREATE TABLE ... LIKE order_item`, không mang theo trigger),
chèn 10.000 dòng cho 5 đơn `PENDING_PAYMENT`, lặp lại với bảng sao đã có 2 chỉ mục thử nghiệm.

| Kịch bản | Số dòng chèn | Thời gian | INDEX_LENGTH của bảng sao |
|---|---|---|---|
| Không có chỉ mục thử nghiệm | 10.000 | 799,53 ms | 65.536 byte |
| Có 2 chỉ mục thử nghiệm | 10.000 | 1.048,40 ms | 98.304 byte |

## Kết luận

- Chi phí ghi tăng **+31%** (799,53 ms → 1.048,40 ms) khi thêm chỉ mục.
- Dung lượng chỉ mục của bảng sao tăng **+32.768 byte** cho 10.000 dòng.
- Kết hợp với kết quả ở `02-optimized.txt` (trình tối ưu **không** chọn các chỉ mục thử nghiệm cho ba
  truy vấn đo), phép thí nghiệm cho thấy: lược đồ chỉ mục hiện có của `sql/01_schema.sql` đã đủ cho các
  truy vấn phân tích chính, và thêm chỉ mục chỉ làm tăng chi phí ghi mà không mang lại lợi ích đọc.
- Vì vậy các chỉ mục thử nghiệm **không được đưa vào schema chính**; lược đồ giữ nguyên
  (việc sửa `sql/01_schema.sql` nằm ngoài phạm vi dự án).

> Số liệu trên đo trên máy đơn, cùng cấu hình cho toàn bộ hai kịch bản; khi trích dẫn trong báo cáo phải
> ghi kèm điều kiện môi trường ở `00-environment.md`.
