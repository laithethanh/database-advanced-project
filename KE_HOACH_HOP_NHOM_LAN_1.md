# KẾ HOẠCH HỌP NHÓM LẦN 1 — NHÓM 7

## Đề tài

**CSDL thương mại điện tử và lập trình SQL nâng cao**

## Vai trò của tao trong buổi họp

Tao là **trưởng nhóm**. Mục tiêu của buổi họp đầu tiên là để cả nhóm cùng hiểu một bức tranh thống nhất về đề tài, biết repo hiện tại đang có gì, phần nào tao đã chuẩn bị, phần nào còn thiếu và sau buổi họp mỗi người phải biết chính xác mình đọc gì, làm gì và bàn giao kết quả ở đâu.

---

## 1. Mở đầu buổi họp — 5 phút

### Tao nói với cả nhóm

> "Hôm nay là buổi họp đầu tiên nên mục tiêu chính của nhóm là thống nhất cách làm trước khi mỗi người bắt đầu code riêng. Tao đã dựng sẵn bộ khung repo, phân tích đề tài, thiết kế dữ liệu ban đầu và một phần SQL. Việc của chúng ta từ hôm nay là cùng hiểu thiết kế đó, review những điểm chưa ổn rồi chia phần để triển khai tiếp.
>
> Đề tài của nhóm là xây dựng CSDL cho một sàn thương mại điện tử nhiều người bán, sau đó dùng chính CSDL này để thể hiện các nội dung của môn CSDL nâng cao: chuẩn hóa, SQL nâng cao, constraint, trigger, procedure/function, SQL động, SQL nhúng, recursive SQL, CSDL hướng đối tượng, transaction/concurrency và benchmark.
>
> Repo được tổ chức để cuối cùng có thể chạy lại từ một database trắng, kiểm thử, benchmark và lấy bằng chứng đưa vào báo cáo. Vì vậy từ giờ mọi người làm theo owner của từng vùng repo và review chéo trước khi merge."

---

## 2. Giới thiệu dự án — 10 phút

### Bài toán nhóm đang làm

Nhóm mô phỏng một **sàn thương mại điện tử nhiều người bán**. Vòng đời dữ liệu chính là:

```text
Customer
   ↓
Catalog → Product → Product Variant/SKU
   ↓
Cart
   ↓
Order → Payment → Shipment
   ↓
Review

Seller → Product → Inventory ← Warehouse

Promotion → Product / Category → Order
```

Các nhóm nghiệp vụ chính:

- Tài khoản, customer, seller.
- Product và product variant/SKU.
- Category nhiều tầng.
- Cart và cart item.
- Warehouse và inventory.
- Promotion và phạm vi áp dụng.
- Order, order item, payment, shipment.
- Review.

### Những kỹ thuật môn học mà dự án phải chứng minh

1. Phân tích nghiệp vụ và business rules.
2. EER/ERD và mapping sang relational schema.
3. Functional dependency, candidate key, minimal cover, 3NF/BCNF và xem xét 4NF.
4. Ít nhất 20 SQL nâng cao, mục tiêu hiện tại là 25 query.
5. Constraint, trigger, procedure/function.
6. Checkout transaction và concurrency chống oversell.
7. Dynamic SQL + whitelist + parameter binding + SQL Injection demo.
8. Embedded SQL bằng Python/PyMySQL.
9. Recursive CTE cho cây category và phân tích subtree.
10. Dataset tối thiểu 100.000 orders.
11. EXPLAIN ANALYZE và benchmark trước/sau tối ưu.
12. CSDL hướng đối tượng + tối thiểu 5 OQL.
13. Regression test và runbook tái lập.

---

## 3. Những gì tao đã chuẩn bị trong repo — 15 phút

### A. Bộ tài liệu nền

Trong `docs/` hiện đã có:

| File                              | Nội dung                          |
| --------------------------------- | ---------------------------------- |
| `00-project-structure.md`       | Cấu trúc và quy ước repo      |
| `01-business-analysis.md`       | Phạm vi, actor, nghiệp vụ       |
| `02-business-rules.md`          | Business rules có mã ID          |
| `03-eer-erd.md`                 | EER, ERD và mapping               |
| `04-relational-schema.md`       | Relational schema                  |
| `05-data-dictionary.md`         | Data dictionary                    |
| `06-normalization.md`           | FD, candidate key, chuẩn hóa     |
| `07-requirements-backlog.md`    | Requirement và backlog            |
| `08-query-catalog.md`           | Danh sách Q01–Q25                |
| `09-transaction-concurrency.md` | Kịch bản transaction/concurrency |
| `10-benchmark.md`               | Kế hoạch benchmark               |
| `11-reproducibility.md`         | Runbook tái lập                  |

