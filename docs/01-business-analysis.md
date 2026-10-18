# Khảo sát nghiệp vụ sàn thương mại điện tử

## 1. Phạm vi

Hệ thống mô phỏng một sàn thương mại điện tử nhiều người bán. Khách hàng duyệt danh mục, xem sản phẩm và biến thể, quản lý giỏ hàng, đặt hàng, thanh toán, nhận hàng và đánh giá. Hệ thống quản trị tập trung vào catalog, seller, tồn kho, khuyến mãi, đơn hàng và giao nhận.

Phạm vi dữ liệu tập trung vào vòng đời từ catalog → cart → order → inventory → payment/shipment → review. Hệ thống không mô hình hóa chi tiết kế toán tổng hợp, thuế quốc gia, vận chuyển thực tế, cổng thanh toán ngoài đời thực, hoặc vận hành logistics nội bộ phức tạp.

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

Seller tạo product → tạo một hoặc nhiều variant → gán category → khai báo SKU, giá và thuộc tính màu/size. Một product có thể có nhiều variant, nhưng tồn kho thực tế được lưu ở Inventory theo chiều seller + warehouse + variant. Variant chỉ lưu metadata sản phẩm, không lưu lượng tồn.

### 3.2 Giỏ hàng

Customer có tối đa một cart đang hoạt động. CartItem tham chiếu một variant và số lượng. Một variant chỉ xuất hiện tối đa một dòng trong cùng cart; khi số lượng cập nhật, hệ thống ghi đè trên dòng đó. Cart chỉ chứa các item có thực sự tồn tại trong inventory tương ứng của seller.

### 3.3 Đặt hàng

Customer chọn địa chỉ và các dòng cart. Hệ thống kiểm tra giá/trạng thái/tồn kho/khuyến mãi, tạo order và order items, giữ/trừ tồn, tính subtotal/discount/shipping/grand total. Nền tảng lưu snapshot địa chỉ và snapshot thông tin sản phẩm để đảm bảo lịch sử đơn hàng không phụ thuộc dữ liệu hiện tại.

### 3.4 Inventory và tồn kho

Inventory là nguồn dữ liệu duy nhất cho lượng tồn kho thực tế. Mỗi hàng tồn được xác định bởi (seller_id, warehouse_id, variant_id). ProductVariant không lưu `warehouse_quantity` vì lượng tồn là thuộc gói inventory, dễ đồng bộ và tránh sai lệch giữa biến thể và kho.

### 3.5 Khuyến mãi

Khuyến mãi được gắn với product hoặc category và chỉ áp dụng trong phạm vi đã khai báo. Dữ liệu redeem promotion được lưu trong `promotion_usage` để tránh race condition khi nhiều checkout cùng lúc. Order lưu snapshot khuyến mãi đã áp dụng để giữ lịch sử.

### 3.6 Đánh giá

Customer chỉ được review product sau khi có `OrderItem` thuộc một đơn đã giao thành công. Mỗi customer chỉ có tối đa một review cho một product theo chính sách hiện tại. Review không được tạo nếu đơn chưa Delivered hoặc nếu customer không mua sản phẩm đó.

### 3.7 Category

Category là cây nhiều tầng. `parent_category_id` có thể null ở root. Một category không được làm ancestor của chính nó; khi cập nhật parent phải ngăn cycle.

## 4. Vòng đời đơn hàng

`PENDING_PAYMENT → PAID → PROCESSING → SHIPPED → DELIVERED`

Nhánh lỗi/ngoại lệ: `PENDING_PAYMENT → CANCELLED`, `PAID → CANCELLED` chỉ khi chính sách cho phép; `SHIPPED → RETURN_REQUESTED → RETURNED` khi hỗ trợ trả hàng.

Chuyển trạng thái phải theo transition hợp lệ. Không cho cập nhật tùy ý từ trạng thái cuối về trạng thái đầu.

## 5. Đối tượng dữ liệu cốt lõi

`Account`, `Customer`, `Seller`, `Address`, `Category`, `Product`, `ProductVariant`, `Warehouse`, `Inventory`, `Cart`, `CartItem`, `Promotion`, `PromotionProduct`, `PromotionCategory`, `PromotionUsage`, `Order`, `OrderItem`, `OrderPromotion`, `Payment`, `Shipment`, `Review`.

## 6. Ranh giới hệ thống

Đề tài tập trung vào CSDL và SQL. UI storefront, hệ thống vận chuyển thực tế, cổng thanh toán thật, thuế theo từng quốc gia và kế toán tổng hợp không nằm trong phạm vi thiết kế dữ liệu chính.

## 7. Ghi chú thiết kế cần lưu ý

- Quantity tồn kho luôn được quản lý ở Inventory; ProductVariant chỉ lưu thuộc tính biến thể và giá.
- Giữ snapshot dữ liệu ở order/order_item để tránh xung đột khi giá hoặc địa chỉ bị cập nhật sau đó.
- Tất cả tính toán đơn hàng, tồn kho và khuyến mãi phải thực hiện trong transaction để tránh oversell và sai lệch dữ liệu.
- Các rule phức tạp như transition state, review validation, unique active cart, cycle category, và concurrency inventory cần thực hiện bằng trigger/procedure hoặc logic ứng dụng.
