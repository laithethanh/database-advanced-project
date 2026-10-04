# Relational schema

Notation: `PK` khóa chính, `FK` khóa ngoại, `UQ` unique, `NN` not null.

```text
ACCOUNT(account_id PK, email UQ, password_hash, full_name, phone, status, created_at, updated_at)
CUSTOMER(account_id PK/FK→ACCOUNT, customer_code UQ, default_address_id FK→ADDRESS nullable)
SELLER(account_id PK/FK→ACCOUNT, seller_code UQ, shop_name UQ, shop_status, created_at)
ADDRESS(address_id PK, customer_id FK→CUSTOMER, recipient_name, phone, line1, ward, district, city, province, postal_code, is_default)

CATEGORY(category_id PK, parent_category_id FK→CATEGORY nullable, name, slug UQ, status, created_at)
PRODUCT(product_id PK, seller_id FK→SELLER, category_id FK→CATEGORY, name, slug, description, brand, status, created_at, updated_at, UQ(seller_id,slug))
PRODUCT_VARIANT(variant_id PK, product_id FK→PRODUCT, sku UQ, color, size, price, compare_at_price, status, UQ(product_id,color,size))

CART(cart_id PK, customer_id FK→CUSTOMER, status, created_at, updated_at, UQ(customer_id,status_active))
CART_ITEM(cart_id PK/FK→CART, variant_id PK/FK→PRODUCT_VARIANT, quantity, added_at)

WAREHOUSE(warehouse_id PK, code UQ, name, address_text, status)
INVENTORY(warehouse_id PK/FK→WAREHOUSE, variant_id PK/FK→PRODUCT_VARIANT, quantity_on_hand, reserved_quantity, reorder_level, updated_at)

PROMOTION(promotion_id PK, code UQ nullable, name, promotion_type, discount_value, min_order_amount, max_discount nullable, start_at, end_at, status, usage_limit nullable)
PROMOTION_PRODUCT(promotion_id PK/FK→PROMOTION, product_id PK/FK→PRODUCT)
PROMOTION_CATEGORY(promotion_id PK/FK→PROMOTION, category_id PK/FK→CATEGORY)

ORDERS(order_id PK, order_number UQ, customer_id FK→CUSTOMER, address_snapshot..., status, subtotal, discount_total, shipping_fee, grand_total, placed_at, created_at, updated_at)
ORDER_ITEM(order_item_id PK, order_id FK→ORDERS, variant_id FK→PRODUCT_VARIANT, product_name_snapshot, sku_snapshot, unit_price, quantity, line_discount, line_total, UQ(order_id,variant_id))
ORDER_PROMOTION(order_id PK/FK→ORDERS, promotion_id PK/FK→PROMOTION, discount_amount, promotion_code_snapshot)
PAYMENT(payment_id PK, order_id FK→ORDERS, provider, transaction_ref UQ nullable, amount, status, paid_at, created_at)
SHIPMENT(shipment_id PK, order_id FK→ORDERS, carrier, tracking_number UQ nullable, status, shipped_at, delivered_at)

REVIEW(review_id PK, product_id FK→PRODUCT, customer_id FK→CUSTOMER, order_item_id FK→ORDER_ITEM, rating, title, body, status, created_at, updated_at, UQ(customer_id,product_id))
```

## Khóa và chỉ mục quan trọng

- PK/FK indexes được tạo theo InnoDB.
- `account.email`, `seller.shop_name`, `seller.seller_code`, `product_variant.sku`, `category.slug`, `orders.order_number` là candidate keys nghiệp vụ.
- Index truy vấn: `product(seller_id, status)`, `product(category_id, status)`, `product_variant(product_id,status)`, `inventory(variant_id)`, `orders(customer_id, created_at)`, `orders(status, created_at)`, `order_item(variant_id)`, `review(product_id,status)`.
- Với benchmark phải đo trước và sau index; không kết luận chỉ từ lý thuyết.
