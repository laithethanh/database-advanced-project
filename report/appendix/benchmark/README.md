# Tóm tắt phép đo baseline / optimized

Tất cả số liệu dưới đây là output thật của `EXPLAIN ANALYZE` trên MySQL 8.4.11 với 100.000 đơn hàng
(xem `00-environment.md`). File kế hoạch thực thi gốc: `01-baseline.txt` và `02-optimized.txt`.

## Ba truy vấn đo

| # | Truy vấn | Baseline | Sau khi thêm 3 chỉ mục thử nghiệm | Nhận xét |
|---|---|---|---|---|
| 1 | Doanh thu theo sản phẩm (`orders ⋈ order_item ⋈ product_variant ⋈ product`) | 3.588 ms / 3.509 ms | 3.612 ms | Không cải thiện; trình tối ưu vẫn dùng `idx_order_item_variant` + `PRIMARY` của `orders` |
| 2 | Doanh thu theo người bán theo khoảng thời gian | 2.280 ms / 2.319 ms | 2.285 ms | Không cải thiện; đã dùng covering index `idx_order_status_created` và `uq_order_seller_variant` |
| 3 | Quét tồn kho dưới ngưỡng đặt lại | 0,18 ms / 0,07 ms (table scan 6.000 dòng) | 0,10 ms → 3,08 ms (covering index scan) | Chậm hơn: quét 6.000 dòng rẻ hơn đọc chỉ mục covering |

## Kế hoạch thực thi baseline (rút gọn)

```text
Q1: Limit -> Sort -> Table scan on <temporary> -> Aggregate using temporary table
      -> Nested loop inner join (orders ⋈ order_item)
        -> Nested loop inner join (product ⋈ product_variant)
             -> Table scan on p
             -> Covering index lookup on v using idx_variant_product_status
        -> Index lookup on oi using idx_order_item_variant
      -> Filter: (o.status in ('PAID','PROCESSING','SHIPPED','DELIVERED'))
      -> Single-row index lookup on o using PRIMARY

Q2: Limit -> Sort -> Table scan on <temporary> -> Aggregate
      -> Nested loop inner join
        -> Covering index scan on o using idx_order_status_created  (lọc status + created_at)
        -> Index lookup on oi using uq_order_seller_variant

Q3: Filter ((quantity_on_hand - reserved_quantity) <= reorder_level) -> Table scan on i (6.000 dòng)
```

## Chi phí ghi

Xem `03-write-cost.md`: 10.000 dòng INSERT tăng từ 799,53 ms lên 1.048,40 ms (+31%) khi có thêm chỉ mục.

## Kết luận chính thức của phép thí nghiệm

1. Lược đồ chỉ mục sẵn có (`idx_order_item_variant`, `uq_order_seller_variant`, `idx_order_status_created`,
   `idx_variant_product_status`) đã phục vụ tốt cho các truy vấn phân tích chính.
2. Ba chỉ mục thử nghiệm **không được trình tối ưu chọn** cho bất kỳ truy vấn nào ở trên, và làm tăng chi phí ghi.
3. Vì vậy giữ nguyên lược đồ chỉ mục của `sql/01_schema.sql`; nếu cần tối ưu truy vấn quét tồn kho quy mô lớn
   thì nên giải quyết bằng **materialized view/bảng tổng hợp theo ngày** thay vì thêm chỉ mục.
4. Hạn chế của phép đo: một máy, một bộ dữ liệu, số lần lặp ít; cần chạy lại ≥ 5 lần và lấy trung vị khi
   so sánh quyết định thiết kế cuối cùng.
