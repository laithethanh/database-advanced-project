# Catalog 25 truy vấn SQL

| ID | Nghiệp vụ | Kỹ thuật |
|---|---|---|
| Q01 | top sản phẩm theo doanh thu | JOIN/GROUP BY/window |
| Q02 | doanh thu theo seller | GROUP BY |
| Q03 | seller chưa có order | OUTER JOIN/NOT EXISTS |
| Q04 | customer chưa từng mua | NOT EXISTS |
| Q05 | SKU chưa từng bán | NOT EXISTS |
| Q06 | SKU có tồn kho thấp | JOIN/HAVING |
| Q07 | customer mua ≥ N SKU | GROUP BY/HAVING |
| Q08 | SKU cao hơn giá trung bình category | correlated subquery |
| Q09 | customer có mua và review | EXISTS |
| Q10 | seller chưa bán sản phẩm nhóm X | NOT EXISTS |
| Q11 | customer mua toàn bộ sản phẩm của tập X | relational division |
| Q12 | seller đạt doanh thu ngưỡng | GROUP BY/HAVING |
| Q13 | category không có product | OUTER JOIN |
| Q14 | top N SKU từng category | window `ROW_NUMBER` |
| Q15 | xếp hạng seller | `DENSE_RANK` |
| Q16 | doanh thu theo tháng | CTE/window |
| Q17 | rolling sales 30 ngày | window frame |
| Q18 | duyệt cây category | recursive CTE |
| Q19 | doanh thu subtree category | recursive CTE + aggregate |
| Q20 | depth/path category | recursive CTE |
| Q21 | A/B hai cách lấy top seller | EXPLAIN ANALYZE |
| Q22 | customer có tỷ lệ return cao | conditional aggregation |
| Q23 | hiệu quả promotion | JOIN/GROUP BY |
| Q24 | product nhiều variant nhưng stock thấp | GROUP BY/HAVING |
| Q25 | phát hiện invariant violation | anti-query |

Mỗi query khi triển khai phải có: mục tiêu nghiệp vụ, SQL, dữ liệu kiểm thử, expected result, actual result và execution plan nếu thuộc nhóm benchmark.
