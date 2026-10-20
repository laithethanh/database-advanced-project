# Ví dụ benchmark truy vấn Q01

Ví dụ này dùng để đo truy vấn top sản phẩm theo doanh thu. Kết quả phải được
chạy trên cùng một cơ sở dữ liệu, cùng một bộ dữ liệu và cùng một cấu hình MySQL.

## Truy vấn

```sql
USE ecommerce_advanced;

EXPLAIN ANALYZE
SELECT
    p.product_id,
    p.name,
    SUM(oi.quantity * oi.unit_price - oi.line_discount) AS revenue
FROM orders o
JOIN order_item oi ON oi.order_id = o.order_id
JOIN product_variant v ON v.variant_id = oi.variant_id
JOIN product p ON p.product_id = v.product_id
WHERE o.status IN ('PAID', 'PROCESSING', 'SHIPPED', 'DELIVERED')
GROUP BY p.product_id, p.name
ORDER BY revenue DESC
LIMIT 10;
```

## Cách chạy

1. Nạp dữ liệu mẫu hoặc dữ liệu lớn.
2. Chạy câu lệnh trên tối thiểu 3 lần.
3. Bỏ qua lần chạy đầu nếu cần loại ảnh hưởng của cache.
4. Ghi lại `thời gian thực tế`, số dòng đọc và kế hoạch truy vấn từ kết quả
   `EXPLAIN ANALYZE`.

## Bảng ghi kết quả

| Phiên bản | Lần chạy | Thời gian | Số dòng đã đọc | Chỉ mục sử dụng | Ghi chú |
|---|---:|---:|---:|---|---|
| Trước tối ưu | 1 | TBD | TBD | TBD | Chưa đo |
| Trước tối ưu | 2 | TBD | TBD | TBD | Chưa đo |
| Sau tối ưu | 1 | TBD | TBD | TBD | Chưa đo |
| Sau tối ưu | 2 | TBD | TBD | TBD | Chưa đo |

`TBD` phải được thay bằng số liệu thực tế, không điền số ước lượng.

## So sánh trước và sau tối ưu

Nếu cần thử nghiệm chỉ mục, tạo chỉ mục trong môi trường benchmark riêng, sau đó
chạy lại cùng câu truy vấn:

```sql
CREATE INDEX idx_orders_status_created
    ON orders (status, created_at, order_id);

EXPLAIN ANALYZE
SELECT
    p.product_id,
    p.name,
    SUM(oi.quantity * oi.unit_price - oi.line_discount) AS revenue
FROM orders o
JOIN order_item oi ON oi.order_id = o.order_id
JOIN product_variant v ON v.variant_id = oi.variant_id
JOIN product p ON p.product_id = v.product_id
WHERE o.status IN ('PAID', 'PROCESSING', 'SHIPPED', 'DELIVERED')
GROUP BY p.product_id, p.name
ORDER BY revenue DESC
LIMIT 10;
```

Lưu ý: index trên `orders` có thể không làm truy vấn nhanh hơn đáng kể vì
truy vấn vẫn phải nối và tổng hợp nhiều dòng `order_item`. Kết luận phải dựa
trên kế hoạch thực thi và số đo thực tế.