### B. Thiết kế dữ liệu

Trong `diagrams/` đã có:

- `eer.mmd`
- `erd.mmd`
- `relational-schema.dbml`

Mô hình đã thể hiện supertype `Account`, subtype `Customer/Seller`, category đệ quy, các quan hệ N:M và các bảng nghiệp vụ chính.

### C. SQL hiện đã có

`sql/01_schema.sql` đã dựng các bảng lõi.

`sql/02_constraints.sql` đã có lớp constraint bổ sung.

`sql/03_seed_small.sql` có seed nhỏ để chạy happy path.

`sql/04_functions.sql` đã có:

- `fn_promotion_discount`.
- `sp_checkout`.
- `sp_seller_ranking`.

`sql/05_triggers.sql` đã có nhiều trigger bảo vệ invariant, gồm seller/category/product, variant, cart item, inventory, order item, order state transition, category cycle và review.

`sql/07_recursive.sql` đã có khung recursive CTE cho cây category.

`sql/09_transaction_tests.sql` đã định nghĩa các kịch bản T01–T05 để kiểm thử checkout, rollback, cạnh tranh tồn kho và state transition.

### D. Python/app hiện đã có khung

`app/embedded_sql.py` có ví dụ PyMySQL với parameterized query.

`app/dynamic_search.py` có whitelist cho sort/direction, tránh ghép trực tiếp input tùy ý vào identifier SQL.

### E. Quy hoạch nhóm đã có

Root repo đã có:

- `PLAN_PHAN_CONG_NHOM_7_DE_TAI_7.md` — kế hoạch 12 tuần.
- `PHAN_CHIA_OWNER_FILE_NHOM_7.md` — owner/reviewer cho từng vùng file.

---

## 4. Điểm phải nói rõ: repo hiện tại chưa hoàn thành — 10 phút

Tao sẽ nói thẳng với cả nhóm để mọi người không hiểu nhầm repo hiện tại là sản phẩm hoàn chỉnh.

### Đã có nền móng

- Scope và yêu cầu đề tài đã được định hình.
- Business rules đã được đặc tả.
- EER/ERD và relational schema đã có bản đầu.
- Data dictionary và normalization baseline đã có.
- Core schema SQL đã được dựng.
- Constraint, function/procedure và trigger đã có bản triển khai ban đầu.
- Seed nhỏ và một số test scaffold đã có.
- Ownership và kế hoạch 12 tuần đã có.

### Cần cả nhóm tiếp tục hoàn thiện

**1. `sql/06_queries.sql`**

Hiện file mới là khung tham chiếu Q01–Q25. Phần SQL thực tế của bộ query vẫn phải viết, chạy và lưu evidence.

**2. `data/generator/generate_data.py`**

Hiện mới là skeleton. Phải biến thành generator có seed cố định và tạo được tối thiểu 100.000 orders cùng dữ liệu liên quan.

**3. `sql/07_recursive.sql`**

Đã có recursive CTE cơ bản; phần subtree revenue và evidence cần hoàn thiện.

**4. `sql/08_benchmark.sql` + `docs/10-benchmark.md`**

Phải có benchmark thực tế, EXPLAIN ANALYZE, baseline/optimized và kết quả đo.

**5. `object-db/`**

Hiện mới có README định hướng. Cần hoàn thiện 4–6 lớp, quan hệ/tập hợp/kế thừa phù hợp, tối thiểu 5 OQL và evidence thực thi hoặc mapping.

**6. `tests/`**

Hiện chủ yếu là test matrix/scaffold. Cần biến thành test chạy được và lưu kết quả.

**7. `report/` và `slides/`**

Hiện mới có README. Nội dung báo cáo, phụ lục evidence và slide sẽ được xây dần theo từng milestone.

---

## 5. Việc đầu tiên mỗi thành viên phải làm — 15 phút

### Lại Thế Thành — Trưởng nhóm / Core SQL & kiến trúc

Tao chịu trách nhiệm:

- Kiến trúc tổng thể.
- Core schema và các SQL khó.
- Transaction/concurrency.
- Tích hợp các phần.
- Git/branch/review.
- Kiểm tra cuối trước khi merge.

Việc ngay sau họp:

