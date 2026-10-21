# Ghi chú thực thi truy vấn và mẫu lưu bằng chứng

`sql/06_queries.sql` là nguồn SQL chuẩn. Bảng dưới đây nêu yêu cầu nghiệp vụ và kết quả kỳ vọng; sau khi chạy bộ dữ liệu, hãy lưu ảnh chụp/CSV kết quả thực tế và kế hoạch thực thi vào `report/appendix/`.

| Truy vấn | Câu hỏi nghiệp vụ | Kết quả kỳ vọng / cách kiểm tra |
|---|---|---|
| Q01 | Sản phẩm nào tạo ra doanh thu được ghi nhận cao nhất? | Sắp xếp doanh thu giảm dần; các hạng bằng nhau dùng chung thứ hạng. |
| Q02 | Mỗi người bán có doanh thu và số đơn hàng bao nhiêu? | Vẫn bao gồm người bán không có doanh thu. |
| Q03–Q05 | Người bán/khách hàng/SKU nào chưa từng phát sinh bán hàng? | Tìm phần chênh lệch tập hợp; có thể không có kết quả với bộ dữ liệu lớn. |
| Q06 | SKU nào của người bán cần bổ sung hàng? | Lượng hàng khả dụng nhỏ hơn hoặc bằng ngưỡng đặt lại. |
| Q07 | Khách hàng nào đạt ngưỡng độ đa dạng sản phẩm đã mua? | Mỗi dòng có ít nhất `@min_skus` biến thể khác nhau. |
| Q08 | SKU nào có giá cao trong danh mục của nó? | Giá cao hơn giá trung bình của các biến thể đang hoạt động trong danh mục đó. |
| Q09 | Người mua sản phẩm đã giao nào đã để lại đánh giá? | Mỗi dòng phải khớp với chi tiết đơn đã giao và đánh giá tương ứng. |
| Q10 | Người bán nào không có mặt hàng thuộc một nhánh danh mục? | Phải xét cả phạm vi danh mục đệ quy. |
| Q11 | Ai đã mua mọi SKU đang hoạt động của một thương hiệu? | Kết quả phép chia quan hệ; nếu tập thương hiệu rỗng thì mọi khách hàng đều đạt, nên hãy chọn thương hiệu có thật. |
| Q12–Q13 | Ai đạt ngưỡng doanh thu / danh mục nào đang trống? | Kiểm tra ngưỡng tổng hợp và kết quả không khớp từ phép nối ngoài. |
| Q14–Q15 | Xếp hạng danh mục/người bán như thế nào? | Tối đa 3 SKU mỗi danh mục; người bán đồng hạng dùng dense rank. |
| Q16–Q17 | Doanh thu thay đổi theo thời gian ra sao? | Biến động theo tháng và tổng lũy động trong 30 ngày. |
| Q18–Q20 | Cây danh mục, doanh thu nhánh và đường dẫn điều hướng là gì? | Độ sâu/đường dẫn không có chu trình; doanh thu nút gốc gồm mọi nút con. |
| Q21 | Cách viết tương đương nào để tìm người bán hàng đầu hiệu quả hơn? | Q21A/Q21B phải trả cùng các dòng; so sánh kế hoạch thực thi thực tế, không đoán trước. |
| Q22–Q24 | Ai hoàn trả quá thường xuyên / khuyến mãi nào hiệu quả / sản phẩm nào sắp hết hàng? | Đối chiếu từng số liệu tổng hợp với các dòng dữ liệu nguồn. |
| Q25 | Có vi phạm bất biến dữ liệu được bảo vệ không? | Bắt buộc trả về **0 dòng**. |

## Quy trình lưu bằng chứng

1. Chạy từng truy vấn trên dữ liệu mẫu nhỏ; lưu kết quả kèm ngày, mã phiên bản Git và số dòng.
2. Với Q01, Q06, Q14, Q15, Q17, Q19 và Q21, chạy `EXPLAIN ANALYZE <query>` trên bộ dữ liệu đo hiệu năng. Lưu nguyên văn kế hoạch thực thi.
3. Với Q21, xác nhận Q21A và Q21B trả về cùng dữ liệu trước khi so sánh thời gian.
4. Không tự tạo kết quả hoặc thời gian chạy. Các tệp hiện chỉ nêu kết quả kỳ vọng cho đến khi nhóm thực sự chạy MySQL.

## Trạng thái chạy thật (2026-10-21)

- Toàn bộ Q01–Q25 và Q18–Q20 (recursive) đã chạy **không lỗi** trên MySQL 8.4.11 với dữ liệu mẫu nhỏ
  (`report/appendix/tests/06-queries-sample.txt`, `07-recursive-sample.txt`).
- Trên dữ liệu 100.000 đơn, Q25 trả về **0 dòng vi phạm** (`report/appendix/benchmark/q25-invariant-check.sql`).
- Kế hoạch thực thi của ba truy vấn đo hiệu năng nằm trong `report/appendix/benchmark/`.
- Cần chạy lại Q01–Q25 trên bộ dữ liệu 100.000 đơn và lưu đầy đủ kết quả từng truy vấn trước khi nộp báo cáo.
