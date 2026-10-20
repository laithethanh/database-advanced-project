# Bộ truy vấn OQL

`ecommerce.oql` chứa năm truy vấn OQL. Để thu thập bằng chứng với ObjectDB/JPA, dùng dạng truy vấn JPQL tương đương dưới đây:

| OQL | Dạng JPQL |
|---|---|
| OQ01 | `SELECT o FROM Order o WHERE o.customer.email=:email AND o.status='DELIVERED'` |
| OQ02 | `SELECT DISTINCT v.product FROM ProductVariant v WHERE v.price>:price` |
| OQ03 | `SELECT s FROM Seller s JOIN s.inventory v WHERE v.sku=:sku` |
| OQ04 | `SELECT c.email, SUM(o.grandTotal) FROM Customer c JOIN c.orders o WHERE o.status IN (...) GROUP BY c.email` |
| OQ05 | Tải `Order` cùng `JOIN FETCH o.items`; JPQL không hỗ trợ trực tiếp việc chiếu một tập hợp lồng nhau như OQL. |

Lưu kết quả ObjectDB/JPQL và SQL được sinh ra (nếu dùng ORM) trong phụ lục. Đặc tả OQL vẫn độc lập với công nghệ thực thi.
