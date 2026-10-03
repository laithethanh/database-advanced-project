# PLAN PHÂN CÔNG ĐỒ ÁN CSDL NÂNG CAO — NHÓM 7
## Đề tài 7: CSDL thương mại điện tử và lập trình SQL nâng cao

**Thành viên**
1. Lại Thế Thành
2. Dương Tấn Tài
3. Trần Văn Minh Tuấn
4. Nguyễn Mậu Công Khoa
5. Phạm Thành Danh

**Thời lượng:** 12 tuần  
**DBMS đề xuất:** MySQL 8.0  
**Kho mã:** GitHub, chia thư mục `docs/`, `sql/`, `data/`, `app/`, `tests/`, `slides/`

---

## 1. Mục tiêu và tiêu chí hoàn thành

Đồ án phải đáp ứng đầy đủ yêu cầu chung trong hướng dẫn môn học và yêu cầu riêng của Đề tài 7. Ngoài phần bắt buộc, nhóm chủ động bổ sung kiểm thử, benchmark và tài liệu tái lập để tăng chất lượng.

### 1.1. Yêu cầu chung bắt buộc
- Phân tích nghiệp vụ, quy tắc dữ liệu.
- EER có chuyên biệt hóa/tổng quát hóa khi phù hợp.
- Lược đồ quan hệ và từ điển dữ liệu.
- Phân tích phụ thuộc hàm, khóa, phủ tối thiểu; chứng minh/lập luận chuẩn hóa 3NF/BCNF; xét 4NF khi có phụ thuộc đa trị.
- SQL nâng cao: truy vấn con, JOIN, GROUP BY/HAVING, ràng buộc, thủ tục/hàm, SQL động, đệ quy; theo Đề tài 7 phải có ít nhất 20 truy vấn phức tạp.
- CSDL hướng đối tượng: khoảng 4–6 lớp, OID/định danh, kế thừa, tập hợp, quan hệ, phương thức; tối thiểu 5 truy vấn OQL. Nếu dùng ObjectDB/JPQL/JDOQL để chạy thì phải trình bày OQL riêng và ánh xạ sang ngôn ngữ thực thi.
- Transaction: kịch bản thành công, lỗi giữa chừng và cạnh tranh giữa ít nhất 2 phiên.
- Thực nghiệm có dữ liệu, script và kết quả tái lập được; tách kết quả đo thực tế với phân tích lý thuyết.

### 1.2. Yêu cầu riêng Đề tài 7
- Mô hình sàn TMĐT: khách hàng, người bán, sản phẩm, biến thể màu/size, danh mục nhiều tầng, giỏ hàng, đơn hàng, khuyến mãi, đánh giá, kho.
- Ít nhất 20 truy vấn phức tạp, gồm: truy vấn con tương quan, EXISTS/NOT EXISTS, phép chia, GROUP BY/HAVING, OUTER JOIN, hàm cửa sổ; cùng một yêu cầu nên có biến thể SQL để so sánh bằng `EXPLAIN ANALYZE`.
- CHECK và ràng buộc toàn vẹn phức tạp bằng TRIGGER; ví dụ không bán vượt tồn kho; ASSERTION trình bày ở mức lý thuyết.
- Thủ tục/hàm: đặt hàng, tính khuyến mãi, xếp hạng người bán.
- SQL động cho tìm kiếm sản phẩm với bộ lọc tùy chọn; phân tích SQL Injection và cách phòng tránh.
- SQL nhúng bằng Java/JDBC + MySQL Connector hoặc Python + PyMySQL có cursor. Chọn Python + PyMySQL nếu cần giảm độ phức tạp triển khai, nhưng phải thể hiện rõ cursor và tham số hóa.
- SQL đệ quy `WITH RECURSIVE` để duyệt cây danh mục và tính tổng doanh thu theo nhánh.
- Sinh dữ liệu mẫu lớn: từ 100.000 đơn hàng trở lên.
- Mỗi truy vấn có: phát biểu nghiệp vụ → SQL → kết quả → kế hoạch thực thi/nhận xét.

---

## 2. Kiến trúc dữ liệu đề xuất

Các thực thể lõi: `Customer`, `Seller`, `Product`, `ProductVariant`, `Category`, `Cart`, `CartItem`, `Order`, `OrderItem`, `Promotion`, `PromotionRule/PromotionProduct`, `Review`, `Warehouse`, `Inventory`.

Các quan hệ cần làm rõ: seller–product, product–variant, category tự liên kết cha/con, customer–cart, customer–order, order–order_item, product–review, warehouse–inventory, promotion–product/order.

