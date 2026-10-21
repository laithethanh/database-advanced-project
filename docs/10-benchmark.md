# Kế hoạch và quy trình đo hiệu năng

## Bộ dữ liệu

- Tối thiểu 100.000 đơn hàng (generator mặc định `--orders 100000`).
- Hàng trăm hoặc hàng nghìn sản phẩm, biến thể, khách hàng và nhiều cấp danh mục.
- Dữ liệu do trình sinh tạo ra phải dùng seed cố định để mọi nhóm chạy lại được cùng dữ liệu.

```bash
python data/generator/generate_data.py --orders 100000 --seed 20261003
```

## Quy trình đo (đặc tả trong `sql/08_benchmark.sql`)

1. Ghi nhận môi trường: `VERSION()`, mức cô lập, số đơn/số dòng hàng, dung lượng bảng và chỉ mục.
2. Làm nóng cache: chạy 3 lần truy vấn tổng hợp trước khi đo.
3. Baseline: `EXPLAIN ANALYZE` cho ba truy vấn đại diện (tổng hợp doanh thu theo sản phẩm, tổng hợp doanh thu theo người bán theo khoảng thời gian, quét tồn kho dưới ngưỡng đặt lại).
4. Thí nghiệm chỉ mục trên **bản sao** cơ sở dữ liệu: tạo 3 chỉ mục thử nghiệm, kiểm tra `SHOW INDEX` trước khi tạo.
5. Optimized: chạy lại đúng ba câu `EXPLAIN ANALYZE` ở bước 3.
6. Đo chi phí ghi và dung lượng: so sánh `data_length`/`index_length` trước và sau, và đo 10.000 lệnh `INSERT` vào bảng sao `order_item_bench` (lặp ≥ 5 lần, lấy trung vị).
7. Dọn chỉ mục thử nghiệm sau khi đã lưu output.

## Nguyên tắc

- Chạy mỗi truy vấn nhiều lần, ghi **trung vị** và điều kiện môi trường.
- Không kết luận hiệu năng chỉ từ một lần chạy.
- Không tự tạo số liệu; mọi ô `[CẦN ĐIỀN]` trong báo cáo phải thay bằng output thật.
- Lưu nguyên văn output của `EXPLAIN ANALYZE` vào `report/appendix/benchmark/`.

## Nội dung cần lưu

| Nội dung | Nơi lưu |
|---|---|
| Metadata môi trường, quy mô dữ liệu | `report/appendix/benchmark/00-environment.md` |
| Kế hoạch thực thi baseline | `report/appendix/benchmark/01-baseline.txt` |
| Kế hoạch thực thi sau tối ưu | `report/appendix/benchmark/02-optimized.txt` |
| Số liệu ghi/dung lượng | `report/appendix/benchmark/03-write-cost.md` |
| Tóm tắt và kết luận | `report/appendix/benchmark/README.md` |
| Bản sao artifact gốc | `data/benchmark/20261021-win-local/` |

## Kết quả đo thật (lần chạy 2026-10-21)

Môi trường: MySQL Community Server 8.4.11, REPEATABLE-READ, `innodb_buffer_pool_size` = 128 MB,
bộ dữ liệu 100.000 đơn / 199.916 dòng hàng sinh bằng `--seed 20261003` (6,5 phút).

| Truy vấn đo | Baseline | Sau khi thêm 3 chỉ mục thử nghiệm | Kết luận |
|---|---|---|---|
| Doanh thu theo sản phẩm | 3.588 ms / 3.509 ms | 3.612 ms | Không cải thiện, trình tối ưu không dùng chỉ mục mới |
| Doanh thu theo người bán theo khoảng thời gian | 2.280 ms / 2.319 ms | 2.285 ms | Không cải thiện |
| Quét tồn kho dưới ngưỡng đặt lại | 0,18 ms (table scan 6.000 dòng) | 3,08 ms (covering index scan) | Chậm hơn |

Chi phí ghi (10.000 dòng INSERT vào bảng sao): 799,53 ms → 1.048,40 ms (**+31%**) khi có thêm chỉ mục.

**Kết luận thí nghiệm:** lược đồ chỉ mục sẵn có trong `sql/01_schema.sql` đã phục vụ tốt cho các truy vấn
phân tích chính; ba chỉ mục thử nghiệm không được trình tối ưu chọn và làm tăng chi phí ghi, nên **không
đưa vào schema chính**. Nếu cần tối ưu truy vấn quét tồn kho quy mô lớn thì dùng bảng tổng hợp theo ngày
thay vì thêm chỉ mục.

Hạn chế: một máy, một bộ dữ liệu, số lần lặp còn ít; cần chạy lại ≥ 5 lần và lấy trung vị trước khi
chốt quyết định thiết kế.
