# Bộ truy vấn OQL

`ecommerce.oql` chứa năm truy vấn OQL. Để thu thập bằng chứng với ObjectDB/JPA, dùng dạng truy vấn JPQL tương đương dưới đây:

| OQL | Dạng JPQL |
|---|---|
| OQ01 | `SELECT o FROM Order o WHERE o.customer.email=:email AND o.status='DELIVERED'` |
| OQ02 | `SELECT DISTINCT v.product FROM ProductVariant v WHERE v.price>:price` |
| OQ03 | `SELECT s FROM Seller s JOIN s.inventory v WHERE v.sku=:sku` |
| OQ04 | `SELECT c.email, COALESCE(SUM(o.grandTotal),0) FROM Customer c LEFT JOIN c.orders o ON o.status IN (...) GROUP BY c.email` |
| OQ05 | Tải `Order` cùng `JOIN FETCH o.items`; JPQL không hỗ trợ trực tiếp việc chiếu một tập hợp lồng nhau như OQL. |

Lưu kết quả ObjectDB/JPQL và SQL được sinh ra (nếu dùng ORM) trong phụ lục. Đặc tả OQL vẫn độc lập với công nghệ thực thi. Bảng kết quả mong đợi cho 5 truy vấn nằm trong `ecommerce.oql`; khi chạy thật, thay `$email`, `$price`, `$sku` bằng dữ liệu mẫu và lưu kết quả nguyên văn.
