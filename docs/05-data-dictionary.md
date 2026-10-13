# Data dictionary

This dictionary follows `sql/01_schema.sql`. All identifier columns are `BIGINT UNSIGNED`; money values use `DECIMAL(15,2)`.

| Table | Key columns and purpose |
|---|---|
| `account` | `account_id` PK; unique `email`; password hash, full name, phone, account status and timestamps. |
| `customer` | `account_id` PK/FK to account; unique `customer_code`. |
| `seller` | `account_id` PK/FK to account; unique `seller_code` and `shop_name`; `shop_status`. |
| `address` | `address_id` PK; `customer_id` FK; recipient and Vietnamese address fields; default flag. |
| `category` | `category_id` PK; nullable self-FK `parent_category_id`; unique slug; active status. |
| `product` | `product_id` PK; `category_id` FK; globally unique slug; name, description, brand, status and timestamps. It has no seller FK. |
| `warehouse` | `warehouse_id` PK; unique code; name, address text and status. The schema seeds WH-HN, WH-DN and WH-HCM. |
| `product_variant` | `variant_id` PK; `warehouse_id` and `product_id` FKs; unique SKU; color, size, price, compare-at price, supplier `warehouse_quantity`, status. Unique `(warehouse_id, product_id, color, size)`. |
| `inventory` | Composite PK `(seller_id, variant_id)`; seller FK and variant FK; seller `quantity_on_hand`, `reserved_quantity`, `reorder_level`, updated timestamp. |
| `cart` | `cart_id` PK; customer FK; status and timestamps. `sql/02_constraints.sql` adds a generated unique key to prevent more than one ACTIVE cart per customer. |
| `cart_item` | Composite PK `(cart_id, seller_id, variant_id)`; cart FK and composite `(seller_id, variant_id)` FK to inventory; quantity and added timestamp. Each line explicitly selects a shop. |
| `promotion` | `promotion_id` PK; optional unique code; type/value, minimum order, maximum discount, validity window, status, usage limit and `used_count`. |
| `promotion_product` | Composite PK `(promotion_id, product_id)`; promotion/product mapping. |
| `promotion_category` | Composite PK `(promotion_id, category_id)`; promotion/category mapping. |
| `orders` | `order_id` PK; unique order number; customer FK; lifecycle status; recipient/address snapshots; subtotal, discount, shipping, grand total and timestamps. |
| `order_item` | `order_item_id` PK; order FK; `seller_id` and `variant_id` composite FK to inventory; product/SKU snapshots, unit price, quantity, discount and total; unique `(order_id, seller_id, variant_id)`. |
| `order_promotion` | Composite PK `(order_id, promotion_id)`; applied discount and promotion-code snapshot. |
| `payment` | `payment_id` PK; order FK; provider, optional unique transaction reference, amount, status and payment timestamps. |
| `shipment` | `shipment_id` PK; order FK; carrier, optional unique tracking number, status and shipping/delivery timestamps. |
| `review` | `review_id` PK; product/customer/order-item FKs; rating, title, body, moderation status and timestamps; unique `(customer_id, product_id)`. |

## Stock concepts

- `product_variant.warehouse_quantity`: quantity recorded at the supplier warehouse for that warehouse-specific variant.
- `inventory.quantity_on_hand`: quantity assigned to a seller/shop for that variant.
- `inventory.reserved_quantity`: part of seller stock reserved for fulfillment; it must not exceed `quantity_on_hand`.
- `quantity_on_hand - reserved_quantity`: currently available seller stock.

## Checkout stock ownership

Both `cart_item` and `order_item` store `seller_id`, constrained with `variant_id` to an existing `inventory` row. Checkout deducts stock only from that selected seller; `product_variant.warehouse_quantity` remains the supplier-warehouse quantity.
