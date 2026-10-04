# Requirements và backlog

## 1. Yêu cầu chung của môn

| ID | Requirement | Priority |
|---|---|---|
| REQ-C01 | Phân tích nghiệp vụ và business rules | Must |
| REQ-C02 | EER có specialization/generalization phù hợp | Must |
| REQ-C03 | Relational schema + data dictionary | Must |
| REQ-C04 | FD, candidate keys, minimal cover, 3NF/BCNF; xét 4NF | Must |
| REQ-C05 | SQL nâng cao ≥20 query | Must |
| REQ-C06 | Constraint, trigger, procedure/function | Must |
| REQ-C07 | Transaction success/failure/concurrency ≥2 sessions | Must |
| REQ-C08 | CSDL hướng đối tượng 4–6 classes + ≥5 OQL | Must |
| REQ-C09 | Thực nghiệm có dữ liệu và khả năng tái lập | Must |

## 2. Yêu cầu riêng Đề tài 7

| ID | Requirement | Priority |
|---|---|---|
| REQ-E01 | Mô hình customer/seller/product/variant/category/cart/order/promotion/review/warehouse | Must |
| REQ-E02 | 20+ query gồm correlated subquery, EXISTS/NOT EXISTS, division, HAVING, OUTER JOIN, window | Must |
| REQ-E03 | CHECK + trigger chống oversell và bảo vệ invariant | Must |
| REQ-E04 | Procedure đặt hàng, function khuyến mãi, seller ranking | Must |
| REQ-E05 | Dynamic SQL filter tùy chọn + whitelist + parameter binding | Must |
| REQ-E06 | Embedded SQL Python/PyMySQL + cursor | Must |
| REQ-E07 | SQL Injection demo và phòng tránh | Must |
| REQ-E08 | Recursive CTE duyệt category và doanh thu subtree | Must |
| REQ-E09 | Generator ≥100.000 orders | Must |
| REQ-E10 | So sánh query bằng EXPLAIN ANALYZE | Must |

## 3. Core requirements của sản phẩm

### Customer

- CR-CUS-01: quản lý profile và nhiều địa chỉ.
- CR-CUS-02: duyệt category/product/variant.
- CR-CUS-03: thêm, sửa, xóa CartItem.
- CR-CUS-04: checkout với tồn kho và promotion được kiểm tra.
- CR-CUS-05: xem lịch sử và trạng thái order.
- CR-CUS-06: review product khi đủ điều kiện.

### Seller

- CR-SEL-01: quản lý shop.
- CR-SEL-02: CRUD Product/Variant.
- CR-SEL-03: theo dõi Inventory theo warehouse.
- CR-SEL-04: xem order liên quan và doanh thu.

### Platform

- CR-PLT-01: quản lý category tree.
- CR-PLT-02: quản lý promotion và scope áp dụng.
- CR-PLT-03: kiểm soát order state và inventory invariant.
- CR-PLT-04: lưu audit-relevant transaction history.

## 4. Backlog ưu tiên

| ID | Epic | Story/Task | Acceptance criterion | Priority |
|---|---|---|---|---|
| BL-01 | Foundation | tạo project tree | toàn bộ thư mục chuẩn tồn tại | Must |
| BL-02 | Analysis | chốt actor + scope | business analysis được review | Must |
| BL-03 | Analysis | chốt business rules | toàn bộ business rules có ID và cơ chế thực thi | Must |
| BL-04 | Modeling | EER | có ISA overlapping/partial + cardinality | Must |
| BL-05 | Modeling | ERD | tất cả FK/N:M chính được biểu diễn | Must |
| BL-06 | Schema | DDL | database dựng được từ DB trắng | Must |
| BL-07 | Integrity | constraints | CHECK/FK/UQ chạy đúng | Must |
| BL-08 | Order | checkout transaction | success/rollback/concurrency có test | Must |
| BL-09 | SQL | 25 query | ≥20 query chạy đúng, đủ nhóm kỹ thuật | Must |
| BL-10 | Routine | procedures/functions | 3 nghiệp vụ chính có demo | Must |
| BL-11 | Security | dynamic SQL | whitelist + bind parameters + injection test | Must |
| BL-12 | Recursive | category analytics | recursive CTE trả depth/path/subtree revenue | Must |
| BL-13 | Data | generator | tái tạo ≥100k orders với seed | Must |
| BL-14 | Performance | benchmark | có baseline/optimized + EXPLAIN ANALYZE | Must |
| BL-15 | Object DB | OQL | ≥5 query + mapping/execution evidence | Must |
| BL-16 | QA | regression | test valid/invalid và lưu kết quả | Should |
| BL-17 | Docs | report | nội dung 20–30 trang + phụ lục | Must |
| BL-18 | Demo | slides | demo end-to-end có kịch bản | Must |

## 5. Definition of Done

Một task chỉ được xem là hoàn thành khi có artifact trong repo, có cách chạy rõ ràng, dữ liệu/test phù hợp và được ít nhất một thành viên khác review. Với SQL, phải có phát biểu nghiệp vụ và kết quả kiểm chứng; với benchmark phải lưu môi trường, dataset và phương pháp đo.
