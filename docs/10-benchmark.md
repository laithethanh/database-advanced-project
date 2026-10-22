# Kế hoạch và quy trình đo hiệu năng

## Bộ dữ liệu

- Tối thiểu 100.000 đơn hàng (generator mặc định `--orders 100000`).
- Hàng trăm hoặc hàng nghìn sản phẩm, biến thể, khách hàng và nhiều cấp danh mục.
- Dữ liệu do trình sinh tạo ra phải dùng seed cố định để mọi nhóm chạy lại được cùng dữ liệu.

```bash
python data/generator/generate_data.py --orders 100000 --seed 20261003
```

## Quy trình đo

1. Ghi nhận môi trường: `VERSION()`, mức cô lập, số đơn/số dòng hàng, dung lượng bảng và chỉ mục.
2. Làm nóng cache: chạy trước các truy vấn đo.
3. Baseline: `EXPLAIN ANALYZE` cho các truy vấn đại diện (doanh thu theo sản phẩm, doanh thu theo ngày, tra cứu đơn theo số điện thoại, và một truy vấn đối chứng đã có chỉ mục sẵn).
4. Thí nghiệm chỉ mục trên **bản sao** cơ sở dữ liệu: tạo chỉ mục thử nghiệm, kiểm tra `SHOW INDEX` trước khi tạo.
5. Optimized: chạy lại đúng các câu `EXPLAIN ANALYZE` ở bước 3.
6. Đo chi phí ghi và dung lượng: so sánh `data_length`/`index_length` trước và sau, đo chi phí INSERT/UPDATE và lấy trung vị qua nhiều lần lặp.
7. Dọn chỉ mục thử nghiệm sau khi đã lưu output.

Script đo hiện hành là `data/benchmark/run_benchmark.py`; `sql/08_benchmark.sql` là bản SQL tham chiếu.

## Nguyên tắc

- Chạy mỗi truy vấn nhiều lần, ghi **trung vị** và điều kiện môi trường.
- Không kết luận hiệu năng chỉ từ một lần chạy.
- Không tự tạo số liệu; mọi ô `[CẦN ĐIỀN]` trong báo cáo phải thay bằng output thật.
- Lưu nguyên văn output của `EXPLAIN ANALYZE` vào `data/benchmark/<YYYYMMDD>-<machine>/`.
- Không giữ kết quả của các lần chạy cũ trong repo; mỗi lần chạy tạo một thư mục riêng theo ngày.

## Nội dung cần lưu

| Nội dung | Nơi lưu |
|---|---|
| Metadata môi trường, quy mô dữ liệu | `data/benchmark/<YYYYMMDD>-<machine>/metadata.md` |
| Kế hoạch thực thi baseline | `data/benchmark/<YYYYMMDD>-<machine>/explain-baseline.txt` |
| Kế hoạch thực thi sau tối ưu | `data/benchmark/<YYYYMMDD>-<machine>/explain-optimized.txt` |
| Số liệu đo và nhận xét | `data/benchmark/<YYYYMMDD>-<machine>/benchmark-results.md`, `benchmark-analysis.md` |
| Bản sao artifact hiện có | `data/benchmark/20261022-danh-win/` |

## Kết quả đo thật (lần chạy 2026-10-22)

Môi trường: MySQL Community Server 8.4.11, REPEATABLE-READ, `innodb_buffer_pool_size` = 128 MB,
bộ dữ liệu 100.003 đơn / 200.182 dòng hàng / 89.923 thanh toán (gồm dữ liệu generator và các đơn demo).
Nguồn: `data/benchmark/20261022-danh-win/benchmark-results.md`.

| Mã | Truy vấn đo | Trước | Sau khi thêm chỉ mục thử nghiệm | Nhanh hơn |
|---|---|---|---|---|
| B1 | Top 10 sản phẩm theo doanh thu | 1.494,68 ms | 937,74 ms | 1,6× |
| B2 | Doanh thu theo ngày trong tháng 03/2026 | 39,41 ms | 7,12 ms | 5,5× |
| B3 | Tra cứu đơn theo số điện thoại người nhận | 38,11 ms | 0,12 ms | ~305× |
| B4 | 10 đơn gần nhất của một khách (đối chứng) | 0,39 ms | 0,55 ms | ~không đổi |

Chi phí ghi: chép 89.923 dòng `payment` vào bảng tạm tăng từ 1.975,19 ms lên 2.136,96 ms (**+8%**) khi có thêm chỉ mục.

**Kết luận thí nghiệm:** chỉ mục mới cải thiện rõ các truy vấn có điều kiện lọc chọn lọc cao (B2, B3), nhưng
chỉ cải thiện hạn chế với truy vấn tổng hợp toàn bộ dữ liệu (B1). B4 là đối chứng và gần như không đổi. Các
chỉ mục thử nghiệm đã được xóa sau khi đo và **không đưa vào schema chính**; nếu triển khai thật, ưu tiên
cân nhắc chỉ mục cho B3/B2 thay vì thêm chỉ mục tràn lan.

Hạn chế: một máy, một bộ dữ liệu; cần chạy lại ≥ 5 lần và lấy trung vị trước khi chốt quyết định thiết kế.
