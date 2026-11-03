# Kế hoạch và quy trình đo hiệu năng

## Bộ dữ liệu

- Tối thiểu 100.000 đơn hàng. Generator có tham số mặc định nhỏ, nên phải truyền đủ quy mô chuẩn.
- Hàng trăm hoặc hàng nghìn sản phẩm, biến thể, khách hàng và nhiều cấp danh mục.
- Dữ liệu do trình sinh tạo ra phải dùng seed cố định để mọi nhóm chạy lại được cùng dữ liệu.

```bash
mysql --default-character-set=utf8mb4 -u root -p -e "source data/generator/reset_bench_db.sql"
python data/generator/generate_data.py --customers 10000 --sellers 100 --products 1000 --orders 100000 --seed 20261003
```

`data/generator/reset_bench_db.sql` xóa và dựng lại database sạch (01 → 02 → 04 → 05, không nạp seed nhỏ); chạy từ thư mục gốc repo.

## Quy trình đo

1. Ghi nhận môi trường: `VERSION()`, mức cô lập, số đơn/số dòng hàng, dung lượng bảng và chỉ mục.
2. Làm nóng cache: chạy trước các truy vấn đo.
3. Baseline: `EXPLAIN ANALYZE` cho các truy vấn đại diện (doanh thu theo sản phẩm, doanh thu theo ngày, tra cứu đơn theo số điện thoại, và một truy vấn đối chứng đã có chỉ mục sẵn).
4. Thí nghiệm chỉ mục trên **bản sao** cơ sở dữ liệu: tạo chỉ mục thử nghiệm, kiểm tra `SHOW INDEX` trước khi tạo.
5. Optimized: chạy lại đúng các câu `EXPLAIN ANALYZE` ở bước 3.
6. Đo chi phí ghi và dung lượng: so sánh `data_length`/`index_length` trước và sau, đo chi phí INSERT/UPDATE và lấy trung vị qua nhiều lần lặp.
7. Dọn chỉ mục thử nghiệm sau khi đã lưu output.

Script đo hiện hành là `data/benchmark/run_benchmark.py`:

```bash
python data/benchmark/run_benchmark.py --warmup 3 --runs 7
```

`sql/08_benchmark.sql` chỉ là bản SQL tham chiếu, không dùng để tạo bằng chứng mới.

## Nguyên tắc

- Chạy mỗi truy vấn nhiều lần, ghi **trung vị** và điều kiện môi trường.
- Không kết luận hiệu năng chỉ từ một lần chạy.
- Không tự tạo số liệu; mọi ô `[CẦN ĐIỀN]` trong báo cáo phải thay bằng output thật.
- Lưu nguyên văn output của `EXPLAIN ANALYZE` vào `data/benchmark/<YYYYMMDD-HHMMSS>-<machine>/`.
- Mỗi lần chạy tạo một thư mục riêng theo ngày và giờ (hoặc `--label`); không ghi đè hay sửa tay kết quả của lần chạy cũ.

## Nội dung cần lưu

| Nội dung | Nơi lưu |
|---|---|
| Metadata môi trường, quy mô dữ liệu | `data/benchmark/<YYYYMMDD-HHMMSS>-<machine>/metadata.md` |
| Kế hoạch thực thi baseline | `data/benchmark/<YYYYMMDD-HHMMSS>-<machine>/explain-baseline.txt` |
| Kế hoạch thực thi sau tối ưu | `data/benchmark/<YYYYMMDD-HHMMSS>-<machine>/explain-optimized.txt` |
| Số liệu đo và nhận xét | `data/benchmark/<YYYYMMDD-HHMMSS>-<machine>/benchmark-results.md`, `benchmark-analysis.md` |
| Các lần đo đã lưu | `data/benchmark/20261022-danh-win/`, `data/benchmark/20261023-004420-DESKTOP-97LS755/`, `data/benchmark/20261103-danh-win/` (xem `data/benchmark/README.md`) |

## Kết quả đo thật (lần chạy chính 2026-11-03)

Lần đo chính chạy trên **đúng bộ dữ liệu của Q01–Q25** (`report/appendix/queries/20261025/`): database sạch không seed nhỏ,
generator `--seed 20261003`, Faker 40.43.0; dấu vân tay dữ liệu trùng khớp với bộ 25/10.
Môi trường: Windows 11, MySQL 8.4.11, REPEATABLE-READ, `innodb_buffer_pool_size` = 128 MB, Python 3.15.0.
Bộ dữ liệu: 100.000 đơn / 200.294 dòng hàng / 89.861 thanh toán.
Nguồn: `data/benchmark/20261103-danh-win/benchmark-results.md`, `README.md`, `00_tong_quan_du_lieu.txt`.

| Mã | Truy vấn đo | Trước | Sau khi thêm chỉ mục thử nghiệm | Nhanh hơn |
|---|---|---|---|---|
| B1 | Top 10 sản phẩm theo doanh thu | 1.575,52 ms | 929,90 ms | 1,7× |
| B2 | Doanh thu theo ngày trong tháng 03/2026 | 38,97 ms | 4,38 ms | 8,9× |
| B3 | Tra cứu đơn theo số điện thoại người nhận | 32,83 ms | 0,14 ms | 237,7× |
| B4 | 10 đơn gần nhất của một khách (đối chứng) | 0,29 ms | 0,20 ms | ~không đổi (dưới 0,1 ms, dao động đo) |

Chi phí ghi: chép 89.861 dòng `payment` vào bảng tạm tăng từ 1.930,82 ms lên 2.180,97 ms (**+13%**) khi có thêm chỉ mục.
Dung lượng chỉ mục tăng +8.752 KB (`order_item`), +3.600 KB (`payment`), +3.600 KB (`orders`).
Biểu đồ: `data/benchmark/20261103-danh-win/benchmark-chart.png`.

**Kết luận thí nghiệm:** chỉ mục mới cải thiện rõ các truy vấn có điều kiện lọc chọn lọc cao (B2, B3), nhưng
chỉ cải thiện hạn chế với truy vấn tổng hợp toàn bộ dữ liệu (B1). B4 là đối chứng và gần như không đổi. Các
chỉ mục thử nghiệm đã được xóa sau khi đo và **không đưa vào schema chính**; nếu triển khai thật, ưu tiên
cân nhắc chỉ mục cho B3/B2 thay vì thêm chỉ mục tràn lan.

## So sánh các lần đo

| Lần đo | Dữ liệu | B1 | B2 | B3 | Chi phí ghi |
|---|---|---|---|---|---|
| 22/10, máy Danh | generator bản đầu, có lẫn seed nhỏ và đơn demo (100.003 đơn) | 1,6× | 5,5× | ~305× | +8% |
| 23/10, máy Thành | generator có địa chỉ/khuyến mãi, Faker 39.1.0 | 1,6× | 6,7× | 108,5× | +18% |
| **03/11, máy Danh (chính)** | **bộ dữ liệu của Q01–Q25**, Faker 40.43.0 | **1,7×** | **8,9×** | **237,7×** | **+13%** |

Số tuyệt đối khác nhau theo máy và bộ dữ liệu, nhưng xu hướng giữ nguyên qua cả ba lần đo.

Hạn chế: mỗi lần đo chạy trên một máy, một cấu hình buffer pool; chưa đo trên phần cứng khác hoặc dữ liệu lớn hơn 100.000 đơn.
