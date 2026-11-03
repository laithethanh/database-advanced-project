# CSDL hướng đối tượng — ODL, OQL và harness ObjectDB/JPA

Thư mục này hoàn thiện phần **CSDL hướng đối tượng** của đồ án theo ba lớp:

1. **Đặc tả ODL** — `model/ecommerce.odl`: 6 lớp bền vững, 1 struct, kế thừa, quan hệ, tập hợp và phương thức.
2. **Đặc tả OQL** — `queries/ecommerce.oql`: 5 truy vấn OQL độc lập với công cụ.
3. **Hiện thực chạy được** — Maven + JPA + **ObjectDB 2.9.5 (jakarta)**: entity, seed dữ liệu mẫu, 5 truy vấn JPQL, self-check và xuất bằng chứng.

## 1. Cấu trúc

```text
object-db/
├─ pom.xml
├─ README.md
├─ model/
│  ├─ ecommerce.odl          # đặc tả ODL
│  └─ README.md              # giải thích mô hình + ánh xạ JPA
├─ queries/
│  ├─ ecommerce.oql          # 5 truy vấn OQL
│  ├─ ecommerce.jpql         # dạng JPQL thực thi
│  └─ README.md              # bảng ánh xạ OQL → JPQL
├─ src/main/java/vn/edu/ecommerce/objectdb/
│  ├─ Main.java              # chạy seed, query, self-check, xuất bằng chứng
│  ├─ model/                 # entity JPA tương ứng ODL
│  ├─ query/OqlQueries.java  # JPQL OQ01–OQ05
│  └─ seed/SampleData.java   # dữ liệu mẫu cố định
├─ src/main/resources/META-INF/persistence.xml
└─ evidence/oql-output.md    # output mặc định của lần chạy gần nhất
```

## 2. Yêu cầu môi trường

- **JDK 17+**. Đã chạy thực tế trên **Java 25** (Oracle JDK).
- **Maven 3.9+**.
- Internet ở lần chạy đầu để Maven tải `com.objectdb:objectdb-jk:2.9.5` từ `https://m2.objectdb.com` và `jakarta.persistence-api:3.1.0` từ Maven Central.
- Không cần cài ObjectDB thủ công; không commit JAR vào repo.

> ObjectDB là sản phẩm thương mại có bản dùng miễn phí cho phát triển/đánh giá. Đồ án chỉ khai báo dependency Maven, không phân phối lại JAR.

## 3. Cách chạy

Từ thư mục `object-db`:

```powershell
mvn -q compile exec:java
```

Output mặc định: `object-db/evidence/oql-output.md`.

Xuất bằng chứng vào đúng thư mục phụ lục báo cáo:

```powershell
mvn -q compile exec:java "-Dexec.args=../report/appendix/objectdb/20261102/oql-output.md"
```

Harness sẽ:

1. Xóa `target/objectdb/ecommerce.odb` để tạo CSDL mới.
2. Tạo `EntityManagerFactory` với provider `com.objectdb.jpa.Provider`.
3. Seed dữ liệu mẫu cố định.
4. Chạy OQ01–OQ05 bằng JPQL và in kết quả.
5. Kiểm chứng các phương thức nghiệp vụ trong ODL.
6. Ghi báo cáo Markdown UTF-8 và trả mã lỗi nếu có kiểm tra `FAIL`.

## 4. Dữ liệu mẫu và kết quả kỳ vọng

| Thực thể | Dữ liệu |
|---|---|
| Khách hàng | Alice (`alice@example.com`), Bob, Carol |
| Người bán | Shop Alpha (ACTIVE), Shop Beta (ACTIVE), Shop Gamma (SUSPENDED) |
| Sản phẩm | Laptop Pro, Wireless Mouse, Old Phone |
| Biến thể | `SKU-LAP-14` (1500), `SKU-LAP-16` (1800), `SKU-MOU-BLK` (25), `SKU-MOU-WHT` (30), `SKU-PHN-OLD` (200, INACTIVE) |
| Đơn hàng | `ORD-1001` DELIVERED, `ORD-1002` PAID, `ORD-1003` CANCELLED, `ORD-1004` SHIPPED, `ORD-1005` PENDING_PAYMENT |

Kết quả đã chạy thật:

| Truy vấn | Tham số | Kết quả |
|---|---|---|
| OQ01 | `alice@example.com`, `DELIVERED` | `ORD-1001` |
| OQ02 | `price > 1000.00` | `Laptop Pro` |
| OQ03 | `SKU-MOU-BLK`, `ACTIVE` | `Shop Alpha` |
| OQ04 | `PAID/PROCESSING/SHIPPED/DELIVERED` | Alice `3350.00`, Bob `50.00`, Carol `0.00` |
| OQ05 | `PAID` | `ORD-1002`, 1 dòng `SKU-LAP-16` |

