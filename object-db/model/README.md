# Mô hình cơ sở dữ liệu hướng đối tượng

`ecommerce.odl` khai báo sáu lớp lưu trữ bền vững: Account, Customer, Seller, Product, ProductVariant và Order. `OrderLine` là kiểu giá trị nằm trong tập hợp có thứ tự, không phải lớp lưu trữ bền vững. Mỗi đối tượng bền vững có OID do hệ thống quản lý; `email`, `sku` và `orderNumber` là mã định danh nghiệp vụ, không phải OID. `Customer` và `Seller` kế thừa các trường định danh dùng chung từ `Account`; các tập hợp biểu diễn quan hệ hai chiều, còn `Order.items` chủ ý dùng danh sách có thứ tự.

Các phương thức nghiệp vụ trong ODL: `Account.isActive()`, `Customer.lifetimeValue()`, `Seller.revenue()`, `Product.activeVariants()`, `ProductVariant.isAvailable()`, `Order.total()` và `Order.canTransitionTo(nextStatus)`. Khi triển khai bằng JPQL, các phương thức này được thay bằng truy vấn tổng hợp hoặc kiểm tra trạng thái tương đương; ODL vẫn là đặc tả độc lập với ORM.

Ánh xạ quan hệ dùng trong phần minh họa: `Account→account`, `Customer→customer`, `Seller→seller`, `Product→product`, `ProductVariant→product_variant`, `Order→orders`, `OrderLine→order_item`; liên kết đối tượng ánh xạ sang các cột FK hiện có. `Order.total()` ánh xạ sang `grand_total`; `OrderLine.lineTotal` ánh xạ sang `line_total` được chụp tại thời điểm đặt hàng.

Để thu thập bằng chứng thực thi, nhập mô hình vào ObjectDB (JPA) hoặc chuyển từng truy vấn OQL trong `../queries/ecommerce.oql` sang JPQL. Repository không khẳng định đã có kết quả ObjectDB nếu chưa chạy môi trường ObjectDB thực tế.
