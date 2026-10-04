# Data dictionary

Quy ước: `PK` khóa chính, `FK` khóa ngoại, `UQ` unique, `NN` not null. Các cột tiền dùng `DECIMAL(15,2)`.

## ACCOUNT
| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| account_id | BIGINT UNSIGNED | No | PK | ID tài khoản |
| email | VARCHAR(255) | No | UQ | Email đăng nhập |
| password_hash | VARCHAR(255) | No | | Hash mật khẩu |
| full_name | VARCHAR(150) | No | | Họ tên |
| phone | VARCHAR(30) | Yes | | Số điện thoại |
| status | ENUM | No | | ACTIVE/BLOCKED/DELETED |
| created_at | DATETIME | No | | Thời điểm tạo |
| updated_at | DATETIME | No | | Thời điểm cập nhật |

## CUSTOMER
| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| account_id | BIGINT UNSIGNED | No | PK/FK | Account tương ứng |
| customer_code | VARCHAR(30) | No | UQ | Mã khách hàng |

## SELLER
| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| account_id | BIGINT UNSIGNED | No | PK/FK | Account tương ứng |
| seller_code | VARCHAR(30) | No | UQ | Mã người bán |
| shop_name | VARCHAR(150) | No | UQ | Tên shop |
| shop_status | ENUM | No | | PENDING/ACTIVE/SUSPENDED/CLOSED |
| created_at | DATETIME | No | | Thời điểm tạo shop |

## ADDRESS
| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| address_id | BIGINT UNSIGNED | No | PK | ID địa chỉ |
| customer_id | BIGINT UNSIGNED | No | FK | Chủ địa chỉ |
| recipient_name | VARCHAR(150) | No | | Người nhận |
| phone | VARCHAR(30) | No | | Điện thoại nhận |
| line1 | VARCHAR(255) | No | | Địa chỉ chi tiết |
| ward | VARCHAR(100) | Yes | | Phường/xã |
| district | VARCHAR(100) | Yes | | Quận/huyện |
| city | VARCHAR(100) | No | | Thành phố |
| province | VARCHAR(100) | No | | Tỉnh/thành |
| postal_code | VARCHAR(20) | Yes | | Mã bưu chính |
| is_default | BOOLEAN | No | | Địa chỉ mặc định |

## CATEGORY
| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| category_id | BIGINT UNSIGNED | No | PK | ID danh mục |
| parent_category_id | BIGINT UNSIGNED | Yes | FK | Category cha; null nếu root |
| name | VARCHAR(150) | No | | Tên danh mục |
| slug | VARCHAR(180) | No | UQ | Khóa URL |
| status | ENUM | No | | ACTIVE/INACTIVE |
| created_at | DATETIME | No | | Thời điểm tạo |

## PRODUCT
| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| product_id | BIGINT UNSIGNED | No | PK | ID sản phẩm |
| seller_id | BIGINT UNSIGNED | No | FK | Seller sở hữu |
| category_id | BIGINT UNSIGNED | No | FK | Category chính |
| name | VARCHAR(255) | No | | Tên sản phẩm |
| slug | VARCHAR(180) | No | | Slug trong phạm vi seller |
| description | TEXT | Yes | | Mô tả |
| brand | VARCHAR(120) | Yes | | Thương hiệu |
| status | ENUM | No | | DRAFT/ACTIVE/INACTIVE/ARCHIVED |
| created_at | DATETIME | No | | Thời điểm tạo |
| updated_at | DATETIME | No | | Thời điểm cập nhật |

## PRODUCT_VARIANT
| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| variant_id | BIGINT UNSIGNED | No | PK | ID biến thể/SKU |
| product_id | BIGINT UNSIGNED | No | FK | Product cha |
| sku | VARCHAR(80) | No | UQ | SKU toàn hệ thống |
| color | VARCHAR(60) | No | | Màu; chuỗi rỗng nếu không áp dụng |
| size | VARCHAR(60) | No | | Size; chuỗi rỗng nếu không áp dụng |
| price | DECIMAL(15,2) | No | | Giá bán hiện tại |
| compare_at_price | DECIMAL(15,2) | Yes | | Giá tham chiếu |
| status | ENUM | No | | ACTIVE/INACTIVE/ARCHIVED |