Tổng kiểm tra: **16/16 PASS** — xem `../report/appendix/objectdb/20261102/oql-output.md`.

## 5. Ánh xạ OQL → JPQL

Chi tiết trong [`queries/README.md`](queries/README.md) và [`queries/ecommerce.jpql`](queries/ecommerce.jpql). Tóm tắt:

| OQL | JPQL |
|---|---|
| OQ01 | `SELECT o FROM Order o WHERE o.customer.email=:email AND o.status=:status` |
| OQ02 | `SELECT DISTINCT v.product FROM ProductVariant v WHERE v.price>:price` |
| OQ03 | `SELECT s FROM Seller s JOIN s.inventory v WHERE s.shopStatus=:shopStatus AND v.sku=:sku` |
| OQ04 | Hai bước: `SELECT c.email FROM Customer c` + `SELECT o.customer.email, SUM(o.grandTotal) FROM Order o WHERE o.status IN :statuses GROUP BY o.customer.email` |
| OQ05 | `SELECT o FROM Order o WHERE o.status=:status` (items tải EAGER) |

**Vì sao OQ04 cần hai bước?** ObjectDB 2.9.5 chưa hỗ trợ `CASE` và `COALESCE` trong JPQL. Truy vấn thứ nhất lấy đủ khách hàng (kể cả Carol chưa có đơn), truy vấn thứ hai tính tổng; lớp Java ghép hai kết quả và gán `0` cho khách hàng không có đơn.

## 6. Mô hình JPA tương ứng ODL

- `Account` là entity lớp cha; `Customer` và `Seller` kế thừa theo `InheritanceType.SINGLE_TABLE`.
- `Customer.orders` ↔ `Order.customer` là quan hệ một-nhiều hai chiều.
- `Seller.inventory` ↔ `ProductVariant.sellers` là quan hệ nhiều-nhiều.
- `Product.variants` ↔ `ProductVariant.product` là quan hệ một-nhiều.
- `Order.items` là `List<OrderLine>` với `@ElementCollection` + `@OrderColumn`; `OrderLine` là `@Embeddable`, không có OID riêng.
- `OrderLine.seller` là `@ManyToOne` tới `Seller`, tương ứng `order_item.seller_id`, để quy doanh thu chính xác theo từng dòng hàng.
- `Account.isActive()`, `Customer.lifetimeValue()`, `Product.activeVariants()`, `ProductVariant.isAvailable()`, `Order.total()`, `Order.canTransitionTo(String)` được cài đặt trực tiếp.
- `Seller.revenue()` được cài đặt thành `Seller.revenue(Collection<Order>)` vì đối tượng `Seller` không sở hữu tập `Order` toàn cục; cách làm này vẫn giữ đúng ngữ nghĩa ODL và được kiểm chứng trong `Main`.

**OID và khóa:** ObjectDB tự quản lý OID nội bộ cho từng đối tượng. Trường `id` trong entity là surrogate key JPA; `email`, `sku`, `orderNumber` là định danh nghiệp vụ có ràng buộc `UNIQUE`, không phải OID.

## 7. Ghi chú kỹ thuật

- `persistence.xml` dùng namespace JPA 2.1 vì bộ ObjectDB 2.9.5 đóng gói XSD 2.1; API biên dịch vẫn là Jakarta Persistence 3.1.
- Trên Java 25, ObjectDB in cảnh báo `sun.misc.Unsafe` khi khởi động. Đây là cảnh báo của thư viện, không làm sai kết quả.
- Nếu tiến trình trước chưa đóng, file `target/objectdb/ecommerce.odb` có thể bị khóa; đóng tiến trình Java rồi chạy lại.
- Không commit `target/` và file `.odb`.
- Báo cáo được ghi bằng UTF-8; nếu console Windows hiển thị sai dấu, mở file `.md` bằng editor UTF-8.

## 8. Xử lý sự cố nhanh

| Hiện tượng | Cách xử lý |
|---|---|
| `mvn` không nhận | Thêm Maven vào `PATH` hoặc dùng `C:\apache-maven-3.9.11\bin\mvn.cmd` |
| Không tải được `objectdb-jk` | Kiểm tra mạng và quyền truy cập `https://m2.objectdb.com` |
| `Unknown attribute 'new'` | Không dùng `;new` trong URL; harness tự xóa file `.odb` trước khi chạy |
| `Content is not allowed in prolog` | `persistence.xml` bị BOM; lưu lại bằng UTF-8 không BOM |
| Kết quả `FAIL` | Đọc chi tiết trong file output; mã lỗi trả về khác 0 |
