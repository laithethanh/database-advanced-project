USE ecommerce_advanced;

WITH RECURSIVE category_tree AS (
  SELECT category_id, parent_category_id, name, 0 AS depth, CAST(name AS CHAR(2000)) AS path
  FROM category
  WHERE parent_category_id IS NULL
  UNION ALL
  SELECT c.category_id, c.parent_category_id, c.name,
         ct.depth + 1,
         CONCAT(ct.path, ' > ', c.name)
  FROM category c
  JOIN category_tree ct ON c.parent_category_id = ct.category_id
)
SELECT * FROM category_tree ORDER BY path;

-- Query subtree revenue sẽ join category_tree với product/product_variant/order_item/orders
-- và aggregate theo root category.
