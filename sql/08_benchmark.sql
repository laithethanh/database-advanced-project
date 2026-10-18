-- Benchmark-only experiment. Do NOT run this on the canonical schema database:
-- it adds/removes experimental indexes. Capture each EXPLAIN ANALYZE output.
USE ecommerce_advanced;

-- Record cardinality and server version in data/benchmark/<run>/metadata.md.
SELECT VERSION() AS mysql_version,@@version_comment AS server_comment,@@transaction_isolation AS isolation_level;
SELECT COUNT(*) AS orders_count FROM orders;
SELECT COUNT(*) AS order_items_count FROM order_item;

-- Baseline Q01: execute three warm repetitions, then prefix this SELECT with EXPLAIN ANALYZE.
SELECT p.product_id,p.name,SUM(oi.line_total) AS revenue
FROM orders o JOIN order_item oi ON oi.order_id=o.order_id JOIN product_variant v ON v.variant_id=oi.variant_id JOIN product p ON p.product_id=v.product_id
WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') GROUP BY p.product_id,p.name ORDER BY revenue DESC LIMIT 10;

-- Baseline Q21A: top sellers in a date range. Change boundaries but keep them identical between runs.
SET @from_at := '2025-01-01 00:00:00'; SET @to_at := '2026-01-01 00:00:00';
SELECT oi.seller_id,SUM(oi.line_total) AS revenue FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') AND o.created_at>=@from_at AND o.created_at<@to_at
GROUP BY oi.seller_id ORDER BY revenue DESC LIMIT 10;

-- Baseline Q06: low-stock lookup.
SELECT i.seller_id,i.variant_id,i.quantity_on_hand,i.reserved_quantity,i.reorder_level FROM inventory i
WHERE i.quantity_on_hand-i.reserved_quantity<=i.reorder_level;

-- Experimental indexes (idempotence is intentionally not hidden: inspect SHOW INDEX first).
-- CREATE INDEX idx_order_item_order_seller_total ON order_item(order_id,seller_id,line_total);
-- CREATE INDEX idx_inventory_reorder_lookup ON inventory(seller_id,variant_id,quantity_on_hand,reserved_quantity,reorder_level);
-- CREATE INDEX idx_product_variant_product_price ON product_variant(product_id,status,price);

-- Repeat exactly the baseline queries, prefixing each with EXPLAIN ANALYZE.
-- Measure write cost separately on a COPY of the database, not on the reporting run:
--   time an INSERT of 10,000 order_item rows before and after each candidate index;
--   record INFORMATION_SCHEMA.TABLES.DATA_LENGTH + INDEX_LENGTH before/after.
-- Roll back experimental schema manually after collecting evidence:
-- DROP INDEX idx_order_item_order_seller_total ON order_item;
-- DROP INDEX idx_inventory_reorder_lookup ON inventory;
-- DROP INDEX idx_product_variant_product_price ON product_variant;