Quy tắc quan trọng nên cài đặt:
- SKU/biến thể là duy nhất.
- Giá bán và số lượng không âm.
- Không tạo đánh giá nếu chưa có lịch sử mua phù hợp.
- Không bán vượt tồn kho.
- Tổng tiền đơn hàng nhất quán với chi tiết đơn.
- Trạng thái đơn hàng chuyển theo state hợp lệ.
- Khuyến mãi có thời gian hiệu lực và điều kiện hợp lệ.
- Danh mục không tạo chu trình.
- Đặt hàng phải xử lý nguyên tử: tạo đơn + chi tiết + trừ tồn kho + áp dụng khuyến mãi.

---

## 3. Phân công vai trò cố định

| Thành viên | Vai trò chính | Trách nhiệm xuyên suốt |
|---|---|---|
| **Lại Thế Thành** | Trưởng nhóm / Core SQL & kiến trúc | kiến trúc tổng thể, core schema/SQL khó, transaction/concurrency, tối ưu, Git, tích hợp, review cuối, điều phối demo |
| **Dương Tấn Tài** | Mô hình dữ liệu & chuẩn hóa | nghiệp vụ, EER, ERD, FD, khóa, 3NF/BCNF/4NF, từ điển dữ liệu |
| **Trần Văn Minh Tuấn** | SQL nâng cao | 20+ truy vấn, JOIN/subquery/window, recursive CTE, EXPLAIN ANALYZE |
| **Nguyễn Mậu Công Khoa** | Ràng buộc & transaction | DDL, CHECK/FK, trigger, function/procedure, transaction, concurrency |
| **Phạm Thành Danh** | Dữ liệu, SQL nhúng & thực nghiệm | generator ≥100k đơn, Python cursor/dynamic SQL, benchmark, kết quả, tái lập |

**Nguyên tắc phân công:** Thành giữ các phần core kỹ thuật và các hạng mục khó cần tính nhất quán xuyên suốt; 4 thành viên còn lại phụ trách các mảng chuyên môn riêng và cung cấp đầu ra để Thành tích hợp. Từ Tuần 6, mỗi người vẫn review chéo ít nhất một phần của người khác; các phần core phải có ít nhất một người backup để tránh phụ thuộc một người duy nhất.

---

# 4. Kế hoạch 12 tuần

## TUẦN 1 — Khởi động, phạm vi và nghiên cứu
**Mục tiêu:** chốt nghiệp vụ và cách làm, chưa code vội.

- **Thành:** chốt kiến trúc kỹ thuật, repo/branch/commit convention, backlog và các yêu cầu core; tổng hợp yêu cầu chung + riêng của Đề tài 7.
- **Tài:** khảo sát nghiệp vụ sàn TMĐT; liệt kê actor và business rules.
- **Tuấn:** nghiên cứu bộ truy vấn cần có; lập danh sách 20–25 truy vấn theo nhóm kỹ thuật.
- **Khoa:** nghiên cứu ràng buộc, trigger, transaction; đề xuất các invariant cần bảo vệ.
- **Danh:** nghiên cứu MySQL + Python/PyMySQL + Faker/generate_series; dựng thử pipeline dữ liệu.

**Deliverable:** scope v1, backlog, business-rule list, kiến trúc công nghệ, danh sách 20+ query, kế hoạch dữ liệu.

## TUẦN 2 — Đặc tả nghiệp vụ và EER v1
**Mục tiêu:** mô hình nghiệp vụ đủ để chuẩn hóa.

- **Thành:** chốt kiến trúc dữ liệu/SQL tổng thể, naming convention và review EER để bảo đảm schema phục vụ các phần SQL khó.
- **Tài:** hoàn thiện EER: thực thể, khóa, cardinality, specialization/generalization nếu có.
- **Tuấn:** map các nghiệp vụ thành câu hỏi SQL; xác định truy vấn cần dữ liệu đặc biệt.
- **Khoa:** viết ma trận business rule → cơ chế thực thi (CHECK/FK/UNIQUE/TRIGGER/procedure).
- **Danh:** thiết kế seed data nhỏ; chuẩn bị dữ liệu cho happy path và edge cases.

**Deliverable:** EER v1 + đặc tả nghiệp vụ + rule matrix + test-data plan.

## TUẦN 3 — Phụ thuộc hàm, khóa và chuẩn hóa
**Mục tiêu:** có lập luận lý thuyết chứ không chỉ vẽ ERD.

