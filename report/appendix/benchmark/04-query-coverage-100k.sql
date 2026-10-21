-- Kiem tra R09: Q06/Q09/Q22/Q24 co du lieu kiem chung tren bo du lieu 100.000 don
SELECT 'Q06_low_stock_skus' AS query_name, COUNT(*) AS rows_returned FROM (
  SELECT v.sku FROM inventory i JOIN product_variant v ON v.variant_id=i.variant_id
  JOIN seller s ON s.account_id=i.seller_id
  WHERE s.shop_status='ACTIVE' AND v.status='ACTIVE'
    AND (i.quantity_on_hand-i.reserved_quantity)<=i.reorder_level
) t;

SELECT 'Q09_reviewed_customers' AS query_name, COUNT(*) AS rows_returned FROM (
  SELECT DISTINCT c.customer_code,a.full_name,p.product_id,p.name FROM customer c JOIN account a ON a.account_id=c.account_id
  JOIN review r ON r.customer_id=c.account_id JOIN product p ON p.product_id=r.product_id
  WHERE EXISTS (SELECT 1 FROM orders o JOIN order_item oi ON oi.order_id=o.order_id JOIN product_variant v ON v.variant_id=oi.variant_id
   WHERE o.customer_id=c.account_id AND v.product_id=p.product_id AND o.status='DELIVERED')
) t;

SELECT 'Q22_return_rate' AS query_name, COUNT(*) AS rows_returned FROM (
  SELECT c.account_id,c.customer_code,COUNT(o.order_id) AS total_orders,SUM(o.status='RETURNED') AS returned_orders,AVG(o.status='RETURNED') AS return_rate
  FROM customer c JOIN orders o ON o.customer_id=c.account_id WHERE o.status IN ('DELIVERED','RETURN_REQUESTED','RETURNED')
  GROUP BY c.account_id,c.customer_code HAVING AVG(o.status='RETURNED')>0.20
) t;

SELECT 'Q24_low_stock_products' AS query_name, COUNT(*) AS rows_returned FROM (
  SELECT p.product_id,p.name,COUNT(DISTINCT v.variant_id) AS variant_count,COALESCE(SUM(i.quantity_on_hand-i.reserved_quantity),0) AS available_stock
  FROM product p JOIN product_variant v ON v.product_id=p.product_id LEFT JOIN inventory i ON i.variant_id=v.variant_id
  GROUP BY p.product_id,p.name HAVING COUNT(DISTINCT v.variant_id)>1 AND COALESCE(SUM(i.quantity_on_hand-i.reserved_quantity),0)<=10
) t;

SELECT 'Q15_dense_rank_sellers' AS query_name, COUNT(*) AS rows_returned FROM (
  SELECT s.account_id,s.shop_name,SUM(oi.line_total) AS revenue,DENSE_RANK() OVER (ORDER BY SUM(oi.line_total) DESC) AS seller_rank
  FROM seller s JOIN order_item oi ON oi.seller_id=s.account_id JOIN orders o ON o.order_id=oi.order_id
  WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') GROUP BY s.account_id,s.shop_name
) t;

SELECT 'Q19_subtree_revenue' AS query_name, COUNT(*) AS rows_returned FROM (
  SELECT c.category_id,c.name,sr.recognized_revenue FROM category c JOIN (
    WITH RECURSIVE closure_tree AS (
      SELECT category_id AS root_category_id,category_id AS descendant_category_id FROM category
      UNION ALL
      SELECT ct.root_category_id,c.category_id FROM closure_tree ct JOIN category c ON c.parent_category_id=ct.descendant_category_id
    ), subtree_revenue AS (
      SELECT ct.root_category_id,COALESCE(SUM(CASE WHEN o.order_id IS NOT NULL THEN oi.line_total ELSE 0 END),0) AS recognized_revenue
      FROM closure_tree ct LEFT JOIN product p ON p.category_id=ct.descendant_category_id
      LEFT JOIN product_variant v ON v.product_id=p.product_id LEFT JOIN order_item oi ON oi.variant_id=v.variant_id
      LEFT JOIN orders o ON o.order_id=oi.order_id AND o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED')
      GROUP BY ct.root_category_id
    ) SELECT root_category_id,recognized_revenue FROM subtree_revenue
  ) sr ON sr.root_category_id=c.category_id
) t;