- Chốt schema v1 sau khi nhận review.
- Chốt naming convention.
- Chốt thứ tự chạy SQL.
- Review PR của các thành viên.

### Dương Tấn Tài — Nghiệp vụ / EER / chuẩn hóa

Đọc trước:

- `docs/01-business-analysis.md`
- `docs/02-business-rules.md`
- `docs/03-eer-erd.md`
- `docs/04-relational-schema.md`
- `docs/05-data-dictionary.md`
- `docs/06-normalization.md`

Việc ngay sau họp:

- Review EER/ERD với schema hiện tại.
- Xác nhận cardinality, PK/FK và specialization/generalization.
- Hoàn thiện FD, candidate keys, minimal cover và lập luận 3NF/BCNF.
- Ghi lại bất kỳ điểm thiết kế nào cần sửa trước khi schema được xem là v1.

Owner chính: `diagrams/`, `docs/01–03`, `docs/05–06`, object model.

### Trần Văn Minh Tuấn — SQL nâng cao

Đọc trước:

- `docs/07-requirements-backlog.md`
- `docs/08-query-catalog.md`
- `docs/04-relational-schema.md`

Việc ngay sau họp:

- Chia Q01–Q25 thành nhóm kỹ thuật.
- Viết phần lớn SQL trong `sql/06_queries.sql`.
- Bảo đảm đủ correlated subquery, EXISTS/NOT EXISTS, division, HAVING, OUTER JOIN, window function, CTE.
- Chuẩn bị các query đại diện cho benchmark.

Owner chính: `docs/08-query-catalog.md`, `sql/06_queries.sql`, phần query trong `sql/07_recursive.sql` và `object-db/queries/`.

### Nguyễn Mậu Công Khoa — Constraint / trigger / procedure / transaction

Đọc trước:

- `docs/02-business-rules.md`
- `docs/09-transaction-concurrency.md`
- `sql/02_constraints.sql`
- `sql/04_functions.sql`
- `sql/05_triggers.sql`
- `sql/09_transaction_tests.sql`

Việc ngay sau họp:

- Review business rule → cơ chế thực thi.
- Kiểm tra trigger có bảo vệ đúng invariant không.
- Hoàn thiện test cho constraint và order flow.
- Chuẩn bị T01–T05 để chạy trên database sạch.
- Tập trung vào rollback và hai session mua SKU cuối.

Owner chính: `sql/02`, `sql/04`, `sql/05`, `sql/09`, `tests/constraint_tests.sql`, `tests/order_tests.sql`.

### Phạm Thành Danh — Data / Embedded SQL / Dynamic SQL / Benchmark

Đọc trước:

- `docs/10-benchmark.md`
- `docs/11-reproducibility.md`
- `app/embedded_sql.py`
- `app/dynamic_search.py`
- `data/generator/generate_data.py`

Việc ngay sau họp:

- Hoàn thiện generator có seed cố định.
- Sinh dataset tối thiểu 100.000 orders.
- Hoàn thiện embedded SQL và dynamic SQL.
- Viết test SQL injection.
- Chuẩn bị benchmark manifest và evidence tái lập.

Owner chính: `data/`, `app/`, `tests/security_tests.sql`, `docs/10–11`.

---

## 6. Cách cả nhóm đọc repo trong ngày đầu

Không cần đọc từng dòng SQL ngay. Đọc theo dependency này:

```text
README.md
    ↓
PLAN_PHAN_CONG_NHOM_7_DE_TAI_7.md
    ↓
docs/01-business-analysis.md
    ↓
docs/02-business-rules.md
    ↓
docs/03-eer-erd.md
    ↓
docs/04-relational-schema.md
    ↓
docs/05-data-dictionary.md
    ↓
docs/06-normalization.md
    ↓
sql/01_schema.sql
    ↓
sql/02_constraints.sql
    ↓
sql/03_seed_small.sql
    ↓
sql/04_functions.sql + sql/05_triggers.sql
    ↓
docs/08-query-catalog.md + sql/06_queries.sql
    ↓
docs/09-transaction-concurrency.md
    ↓
docs/10-benchmark.md + docs/11-reproducibility.md
    ↓
object-db/ + app/ + tests/
```

Mỗi người khi đọc phải trả lời được 5 câu:

1. Hệ thống đang mô hình hóa nghiệp vụ gì?
2. Các bảng chính liên hệ với nhau như thế nào?
3. Rule nào được bảo vệ bằng schema/constraint/trigger/procedure?
4. Phần mình phụ trách phụ thuộc vào file nào?
5. Kết quả cuối của phần mình phải chứng minh bằng code hoặc evidence nào?

