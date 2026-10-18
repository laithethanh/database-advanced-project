-- Proposed full schema replacing migration: sql/10_fix_inventory_variant_promotion.sql
-- This file now contains the full, corrected schema for the project (MySQL 8+).
-- Database: ecommerce_advanced_proposed
-- Purpose: a ready-to-run schema that aligns ERD, business rules and fixes inventory/promotion duplication.

CREATE DATABASE IF NOT EXISTS ecommerce_advanced_proposed CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE ecommerce_advanced_proposed;

-- ACCOUNT
CREATE TABLE account (
  account_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(150) NOT NULL,
  phone VARCHAR(30),
  status ENUM('ACTIVE','BLOCKED','DELETED') NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- CUSTOMER (subtype)
CREATE TABLE customer (
  account_id BIGINT UNSIGNED PRIMARY KEY,
  customer_code VARCHAR(40) NOT NULL UNIQUE,
  FOREIGN KEY (account_id) REFERENCES account(account_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- SELLER (subtype)
CREATE TABLE seller (
  account_id BIGINT UNSIGNED PRIMARY KEY,
  seller_code VARCHAR(40) NOT NULL UNIQUE,
  shop_name VARCHAR(150) NOT NULL UNIQUE,
  shop_status ENUM('PENDING','ACTIVE','SUSPENDED','CLOSED') NOT NULL DEFAULT 'PENDING',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (account_id) REFERENCES account(account_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ADDRESS
CREATE TABLE address (
  address_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  customer_id BIGINT UNSIGNED NOT NULL,
  recipient_name VARCHAR(150) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  line1 VARCHAR(255) NOT NULL,
  ward VARCHAR(100), district VARCHAR(100), city VARCHAR(100) NOT NULL, province VARCHAR(100) NOT NULL,
  postal_code VARCHAR(20), is_default BOOLEAN NOT NULL DEFAULT FALSE,
  FOREIGN KEY (customer_id) REFERENCES customer(account_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- CATEGORY (adjacency list)
CREATE TABLE category (
  category_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  parent_category_id BIGINT UNSIGNED NULL,
  name VARCHAR(150) NOT NULL,
  slug VARCHAR(180) NOT NULL UNIQUE,
  status ENUM('ACTIVE','INACTIVE') NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (parent_category_id) REFERENCES category(category_id)
) ENGINE=InnoDB;

-- PRODUCT
CREATE TABLE product (
  product_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  seller_id BIGINT UNSIGNED NOT NULL,
  category_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(180) NOT NULL UNIQUE,
  description TEXT,
  brand VARCHAR(120),
  status ENUM('DRAFT','ACTIVE','INACTIVE','ARCHIVED') NOT NULL DEFAULT 'DRAFT',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (seller_id) REFERENCES seller(account_id),
  FOREIGN KEY (category_id) REFERENCES category(category_id),
  KEY idx_product_seller (seller_id),
  KEY idx_product_category_status (category_id, status)
) ENGINE=InnoDB;

-- WAREHOUSE
CREATE TABLE warehouse (
  warehouse_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(40) NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL,
  address_text VARCHAR(500),
  status ENUM('ACTIVE','INACTIVE') NOT NULL DEFAULT 'ACTIVE'
) ENGINE=InnoDB;

-- PRODUCT_VARIANT: metadata only (no stock quantity here)
CREATE TABLE product_variant (
  variant_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  warehouse_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  sku VARCHAR(100) NOT NULL UNIQUE,
  color VARCHAR(60) NOT NULL DEFAULT '',
  size VARCHAR(60) NOT NULL DEFAULT '',
  price DECIMAL(15,2) NOT NULL CHECK (price >= 0),
  compare_at_price DECIMAL(15,2) NULL CHECK (compare_at_price IS NULL OR compare_at_price >= price),
  status ENUM('ACTIVE','INACTIVE','ARCHIVED') NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_variant_warehouse_combination (warehouse_id, product_id, color, size),
  FOREIGN KEY (warehouse_id) REFERENCES warehouse(warehouse_id),
  FOREIGN KEY (product_id) REFERENCES product(product_id),
  KEY idx_variant_product_status (product_id, status)
) ENGINE=InnoDB;

-- INVENTORY: single source of truth for stock; supports seller + warehouse + variant
CREATE TABLE inventory (
  inventory_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  seller_id BIGINT UNSIGNED NOT NULL,
  warehouse_id BIGINT UNSIGNED NOT NULL,
  variant_id BIGINT UNSIGNED NOT NULL,
  quantity_on_hand INT UNSIGNED NOT NULL DEFAULT 0,
  reserved_quantity INT UNSIGNED NOT NULL DEFAULT 0,
  reorder_level INT UNSIGNED NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_inventory_seller_warehouse_variant (seller_id, warehouse_id, variant_id),
  FOREIGN KEY (seller_id) REFERENCES seller(account_id),
  FOREIGN KEY (warehouse_id) REFERENCES warehouse(warehouse_id),
  FOREIGN KEY (variant_id) REFERENCES product_variant(variant_id),
  CHECK (quantity_on_hand >= reserved_quantity)
) ENGINE=InnoDB;

-- CART (one active cart per customer enforced by application or partial unique index)
CREATE TABLE cart (
  cart_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  customer_id BIGINT UNSIGNED NOT NULL,
  status ENUM('ACTIVE','CHECKED_OUT','ABANDONED') NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customer(account_id),
  KEY idx_cart_customer_status (customer_id, status)
) ENGINE=InnoDB;

-- CART_ITEM: surrogate PK for easier referencing, unique constraint per variant in a cart
CREATE TABLE cart_item (
  cart_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cart_id BIGINT UNSIGNED NOT NULL,
  seller_id BIGINT UNSIGNED NOT NULL,
  variant_id BIGINT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL CHECK (quantity > 0),
  added_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_cart_item_unique (cart_id, seller_id, variant_id),
  FOREIGN KEY (cart_id) REFERENCES cart(cart_id) ON DELETE CASCADE,
  FOREIGN KEY (seller_id, variant_id) REFERENCES inventory(seller_id, variant_id)
) ENGINE=InnoDB;

-- PROMOTION
CREATE TABLE promotion (
  promotion_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) UNIQUE,
  name VARCHAR(150) NOT NULL,
  promotion_type ENUM('PERCENT','FIXED') NOT NULL,
  discount_value DECIMAL(15,2) NOT NULL CHECK (discount_value >= 0),
  min_order_amount DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (min_order_amount >= 0),
  max_discount DECIMAL(15,2) NULL CHECK (max_discount IS NULL OR max_discount >= 0),
  start_at DATETIME NOT NULL,
  end_at DATETIME NOT NULL,
  status ENUM('DRAFT','ACTIVE','INACTIVE','EXPIRED') NOT NULL DEFAULT 'DRAFT',
  usage_limit INT UNSIGNED NULL,
  used_count INT UNSIGNED NOT NULL DEFAULT 0,
  CHECK (start_at < end_at),
  CHECK (promotion_type <> 'PERCENT' OR discount_value <= 100)
) ENGINE=InnoDB;

CREATE TABLE promotion_product (
  promotion_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (promotion_id, product_id),
  FOREIGN KEY (promotion_id) REFERENCES promotion(promotion_id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES product(product_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE promotion_category (
  promotion_id BIGINT UNSIGNED NOT NULL,
  category_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (promotion_id, category_id),
  FOREIGN KEY (promotion_id) REFERENCES promotion(promotion_id) ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES category(category_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Promotion usage log to avoid race conditions on used_count and for auditing
CREATE TABLE promotion_usage (
  promotion_usage_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  promotion_id BIGINT UNSIGNED NOT NULL,
  order_id BIGINT UNSIGNED NULL,
  customer_id BIGINT UNSIGNED NULL,
  discount_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
  coupon_code_snapshot VARCHAR(50),
  used_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (promotion_id) REFERENCES promotion(promotion_id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE SET NULL,
  FOREIGN KEY (customer_id) REFERENCES customer(account_id) ON DELETE SET NULL,
  KEY idx_pu_promotion (promotion_id),
  KEY idx_pu_customer (customer_id)
) ENGINE=InnoDB;

-- ORDERS with address_id FK + snapshot fields
CREATE TABLE orders (
  order_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_number VARCHAR(60) NOT NULL UNIQUE,
  customer_id BIGINT UNSIGNED NOT NULL,
  status ENUM('PENDING_PAYMENT','PAID','PROCESSING','SHIPPED','DELIVERED','CANCELLED','RETURN_REQUESTED','RETURNED') NOT NULL DEFAULT 'PENDING_PAYMENT',
  address_id BIGINT UNSIGNED NULL,
  recipient_name VARCHAR(150) NOT NULL,
  recipient_phone VARCHAR(30) NOT NULL,
  shipping_address VARCHAR(600) NOT NULL,
  subtotal DECIMAL(15,2) NOT NULL DEFAULT 0,
  discount_total DECIMAL(15,2) NOT NULL DEFAULT 0,
  shipping_fee DECIMAL(15,2) NOT NULL DEFAULT 0,
  grand_total DECIMAL(15,2) NOT NULL DEFAULT 0,
  placed_at DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customer(account_id),
  FOREIGN KEY (address_id) REFERENCES address(address_id),
  KEY idx_order_customer_created (customer_id, created_at),
  KEY idx_order_status_created (status, created_at),
  CHECK (grand_total >= 0)
) ENGINE=InnoDB;

-- ORDER_ITEM: snapshot price and product info
CREATE TABLE order_item (
  order_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  seller_id BIGINT UNSIGNED NOT NULL,
  variant_id BIGINT UNSIGNED NOT NULL,
  product_name_snapshot VARCHAR(255) NOT NULL,
  sku_snapshot VARCHAR(100) NOT NULL,
  unit_price DECIMAL(15,2) NOT NULL CHECK (unit_price >= 0),
  quantity INT UNSIGNED NOT NULL CHECK (quantity > 0),
  line_discount DECIMAL(15,2) NOT NULL DEFAULT 0,
  line_total DECIMAL(15,2) NOT NULL,
  UNIQUE KEY uq_order_seller_variant (order_id, seller_id, variant_id),
  FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE RESTRICT,
  FOREIGN KEY (seller_id, variant_id) REFERENCES inventory(seller_id, variant_id)
) ENGINE=InnoDB;

-- ORDER_PROMOTION: store snapshot of promotion applied
CREATE TABLE order_promotion (
  order_promotion_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  promotion_id BIGINT UNSIGNED NOT NULL,
  discount_amount DECIMAL(15,2) NOT NULL,
  promotion_code_snapshot VARCHAR(50),
  FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
  FOREIGN KEY (promotion_id) REFERENCES promotion(promotion_id),
  UNIQUE KEY uq_order_promotion (order_id, promotion_id)
) ENGINE=InnoDB;

-- PAYMENT
CREATE TABLE payment (
  payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  provider VARCHAR(50) NOT NULL,
  transaction_ref VARCHAR(120) UNIQUE,
  amount DECIMAL(15,2) NOT NULL,
  status ENUM('PENDING','SUCCESS','FAILED','REFUNDED') NOT NULL DEFAULT 'PENDING',
  paid_at DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- SHIPMENT
CREATE TABLE shipment (
  shipment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  carrier VARCHAR(80) NOT NULL,
  tracking_number VARCHAR(120) UNIQUE,
  status ENUM('PENDING','SHIPPED','IN_TRANSIT','DELIVERED','RETURNED') NOT NULL DEFAULT 'PENDING',
  shipped_at DATETIME,
  delivered_at DATETIME,
  FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- REVIEW
CREATE TABLE review (
  review_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT UNSIGNED NOT NULL,
  customer_id BIGINT UNSIGNED NOT NULL,
  order_item_id BIGINT UNSIGNED NOT NULL,
  rating TINYINT UNSIGNED NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title VARCHAR(200),
  body TEXT,
  status ENUM('PUBLISHED','HIDDEN','PENDING') NOT NULL DEFAULT 'PUBLISHED',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_review_customer_product (customer_id, product_id),
  FOREIGN KEY (product_id) REFERENCES product(product_id),
  FOREIGN KEY (customer_id) REFERENCES customer(account_id),
  FOREIGN KEY (order_item_id) REFERENCES order_item(order_item_id)
) ENGINE=InnoDB;

-- Useful indexes
CREATE INDEX idx_inventory_variant ON inventory(variant_id);
CREATE INDEX idx_product_sku ON product_variant(sku);

-- End of proposed schema
