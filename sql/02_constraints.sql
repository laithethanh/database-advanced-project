USE ecommerce_advanced;

ALTER TABLE product_variant
  ADD CONSTRAINT chk_variant_price_nonnegative CHECK (price >= 0),
  ADD CONSTRAINT chk_variant_compare_price CHECK (compare_at_price IS NULL OR compare_at_price >= price);

ALTER TABLE cart_item
  ADD CONSTRAINT chk_cart_item_quantity CHECK (quantity > 0);

ALTER TABLE cart
  ADD COLUMN active_customer_key BIGINT UNSIGNED
    GENERATED ALWAYS AS (CASE WHEN status = 'ACTIVE' THEN customer_id ELSE NULL END) STORED,
  ADD UNIQUE KEY uq_cart_one_active_per_customer (active_customer_key);

ALTER TABLE inventory
  ADD CONSTRAINT chk_inventory_values CHECK (quantity_on_hand >= reserved_quantity);

ALTER TABLE promotion
  ADD CONSTRAINT chk_promotion_window CHECK (start_at < end_at),
  ADD CONSTRAINT chk_promotion_discount CHECK (discount_value >= 0),
  ADD CONSTRAINT chk_promotion_min_order CHECK (min_order_amount >= 0),
  ADD CONSTRAINT chk_promotion_max_discount CHECK (max_discount IS NULL OR max_discount >= 0),
  ADD CONSTRAINT chk_promotion_percent CHECK (promotion_type <> 'PERCENT' OR discount_value <= 100);

ALTER TABLE order_item
  ADD CONSTRAINT chk_order_item_values CHECK (
    quantity > 0 AND unit_price >= 0 AND line_discount >= 0 AND line_total >= 0
  );

ALTER TABLE orders
  ADD CONSTRAINT chk_order_totals_nonnegative CHECK (
    subtotal >= 0 AND discount_total >= 0 AND shipping_fee >= 0 AND grand_total >= 0
  );

ALTER TABLE payment
  ADD CONSTRAINT chk_payment_amount CHECK (amount >= 0);

ALTER TABLE review
  ADD CONSTRAINT chk_review_rating CHECK (rating BETWEEN 1 AND 5);

-- Invariant cấp nhiều dòng phải được kiểm tra bằng trigger/procedure:
-- 1) Cart chỉ có tối đa một ACTIVE cart/customer.
-- 2) Order grand_total = subtotal - discount_total + shipping_fee.
-- 3) Review.order_item phải thuộc đúng customer/product và order DELIVERED.
-- 4) Order status transition phải hợp lệ.
-- 5) Category parent không tạo cycle.
-- 6) Seller phải ACTIVE mới được publish product.
-- 7) Checkout không được làm available stock âm.
