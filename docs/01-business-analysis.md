# Khảo sát nghiệp vụ sàn thương mại điện tử

## 1. Phạm vi

Hệ thống mô phỏng một sàn TMĐT nhiều người bán. Khách hàng duyệt danh mục, xem sản phẩm và biến thể, quản lý giỏ hàng, đặt hàng, nhận hàng, đánh giá sản phẩm và sử dụng khuyến mãi. Người bán quản lý sản phẩm, SKU, tồn kho và theo dõi đơn liên quan. Hệ thống quản lý danh mục, khuyến mãi, kho, thanh toán và giao hàng.

Phạm vi dữ liệu tập trung vào **vòng đời từ catalog → cart → order → inventory → payment/shipment → review**. Không mô hình hóa chi tiết vận hành logistics nội bộ của đơn vị vận chuyển.

## 2. Actor

| Actor | Mục tiêu | Nghiệp vụ chính |
|---|---|---|
| Khách hàng (Customer) | Mua hàng | đăng ký, quản lý địa chỉ, duyệt sản phẩm, giỏ hàng, đặt hàng, thanh toán, theo dõi đơn, review |
| Người bán (Seller) | Bán hàng | quản lý shop, sản phẩm, SKU, giá, tồn kho, xử lý đơn, xem doanh thu |
| Quản trị viên (Admin) | Quản trị sàn | quản lý tài khoản, danh mục, kiểm duyệt catalog, khuyến mãi, xử lý vi phạm |
| Kho (Warehouse) | Quản lý tồn | nhập/điều chỉnh tồn, giữ tồn khi đặt hàng, xuất/hoàn tồn |
| Cổng thanh toán (Payment Gateway) | Xử lý thanh toán | nhận yêu cầu, trả trạng thái thanh toán, đối soát |
| Đơn vị vận chuyển (Carrier) | Giao hàng | nhận shipment, cập nhật trạng thái, xác nhận giao |

Admin, Payment Gateway và Carrier được coi là actor ngoài hệ thống hoặc actor vận hành; không nhất thiết phải có tài khoản trong DB lõi.

## 3. Luồng nghiệp vụ chính

### 3.1 Catalog

Seller tạo product → tạo một hoặc nhiều variant → gán category → khai báo SKU, giá và thuộc tính màu/size → tồn kho được quản lý theo variant tại warehouse.

### 3.2 Giỏ hàng

Customer có tối đa một cart đang hoạt động. CartItem tham chiếu một variant. Cùng một variant trong một cart được biểu diễn bằng một dòng và cập nhật quantity.

### 3.3 Đặt hàng

Customer chọn địa chỉ và các dòng cart. Hệ thống kiểm tra giá/trạng thái/tồn kho/khuyến mãi, tạo order và order items, giữ/trừ tồn, tính subtotal/discount/shipping/grand total, tạo payment và shipment theo chính sách. Toàn bộ thao tác dữ liệu lõi phải nằm trong một transaction.

### 3.4 Đánh giá

Customer chỉ được review product sau khi có OrderItem thuộc một đơn đã giao thành công. Mỗi customer chỉ có tối đa một review cho một product theo chính sách của đề tài.

### 3.5 Category

Category là cây nhiều tầng. `parent_category_id` có thể null ở root. Một category không được làm ancestor của chính nó; khi cập nhật parent phải ngăn cycle.

## 4. Vòng đời đơn hàng

`PENDING_PAYMENT → PAID → PROCESSING → SHIPPED → DELIVERED`

Nhánh lỗi/ngoại lệ: `PENDING_PAYMENT → CANCELLED`, `PAID → CANCELLED` chỉ khi chính sách cho phép; `SHIPPED → RETURN_REQUESTED → RETURNED` khi hỗ trợ trả hàng.

Chuyển trạng thái phải theo transition hợp lệ. Không cho cập nhật tùy ý từ trạng thái cuối về trạng thái đầu.

## 5. Đối tượng dữ liệu cốt lõi

`Account`, `Customer`, `Seller`, `Address`, `Category`, `Product`, `ProductVariant`, `Cart`, `CartItem`, `Warehouse`, `Inventory`, `Promotion`, `PromotionProduct`, `PromotionCategory`, `Order`, `OrderItem`, `OrderPromotion`, `Payment`, `Shipment`, `Review`.

## 6. Ranh giới hệ thống

Đề tài tập trung vào CSDL và SQL. UI storefront, hệ thống vận chuyển thực tế, cổng thanh toán thật, thuế theo từng quốc gia và kế toán tổng hợp không nằm trong core schema. Những phần đó chỉ được mô phỏng bằng trạng thái và mã tham chiếu cần thiết.
