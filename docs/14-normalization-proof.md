# Normalization supplement

## Minimal-cover basis

For each base relation, FDs are decomposed to one attribute on the right. Representative cover members are `account_id→email`, `email→account_id`, `variant_id→sku`, `sku→variant_id`, `(seller_id,variant_id)→quantity_on_hand`, `(seller_id,variant_id)→reserved_quantity`, `order_id→order_number`, `order_number→order_id`, and `(order_id,seller_id,variant_id)→order_item_id`. Attributes not listed on the left are similarly determined by that relation's declared primary/unique candidate key. No left side can be reduced: the two attributes of the inventory/order-line keys identify different dimensions.

## Keys and normal forms

The candidate keys documented in `06-normalization.md` follow directly from that cover plus UNIQUE constraints. In `account`, `email` is an alternate key; in `product_variant`, `sku` is an alternate key; in `orders`, `order_number` is an alternate key. Every non-trivial FD has a superkey determinant in the core relations, so they are BCNF under declared dependencies. Associative relations (`inventory`, `cart_item`, `promotion_product`, `promotion_category`, `order_promotion`) have no non-key determinant and are also BCNF.

`order_item` retains price/name/SKU snapshots by design: it models a historical sale fact. These values describe the line at order time and are not dependencies on mutable catalog values. This controlled historical duplication prevents update anomalies in audit history.

## Lossless join and dependency preservation

Subtype tables decompose `Account` losslessly because `customer.account_id` and `seller.account_id` are PK/FK references to `account`. N:M mappings are lossless because each bridge contains the two referenced keys. An order reconstructed from `orders ⋈ order_item` is lossless by the non-null FK `order_item.order_id`; its line-level grain remains explicit. FK/PK/UNIQUE declarations preserve the key dependencies locally, while cross-row assertions (totals, valid state, review eligibility and stock) are intentionally enforced by triggers/procedures because SQL FDs alone cannot express them.

## 4NF

Independent many-valued facts are separated: product variants are rows instead of product color/size lists; promotions have separate product/category bridges; seller stock is an `inventory` bridge. Thus no relation stores an independent multivalued attribute pair that would create a 4NF anomaly.