## CART / CART_ITEM
| Table.Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| cart.cart_id | BIGINT UNSIGNED | No | PK | ID giỏ |
| cart.customer_id | BIGINT UNSIGNED | No | FK | Chủ giỏ |
| cart.status | ENUM | No | | ACTIVE/CHECKED_OUT/ABANDONED |
| cart.created_at | DATETIME | No | | Thời điểm tạo |
| cart.updated_at | DATETIME | No | | Thời điểm cập nhật |
| cart_item.cart_id | BIGINT UNSIGNED | No | PK/FK | Giỏ |
| cart_item.variant_id | BIGINT UNSIGNED | No | PK/FK | SKU |
| cart_item.quantity | INT UNSIGNED | No | | Số lượng |
| cart_item.added_at | DATETIME | No | | Thời điểm thêm |

## WAREHOUSE / INVENTORY
| Table.Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| warehouse.warehouse_id | BIGINT UNSIGNED | No | PK | ID kho |
| warehouse.code | VARCHAR(40) | No | UQ | Mã kho |
| warehouse.name | VARCHAR(150) | No | | Tên kho |
| warehouse.address_text | VARCHAR(500) | Yes | | Địa chỉ kho |
| warehouse.status | ENUM | No | | ACTIVE/INACTIVE |
| inventory.warehouse_id | BIGINT UNSIGNED | No | PK/FK | Kho |
| inventory.variant_id | BIGINT UNSIGNED | No | PK/FK | SKU |
| inventory.quantity_on_hand | INT UNSIGNED | No | | Tồn thực |
| inventory.reserved_quantity | INT UNSIGNED | No | | Tồn đã giữ |
| inventory.reorder_level | INT UNSIGNED | No | | Ngưỡng cảnh báo |
| inventory.updated_at | DATETIME | No | | Thời điểm cập nhật |

## PROMOTION / JUNCTIONS
| Table.Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| promotion.promotion_id | BIGINT UNSIGNED | No | PK | ID promotion |
| promotion.code | VARCHAR(50) | Yes | UQ | Coupon code |
| promotion.name | VARCHAR(150) | No | | Tên promotion |
| promotion.promotion_type | ENUM | No | | PERCENT/FIXED |
| promotion.discount_value | DECIMAL(15,2) | No | | Giá trị giảm |
| promotion.min_order_amount | DECIMAL(15,2) | No | | Đơn tối thiểu |
| promotion.max_discount | DECIMAL(15,2) | Yes | | Mức giảm tối đa |
| promotion.start_at | DATETIME | No | | Bắt đầu hiệu lực |
| promotion.end_at | DATETIME | No | | Kết thúc hiệu lực |
| promotion.status | ENUM | No | | DRAFT/ACTIVE/INACTIVE/EXPIRED |
| promotion.usage_limit | INT UNSIGNED | Yes | | Giới hạn lượt dùng |
| promotion_product.promotion_id | BIGINT UNSIGNED | No | PK/FK | Promotion |
| promotion_product.product_id | BIGINT UNSIGNED | No | PK/FK | Product được áp dụng |
| promotion_category.promotion_id | BIGINT UNSIGNED | No | PK/FK | Promotion |
| promotion_category.category_id | BIGINT UNSIGNED | No | PK/FK | Category được áp dụng |

