-- Danh mục truy vấn nâng cao cho MySQL 8.0+. Chạy sau lược đồ, ràng buộc,
-- dữ liệu mẫu, hàm và trigger. Mỗi truy vấn Qxx có thể chạy độc lập.
USE ecommerce_advanced;

-- Q01. Top 10 sản phẩm theo doanh thu được ghi nhận (GROUP BY + xếp hạng cửa sổ).
WITH product_sales AS (
  SELECT p.product_id, p.name, SUM(oi.line_total) AS revenue
  FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
  JOIN product_variant v ON v.variant_id=oi.variant_id JOIN product p ON p.product_id=v.product_id
  WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') GROUP BY p.product_id,p.name
) SELECT product_id,name,revenue,DENSE_RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM product_sales ORDER BY revenue DESC,product_id LIMIT 10;

-- Q02. Doanh thu và số lượng đơn hàng của từng người bán.
SELECT s.account_id AS seller_id,s.shop_name,COUNT(DISTINCT o.order_id) AS order_count,
 COALESCE(SUM(CASE WHEN o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') THEN oi.line_total END),0) AS revenue
FROM seller s LEFT JOIN order_item oi ON oi.seller_id=s.account_id LEFT JOIN orders o ON o.order_id=oi.order_id
GROUP BY s.account_id,s.shop_name ORDER BY revenue DESC;

-- Q03. Người bán đang hoạt động nhưng chưa từng bán mặt hàng nào (nối ngoài).
SELECT s.account_id,s.seller_code,s.shop_name FROM seller s LEFT JOIN order_item oi ON oi.seller_id=s.account_id
WHERE s.shop_status='ACTIVE' GROUP BY s.account_id,s.seller_code,s.shop_name HAVING COUNT(oi.order_item_id)=0;

-- Q04. Khách hàng chưa từng có đơn hàng từ trạng thái đã thanh toán trở đi (NOT EXISTS).
SELECT c.account_id,c.customer_code,a.full_name FROM customer c JOIN account a ON a.account_id=c.account_id
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id=c.account_id AND o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED'));

-- Q05. SKU đang hoạt động chưa từng xuất hiện trong đơn hàng (NOT EXISTS).
SELECT v.variant_id,v.sku,p.name,v.price FROM product_variant v JOIN product p ON p.product_id=v.product_id
WHERE v.status='ACTIVE' AND NOT EXISTS (SELECT 1 FROM order_item oi WHERE oi.variant_id=v.variant_id);

-- Q06. Tồn kho SKU của người bán bằng hoặc thấp hơn ngưỡng bổ sung hàng.
SELECT s.shop_name,v.sku,i.quantity_on_hand,i.reserved_quantity,i.reorder_level,i.quantity_on_hand-i.reserved_quantity AS available_quantity
FROM inventory i JOIN seller s ON s.account_id=i.seller_id JOIN product_variant v ON v.variant_id=i.variant_id
WHERE i.quantity_on_hand-i.reserved_quantity<=i.reorder_level ORDER BY available_quantity,s.shop_name;

-- Q07. Khách hàng đã mua ít nhất @min_skus SKU khác nhau (HAVING).
SET @min_skus := 3;
SELECT c.account_id,c.customer_code,COUNT(DISTINCT oi.variant_id) AS distinct_skus
FROM customer c JOIN orders o ON o.customer_id=c.account_id JOIN order_item oi ON oi.order_id=o.order_id
WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') GROUP BY c.account_id,c.customer_code
HAVING COUNT(DISTINCT oi.variant_id)>=@min_skus ORDER BY distinct_skus DESC;

-- Q08. SKU có giá cao hơn mức trung bình của danh mục (truy vấn con tương quan).
SELECT p.name,v.sku,v.price,c.name AS category_name FROM product p JOIN product_variant v ON v.product_id=p.product_id
JOIN category c ON c.category_id=p.category_id WHERE v.status='ACTIVE' AND v.price > (
 SELECT AVG(v2.price) FROM product p2 JOIN product_variant v2 ON v2.product_id=p2.product_id
 WHERE p2.category_id=p.category_id AND v2.status='ACTIVE') ORDER BY c.name,v.price DESC;

-- Q09. Khách hàng vừa mua vừa đánh giá sản phẩm (EXISTS).
SELECT DISTINCT c.customer_code,a.full_name,p.product_id,p.name FROM customer c JOIN account a ON a.account_id=c.account_id
JOIN review r ON r.customer_id=c.account_id JOIN product p ON p.product_id=r.product_id
WHERE EXISTS (SELECT 1 FROM orders o JOIN order_item oi ON oi.order_id=o.order_id JOIN product_variant v ON v.variant_id=oi.variant_id
 WHERE o.customer_id=c.account_id AND v.product_id=p.product_id AND o.status='DELIVERED');

-- Q10. Người bán không bán SKU nào thuộc cây con danh mục được yêu cầu.
SET @category_root := 1;
WITH RECURSIVE category_scope AS (
 SELECT category_id FROM category WHERE category_id=@category_root UNION ALL
 SELECT c.category_id FROM category c JOIN category_scope cs ON c.parent_category_id=cs.category_id
) SELECT s.account_id,s.shop_name FROM seller s WHERE s.shop_status='ACTIVE' AND NOT EXISTS (
 SELECT 1 FROM inventory i JOIN product_variant v ON v.variant_id=i.variant_id JOIN product p ON p.product_id=v.product_id
 JOIN category_scope cs ON cs.category_id=p.category_id WHERE i.seller_id=s.account_id);

-- Q11. Phép chia quan hệ: khách hàng đã mua mọi SKU đang hoạt động của @brand_name.
SET @brand_name := 'Demo';
SELECT c.account_id,c.customer_code FROM customer c WHERE NOT EXISTS (
 SELECT 1 FROM product p JOIN product_variant v ON v.product_id=p.product_id
 WHERE p.brand=@brand_name AND p.status='ACTIVE' AND v.status='ACTIVE' AND NOT EXISTS (
  SELECT 1 FROM orders o JOIN order_item oi ON oi.order_id=o.order_id WHERE o.customer_id=c.account_id
  AND oi.variant_id=v.variant_id AND o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED')));

-- Q12. Người bán đạt ngưỡng doanh thu (GROUP BY/HAVING).
SET @revenue_threshold := 1000000;
SELECT s.account_id,s.shop_name,SUM(oi.line_total) AS revenue FROM seller s JOIN order_item oi ON oi.seller_id=s.account_id
JOIN orders o ON o.order_id=oi.order_id WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED')
GROUP BY s.account_id,s.shop_name HAVING SUM(oi.line_total)>=@revenue_threshold ORDER BY revenue DESC;

-- Q13. Danh mục đang hoạt động nhưng không có sản phẩm trực tiếp (nối ngoài).
SELECT c.category_id,c.name,c.slug FROM category c LEFT JOIN product p ON p.category_id=c.category_id WHERE c.status='ACTIVE'
GROUP BY c.category_id,c.name,c.slug HAVING COUNT(p.product_id)=0;

-- Q14. Ba SKU có doanh thu cao nhất trong mỗi danh mục (ROW_NUMBER).
WITH sku_sales AS (
 SELECT p.category_id,c.name AS category_name,v.variant_id,v.sku,COALESCE(SUM(CASE WHEN o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') THEN oi.line_total END),0) AS revenue
 FROM product p JOIN category c ON c.category_id=p.category_id JOIN product_variant v ON v.product_id=p.product_id
 LEFT JOIN order_item oi ON oi.variant_id=v.variant_id LEFT JOIN orders o ON o.order_id=oi.order_id GROUP BY p.category_id,c.name,v.variant_id,v.sku
), ranked AS (SELECT *,ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY revenue DESC,variant_id) AS rn FROM sku_sales)
SELECT category_name,sku,revenue,rn FROM ranked WHERE rn<=3 ORDER BY category_name,rn;

-- Q15. Xếp hạng doanh thu người bán (DENSE_RANK).
WITH seller_sales AS (
 SELECT s.account_id,s.shop_name,COALESCE(SUM(CASE WHEN o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') THEN oi.line_total END),0) AS revenue
 FROM seller s LEFT JOIN order_item oi ON oi.seller_id=s.account_id LEFT JOIN orders o ON o.order_id=oi.order_id GROUP BY s.account_id,s.shop_name
) SELECT *,DENSE_RANK() OVER (ORDER BY revenue DESC) AS seller_rank FROM seller_sales ORDER BY seller_rank,account_id;

-- Q16. Doanh thu theo tháng và mức thay đổi so với tháng trước (CTE + LAG).
WITH monthly_sales AS (
 SELECT DATE_FORMAT(o.created_at,'%Y-%m-01') AS month_start,SUM(oi.line_total) AS revenue FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
 WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') GROUP BY DATE_FORMAT(o.created_at,'%Y-%m-01')
) SELECT month_start,revenue,revenue-LAG(revenue) OVER (ORDER BY month_start) AS revenue_change FROM monthly_sales ORDER BY month_start;

-- Q17. Doanh số theo ngày và tổng doanh số trượt 30 ngày (khung cửa sổ).
WITH daily_sales AS (
 SELECT DATE(o.created_at) AS sales_day,SUM(oi.line_total) AS revenue FROM orders o JOIN order_item oi ON oi.order_id=o.order_id
 WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') GROUP BY DATE(o.created_at)
) SELECT sales_day,revenue,SUM(revenue) OVER (ORDER BY sales_day ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS rolling_30_day_revenue FROM daily_sales;

-- Q18–Q20 là các truy vấn phân tích đệ quy có thể chạy trong sql/07_recursive.sql.

-- Q21A. Người bán hàng đầu: nối và tổng hợp trực tiếp. Thêm EXPLAIN ANALYZE phía trước để đo hiệu năng.
SELECT s.account_id,s.shop_name,SUM(oi.line_total) AS revenue FROM seller s JOIN order_item oi ON oi.seller_id=s.account_id
JOIN orders o ON o.order_id=oi.order_id WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED')
GROUP BY s.account_id,s.shop_name ORDER BY revenue DESC LIMIT 10;
-- Q21B. Cùng kết quả nhưng tổng hợp trước.
WITH seller_revenue AS (SELECT oi.seller_id,SUM(oi.line_total) AS revenue FROM order_item oi JOIN orders o ON o.order_id=oi.order_id
 WHERE o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED') GROUP BY oi.seller_id)
SELECT s.account_id,s.shop_name,sr.revenue FROM seller_revenue sr JOIN seller s ON s.account_id=sr.seller_id ORDER BY sr.revenue DESC LIMIT 10;

-- Q22. Khách hàng có tỷ lệ đơn bị trả vượt @return_rate.
SET @return_rate := 0.20;
SELECT c.account_id,c.customer_code,COUNT(o.order_id) AS total_orders,SUM(o.status='RETURNED') AS returned_orders,AVG(o.status='RETURNED') AS return_rate
FROM customer c JOIN orders o ON o.customer_id=c.account_id WHERE o.status IN ('DELIVERED','RETURN_REQUESTED','RETURNED')
GROUP BY c.account_id,c.customer_code HAVING AVG(o.status='RETURNED')>@return_rate ORDER BY return_rate DESC;

-- Q23. Hiệu quả khuyến mãi.
SELECT pr.promotion_id,pr.code,pr.name,COUNT(op.order_id) AS orders_using_promotion,COALESCE(SUM(op.discount_amount),0) AS discount_given,COALESCE(SUM(o.grand_total),0) AS gross_revenue
FROM promotion pr LEFT JOIN order_promotion op ON op.promotion_id=pr.promotion_id LEFT JOIN orders o ON o.order_id=op.order_id
GROUP BY pr.promotion_id,pr.code,pr.name ORDER BY discount_given DESC;

-- Q24. Sản phẩm có nhiều biến thể nhưng tổng tồn kho khả dụng tại người bán thấp.
SET @low_stock_limit := 10;
SELECT p.product_id,p.name,COUNT(DISTINCT v.variant_id) AS variant_count,COALESCE(SUM(i.quantity_on_hand-i.reserved_quantity),0) AS available_stock
FROM product p JOIN product_variant v ON v.product_id=p.product_id LEFT JOIN inventory i ON i.variant_id=v.variant_id
GROUP BY p.product_id,p.name HAVING COUNT(DISTINCT v.variant_id)>1 AND COALESCE(SUM(i.quantity_on_hand-i.reserved_quantity),0)<=@low_stock_limit;

-- Q25. Truy vấn phát hiện vi phạm: kết quả phải không có dòng nào nếu các bất biến liên bảng được bảo đảm.
SELECT 'ORDER_TOTAL_MISMATCH' AS violation,CAST(o.order_id AS CHAR) AS entity_id FROM orders o
WHERE o.subtotal<>(SELECT COALESCE(SUM(oi.line_total),0) FROM order_item oi WHERE oi.order_id=o.order_id)
UNION ALL SELECT 'NEGATIVE_AVAILABLE',CONCAT(i.seller_id,':',i.variant_id) FROM inventory i WHERE i.reserved_quantity>i.quantity_on_hand
UNION ALL SELECT 'REVIEW_NOT_DELIVERED',CAST(r.review_id AS CHAR) FROM review r WHERE NOT EXISTS (
 SELECT 1 FROM order_item oi JOIN orders o ON o.order_id=oi.order_id JOIN product_variant v ON v.variant_id=oi.variant_id
 WHERE oi.order_item_id=r.order_item_id AND o.customer_id=r.customer_id AND v.product_id=r.product_id AND o.status='DELIVERED');
