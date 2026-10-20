USE ecommerce_advanced;

-- Văn bản nghiệp vụ không được để trống. Chỉ dùng NOT NULL vẫn cho phép chuỗi rỗng.
ALTER TABLE account
  ADD CONSTRAINT chk_account_email_not_blank CHECK (CHAR_LENGTH(TRIM(email)) > 0);

ALTER TABLE seller
  ADD CONSTRAINT chk_seller_shop_name_not_blank CHECK (CHAR_LENGTH(TRIM(shop_name)) > 0);

ALTER TABLE category
  ADD CONSTRAINT chk_category_name_not_blank CHECK (CHAR_LENGTH(TRIM(name)) > 0);

ALTER TABLE product
  ADD CONSTRAINT chk_product_name_not_blank CHECK (CHAR_LENGTH(TRIM(name)) > 0);

ALTER TABLE product_variant
  ADD CONSTRAINT chk_variant_price_nonnegative CHECK (price >= 0),
  ADD CONSTRAINT chk_variant_compare_price CHECK (compare_at_price IS NULL OR compare_at_price >= price);

ALTER TABLE cart_item
  ADD CONSTRAINT chk_cart_item_quantity CHECK (quantity > 0);

ALTER TABLE cart
  ADD COLUMN active_customer_key BIGINT UNSIGNED
    GENERATED ALWAYS AS (CASE WHEN status = 'ACTIVE' THEN customer_id ELSE NULL END) STORED,
  ADD UNIQUE KEY uq_cart_one_active_per_customer (active_customer_key);

-- UNIQUE của MySQL cho phép nhiều giá trị NULL, nhờ đó mỗi khách hàng có thể có một địa chỉ mặc định.
ALTER TABLE address
  ADD COLUMN default_customer_key BIGINT UNSIGNED
    GENERATED ALWAYS AS (CASE WHEN is_default THEN customer_id ELSE NULL END) STORED,
  ADD UNIQUE KEY uq_address_one_default_per_customer (default_customer_key);

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
    AND line_discount <= quantity * unit_price
  );

-- Mỗi dòng order_promotion là một mã đã áp dụng; tổng các dòng phải bằng orders.discount_total
-- và không vượt subtotal (được bảo đảm bởi trigger trong 05_triggers.sql).
ALTER TABLE order_promotion
  ADD CONSTRAINT chk_order_promotion_discount_nonnegative CHECK (discount_amount >= 0);

ALTER TABLE orders
  ADD CONSTRAINT chk_order_totals_nonnegative CHECK (
    subtotal >= 0 AND discount_total >= 0 AND shipping_fee >= 0 AND grand_total >= 0
  ),
  ADD CONSTRAINT chk_order_discount_not_over_subtotal CHECK (discount_total <= subtotal);

ALTER TABLE payment
  ADD CONSTRAINT chk_payment_amount CHECK (amount >= 0);

ALTER TABLE review
  ADD CONSTRAINT chk_review_rating CHECK (rating BETWEEN 1 AND 5);

-- Các bất biến liên quan nhiều dòng phải được kiểm tra bằng trigger/thủ tục:
-- 1) Mỗi khách hàng chỉ có tối đa một giỏ hàng ACTIVE.
-- 2) Tổng đơn hàng = tiền hàng - tiền giảm giá + phí vận chuyển.
-- 3) order_item của đánh giá phải thuộc đúng khách hàng/sản phẩm và đơn hàng đã DELIVERED.
-- 4) Chuyển trạng thái đơn hàng phải hợp lệ.
-- 5) Category parent không tạo cycle.
-- 6) Người bán phải ở trạng thái ACTIVE mới được bán biến thể thông qua inventory/giỏ hàng.
-- 7) Thanh toán không được làm số lượng hàng khả dụng âm.
-- 8) Tổng discount của order_promotion không vượt subtotal và bằng orders.discount_total.
