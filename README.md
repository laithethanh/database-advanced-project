# Đồ án CSDL Nâng cao — Đề tài 7

## CSDL thương mại điện tử và lập trình SQL nâng cao

Đồ án môn **Cơ sở dữ liệu nâng cao** của **Nhóm 7**, tập trung vào thiết kế và triển khai CSDL cho hệ thống thương mại điện tử; đồng thời nghiên cứu SQL nâng cao, CSDL hướng đối tượng, transaction, concurrency và đánh giá hiệu năng.

## Tài liệu thiết kế

- [Cấu trúc dự án](docs/00-project-structure.md)
- [Khảo sát nghiệp vụ và tác nhân](docs/01-business-analysis.md)
- [Quy tắc nghiệp vụ](docs/02-business-rules.md)
- [EER/ERD và mapping](docs/03-eer-erd.md)
- [Lược đồ quan hệ](docs/04-relational-schema.md)
- [Từ điển dữ liệu](docs/05-data-dictionary.md)
- [Cơ sở chuẩn hóa](docs/06-normalization.md)
- [Yêu cầu và danh sách công việc](docs/07-requirements-backlog.md)
- [Danh mục 25 truy vấn](docs/08-query-catalog.md)
- [Giao dịch và xử lý đồng thời](docs/09-transaction-concurrency.md)
- [Đo hiệu năng](docs/10-benchmark.md)
- [Tái lập thực nghiệm](docs/11-reproducibility.md)
- [Mẫu ghi bằng chứng truy vấn](docs/12-query-execution-notes.md)
- [Hướng dẫn chạy cơ sở dữ liệu](docs/13-experiment-runbook.md)
- [Chứng minh chuẩn hóa](docs/14-normalization-proof.md)

## 👥 Thành viên

| STT | Thành viên                      | Vai trò chính                                                                                                               |
| --- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Lại Thế Thành**        | Trưởng nhóm / Core SQL & kiến trúc; schema/SQL khó, transaction/concurrency, tối ưu, Git, tích hợp và review cuối |
| 2   | **Dương Tấn Tài**       | Mô hình dữ liệu & chuẩn hóa; nghiệp vụ, EER, ERD, FD, khóa, 3NF/BCNF/4NF, từ điển dữ liệu                       |
| 3   | **Trần Văn Minh Tuấn**   | SQL nâng cao; 20+ truy vấn, JOIN/subquery/window, recursive CTE, EXPLAIN ANALYZE                                            |
| 4   | **Nguyễn Mậu Công Khoa** | Ràng buộc & transaction; DDL, CHECK/FK, trigger, function/procedure, transaction, concurrency                               |
| 5   | **Phạm Thành Danh**       | Dữ liệu, SQL nhúng & thực nghiệm; generator ≥100.000 đơn, PyMySQL/dynamic SQL, benchmark và tái lập                |

**Thời lượng:** 12 tuần · **DBMS:** MySQL 8.0.18+ · **Kho mã:** GitHub

> Phân công chi tiết theo từng tuần và ma trận trách nhiệm được quản lý trong [`PLAN_PHAN_CONG_NHOM_7_DE_TAI_7.md`](PLAN_PHAN_CONG_NHOM_7_DE_TAI_7.md).

## 🎯 Mục tiêu

Xây dựng CSDL cho sàn thương mại điện tử với các nghiệp vụ khách hàng, người bán, sản phẩm, biến thể màu/size, danh mục nhiều tầng, giỏ hàng, đơn hàng, khuyến mãi, đánh giá và kho. Trên hệ thống đó, nhóm triển khai và đánh giá các kỹ thuật CSDL nâng cao.

## 🔎 Câu hỏi nghiên cứu

> Làm thế nào để thiết kế, chuẩn hóa và tổ chức transaction cho CSDL thương mại điện tử nhằm đảm bảo tính đúng đắn của dữ liệu, đồng thời vẫn hỗ trợ hiệu quả các truy vấn SQL phức tạp và nghiệp vụ có tính cạnh tranh cao?

## 🧩 Phạm vi hệ thống

- Khách hàng và người bán.
- Sản phẩm và biến thể màu/size.
- Danh mục sản phẩm nhiều tầng.
- Giỏ hàng và chi tiết giỏ hàng.
- Đơn hàng và chi tiết đơn hàng.
- Kho và tồn kho.
- Khuyến mãi và điều kiện áp dụng (một đơn áp dụng được nhiều mã, tối đa 5).
- Đánh giá sản phẩm.

## 🛠️ Công nghệ

