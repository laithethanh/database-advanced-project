# Phân tích benchmark — Phạm Thành Danh

Nguồn số liệu: `benchmark-results.md`, `explain-baseline.txt`, `explain-optimized.txt` (cùng thư mục),
chạy ngày 22/10/2026 bằng `python data\benchmark\run_benchmark.py` trên bộ 100.003 đơn / 200.182 dòng hàng /
89.923 thanh toán. Mỗi truy vấn làm nóng 3 lần, đo 7 lần, lấy trung vị.

## 1. Tổng hợp

| Mã | Truy vấn | Trước | Sau | Nhanh hơn | Kế hoạch thực thi thay đổi thế nào |
|---|---|---|---|---|---|
| B1 | Top 10 sản phẩm theo doanh thu | 1.494,68 ms | 937,74 ms | 1,6 lần | `order_item`: Index lookup (phải đọc thêm dòng gốc) → **Covering index lookup** |
| B2 | Doanh thu theo ngày, tháng 03/2026 | 39,41 ms | 7,12 ms | 5,5 lần | **Table scan 89.923 dòng → Covering index range scan 7.589 dòng** |
| B3 | Tra đơn theo số điện thoại người nhận | 38,11 ms | 0,12 ms | ~305 lần | **Table scan 100.003 dòng → Index lookup 1 dòng** |
| B4 | 10 đơn gần nhất của 1 khách (đối chứng) | 0,39 ms | 0,55 ms | ~ không đổi | Không đổi — cả hai lần đều dùng `idx_order_customer_created` có sẵn |

## 2. Giải thích từng trường hợp

**B3 — cải thiện lớn nhất.** Không có index trên `recipient_phone`, MySQL phải đọc toàn bộ 100.003 đơn để tìm 1 đơn
(`Table scan on orders ... rows=100003`). Có index thì nhảy thẳng tới đúng dòng (`Index lookup ... rows=1`).
Điều kiện `=` trên cột có độ chọn lọc rất cao (gần như mỗi số điện thoại chỉ có 1 đơn) là trường hợp lý tưởng của B-tree index.

**B2 — cải thiện rõ.** Trước: quét cả bảng `payment` (89.923 dòng) rồi mới lọc ra 7.589 dòng của tháng 3.
Sau: index `(status, paid_at, amount)` cho phép đọc **đúng một khoảng liên tục** 7.589 dòng (`range scan`).
Index còn là **covering index**: chứa sẵn cả `amount` nên MySQL không cần quay lại bảng gốc. Thứ tự cột quan trọng:
`status` (so sánh bằng) đứng trước, `paid_at` (so sánh khoảng) đứng sau.

**B1 — cải thiện có giới hạn.** Index mới giúp bước đọc `order_item` từ ~645 ms xuống ~117 ms vì đã là covering index.
Nhưng truy vấn vẫn phải tra 200.182 lần vào bảng `orders` theo khóa chính để kiểm tra `status`
(`Single-row index lookup on o using PRIMARY ... loops=200182`), và bước này chiếm phần lớn thời gian còn lại.
Đây là truy vấn **tổng hợp trên toàn bộ dữ liệu**: index không giúp đọc ít dòng hơn, chỉ giúp đọc mỗi dòng rẻ hơn,
nên chỉ nhanh 1,6 lần. Muốn nhanh hơn nhiều phải đổi cách tiếp cận (bảng tổng hợp doanh thu theo ngày/sản phẩm
được cập nhật định kỳ), không phải thêm index.

**B4 — đối chứng.** Không thêm index, kế hoạch thực thi trước và sau giống hệt nhau. Thời gian dưới 1 ms và chênh lệch
0,39 → 0,55 ms nằm trong mức dao động của phép đo (EXPLAIN ANALYZE cho thấy phần MySQL thực thi chỉ ~0,02–0,03 ms,
phần còn lại là thời gian gửi/nhận giữa Python và MySQL). Điều này xác nhận cải thiện ở B1–B3 là nhờ index chứ không phải do nhiễu.

## 3. Cái giá phải trả

| Index thử nghiệm | Dung lượng tăng thêm | So với index sẵn có của bảng |
|---|---|---|
| `order_item (variant_id, order_id, line_total)` | +8.752 KB | +22% |
| `payment (status, paid_at, amount)` | +3.600 KB | +58% |
| `orders (recipient_phone)` | +3.600 KB | +27% |

- Thời gian tạo index: 0,3–1,2 giây trên dữ liệu hiện tại.
- Chi phí ghi: chép 89.923 dòng `payment` chậm thêm **8%** khi có thêm 1 index (1.975 → 2.137 ms).
  Mỗi index thêm vào là thêm một cấu trúc phải cập nhật mỗi khi INSERT/UPDATE.

## 4. Kết luận và đề xuất

| Index | Đề xuất | Lý do |
|---|---|---|
| `orders (recipient_phone)` | **Nên thêm** | Tra cứu theo SĐT là thao tác thường xuyên của chăm sóc khách hàng; nhanh ~305 lần, chỉ tốn 3,6 MB |
| `payment (status, paid_at, amount)` | Nên thêm nếu báo cáo doanh thu theo ngày chạy thường xuyên | Nhanh 5,5 lần, chi phí ghi +8% chấp nhận được với bảng thanh toán |
| `order_item (variant_id, order_id, line_total)` | **Không nên** | Tốn 8,7 MB trên bảng ghi nhiều nhất mà chỉ nhanh 1,6 lần cho một truy vấn báo cáo; nên dùng bảng tổng hợp |

**Bài học chính:** index hiệu quả nhất khi giúp MySQL **đọc ít dòng hơn** (điều kiện lọc có độ chọn lọc cao trên cột
chưa có index — B2, B3). Với truy vấn phải tổng hợp toàn bộ dữ liệu (B1), index chỉ giảm chi phí mỗi dòng nên hiệu quả hạn chế.

## 5. Liên hệ với kết quả benchmark của nhóm

Bản benchmark trên nhánh `main` (`report/appendix/benchmark/`) thử 3 index cho các truy vấn tổng hợp và kết luận
index **không được trình tối ưu chọn** hoặc không cải thiện, trong khi làm ghi chậm thêm 31%. Kết quả ở đây **bổ sung**
cho kết luận đó: với truy vấn tổng hợp toàn bộ (B1) index chỉ giúp ít, nhưng với truy vấn có điều kiện lọc chọn lọc
(B2, B3) index cải thiện từ 5 đến hàng trăm lần. Hai kết quả cùng chỉ ra rằng việc thêm index phải dựa trên
**loại truy vấn** chứ không nên thêm tràn lan.

> Lưu ý khi so số tuyệt đối: hai lần đo chạy trên hai máy khác nhau với hai generator khác nhau,
> nên chỉ so sánh xu hướng, không so trực tiếp số mili-giây.