---

## 7. Cách làm việc sau buổi họp

### Branch

Giữ `main` ổn định, dùng `develop` để tích hợp. Mỗi task tạo branch:

```text
feat/<id>-<ten-task>
```

Ví dụ:

```text
feat/TUAN-q01-q10
feat/KHOA-order-tests
feat/DANH-data-generator
feat/TAI-normalization
```

### Commit

Dùng prefix thống nhất:

```text
feat:
fix:
docs:
test:
perf:
```

Commit nên nhỏ và có một mục đích rõ.

### Pull request

Mỗi PR phải ghi:

- Đã làm gì.
- File nào thay đổi.
- Cách chạy/test.
- Kết quả test/evidence.
- Ai review.

Không tự merge phần quan trọng nếu chưa có review.

### Ownership

Mỗi vùng repo có owner. Nếu cần sửa file của người khác thì trao đổi trước và để owner review. Mục tiêu là giảm conflict và giữ trách nhiệm rõ ràng.

---

## 8. Việc nhóm phải chốt ngay trong buổi họp

- [ ] Tất cả thành viên clone/pull được repo.
- [ ] Tất cả cài được MySQL 8.0+ và Python 3.x.
- [ ] Tất cả hiểu scope của đề tài.
- [ ] Tất cả đọc đúng nhóm tài liệu theo owner.
- [ ] Thống nhất schema v1 và các điểm cần chỉnh.
- [ ] Thống nhất business rules quan trọng.
- [ ] Chốt owner/reviewer như trong `PHAN_CHIA_OWNER_FILE_NHOM_7.md`.
- [ ] Chốt branch/commit/PR convention.
- [ ] Chốt deadline cho deliverable đầu tiên.
- [ ] Chốt cách lưu evidence để cuối kỳ có thể tái lập.

---

## 9. Deliverable đầu tiên sau buổi họp

### Tài

**EER + normalization review v1**

Phải chỉ ra rõ các điểm đúng, điểm cần sửa và quyết định thiết kế cuối.

### Tuấn

**Query plan v1 + nhóm Q01–Q25**

Mỗi query có nghiệp vụ, kỹ thuật SQL và dữ liệu cần để kiểm chứng.

### Khoa

**Integrity/transaction test plan v1**

Mapping business rule → constraint/trigger/procedure + T01–T05.

### Danh

**Data/benchmark plan v1**

Generator plan, seed strategy, embedded/dynamic SQL plan và cách đo benchmark.

### Thành

**Integration baseline**

Tổng hợp review, chốt schema v1, cập nhật backlog và chuẩn bị nhánh tích hợp.

---

## 10. Mốc tiếp theo của nhóm

### Sau buổi họp 1

Mọi người hiểu kiến trúc và bắt đầu làm phần owner.

### Kết thúc giai đoạn khởi động

Phải có scope, business rules, EER v1, query catalog, test/data plan rõ ràng.

### Sau khi schema v1 được chốt

Tập trung triển khai DDL → constraints → seed → routines/triggers → queries → recursive → benchmark/transaction.

### Trước khi chuyển sang báo cáo cuối

Mọi kỹ thuật bắt buộc phải có code/script chạy được và evidence tương ứng.

---

## 11. Kết thúc buổi họp — 5 phút

Tao chốt với cả nhóm:

> "Từ hôm nay mỗi người chịu trách nhiệm rõ một vùng, nhưng sản phẩm cuối vẫn là của cả nhóm. Mọi phần code phải khớp với schema và business rules chung. Khi gặp vấn đề về thiết kế thì đưa lên nhóm để quyết định trước khi tự sửa kiến trúc. Mục tiêu trước mắt không phải làm thật nhiều file, mà là làm cho từng phần có thể chạy, kiểm chứng và tích hợp được."

Sau đó tao gửi lại cho cả nhóm:

1. `README.md`.
2. `PLAN_PHAN_CONG_NHOM_7_DE_TAI_7.md`.
3. `PHAN_CHIA_OWNER_FILE_NHOM_7.md`.
4. File này: `KE_HOACH_HOP_NHOM_LAN_1.md`.

Mỗi thành viên phản hồi lại trong nhóm chat bằng 3 dòng:

```text
Đã đọc: <các file chính>
Phần phụ trách: <owner>
Deliverable đầu tiên + deadline: <...>
```