- **Thành:** kiểm tra tính nhất quán và xử lý các phần khó về mapping nghiệp vụ → EER → relational schema; chốt các quyết định kỹ thuật.
- **Tài:** lập FD, candidate keys, minimal cover; chọn 2–3 quan hệ tiêu biểu để trình bày chi tiết 3NF/BCNF; xét 4NF nếu phù hợp.
- **Tuấn:** kiểm tra thiết kế có hỗ trợ đầy đủ các query nâng cao.
- **Khoa:** xác định constraint từ kết quả chuẩn hóa.
- **Danh:** chuẩn bị script tạo dữ liệu cho bảng sau khi chốt schema.

**Deliverable:** normalization.md + relational schema v1 + data dictionary v1.

## TUẦN 4 — DDL và CSDL quan hệ v1
**Mục tiêu:** chạy được schema từ đầu đến cuối.

- **Thành:** phụ trách core DDL/schema, migration/reset script, README chạy dự án và tích hợp các phần của nhóm.
- **Tài:** review bảng, PK/FK, cardinality và mapping EER→relational.
- **Tuấn:** tạo view hỗ trợ truy vấn/phân tích nếu cần.
- **Khoa:** triển khai CHECK, UNIQUE, FK và trạng thái đơn hàng.
- **Danh:** seed dữ liệu nhỏ, script truncate/reset và kiểm tra tính tái lập.

**Deliverable:** `01_schema.sql`, `02_constraints.sql`, `03_seed_small.sql`, database v1.

## TUẦN 5 — SQL nâng cao: bộ 20+ truy vấn
**Mục tiêu:** hoàn thành khung 20+ query, mỗi query có mục đích rõ.

- **Thành:** phụ trách các query khó/đại diện và review toàn bộ Q01–Q25, chuẩn output, đánh số query và tính đúng đắn.
- **Tài:** hỗ trợ kiểm chứng query theo nghiệp vụ và dữ liệu.
- **Tuấn:** viết phần lớn query nghiệp vụ trong bộ 20–25 query; phối hợp Thành xử lý các query khó và query benchmark. correlated subquery, EXISTS/NOT EXISTS, division, GROUP BY/HAVING, OUTER JOIN, window functions, CTE.
- **Khoa:** bổ sung query kiểm tra constraint/trạng thái và các truy vấn transaction-related.
- **Danh:** chạy thử, tạo dữ liệu phục vụ edge case và ghi thời gian baseline.

**Deliverable:** `queries.sql` với ≥20 query; file kết quả; mô tả nghiệp vụ từng query.

## TUẦN 6 — Trigger, procedure/function và đặt hàng
**Mục tiêu:** nghiệp vụ đặt hàng có kiểm soát toàn vẹn.

- **Thành:** phụ trách core flow đặt hàng và transaction boundary; tích hợp procedure/trigger với script demo và chuẩn hóa cách chạy.
- **Tài:** review trigger có phản ánh đúng business rules không.
- **Tuấn:** tối ưu query liên quan đơn hàng, tồn kho, khuyến mãi.
- **Khoa:** triển khai procedure/function đặt hàng, tính khuyến mãi, xếp hạng seller; trigger chống âm kho, kiểm tra tổng đơn và state transition; phối hợp Thành ở transaction boundary.
- **Danh:** viết test case hợp lệ/vi phạm; đo thời gian và thu thập log.

**Deliverable:** `04_functions.sql`, `05_triggers.sql`, `tests_constraints.sql`, demo đặt hàng.

## TUẦN 7 — SQL động + SQL nhúng + bảo mật
**Mục tiêu:** hoàn thành hai yêu cầu dễ bị bỏ sót của đề tài.

- **Thành:** phụ trách integration của dynamic SQL/embedded SQL vào kiến trúc chung và review cách chạy.
- **Tài:** review SQL động có đúng nghiệp vụ và không phá constraint.
- **Tuấn:** xây query builder/filter logic và benchmark một số cách viết.
- **Khoa:** kiểm tra transaction khi gọi procedure; bổ sung test rollback.
- **Danh:** phụ trách chương trình Python dùng PyMySQL cursor; SQL động với whitelist field/operator + parameter binding; tạo case SQL Injection và bản phòng chống.

**Deliverable:** `app/embedded_sql.py`, `dynamic_search.py`, security test, tài liệu parameterized query.

## TUẦN 8 — Recursive SQL + dữ liệu lớn
**Mục tiêu:** đạt yêu cầu ≥100.000 đơn và xử lý cây danh mục.