- **RDBMS:** MySQL 8.0+
- **SQL nhúng:** Python + PyMySQL + cursor + parameterized query.
- **Sinh dữ liệu:** Python Faker và generator có seed cố định để tái lập.
- **CSDL hướng đối tượng:** ObjectDB/OQL hoặc công cụ tương đương phù hợp với yêu cầu môn học.
- **Thiết kế:** diagrams.net / dbdiagram.io.
- **Quản lý mã nguồn:** GitHub.

## 🏗️ Nội dung thực hiện

### 1. Phân tích nghiệp vụ và thiết kế

- Đặc tả nghiệp vụ và quy tắc dữ liệu.
- EER có chuyên biệt hóa/tổng quát hóa khi phù hợp.
- Lược đồ quan hệ và từ điển dữ liệu.
- Mapping từ EER sang relational schema.

### 2. Phụ thuộc hàm và chuẩn hóa

- Xác định FD, candidate key, minimal cover.
- Lập luận chuẩn hóa 3NF/BCNF.
- Xét 4NF khi có phụ thuộc đa trị.
- Lập luận về nối không mất mát và bảo toàn phụ thuộc.

### 3. SQL nâng cao

Mục tiêu **25 truy vấn** để có dư địa, trong đó tối thiểu 20 truy vấn đáp ứng yêu cầu đề tài:

- Subquery và correlated subquery.
- `EXISTS` / `NOT EXISTS`.
- Phép chia quan hệ.
- `GROUP BY` / `HAVING`.
- `INNER JOIN` / `OUTER JOIN`.
- Window functions.
- CTE và recursive CTE.
- Thống kê và phân tích dữ liệu.
- So sánh các cách viết bằng `EXPLAIN ANALYZE`.

Mỗi truy vấn phải có: **phát biểu nghiệp vụ → SQL → kết quả → kế hoạch thực thi/nhận xét**.

### 4. Constraint, Trigger, Procedure và Function

- `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK`.
- Trigger chống bán vượt tồn kho và bảo vệ các invariant quan trọng.
- Procedure đặt hàng.
- Function tính khuyến mãi.
- Function xếp hạng người bán.
- State transition của đơn hàng.
- ASSERTION được trình bày ở mức lý thuyết.

### 5. SQL động và SQL Injection

Xây dựng tìm kiếm sản phẩm theo tên, danh mục, khoảng giá, thương hiệu và đánh giá tối thiểu. SQL động phải sử dụng **whitelist** cho field/operator/sort và **parameter binding** cho dữ liệu đầu vào; đồng thời có demo SQL Injection và biện pháp phòng tránh.

### 6. SQL nhúng

Sử dụng Python/PyMySQL để kết nối MySQL, thực thi câu lệnh bằng cursor, fetch/cập nhật dữ liệu và thể hiện rõ parameterized query.

### 7. SQL đệ quy

Sử dụng `WITH RECURSIVE` trên MySQL 8.0+ để duyệt cây danh mục, xác định depth/path và tính tổng doanh thu theo subtree.

### 8. CSDL hướng đối tượng và OQL

Thiết kế khoảng **4–6 lớp**, thể hiện định danh/OID, quan hệ, tập hợp, kế thừa và phương thức khi phù hợp. Thực hiện tối thiểu **5 truy vấn OQL** và lập bảng ánh xạ OQL với ngôn ngữ thực thi nếu công cụ sử dụng là JPQL/JDOQL hoặc tương đương.

### 9. Transaction và concurrency

Thực nghiệm:

- Đặt hàng thành công → commit.
- Lỗi giữa chừng → rollback toàn bộ.
- Hai session cùng mua số lượng tồn kho cuối → không oversell.
- Kiểm tra contention/lock và tính nhất quán dữ liệu.

### 10. Dữ liệu lớn, benchmark và tối ưu

- Tối thiểu **100.000 đơn hàng** cho kiểm thử chính.
- Có thể mở rộng lên hàng triệu bản ghi.
- Đo baseline và optimized, sử dụng `EXPLAIN ANALYZE`.
- Đánh giá tác động của index tới SELECT cũng như INSERT/UPDATE và storage.
- Benchmark nhiều lần, ghi median/thời gian và điều kiện môi trường.
- Lưu log và script để tái lập kết quả.

