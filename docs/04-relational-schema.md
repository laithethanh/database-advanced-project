# Lược đồ quan hệ (đồng bộ với `sql/01_schema.sql`)

`sql/01_schema.sql` là nguồn chuẩn của cấu trúc vật lý. Yêu cầu MySQL 8.0 trở lên, cơ sở dữ liệu `ecommerce_advanced`.

```text
ACCOUNT(account_id PK, email UQ, password_hash, full_name, phone, status, created_at, updated_at)
CUSTOMER(account_id PK/FK→ACCOUNT, customer_code UQ)
SELLER(account_id PK/FK→ACCOUNT, seller_code UQ, shop_name UQ, shop_status, created_at)
ADDRESS(address_id PK, customer_id FK→CUSTOMER, recipient_name, phone, line1, ward, district, city, province, postal_code, is_default)
CATEGORY(category_id PK, parent_category_id FK→CATEGORY, name, slug UQ, status, created_at)
PRODUCT(product_id PK, category_id FK→CATEGORY, name, slug UQ, description, brand, status, created_at, updated_at)
WAREHOUSE(warehouse_id PK, code UQ, name, address_text, status)
PRODUCT_VARIANT(variant_id PK, warehouse_id FK→WAREHOUSE, product_id FK→PRODUCT, sku UQ, color, size, price, compare_at_price, warehouse_quantity, status, UQ(warehouse_id,product_id,color,size))
INVENTORY(seller_id PK/FK→SELLER, variant_id PK/FK→PRODUCT_VARIANT, quantity_on_hand, reserved_quantity, reorder_level, updated_at)
CART(cart_id PK, customer_id FK→CUSTOMER, status, created_at, updated_at)
CART_ITEM(cart_id PK/FK→CART, seller_id PK, variant_id PK, quantity, added_at, FK(seller_id,variant_id)→INVENTORY)
PROMOTION(promotion_id PK, code UQ, name, promotion_type, discount_value, min_order_amount, max_discount, start_at, end_at, status, usage_limit, used_count)
PROMOTION_PRODUCT(promotion_id PK/FK→PROMOTION, product_id PK/FK→PRODUCT)
PROMOTION_CATEGORY(promotion_id PK/FK→PROMOTION, category_id PK/FK→CATEGORY)
ORDERS(order_id PK, order_number UQ, customer_id FK→CUSTOMER, status, recipient_name, recipient_phone, shipping_address, subtotal, discount_total, shipping_fee, grand_total, placed_at, created_at, updated_at)
ORDER_ITEM(order_item_id PK, order_id FK→ORDERS, seller_id, variant_id, product_name_snapshot, sku_snapshot, unit_price, quantity, line_discount, line_total, UQ(order_id,seller_id,variant_id), FK(seller_id,variant_id)→INVENTORY)
ORDER_PROMOTION(order_id PK/FK→ORDERS, promotion_id PK/FK→PROMOTION, discount_amount, promotion_code_snapshot)
PAYMENT(payment_id PK, order_id FK→ORDERS, provider, transaction_ref UQ, amount, status, paid_at, created_at)
SHIPMENT(shipment_id PK, order_id FK→ORDERS, carrier, tracking_number UQ, status, shipped_at, delivered_at)
REVIEW(review_id PK, product_id FK→PRODUCT, customer_id FK→CUSTOMER, order_item_id FK→ORDER_ITEM, rating, title, body, status, created_at, updated_at, UQ(customer_id,product_id))
```

## Các chỉ mục được khai báo trong lược đồ

- `product(category_id, status)`
- `product_variant(product_id, status)` và `product_variant(warehouse_id, product_id)`
- `inventory(variant_id)`
- `cart(customer_id, status)`; `sql/02_constraints.sql` bổ sung khóa sinh tự động và ràng buộc duy nhất để mỗi khách hàng chỉ có một giỏ hàng đang hoạt động
- `orders(customer_id, created_at)` và `orders(status, created_at)`
- `order_item(variant_id)`, `payment(order_id, status)`

## Important modeling implications

- `product` là mục danh mục dùng chung và không có cột `seller_id`.
- `product_variant` thuộc về một sản phẩm trong danh mục và một kho của nhà cung cấp. `warehouse_quantity` lưu số lượng tồn tại kho nhà cung cấp.
- `inventory` lưu tồn kho của từng người bán cho mỗi biến thể, với khóa `(seller_id, variant_id)`.
- `cart_item` lưu `seller_id`; khóa ngoại ghép `(seller_id, variant_id)` tham chiếu `inventory`, vì vậy một dòng giỏ hàng chỉ có thể chọn biến thể thực sự có trong kho của cửa hàng đó. `order_item` lưu lại mã người bán tại thời điểm đặt hàng và tham chiếu cùng khóa tồn kho, giúp xác định đúng người bán khi xử lý đơn và lập báo cáo. Khi thanh toán, hệ thống chỉ trừ tồn kho của người bán đã chọn, không tự chia một dòng hàng cho nhiều cửa hàng.
- `product.slug` và tổ hợp kho/sản phẩm/màu/kích cỡ của `product_variant` chịu ràng buộc duy nhất trên toàn hệ thống như khai báo trong DDL; không được mặc định slug hoặc tổ hợp biến thể là duy nhất theo từng người bán.