## ORDERS / ORDER_ITEM / ORDER_PROMOTION
| Table.Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| orders.order_id | BIGINT UNSIGNED | No | PK | ID đơn |
| orders.order_number | VARCHAR(40) | No | UQ | Mã đơn nghiệp vụ |
| orders.customer_id | BIGINT UNSIGNED | No | FK | Chủ đơn |
| orders.status | ENUM | No | | State của đơn |
| orders.recipient_name | VARCHAR(150) | No | | Snapshot người nhận |
| orders.recipient_phone | VARCHAR(30) | No | | Snapshot điện thoại |
| orders.shipping_address | VARCHAR(600) | No | | Snapshot địa chỉ |
| orders.subtotal | DECIMAL(15,2) | No | | Tổng dòng trước discount |
| orders.discount_total | DECIMAL(15,2) | No | | Tổng giảm |
| orders.shipping_fee | DECIMAL(15,2) | No | | Phí vận chuyển |
| orders.grand_total | DECIMAL(15,2) | No | | Tổng phải trả |
| orders.placed_at | DATETIME | Yes | | Thời điểm đặt |
| orders.created_at | DATETIME | No | | Thời điểm tạo |
| orders.updated_at | DATETIME | No | | Thời điểm cập nhật |
| order_item.order_item_id | BIGINT UNSIGNED | No | PK | ID dòng |
| order_item.order_id | BIGINT UNSIGNED | No | FK | Đơn |
| order_item.variant_id | BIGINT UNSIGNED | No | FK | SKU được mua |
| order_item.product_name_snapshot | VARCHAR(255) | No | | Tên tại lúc mua |
| order_item.sku_snapshot | VARCHAR(80) | No | | SKU tại lúc mua |
| order_item.unit_price | DECIMAL(15,2) | No | | Giá tại lúc mua |
| order_item.quantity | INT UNSIGNED | No | | Số lượng |
| order_item.line_discount | DECIMAL(15,2) | No | | Giảm trên dòng |
| order_item.line_total | DECIMAL(15,2) | No | | Tổng dòng |
| order_promotion.order_id | BIGINT UNSIGNED | No | PK/FK | Đơn |
| order_promotion.promotion_id | BIGINT UNSIGNED | No | PK/FK | Promotion |
| order_promotion.discount_amount | DECIMAL(15,2) | No | | Snapshot discount |
| order_promotion.promotion_code_snapshot | VARCHAR(50) | Yes | | Code tại lúc dùng |

## PAYMENT / SHIPMENT
| Table.Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| payment.payment_id | BIGINT UNSIGNED | No | PK | ID thanh toán |
| payment.order_id | BIGINT UNSIGNED | No | FK | Đơn |
| payment.provider | VARCHAR(50) | No | | Payment provider |
| payment.transaction_ref | VARCHAR(120) | Yes | UQ | Mã giao dịch gateway |
| payment.amount | DECIMAL(15,2) | No | | Số tiền giao dịch |
| payment.status | ENUM | No | | PENDING/SUCCESS/FAILED/REFUNDED |
| payment.paid_at | DATETIME | Yes | | Thời điểm thanh toán |
| payment.created_at | DATETIME | No | | Thời điểm tạo |
| shipment.shipment_id | BIGINT UNSIGNED | No | PK | ID shipment |
| shipment.order_id | BIGINT UNSIGNED | No | FK | Đơn |
| shipment.carrier | VARCHAR(80) | No | | Đơn vị vận chuyển |
| shipment.tracking_number | VARCHAR(120) | Yes | UQ | Mã tracking |
| shipment.status | ENUM | No | | PENDING/SHIPPED/IN_TRANSIT/DELIVERED/RETURNED |
| shipment.shipped_at | DATETIME | Yes | | Thời điểm gửi |
| shipment.delivered_at | DATETIME | Yes | | Thời điểm giao |

## REVIEW
| Column | Type | Null | Key | Description |
|---|---|---:|---|---|
| review_id | BIGINT UNSIGNED | No | PK | ID review |
| product_id | BIGINT UNSIGNED | No | FK | Product được đánh giá |
| customer_id | BIGINT UNSIGNED | No | FK | Người đánh giá |
| order_item_id | BIGINT UNSIGNED | No | FK | Bằng chứng đã mua |
| rating | TINYINT UNSIGNED | No | | 1..5 |
| title | VARCHAR(200) | Yes | | Tiêu đề |
| body | TEXT | Yes | | Nội dung |
| status | ENUM | No | | PUBLISHED/HIDDEN/PENDING |
| created_at | DATETIME | No | | Thời điểm tạo |
| updated_at | DATETIME | No | | Thời điểm cập nhật |

## Snapshot và derived data

`order_item.unit_price`, `product_name_snapshot`, `sku_snapshot` và thông tin giao hàng trong `orders` là snapshot của giao dịch. Chúng phải giữ nguyên sau khi catalog thay đổi.

`subtotal`, `discount_total`, `grand_total`, `line_total`, `quantity_on_hand` và `reserved_quantity` có ý nghĩa nghiệp vụ riêng. Nhóm phải thống nhất procedure/trigger hoặc invariant query để không cho phép các giá trị mâu thuẫn.