## 📁 Cấu trúc repository

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
│ ├─ generator/
│ ├─ seed/
│ └─ benchmark/
├─ app/
│ ├─ embedded_sql.py
│ ├─ dynamic_search.py
│ └─ requirements.txt
├─ object-db/
│ ├─ model/
│ └─ queries/
├─ tests/
│  ├─ constraint_tests.sql
│  ├─ order_tests.sql
│  ├─ promotion_tests.sql
│  ├─ concurrency_setup.sql
│  ├─ security_tests.sql
│  ├─ test_dynamic_search.py
│  └─ regression/
├─ slides/
│  ├─ slide-outline.md
│  └─ slides-draft.md
├─ report/
│  ├─ chapters/
│  │  ├─ report-outline.md
│  │  └─ report-draft.md
│  └─ appendix/
├─ requirements.txt
└─ README.md
```

## 📊 Tiến độ 12 tuần

| Thời gian | Trọng tâm                                                                  |
| ---------- | ---------------------------------------------------------------------------- |
| Tuần 1–2 | Phạm vi, nghiệp vụ, EER và kế hoạch dữ liệu                          |
| Tuần 3    | FD, khóa, chuẩn hóa và relational schema                                 |
| Tuần 4–5 | DDL, constraint và bộ 20+ SQL queries                                      |
| Tuần 6–7 | Trigger/procedure/function, đặt hàng, SQL động, SQL nhúng và security |
| Tuần 8    | Recursive SQL và dữ liệu ≥100.000 đơn                                  |
| Tuần 9    | EXPLAIN ANALYZE, benchmark và tối ưu                                      |
| Tuần 10   | CSDL hướng đối tượng và OQL                                           |
| Tuần 11   | Transaction, concurrency và regression test                                 |
| Tuần 12   | Báo cáo, slide, demo và bảo vệ                                          |

## 📦 Sản phẩm đầu ra

- Báo cáo **20–30 trang** không tính phụ lục.
- Slide thuyết trình.
- Source code và script CSDL.
- DDL, constraint, trigger, procedure/function và ≥20 truy vấn SQL nâng cao.
- Dataset lớn hoặc generator tái tạo dataset ≥100.000 đơn hàng.
- Bộ truy vấn OQL ≥5.
- Chương trình SQL nhúng và dynamic SQL.
- Kịch bản transaction/concurrency và kết quả thực nghiệm.
- Benchmark, execution plans và phân tích trước/sau tối ưu.
- Regression tests, log và runbook tái lập.
- Nhật ký làm việc nhóm.

## 🚀 Hướng dẫn chạy

### Yêu cầu

- MySQL 8.0.18+ (bắt buộc cho `EXPLAIN ANALYZE`). Đã kiểm thử thực tế trên **MySQL 8.4.11** (Windows).
- Python 3.10+ (đã kiểm thử trên 3.13.2).
- Git.

> Kết quả thực nghiệm mới nhất nằm trong `data/benchmark/20261022-danh-win/` và `report/appendix/danh/`. Các lần chạy sau lưu vào `data/benchmark/<YYYYMMDD>-<machine>/`; không dùng lại kết quả cũ.

### Quy trình tổng quát

```bash
git clone <repository-url>
cd <repository-folder>
pip install -r requirements.txt
```

Dựng database mẫu `ecommerce_advanced` trên MySQL:

```powershell
mysql -u <user> -p < sql/01_schema.sql
mysql -u <user> -p < sql/02_constraints.sql
mysql -u <user> -p < sql/03_seed_small.sql
mysql -u <user> -p < sql/04_functions.sql
mysql -u <user> -p < sql/05_triggers.sql
mysql -u <user> -p < tests/constraint_tests.sql
mysql -u <user> -p < tests/promotion_tests.sql
mysql -u <user> -p < tests/order_tests.sql
mysql -u <user> -p < sql/06_queries.sql
mysql -u <user> -p < sql/07_recursive.sql
```

`sql/03_seed_small.sql` chỉ nạp **dữ liệu mẫu nhỏ** (vài dòng cho mỗi bảng) làm fixture cho `tests/*.sql`, cho demo và để chạy Q01–Q25 trên dữ liệu nhỏ. Fixture quan trọng do file này tạo: `CUS0001`, `SEL0001`, `SKU-DEMO-001`.

Với database benchmark **sạch riêng** (không nạp seed nhỏ), nạp `01`, `02`, `04`, `05`, sau đó chạy generator và benchmark:

```powershell
python data/generator/generate_data.py --orders 100000 --seed 20261003
mysql -u <user> -p < sql/08_benchmark.sql
```

Quy trình chi tiết, cách lưu bằng chứng và kịch bản hai phiên nằm trong `docs/13-experiment-runbook.md`.

> Không commit password, connection string thật hoặc `.env` chứa thông tin nhạy cảm. Dùng `.env.example`.

## 🌿 Quy trình Git

- `main`: bản ổn định.
- `develop`: nhánh tích hợp.
- Mỗi task dùng branch `feat/<id>-<ten-task>`.
- Commit theo dạng `feat:`, `fix:`, `docs:`, `test:`, `perf:`.
- Pull request phải có mô tả, cách test và người review.
- Mỗi tuần tạo tag/release checkpoint `week-01` … `week-12`.

## ✅ Checklist

- [x] EER + quy tắc nghiệp vụ hoàn chỉnh (`docs/01`–`docs/03`).
- [x] Relational schema + data dictionary (`docs/04`, `docs/05`).
- [x] FD, candidate key, minimal cover và lập luận 3NF/BCNF/4NF (`docs/06`, `docs/14`).
- [x] ≥20 SQL nâng cao; mục tiêu 25 (`sql/06_queries.sql`, `sql/07_recursive.sql`).
- [x] EXISTS/NOT EXISTS, division, GROUP BY/HAVING, OUTER JOIN, correlated subquery, window function.
- [x] Script sinh ≥100.000 đơn hàng, seed cố định (`data/generator/generate_data.py`).
- [x] CHECK + FK/UNIQUE + trigger (`sql/02`, `sql/05`).
- [x] Procedure/function: đặt hàng, khuyến mãi, seller ranking (`sql/04`).
- [x] Dynamic SQL + whitelist + parameter binding + SQL Injection demo (`app/dynamic_search.py`).
- [x] Embedded SQL + cursor (`app/embedded_sql.py`).
- [x] Recursive CTE cho category + doanh thu subtree.
- [x] 4–6 object classes + ≥5 OQL (`object-db/`).
- [x] Test cases valid/invalid (`tests/constraint_tests.sql`, `tests/order_tests.sql`, `tests/promotion_tests.sql`, `tests/test_dynamic_search.py`).
- [x] README có thể chạy lại từ database trắng.
- [x] Bản nháp báo cáo và slide (`report/chapters/report-draft.md`, `slides/slides-draft.md`).
- [ ] Chạy lại toàn bộ script SQL và test trên MySQL 8.4.11, lưu log bằng chứng theo run-date.
- [ ] Chạy transaction/concurrency 2 session và lưu bằng chứng khóa dòng/không oversell theo run-date.
- [x] Chạy benchmark `EXPLAIN ANALYZE` trên 100.000 đơn ngày 22/10 (`data/benchmark/20261022-danh-win/`).
- [ ] Chạy ObjectDB/OQL và lưu output 5 truy vấn (cần môi trường ObjectDB/JPA).
- [ ] Bổ sung output đầy đủ Q01–Q25 trên bộ 100.000 đơn (ảnh/CSV từng truy vấn).
- [ ] Báo cáo 20–30 trang hoàn chỉnh + phụ lục.
- [ ] Slide + demo + mỗi thành viên nắm rõ phần của mình và phần tích hợp.
- [ ] GitHub có lịch sử commit/phân công làm việc rõ ràng.

## 📄 Báo cáo và slide

- [Bản nháp báo cáo](report/chapters/report-draft.md) — 11 chương + phụ lục, các vị trí `[CẦN ĐIỀN]` là số liệu thực nghiệm chờ điền.
- [Đề cương báo cáo](report/chapters/report-outline.md).
- [Bản nháp slide](slides/slides-draft.md) — 13 slide kèm ghi chú thuyết trình và kịch bản demo.
- [Đề cương slide](slides/slide-outline.md).

## 📚 Tài liệu tham khảo

- **Database System Concepts** — Silberschatz, Korth, Sudarshan.
- **Fundamentals of Database Systems** — Elmasri & Navathe.
- **Database Systems: A Practical Approach to Design, Implementation, and Management** — Connolly & Begg.
- MySQL 8.0 Documentation.
- Tài liệu OQL / ObjectDB cho phần CSDL hướng đối tượng.

## 📌 Trạng thái

**Artifact mã nguồn và tài liệu đã hoàn thiện; còn chờ chạy thực nghiệm thật trên MySQL 8.0 để điền số liệu báo cáo.**

Phần đã sẵn sàng: schema + constraint, trigger/procedure/function, 25 truy vấn nâng cao + recursive SQL, SQL động/nhúng, ODL/OQL, generator 100.000 đơn, bộ test, tài liệu thiết kế và bản nháp báo cáo/slide. Phần còn lại là chạy thật và điền bằng chứng (mục t checklist chưa tick ở trên).

README này mô tả mục tiêu, phạm vi, công nghệ, cấu trúc repository, quy trình chạy và tiêu chí hoàn thành. Phân công chi tiết và kế hoạch theo tuần nằm trong `PLAN_PHAN_CONG_NHOM_7_DE_TAI_7.md`.
