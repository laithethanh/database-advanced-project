USE ecommerce_advanced;

-- Migration: 10_fix_inventory_variant_promotion.sql
-- Purpose: remove duplicated stock column from product_variant (warehouse_quantity),
-- add promotion_usage table to track promotion redemptions (avoid race on promotion.used_count),
-- add optional orders.address_id to link to address while keeping snapshot fields.

START TRANSACTION;

-- 1) Drop product_variant.warehouse_quantity if it exists (safe, idempotent)
SET @sql = (
  SELECT IF(COUNT(*)>0,
    'ALTER TABLE product_variant DROP COLUMN warehouse_quantity',
    'SELECT 1')
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'product_variant'
    AND COLUMN_NAME = 'warehouse_quantity'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2) Add orders.address_id (nullable) to keep an optional FK to address while snapshot fields remain
SET @sql = (
  SELECT IF(COUNT(*)=0,
    'ALTER TABLE orders ADD COLUMN address_id BIGINT UNSIGNED NULL',
    'SELECT 1')
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'orders'
    AND COLUMN_NAME = 'address_id'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add FK for address_id if the column was just created and FK not exists
-- Note: Attempt to add FK only if both column and referenced table exist and FK not already present.
SET @fk_sql = (
  SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='orders' AND COLUMN_NAME='address_id')>0
    AND (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='address')>0
    AND (SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='orders' AND COLUMN_NAME='address_id' AND REFERENCED_TABLE_NAME='address')=0,
    'ALTER TABLE orders ADD CONSTRAINT fk_orders_address FOREIGN KEY (address_id) REFERENCES address(address_id)',
    'SELECT 1'
  )
);
PREPARE stmt2 FROM @fk_sql; EXECUTE stmt2; DEALLOCATE PREPARE stmt2;

-- 3) Create promotion_usage table to track individual redemptions (idempotent)
CREATE TABLE IF NOT EXISTS promotion_usage (
  promotion_usage_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  promotion_id BIGINT UNSIGNED NOT NULL,
  order_id BIGINT UNSIGNED NULL,
  customer_id BIGINT UNSIGNED NULL,
  discount_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
  coupon_code_snapshot VARCHAR(50),
  used_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_pu_promotion FOREIGN KEY (promotion_id) REFERENCES promotion(promotion_id) ON DELETE CASCADE,
  CONSTRAINT fk_pu_order FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE SET NULL,
  CONSTRAINT fk_pu_customer FOREIGN KEY (customer_id) REFERENCES customer(account_id) ON DELETE SET NULL,
  KEY idx_pu_promotion (promotion_id),
  KEY idx_pu_customer (customer_id)
) ENGINE=InnoDB;

-- 4) Add uniqueness/indexes/checks that are safe incremental changes
-- Ensure product_variant has expected unique constraint on (warehouse_id, product_id, color, size)
ALTER TABLE product_variant
  ADD CONSTRAINT IF NOT EXISTS uq_variant_warehouse_combination UNIQUE (warehouse_id, product_id, color, size);

-- Note: MySQL before 8.0 may not support IF NOT EXISTS for ADD CONSTRAINT; the ALTER above is safe in MySQL 8+. If it fails, please run the equivalent check manually.

COMMIT;

-- End migration
