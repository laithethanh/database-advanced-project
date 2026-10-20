# Yêu cầu và danh sách công việc

## 1. Yêu cầu chung của môn

| ID | Yêu cầu | Mức ưu tiên |
|---|---|---|
| REQ-C01 | Phân tích nghiệp vụ và business rules | Bắt buộc |
| REQ-C02 | EER có specialization/generalization phù hợp | Bắt buộc |
| REQ-C03 | Relational schema + data dictionary | Bắt buộc |
| REQ-C04 | FD, candidate keys, minimal cover, 3NF/BCNF; xét 4NF | Bắt buộc |
| REQ-C05 | SQL nâng cao ≥20 query | Bắt buộc |
| REQ-C06 | Constraint, trigger, procedure/function | Bắt buộc |
| REQ-C07 | Transaction success/failure/concurrency ≥2 sessions | Bắt buộc |
| REQ-C08 | CSDL hướng đối tượng 4–6 classes + ≥5 OQL | Bắt buộc |
| REQ-C09 | Thực nghiệm có dữ liệu và khả năng tái lập | Bắt buộc |

## 2. Yêu cầu riêng Đề tài 7

| ID | Yêu cầu | Mức ưu tiên |
|---|---|---|
| REQ-E01 | Mô hình customer/seller/product/variant/category/cart/order/promotion/review/warehouse | Bắt buộc |
| REQ-E02 | 20+ query gồm correlated subquery, EXISTS/NOT EXISTS, division, HAVING, OUTER JOIN, window | Bắt buộc |
| REQ-E03 | CHECK + trigger chống oversell và bảo vệ invariant | Bắt buộc |
| REQ-E04 | Procedure đặt hàng, function khuyến mãi, seller ranking | Bắt buộc |
| REQ-E05 | Dynamic SQL filter tùy chọn + whitelist + parameter binding | Bắt buộc |
| REQ-E06 | Embedded SQL Python/PyMySQL + cursor | Bắt buộc |
| REQ-E07 | SQL Injection demo và phòng tránh | Bắt buộc |
| REQ-E08 | Recursive CTE duyệt category và doanh thu subtree | Bắt buộc |
| REQ-E09 | Generator ≥100.000 orders | Bắt buộc |
| REQ-E10 | So sánh query bằng EXPLAIN ANALYZE | Bắt buộc |

## 3. Yêu cầu cốt lõi của sản phẩm

### Khách hàng

- CR-CUS-01: quản lý profile và nhiều địa chỉ.
- CR-CUS-02: duyệt category/product/variant.
- CR-CUS-03: thêm, sửa, xóa CartItem.
- CR-CUS-04: checkout với tồn kho và promotion được kiểm tra.
- CR-CUS-05: xem lịch sử và trạng thái order.
- CR-CUS-06: review product khi đủ điều kiện.

### Người bán

- CR-SEL-01: quản lý shop.
- CR-SEL-02: CRUD Product/Variant.
- CR-SEL-03: theo dõi Inventory theo seller/variant; đối chiếu với warehouse-specific ProductVariant.
- CR-SEL-04: xem order liên quan và doanh thu.

### Nền tảng

- CR-PLT-01: quản lý category tree.
- CR-PLT-02: quản lý promotion và scope áp dụng.
- CR-PLT-03: kiểm soát order state và inventory invariant.
- CR-PLT-04: lưu audit-relevant transaction history.

## 4. Backlog ưu tiên

| ID | Epic | Story/Task | Acceptance criterion | Mức ưu tiên |
|---|---|---|---|---|
| BL-01 | Foundation | tạo project tree | toàn bộ thư mục chuẩn tồn tại | Bắt buộc |
| BL-02 | Analysis | chốt actor + scope | business analysis được review | Bắt buộc |
| BL-03 | Analysis | chốt business rules | toàn bộ business rules có ID và cơ chế thực thi | Bắt buộc |
| BL-04 | Modeling | EER | có ISA overlapping/partial + cardinality | Bắt buộc |
| BL-05 | Modeling | ERD | tất cả FK/N:M chính được biểu diễn | Bắt buộc |
| BL-06 | Schema | DDL | database dựng được từ DB trắng | Bắt buộc |
| BL-07 | Integrity | constraints | CHECK/FK/UQ chạy đúng | Bắt buộc |
| BL-08 | Order | checkout transaction | success/rollback/concurrency có test | Bắt buộc |
| BL-09 | SQL | 25 query | ≥20 query chạy đúng, đủ nhóm kỹ thuật | Bắt buộc |
| BL-10 | Routine | procedures/functions | 3 nghiệp vụ chính có demo | Bắt buộc |
| BL-11 | Security | dynamic SQL | whitelist + bind parameters + injection test | Bắt buộc |
| BL-12 | Recursive | category analytics | recursive CTE trả depth/path/subtree revenue | Bắt buộc |
| BL-13 | Data | generator | tái tạo ≥100k orders với seed | Bắt buộc |
| BL-14 | Performance | benchmark | có baseline/optimized + EXPLAIN ANALYZE | Bắt buộc |
| BL-15 | Object DB | OQL | ≥5 query + mapping/execution evidence | Bắt buộc |
| BL-16 | QA | regression | test valid/invalid và lưu kết quả | Nên có |
| BL-17 | Docs | report | nội dung 20–30 trang + phụ lục | Bắt buộc |
| BL-18 | Demo | slides | demo end-to-end có kịch bản | Bắt buộc |

## 5. Tiêu chí hoàn thành

Một công việc chỉ được xem là hoàn thành khi có artifact trong repo, có cách chạy rõ ràng, dữ liệu/test phù hợp và được ít nhất một thành viên khác review. Với SQL, phải có phát biểu nghiệp vụ và kết quả kiểm chứng; với benchmark phải lưu môi trường, dataset và phương pháp đo.
