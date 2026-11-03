-- Kiểm thử SQL Injection ở mức MySQL — Phạm Thành Danh.
-- So sánh hai cách dựng CÙNG một câu tìm sản phẩm theo tên (giống app/dynamic_search.py):
--   (1) ghép chuỗi: nối thẳng chuỗi người dùng nhập vào câu SQL rồi PREPARE      -> KHÔNG an toàn
--   (2) tham số:    PREPARE câu có dấu ?, truyền chuỗi bằng EXECUTE ... USING    -> an toàn
-- Chỉ đọc dữ liệu (SELECT COUNT), không sửa database. Chạy trên database mẫu hoặc database 100.000 đơn:
--   mysql --default-character-set=utf8mb4 -u root -p ecommerce_advanced < tests/security_tests.sql
-- Cột result = PASS khi bản ghép chuỗi BỊ khai thác (trả dữ liệu ngoài ý muốn) VÀ bản tham số trả 0 dòng.
--
-- Phần kiểm thử phía Python (whitelist ORDER BY/ASC-DESC, kiểm tra khoảng giá, giới hạn số dòng):
--   python -m unittest tests.test_dynamic_search -v
USE ecommerce_advanced;

-- S1. Payload  ' OR '1'='1' --   phá điều kiện WHERE, vượt qua cả bộ lọc status = 'ACTIVE'.
--     Câu ghép thành: ... WHERE status = 'ACTIVE' AND name LIKE '%' OR '1'='1' -- %'
SET @payload_s1 := ''' OR ''1''=''1'' -- ';

SET @sql_ghep_s1 := CONCAT(
  'SELECT COUNT(*) INTO @s1_ghep FROM product ',
  'WHERE status = ''ACTIVE'' AND name LIKE ''%', @payload_s1, '%''');
PREPARE cau_ghep FROM @sql_ghep_s1;
EXECUTE cau_ghep;
DEALLOCATE PREPARE cau_ghep;

PREPARE cau_tham_so FROM
  'SELECT COUNT(*) INTO @s1_tham_so FROM product WHERE status = ''ACTIVE'' AND name LIKE CONCAT(''%'', ?, ''%'')';
EXECUTE cau_tham_so USING @payload_s1;
DEALLOCATE PREPARE cau_tham_so;

-- S2. Payload UNION đọc sang bảng account (lộ email đăng nhập).
--     Câu ghép thành: ... name LIKE '%khongco' UNION SELECT email FROM account WHERE email LIKE '%') AS t
SET @payload_s2 := 'khongco'' UNION SELECT email FROM account WHERE email LIKE ''';

SET @sql_ghep_s2 := CONCAT(
  'SELECT COUNT(*) INTO @s2_ghep FROM (SELECT name FROM product ',
  'WHERE status = ''ACTIVE'' AND name LIKE ''%', @payload_s2, '%'') AS t');
PREPARE cau_ghep FROM @sql_ghep_s2;
EXECUTE cau_ghep;
DEALLOCATE PREPARE cau_ghep;

PREPARE cau_tham_so FROM
  'SELECT COUNT(*) INTO @s2_tham_so FROM (SELECT name FROM product WHERE status = ''ACTIVE'' AND name LIKE CONCAT(''%'', ?, ''%'')) AS t';
EXECUTE cau_tham_so USING @payload_s2;
DEALLOCATE PREPARE cau_tham_so;

-- Kết quả
SELECT 'S1 OR 1=1 bypasses WHERE and status filter' AS test_name,
       @s1_ghep AS rows_concat,
       @s1_tham_so AS rows_param,
       (SELECT COUNT(*) FROM product) AS all_products,
       CASE WHEN (SELECT COUNT(*) FROM product) > 0
             AND @s1_ghep = (SELECT COUNT(*) FROM product)
             AND @s1_tham_so = 0
            THEN 'PASS' ELSE 'FAIL' END AS result;

SELECT 'S2 UNION leaks account emails' AS test_name,
       @s2_ghep AS rows_concat,
       @s2_tham_so AS rows_param,
       (SELECT COUNT(*) FROM account) AS all_accounts,
       CASE WHEN (SELECT COUNT(*) FROM account) > 0
             AND @s2_ghep = (SELECT COUNT(*) FROM account)
             AND @s2_tham_so = 0
            THEN 'PASS' ELSE 'FAIL' END AS result;