- **Thành:** kiểm tra pipeline dữ liệu phục vụ các query/benchmark core và tích hợp hướng dẫn chạy.
- **Tài:** kiểm tra dữ liệu phản ánh đúng quan hệ danh mục nhiều tầng.
- **Tuấn:** hoàn thiện `WITH RECURSIVE`: cây danh mục, doanh thu theo nhánh, depth/path; kiểm tra chu trình.
- **Khoa:** kiểm tra constraint/trigger trên dữ liệu lớn và transaction đặt hàng.
- **Danh:** generator ≥100.000 orders + dữ liệu sản phẩm/variant/customer/inventory; tạo seed reproducible bằng seed cố định.

**Deliverable:** `generate_data.py`/SQL generator; dataset lớn; recursive queries; log số lượng bản ghi.

## TUẦN 9 — EXPLAIN ANALYZE và tối ưu truy vấn
**Mục tiêu:** biến phần SQL thành phần thực nghiệm có số liệu.

- **Thành:** phụ trách các ca tối ưu core và review benchmark protocol, môi trường, số lần chạy; chốt các index/query thay đổi.
- **Tài:** kiểm tra chỉ mục có đúng với khóa và nghiệp vụ.
- **Tuấn:** chọn 5–8 query tiêu biểu, viết phiên bản A/B và chạy `EXPLAIN (ANALYZE, BUFFERS)`.
- **Khoa:** đề xuất index nhưng đánh giá tác động INSERT/UPDATE và trigger.
- **Danh:** chạy benchmark nhiều lần, ghi median/thời gian, tổng hợp bảng và biểu đồ; cung cấp số liệu để Thành chốt tối ưu.

**Deliverable:** `benchmark.sql`, execution plans, bảng baseline vs optimized, nhận xét có căn cứ.

## TUẦN 10 — CSDL hướng đối tượng + OQL
**Mục tiêu:** đáp ứng yêu cầu chung về object database, không bỏ phần này.

- **Thành:** review việc tích hợp object-db với hệ thống SQL chung và thống nhất cách trình bày OQL.
- **Tài:** thiết kế 4–6 lớp: Customer, Seller, Product, ProductVariant, Order, OrderItem (có thể điều chỉnh); xác định kế thừa/tập hợp/quan hệ/phương thức phù hợp.
- **Tuấn:** viết ≥5 OQL theo đúng cú pháp môn học; lập bảng OQL → ngôn ngữ thực thi nếu dùng JPQL/JDOQL.
- **Khoa:** chuẩn bị dữ liệu object và test quan hệ/tập hợp.
- **Danh:** chạy thử object queries, chụp/ghi kết quả và so sánh với SQL tương ứng.

**Deliverable:** object model, ODL/class diagram, ≥5 OQL, mapping/execution notes, kết quả chạy.

## TUẦN 11 — Transaction, concurrency, regression test
**Mục tiêu:** có bằng chứng thực nghiệm rõ ràng.

- **Thành:** điều phối full regression, kiểm tra core transaction/concurrency và chuẩn bị kịch bản demo 5 phút.
- **Tài:** kiểm tra tính nhất quán dữ liệu trước/sau test.
- **Tuấn:** test query correctness trên dataset lớn; kiểm tra recursive và window queries.
- **Khoa:** chuẩn bị và chạy các kịch bản success/rollback; phối hợp Thành thực hiện 2+ session, contention/lock và ghi kết quả.
- **Danh:** tự động hóa regression + thu log; tổng hợp reproducibility checklist.

**Deliverable:** transaction lab, screenshots/logs, regression report, danh sách bug đã đóng.

## TUẦN 12 — Báo cáo, slide, demo và bảo vệ
**Mục tiêu:** đóng gói sản phẩm và luyện bảo vệ cá nhân.

- **Thành:** merge/release cuối, review toàn bộ core kỹ thuật, kiểm tra repo, điều phối slide và rehearsal.
- **Tài:** hoàn thiện chương EER + normalization + data dictionary.
- **Tuấn:** hoàn thiện chương SQL nâng cao + execution plans.
- **Khoa:** hoàn thiện trigger/procedure/transaction + test evidence.
- **Danh:** hoàn thiện thực nghiệm, benchmark, tái lập + phụ lục chạy chương trình.

**Deliverable cuối:** báo cáo 20–30 trang (không tính phụ lục), slide, source/script, dataset hoặc generator, SQL/OQL, nhật ký thực nghiệm, hướng dẫn chạy lại.

---

