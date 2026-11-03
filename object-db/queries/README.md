# Bộ truy vấn OQL và JPQL

`ecommerce.oql` chứa năm truy vấn OQL độc lập với công cụ. `ecommerce.jpql` chứa dạng JPQL thực thi trên ObjectDB 2.9.5; các hằng số tương ứng nằm trong `../src/main/java/vn/edu/ecommerce/objectdb/query/OqlQueries.java`.

## 1. Bảng ánh xạ

| OQL | Dạng JPQL thực thi | Ghi chú |
|---|---|---|
| OQ01 | `SELECT o FROM Order o WHERE o.customer.email=:email AND o.status=:status ORDER BY o.orderNumber` | Duyệt quan hệ `Order.customer` → `Account.email`. |
| OQ02 | `SELECT DISTINCT v.product FROM ProductVariant v WHERE v.price>:price ORDER BY v.product.name` | `DISTINCT` loại trùng khi một sản phẩm có nhiều biến thể vượt ngưỡng. |
| OQ03 | `SELECT s FROM Seller s JOIN s.inventory v WHERE s.shopStatus=:shopStatus AND v.sku=:sku ORDER BY s.shopName` | `JOIN` trên tập nhiều-nhiều `Seller.inventory`. |
| OQ04 | `SELECT c.email FROM Customer c ORDER BY c.email` + `SELECT o.customer.email, SUM(o.grandTotal) FROM Order o WHERE o.status IN :statuses GROUP BY o.customer.email ORDER BY o.customer.email` | ObjectDB 2.9.5 chưa hỗ trợ `CASE`/`COALESCE`; ghép hai kết quả trong Java để khách hàng không có đơn nhận `0`. |
| OQ05 | `SELECT o FROM Order o WHERE o.status=:status ORDER BY o.orderNumber` | JPQL không chiếu trực tiếp tập `items` lồng nhau; `Order.items` dùng `@ElementCollection` EAGER + `@OrderColumn`. |

## 2. Kết quả chạy thật

Bộ dữ liệu mẫu cố định trong `../src/main/java/vn/edu/ecommerce/objectdb/seed/SampleData.java`:

| OQL | Tham số | Kết quả |
|---|---|---|
| OQ01 | `email=alice@example.com`, `status=DELIVERED` | `ORD-1001` |
| OQ02 | `price=1000.00` | `Laptop Pro` |
| OQ03 | `sku=SKU-MOU-BLK` | `Shop Alpha` |
| OQ04 | `statuses=[PAID, PROCESSING, SHIPPED, DELIVERED]` | `alice@example.com=3350.00`, `bob@example.com=50.00`, `carol@example.com=0.00` |
| OQ05 | `status=PAID` | `ORD-1002` — 1 dòng `SKU-LAP-16`, total `1800.00` |

Kết quả đầy đủ, gồm mapping và 16/16 kiểm tra PASS, nằm trong `../../report/appendix/objectdb/20261102/oql-output.md`.

## 3. Cách chạy

```powershell
cd object-db
mvn -q compile exec:java "-Dexec.args=../report/appendix/objectdb/20261102/oql-output.md"
```

Hoặc chạy mặc định, ghi vào `object-db/evidence/oql-output.md`:

```powershell
mvn -q compile exec:java
```

Khi chạy thật, thay các tham số mẫu bằng dữ liệu mong muốn trong `OqlQueries` hoặc bổ sung tham số dòng lệnh nếu cần. Báo cáo OQL vẫn là đặc tả độc lập; JPQL chỉ là ngôn ngữ thực thi của ObjectDB/JPA.
