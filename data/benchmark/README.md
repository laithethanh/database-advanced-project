# Dữ liệu đo hiệu năng

Mỗi lần chạy `python data/benchmark/run_benchmark.py` lưu một thư mục riêng ở đây, gồm `metadata.md`,
`benchmark-results.md`, `explain-baseline.txt`, `explain-optimized.txt`. Không commit các bộ dữ liệu sinh ra
(database), chỉ commit metadata và kết quả đo.

| Thư mục | Ngày | Máy | Bộ dữ liệu | Ghi chú |
|---|---|---|---|---|
| `20261103-danh-win/` | 03/11/2026 | Danh | Đúng bộ dữ liệu của Q01–Q25 (dấu vân tay trùng bộ 25/10) | **Lần đo chính**, dùng cho chương 10 |
| `20261023-004420-DESKTOP-97LS755/` | 23/10/2026 | Thành | Generator có địa chỉ/khuyến mãi, Faker 39.1.0 | Lần đo đối chiếu trên máy khác |
| `20261022-danh-win/` | 22/10/2026 | Danh | Generator bản đầu, lẫn seed nhỏ và đơn demo | Lần đo đầu tiên; kèm phân tích và kiểm chứng tái lập của bản generator đầu |

Ba lần đo cho cùng xu hướng: index giúp nhiều cho truy vấn lọc chọn lọc cao (B2, B3), giúp ít cho truy vấn tổng hợp
toàn bộ (B1), không cần cho truy vấn đã có index phù hợp (B4), và luôn làm tăng chi phí ghi. Xem `docs/10-benchmark.md`.