# 5. Ma trận trách nhiệm theo sản phẩm

| Sản phẩm | Owner | Review 1 | Review 2 |
|---|---|---|---|
| Đặc tả nghiệp vụ | Tài | Thành | Khoa |
| EER + relational schema | Tài + Thành | Tuấn | Khoa |
| FD/keys/3NF/BCNF/4NF | Tài | Thành | Tuấn |
| DDL/core schema | Thành | Khoa | Tài |
| Constraints | Khoa | Thành | Tài |
| 20+ SQL queries | Thành + Tuấn | Tài | Danh |
| Query khó/benchmark queries | Thành | Tuấn | Danh |
| Trigger/procedure/function | Khoa | Thành | Tuấn |
| Dynamic SQL + security | Danh | Thành | Khoa |
| Embedded SQL/cursor | Danh | Thành | Tuấn |
| Recursive SQL | Thành + Tuấn | Tài | Danh |
| Dataset ≥100k orders | Danh | Khoa | Tuấn |
| Benchmark/EXPLAIN + optimization | Thành + Danh | Tuấn | Khoa |
| Object model/OQL | Tài + Tuấn | Thành | Danh |
| Transaction/concurrency | Thành + Khoa | Danh | Tuấn |
| Báo cáo | Tất cả theo chương | Thành | cả nhóm |
| Slide/demo/integration | Thành | cả nhóm | cả nhóm |

---

# 6. Bộ 20+ truy vấn nên có

Q01 top sản phẩm theo doanh thu; Q02 doanh thu theo seller; Q03 seller không có đơn; Q04 khách chưa từng mua; Q05 sản phẩm chưa từng bán; Q06 sản phẩm có tồn kho thấp; Q07 khách mua ≥N sản phẩm; Q08 correlated subquery tìm sản phẩm trên giá trung bình của chính category; Q09 EXISTS tìm khách có mua và review; Q10 NOT EXISTS tìm seller chưa bán sản phẩm thuộc nhóm; Q11 phép chia: khách mua toàn bộ sản phẩm của một brand; Q12 GROUP BY/HAVING seller đạt ngưỡng doanh thu; Q13 OUTER JOIN tìm category không có sản phẩm; Q14 top-N sản phẩm theo từng category bằng window; Q15 ranking seller bằng DENSE_RANK; Q16 doanh thu theo tháng bằng window; Q17 rolling sales 7/30 ngày; Q18 recursive cây category; Q19 recursive tổng doanh thu theo subtree; Q20 tìm đường/độ sâu category; Q21 so sánh 2 cách viết cùng nghiệp vụ bằng EXPLAIN ANALYZE; Q22 khách có tỷ lệ đơn hoàn trả cao; Q23 hiệu quả coupon/promotion; Q24 sản phẩm có nhiều variant nhưng tồn kho thấp; Q25 phát hiện dữ liệu bất thường/invariant violation.

Mục tiêu nên làm **25 query** để có dư địa nếu một query không đủ thuyết phục.

---

# 7. Test matrix bắt buộc

### Constraint
- Giá < 0 → fail.
- Tồn kho < 0 → fail.
- SKU trùng → fail.
- FK sai → fail.
- Category tạo cycle → fail.
- Review không hợp lệ → fail.

### Order/transaction
- Đặt hàng hợp lệ → commit.
- Thiếu tồn kho → rollback toàn bộ.
- Lỗi sau khi tạo Order nhưng trước khi trừ kho → rollback.
- Hai session cùng mua số lượng cuối → không tạo oversell.
- Khuyến mãi hết hạn → không áp dụng.
- Tổng tiền chi tiết khác tổng đơn → bị chặn/không hợp lệ.

### Dynamic SQL/security
- Không filter.
- Một filter.
- Nhiều filter.
- Sort hợp lệ.
- Sort/column không nằm trong whitelist.
- Payload SQL Injection mẫu → không được thực thi.

### Query performance
- Baseline.
- Sau index.
- EXPLAIN ANALYZE + BUFFERS.
- Nêu trade-off index với INSERT/UPDATE và storage.

---

# 8. Chuẩn Git và quản lý công việc

- `main`: bản ổn định; `develop`: tích hợp; mỗi task dùng branch `feat/<id>-<ten-task>`.
- Commit theo dạng `feat:`, `fix:`, `docs:`, `test:`, `perf:`.
- Pull request phải có mô tả, cách test và người review.
- Mỗi tuần tạo tag hoặc release checkpoint `week-01` … `week-12`.
- Không commit password/connection string thật; dùng `.env.example`.
- Mọi script phải có thứ tự chạy và điều kiện đầu vào rõ ràng.

