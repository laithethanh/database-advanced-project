# Từ điển dữ liệu

Từ điển này tuân theo `sql/01_schema.sql`. Tất cả cột định danh dùng `BIGINT UNSIGNED`; giá trị tiền tệ dùng `DECIMAL(15,2)`.

| Bảng | Các cột khóa và mục đích |
|---|---|
| `account` | `account_id` PK; `email` duy nhất; mật khẩu đã băm, họ tên, số điện thoại, trạng thái tài khoản và dấu thời gian. |
| `customer` | `account_id` PK/FK to account; unique `customer_code`. |
| `seller` | `account_id` PK/FK tới account; `seller_code` và `shop_name` duy nhất; `shop_status`. |
| `address` | `address_id` PK; `customer_id` FK; thông tin người nhận và địa chỉ tại Việt Nam; cờ địa chỉ mặc định. |
| `category` | `category_id` PK; nullable self-FK `parent_category_id`; unique slug; active status. |
| `product` | `product_id` PK; `category_id` FK; slug duy nhất trên toàn hệ thống; tên, mô tả, thương hiệu, trạng thái và dấu thời gian. Bảng không có khóa ngoại tới người bán. |
| `warehouse` | `warehouse_id` PK; mã duy nhất; tên, địa chỉ dạng văn bản và trạng thái. Lược đồ tạo sẵn WH-HN, WH-DN và WH-HCM. |
| `product_variant` | `variant_id` PK; khóa ngoại `warehouse_id` và `product_id`; SKU duy nhất; màu sắc, kích cỡ, giá, giá niêm yết để so sánh, `warehouse_quantity` tại kho nhà cung cấp và trạng thái. Duy nhất `(warehouse_id, product_id, color, size)`. |
| `inventory` | Khóa chính ghép `(seller_id, variant_id)`; khóa ngoại người bán và biến thể; số lượng thực có `quantity_on_hand`, `reserved_quantity`, `reorder_level` và thời điểm cập nhật. |
| `cart` | `cart_id` PK; khóa ngoại khách hàng; trạng thái và dấu thời gian. `sql/02_constraints.sql` bổ sung khóa duy nhất được sinh tự động để ngăn một khách hàng có nhiều giỏ hàng ACTIVE. |
| `cart_item` | Khóa chính ghép `(cart_id, seller_id, variant_id)`; khóa ngoại giỏ hàng và khóa ngoại ghép `(seller_id, variant_id)` tới inventory; số lượng và thời điểm thêm. Mỗi dòng chỉ rõ cửa hàng được chọn. |
| `promotion` | `promotion_id` PK; mã tùy chọn và duy nhất; loại/giá trị, giá trị đơn hàng tối thiểu, mức giảm tối đa, thời gian hiệu lực, trạng thái, giới hạn sử dụng và `used_count`. |
| `promotion_product` | Composite PK `(promotion_id, product_id)`; promotion/product mapping. |
| `promotion_category` | Composite PK `(promotion_id, category_id)`; promotion/category mapping. |
| `orders` | `order_id` PK; mã đơn hàng duy nhất; khóa ngoại khách hàng; trạng thái vòng đời; bản chụp người nhận/địa chỉ; tiền hàng, giảm giá, phí vận chuyển, tổng tiền và dấu thời gian. |
| `order_item` | `order_item_id` PK; khóa ngoại đơn hàng; khóa ngoại ghép `seller_id` và `variant_id` tới inventory; bản chụp sản phẩm/SKU, đơn giá, số lượng, mức giảm và thành tiền; duy nhất `(order_id, seller_id, variant_id)`. |
| `order_promotion` | Khóa chính ghép `(order_id, promotion_id)`; mỗi dòng là một mã đã áp dụng, gồm mức giảm thực tế và bản chụp mã khuyến mãi. Tổng `discount_amount` của một đơn bằng `orders.discount_total`. |
| `payment` | `payment_id` PK; khóa ngoại đơn hàng; nhà cung cấp thanh toán, mã giao dịch có thể để trống nhưng nếu có phải duy nhất, số tiền, trạng thái và dấu thời gian thanh toán. |
| `shipment` | `shipment_id` PK; khóa ngoại đơn hàng; đơn vị vận chuyển, mã theo dõi có thể để trống nhưng nếu có phải duy nhất, trạng thái và dấu thời gian gửi/giao hàng. |
| `review` | `review_id` PK; khóa ngoại sản phẩm/khách hàng/chi tiết đơn hàng; điểm đánh giá, tiêu đề, nội dung, trạng thái kiểm duyệt và dấu thời gian; duy nhất `(customer_id, product_id)`. |

## Các khái niệm về tồn kho

- `product_variant.warehouse_quantity`: số lượng của biến thể tương ứng được ghi nhận tại kho nhà cung cấp.
- `inventory.quantity_on_hand`: số lượng biến thể đó được phân bổ cho người bán/cửa hàng.
- `inventory.reserved_quantity`: phần tồn kho của người bán đã được giữ chỗ để xử lý đơn; giá trị này không được vượt `quantity_on_hand`.
- `quantity_on_hand - reserved_quantity`: số lượng hàng hiện còn có thể bán của người bán.

## Quy tắc xác định chủ sở hữu tồn kho

Cả `cart_item` và `order_item` đều lưu `seller_id`, kết hợp với `variant_id` để tham chiếu một dòng `inventory` tồn tại. Khi đặt hàng, hệ thống chỉ trừ tồn kho của người bán đã chọn; `product_variant.warehouse_quantity` vẫn là số lượng tại kho nhà cung cấp.
