-- Q18–Q20: phân tích danh mục đệ quy. Yêu cầu MySQL 8.0 trở lên.
USE ecommerce_advanced;

-- Q18. Duyệt toàn bộ rừng danh mục; đường dẫn ổn định và dễ đọc.
WITH RECURSIVE category_tree AS (
 SELECT category_id,parent_category_id,name,0 AS depth,CAST(LPAD(category_id,20,'0') AS CHAR(2000)) AS sort_path,
        CAST(name AS CHAR(2000)) AS display_path
 FROM category WHERE parent_category_id IS NULL
 UNION ALL
 SELECT c.category_id,c.parent_category_id,c.name,ct.depth+1,
        CONCAT(ct.sort_path,'/',LPAD(c.category_id,20,'0')),CONCAT(ct.display_path,' > ',c.name)
 FROM category c JOIN category_tree ct ON c.parent_category_id=ct.category_id
) SELECT category_id,parent_category_id,name,depth,display_path FROM category_tree ORDER BY sort_path;

-- Q19. Doanh thu của cây con thuộc từng danh mục. Nhánh chưa có đơn đã thanh toán trở đi sẽ có doanh thu bằng 0.
-- Chi phí: closure (root × descendant) nhân với số dòng order_item, nên trên dữ liệu 100.000 đơn
-- truy vấn này khá nặng; dùng để minh họa kỹ thuật, không dùng làm truy vấn dashboard.
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

-- Q20. Đường dẫn/độ sâu từ một danh mục lên các danh mục tổ tiên, hữu ích cho điều hướng breadcrumb.
SET @leaf_category_id := (SELECT category_id FROM category WHERE slug='dien-tu' LIMIT 1);
WITH RECURSIVE ancestors AS (
 SELECT category_id,parent_category_id,name,0 AS distance_from_leaf,CAST(name AS CHAR(2000)) AS path_from_leaf
 FROM category WHERE category_id=@leaf_category_id
 UNION ALL
 SELECT c.category_id,c.parent_category_id,c.name,a.distance_from_leaf+1,CONCAT(a.path_from_leaf,' < ',c.name)
 FROM category c JOIN ancestors a ON a.parent_category_id=c.category_id
) SELECT category_id,name,distance_from_leaf,path_from_leaf FROM ancestors ORDER BY distance_from_leaf DESC;

-- Kiểm tra an toàn: trigger chống chu trình danh mục phải bảo đảm truy vấn này không trả về dòng nào.
WITH RECURSIVE walk AS (
 SELECT category_id,parent_category_id,CAST(CONCAT(',',category_id,',') AS CHAR(2000)) AS visited,0 AS has_cycle FROM category
 UNION ALL
 SELECT w.category_id,c.parent_category_id,CONCAT(w.visited,c.category_id,','),FIND_IN_SET(c.category_id,TRIM(BOTH ',' FROM w.visited))>0
 FROM walk w JOIN category c ON c.category_id=w.parent_category_id WHERE w.has_cycle=0
) SELECT DISTINCT category_id AS cycle_start FROM walk WHERE has_cycle=1;