---

# 9. Cấu trúc repository đề xuất

```text
project/
├─ docs/
│  ├─ business-rules.md
│  ├─ eer.png
│  ├─ normalization.md
│  ├─ data-dictionary.md
│  ├─ benchmark.md
│  └─ reproducibility.md
├─ sql/
│  ├─ 01_schema.sql
│  ├─ 02_constraints.sql
│  ├─ 03_seed_small.sql
│  ├─ 04_functions.sql
│  ├─ 05_triggers.sql
│  ├─ 06_queries.sql
│  ├─ 07_recursive.sql
│  ├─ 08_benchmark.sql
│  └─ 09_transaction_tests.sql
├─ data/
│  └─ generator/
├─ app/
│  ├─ embedded_sql.py
│  └─ dynamic_search.py
├─ object-db/
│  ├─ model/
│  └─ queries/
├─ tests/
├─ slides/
├─ report/
└─ README.md
```

---

# 10. Chuẩn báo cáo cuối

Báo cáo nên bám cấu trúc hướng dẫn: **bài toán/câu hỏi nghiên cứu → cơ sở lý thuyết → thiết kế → hiện thực → thực nghiệm → thảo luận kết quả và hạn chế → kết luận**.

Đề cương đề xuất:
1. Giới thiệu và mục tiêu.
2. Phân tích nghiệp vụ và câu hỏi nghiên cứu.
3. EER và quy tắc dữ liệu.
4. Lược đồ quan hệ + FD + khóa + chuẩn hóa.
5. Thiết kế vật lý: index, dữ liệu lớn.
6. SQL nâng cao 20+ truy vấn.
7. Constraint, trigger, procedure/function, dynamic SQL, embedded SQL, recursive SQL.
8. CSDL hướng đối tượng và OQL.
9. Transaction/concurrency.
10. Thực nghiệm + benchmark + EXPLAIN ANALYZE.
11. Bảo mật SQL Injection và biện pháp phòng tránh.
12. Kết luận, hạn chế, hướng phát triển.
13. Tài liệu tham khảo.
14. Phụ lục: script, test case, kết quả chạy.

**Nguyên tắc:** mỗi kết luận quan trọng phải có lập luận hoặc số liệu; mỗi thực nghiệm phải ghi môi trường, dataset, cách chạy và kết quả; không chỉ chụp SQL mà không giải thích.

---

# 11. Checklist trước khi nộp

- [ ] EER + quy tắc nghiệp vụ hoàn chỉnh.
- [ ] Relational schema + data dictionary.
- [ ] FD, candidate key, minimal cover và lập luận 3NF/BCNF; 4NF nếu có.
- [ ] ≥20 SQL nâng cao; khuyến nghị 25.
- [ ] EXISTS/NOT EXISTS, division, GROUP BY/HAVING, OUTER JOIN, correlated subquery, window function.
- [ ] ≥100.000 đơn hàng và script tái tạo dữ liệu.
- [ ] CHECK + FK/UNIQUE + trigger.
- [ ] Procedure/function: đặt hàng, khuyến mãi, seller ranking.
- [ ] Dynamic SQL + whitelist + parameter binding + SQL Injection demo.
- [ ] Embedded SQL + cursor.
- [ ] Recursive CTE cho category + doanh thu subtree.
- [ ] ≥4–6 object classes + ≥5 OQL.
- [ ] Transaction success/failure/concurrency ≥2 sessions.
- [ ] EXPLAIN ANALYZE và benchmark trước/sau tối ưu.
- [ ] Test cases cho cả valid/invalid.
- [ ] README có thể chạy lại từ database trắng.
- [ ] Báo cáo 20–30 trang + phụ lục.
- [ ] Slide + demo + mỗi thành viên nắm rõ phần của mình và phần tích hợp.
- [ ] GitHub có lịch sử commit/phân công làm việc rõ ràng.

---

## Kết luận kế hoạch

Trọng tâm để đồ án có chất lượng cao không phải làm thật nhiều bảng mà là **liên kết chặt chẽ giữa nghiệp vụ → EER → chuẩn hóa → SQL → constraint/trigger → transaction → thực nghiệm**. Nhóm nên hoàn thành bản chạy được trước Tuần 8, dành Tuần 9–11 cho đo đạc, kiểm thử và phần object/OQL, rồi Tuần 12 chỉ đóng gói và luyện bảo vệ.
