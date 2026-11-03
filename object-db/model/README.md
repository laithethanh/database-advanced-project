# Mô hình cơ sở dữ liệu hướng đối tượng

`ecommerce.odl` khai báo sáu lớp lưu trữ bền vững: `Account`, `Customer`, `Seller`, `Product`, `ProductVariant` và `Order`. `OrderLine` là kiểu giá trị nằm trong tập hợp có thứ tự, không phải lớp lưu trữ bền vững. Mỗi đối tượng bền vững có OID do hệ thống quản lý; `email`, `sku` và `orderNumber` là mã định danh nghiệp vụ, không phải OID. `Customer` và `Seller` kế thừa các trường định danh dùng chung từ `Account`; các tập hợp biểu diễn quan hệ hai chiều, còn `Order.items` chủ ý dùng danh sách có thứ tự.

## 1. Phương thức nghiệp vụ

| ODL | Ngữ nghĩa | Hiện thực |
|---|---|---|
| `Account.isActive()` | Tài khoản đang `ACTIVE` | `Account.isActive()` |
| `Customer.lifetimeValue()` | Tổng `grandTotal` của đơn `PAID/PROCESSING/SHIPPED/DELIVERED`; không có đơn trả `0` | `Customer.lifetimeValue()` |
| `Seller.revenue()` | Tổng `lineTotal` của các dòng hàng do người bán chịu trách nhiệm, chỉ tính đơn đã ghi nhận | `Seller.revenue(Collection<Order>)` |
| `Product.activeVariants()` | Các biến thể `ACTIVE` của sản phẩm | `Product.activeVariants()` |
| `ProductVariant.isAvailable()` | Biến thể `ACTIVE` và giá dương | `ProductVariant.isAvailable()` |
| `Order.total()` | Tổng `lineTotal` của các dòng hàng | `Order.total()` |
| `Order.canTransitionTo(nextStatus)` | Kiểm tra chuyển trạng thái hợp lệ | `Order.canTransitionTo(String)` |

`Seller.revenue()` nhận thêm tập `Order` vì trong mô hình, đơn hàng thuộc `Customer` chứ không thuộc `Seller`; một entity bền vững không tự truy cập được extent toàn cục. Cách làm này giữ nguyên ngữ nghĩa ODL và được kiểm chứng trong `Main.runBusinessMethods()`.

`OrderLine` có tham chiếu `Seller` để quy doanh thu chính xác theo từng dòng hàng, tương ứng `order_item.seller_id` trong lược đồ quan hệ. Nếu chỉ dựa trên `sku`, hai người bán cùng bán một SKU sẽ bị tính trùng doanh thu.

## 2. Ánh xạ ODL → JPA

| ODL | Java/JPA | Ghi chú |
|---|---|---|
| `interface Account` | `@Entity class Account` | Supertype; `@Inheritance(SINGLE_TABLE)` |
| `Customer : Account` | `@Entity @DiscriminatorValue("CUSTOMER")` | `@OneToMany(mappedBy="customer")` tới `Order` |
| `Seller : Account` | `@Entity @DiscriminatorValue("SELLER")` | `@ManyToMany` tới `ProductVariant` qua `seller_inventory` |
| `Product` | `@Entity Product` | `@OneToMany(mappedBy="product")` tới biến thể |
| `ProductVariant` | `@Entity ProductVariant` | `sku` UNIQUE; `price` là `BigDecimal` |
| `struct OrderLine` | `@Embeddable OrderLine` | Không có OID; lưu trong `@ElementCollection`; có `@ManyToOne Seller seller` |
| `Order` | `@Entity @Table(name="orders")` | `List<OrderLine>` dùng `@OrderColumn` |

- `id` trong mỗi entity là surrogate key do JPA sinh; ObjectDB vẫn quản lý OID nội bộ riêng.
- `email`, `sku`, `orderNumber` có ràng buộc `UNIQUE` và là định danh nghiệp vụ.
- `Order.items` dùng `fetch = EAGER` để minh họa tải tập lồng nhau; trong hệ thống lớn nên cân nhắc `LAZY` + `JOIN FETCH` có kiểm soát.

## 3. Thực thi

Mô hình Java nằm trong `../src/main/java/vn/edu/ecommerce/objectdb/model/` và được chạy thật bằng ObjectDB 2.9.5. Xem `../README.md` để biết lệnh chạy và bằng chứng.
