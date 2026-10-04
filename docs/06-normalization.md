# Phụ thuộc hàm và chuẩn hóa

## 1. Nguyên tắc

Thiết kế tách các nhóm thuộc tính có phụ thuộc chức năng khác nhau. N:M được tách thành quan hệ trung gian; thuộc tính lặp theo dòng đơn được đưa vào `order_item`.

## 2. Một số FD tiêu biểu

### ACCOUNT

`account_id → email, password_hash, full_name, phone, status, created_at, updated_at`

`email → account_id, password_hash, full_name, phone, status, created_at, updated_at` vì email UNIQUE.

### PRODUCT_VARIANT

`variant_id → product_id, sku, color, size, price, compare_at_price, status`

`sku → variant_id, product_id, color, size, price, compare_at_price, status`.

### INVENTORY

`(warehouse_id, variant_id) → quantity_on_hand, reserved_quantity, reorder_level, updated_at`.

### ORDER_ITEM

`order_item_id → order_id, variant_id, product_name_snapshot, sku_snapshot, unit_price, quantity, line_discount, line_total`.

`(order_id, variant_id) → order_item_id, ...` theo chính sách hiện tại một SKU chỉ xuất hiện một lần trong một order.

## 3. Candidate keys

| Relation | Candidate key |
|---|---|
| Account | `account_id`, `email` |
| Seller | `account_id`, `seller_code`, `shop_name` |
| ProductVariant | `variant_id`, `sku` |
| Inventory | `(warehouse_id, variant_id)` |
| CartItem | `(cart_id, variant_id)` |
| PromotionProduct | `(promotion_id, product_id)` |
| PromotionCategory | `(promotion_id, category_id)` |
| Order | `order_id`, `order_number` |
| OrderPromotion | `(order_id, promotion_id)` |
| Review | `review_id`, `(customer_id, product_id)` |

## 4. Vì sao đạt 3NF/BCNF ở lõi

Các bảng lõi có thuộc tính không khóa phụ thuộc vào candidate key và không lưu thuộc tính dẫn xuất từ một non-key determinant. Những quan hệ associative có khóa ghép và thuộc tính phụ thuộc vào toàn bộ khóa.

`OrderItem` cố tình lưu snapshot như `unit_price` và `product_name_snapshot` vì chúng mô tả **sự kiện bán tại thời điểm order**, không phải thuộc tính hiện tại của Product. Đây là quyết định nghiệp vụ, không phải dư thừa sai chuẩn hóa.

`Inventory` đạt BCNF theo FD chính nếu không có determinant phụ khác. `CartItem`, `PromotionProduct`, `PromotionCategory`, `OrderPromotion` cũng đạt BCNF với candidate key ghép tương ứng.

## 5. 4NF

Các quan hệ độc lập nhiều giá trị như Product có nhiều color và nhiều size được mô hình hóa bằng `ProductVariant` thay vì lưu hai tập đa trị độc lập trong một bảng. Do đó tránh MVD gây vi phạm 4NF trong thiết kế variant.

## 6. Kiểm chứng formal ở giai đoạn tiếp theo

Nhóm cần đưa minimal cover đầy đủ vào phụ lục báo cáo sau khi DDL v1 được chốt. Tài liệu này là baseline để review; mọi thay đổi schema phải cập nhật lại FD/candidate keys và lập luận chuẩn hóa.
