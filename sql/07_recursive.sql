-- Q18-Q20: recursive category analyses. MySQL 8.0+.
USE ecommerce_advanced;

-- Q18. Traverse the complete category forest; path is stable and human-readable.
WITH RECURSIVE category_tree AS (
 SELECT category_id,parent_category_id,name,0 AS depth,CAST(LPAD(category_id,20,'0') AS CHAR(2000)) AS sort_path,
        CAST(name AS CHAR(2000)) AS display_path
 FROM category WHERE parent_category_id IS NULL
 UNION ALL
 SELECT c.category_id,c.parent_category_id,c.name,ct.depth+1,
        CONCAT(ct.sort_path,'/',LPAD(c.category_id,20,'0')),CONCAT(ct.display_path,' > ',c.name)
 FROM category c JOIN category_tree ct ON c.parent_category_id=ct.category_id
) SELECT category_id,parent_category_id,name,depth,display_path FROM category_tree ORDER BY sort_path;

-- Q19. Revenue of every category subtree. It reports 0 for branches with no paid-or-later sales.
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
) SELECT c.category_id,c.name,sr.recognized_revenue FROM category c JOIN subtree_revenue sr ON sr.root_category_id=c.category_id
ORDER BY sr.recognized_revenue DESC,c.category_id;

-- Q20. Ancestor path/depth for one category, useful for breadcrumb navigation.
SET @leaf_category_id := 1;
WITH RECURSIVE ancestors AS (
 SELECT category_id,parent_category_id,name,0 AS distance_from_leaf,CAST(name AS CHAR(2000)) AS path_from_leaf
 FROM category WHERE category_id=@leaf_category_id
 UNION ALL
 SELECT c.category_id,c.parent_category_id,c.name,a.distance_from_leaf+1,CONCAT(a.path_from_leaf,' < ',c.name)
 FROM category c JOIN ancestors a ON a.parent_category_id=c.category_id
) SELECT category_id,name,distance_from_leaf,path_from_leaf FROM ancestors ORDER BY distance_from_leaf DESC;

-- Safety audit: category-cycle trigger should guarantee this returns no rows.
WITH RECURSIVE walk AS (
 SELECT category_id,parent_category_id,CAST(CONCAT(',',category_id,',') AS CHAR(2000)) AS visited,0 AS has_cycle FROM category
 UNION ALL
 SELECT w.category_id,c.parent_category_id,CONCAT(w.visited,c.category_id,','),FIND_IN_SET(c.category_id,TRIM(BOTH ',' FROM w.visited))>0
 FROM walk w JOIN category c ON c.category_id=w.parent_category_id WHERE w.has_cycle=0
) SELECT DISTINCT category_id AS cycle_start FROM walk WHERE has_cycle=1;
