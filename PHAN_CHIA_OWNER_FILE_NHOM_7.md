# PHÂN CHIA FILE/FOLDER THEO OWNER — NHÓM 7 — ĐỀ TÀI 7

> Mục tiêu: mỗi file có **01 owner chính** chịu trách nhiệm chỉnh sửa. Người khác chỉ review qua PR hoặc tạo file riêng được giao. Quy tắc này dùng để giảm tối đa việc hai thành viên cùng sửa một file và gây conflict.

## 1. Thành viên và mã viết tắt

| Mã   | Thành viên            | Vai trò                                                                   |
| ----- | ----------------------- | -------------------------------------------------------------------------- |
| THANH | Lại Thế Thành        | Trưởng nhóm, core SQL, kiến trúc, tích hợp, Git                     |
| TAI   | Dương Tấn Tài       | Nghiệp vụ, EER/ERD, chuẩn hóa, data dictionary                         |
| TUAN  | Trần Văn Minh Tuấn   | SQL nâng cao, query catalog, recursive SQL, query performance             |
| KHOA  | Nguyễn Mậu Công Khoa | Constraint, trigger, procedure/function, transaction                       |
| DANH  | Phạm Thành Danh       | Data generator, embedded/dynamic SQL, security, benchmark, reproducibility |

---

## 2. Nguyên tắc chống conflict

1. **Mỗi file chỉ có một Owner.** Owner là người được phép chủ động sửa file đó.
2. Người khác cần thay đổi file của Owner phải tạo PR và để Owner review/merge phần thay đổi.
3. Không có chuyện hai người cùng sửa trực tiếp một file trong cùng thời gian.
4. Nếu một task cần sửa nhiều khu vực, tách task theo file/folder trước khi code.
5. Không sửa `sql/01_schema.sql` để phục vụ một query riêng. Nếu cần dữ liệu/test riêng, dùng seed/test file của task đó.
6. Các file tích hợp như `README.md`, `PLAN...md`, `.env.example`, `.gitignore`, `.vscode/settings.json` chỉ do THANH quản lý.
7. Các file sinh kết quả benchmark/log/report evidence nên được DANH tích hợp vào repo sau khi các thành viên cung cấp artifact riêng.
8. Nếu phát hiện file chưa có trong bảng này: người phát hiện tạo issue/task và THANH gán owner trước khi bắt đầu sửa.

---

## 3. Ownership toàn bộ repository hiện tại

### Root

| File                                                         | Owner | Review chính | Ghi chú                                                                             |
| ------------------------------------------------------------ | ----- | ------------- | ------------------------------------------------------------------------------------ |
| `README.md`                                                | THANH | TAI           | File giới thiệu + hướng dẫn chạy + tích hợp cuối                            |
| `PLAN_PHAN_CONG_NHOM_7_DE_TAI_7.md`                        | THANH | Tất cả      | Kế hoạch/phân công gốc                                                          |
| `.env.example`                                             | THANH | DANH          | Chỉ sửa tên biến cấu hình, không đưa secret thật                           |
| `.gitignore`                                               | THANH | DANH          | Quy tắc repo                                                                        |
| `.vscode/settings.json`                                    | THANH | DANH          | Cấu hình dùng chung                                                               |
| `Gỏi SV- Hướng dẫn  các đề tài CSDL nâng cao.md`  | THANH | TAI           | Tài liệu môn học, coi là reference; không sửa trong quá trình làm đồ án |
| `Gỏi SV- Hướng dẫn  các đề tài CSDL nâng cao.pdf` | THANH | TAI           | Tài liệu reference; không sửa                                                    |

> `__pycache__/` là file sinh tự động, **không thuộc ownership phát triển** và không được commit.

### `diagrams/` — TAI owner

| File                                | Owner | Review |
| ----------------------------------- | ----- | ------ |
| `diagrams/eer.mmd`                | TAI   | THANH  |
| `diagrams/erd.mmd`                | TAI   | THANH  |
| `diagrams/relational-schema.dbml` | TAI   | THANH  |

TAI chịu trách nhiệm đồng bộ ba sơ đồ. Khi schema SQL thay đổi, TAI nhận issue cập nhật diagram; không để TUAN/KHOA/DANH tự sửa diagram trực tiếp.

### `docs/` — chia theo nội dung, 01 owner/file

| File                                   | Owner | Review |
| -------------------------------------- | ----- | ------ |
| `docs/00-project-structure.md`       | THANH | TAI    |
| `docs/01-business-analysis.md`       | TAI   | THANH  |
| `docs/02-business-rules.md`          | TAI   | KHOA   |
| `docs/03-eer-erd.md`                 | TAI   | THANH  |
| `docs/04-relational-schema.md`       | THANH | TAI    |
| `docs/05-data-dictionary.md`         | TAI   | THANH  |
| `docs/06-normalization.md`           | TAI   | TUAN   |
| `docs/07-requirements-backlog.md`    | THANH | TAI    |
| `docs/08-query-catalog.md`           | TUAN  | THANH  |
| `docs/09-transaction-concurrency.md` | KHOA  | THANH  |
| `docs/10-benchmark.md`               | DANH  | THANH  |
| `docs/11-reproducibility.md`         | DANH  | THANH  |

**Quy tắc liên kết:** TAI là source of truth cho nghiệp vụ/mô hình; THANH là source of truth cho schema triển khai; TUAN là source of truth cho catalog query; KHOA là source of truth cho transaction/constraint; DANH là source of truth cho benchmark/reproducibility.

### `sql/` — chia từng script thành owner duy nhất

| File                             | Owner | Review       | Phạm vi                                               |
| -------------------------------- | ----- | ------------ | ------------------------------------------------------ |
| `sql/01_schema.sql`            | THANH | TAI + KHOA   | CREATE DATABASE/TABLE, PK/FK/index nền tảng          |
| `sql/02_constraints.sql`       | KHOA  | THANH + TAI  | CHECK/UNIQUE/FK bổ sung và invariant cần constraint |
| `sql/03_seed_small.sql`        | DANH  | TAI          | Seed nhỏ deterministic                                |
| `sql/04_functions.sql`         | KHOA  | THANH + TUAN | Function, checkout procedure, seller ranking           |
| `sql/05_triggers.sql`          | KHOA  | THANH + TAI  | Trigger integrity/state/cycle/review                   |
| `sql/06_queries.sql`           | TUAN  | THANH + DANH | Q01–Q25 SQL nâng cao                                 |
| `sql/07_recursive.sql`         | TUAN  | TAI + THANH  | Recursive category/depth/path/subtree revenue          |
| `sql/08_benchmark.sql`         | DANH  | THANH + TUAN | Benchmark command/protocol/execution setup             |
| `sql/09_transaction_tests.sql` | KHOA  | THANH + DANH | T01–T05 transaction/concurrency scripts               |

**Điểm quan trọng:** PLAN cũ ghi một số hạng mục kiểu `Thành + Tuấn` hoặc `Thành + Khoa`. Trong repo thật, để tránh conflict, bảng này quy định **một người trực tiếp sửa file**; người còn lại review và có thể tạo PR đề xuất.

### `data/` — DANH owner

| File/folder                         | Owner | Review       | Ghi chú                                 |
| ----------------------------------- | ----- | ------------ | ---------------------------------------- |
| `data/generator/generate_data.py` | DANH  | THANH + TUAN | Generator >=100k orders, seed cố định |
| `data/generator/requirements.txt` | DANH  | THANH        | Dependency generator                     |
| `data/seed/README.md`             | DANH  | TAI          | Hướng dẫn seed                        |
| `data/seed/sample.yaml`           | DANH  | TAI          | Dữ liệu mẫu dạng data                |
| `data/benchmark/README.md`        | DANH  | THANH        | Metadata/artifact benchmark              |
| `data/benchmark/`                 | DANH  | THANH        | Output benchmark, manifest, metadata     |
| `data/seed/`                      | DANH  | TAI          | Seed artifacts                           |
| `data/generator/`                 | DANH  | THANH        | Generator artifacts                      |

### `app/` — DANH owner

| File                      | Owner | Review       |
| ------------------------- | ----- | ------------ |
| `app/embedded_sql.py`   | DANH  | THANH + TUAN |
| `app/dynamic_search.py` | DANH  | THANH + KHOA |
| `app/requirements.txt`  | DANH  | THANH        |
| `app/`                  | DANH  | THANH        |

DANH chịu trách nhiệm phần Python/PyMySQL, parameter binding, whitelist và SQL Injection demo. TUAN chỉ review query semantics; KHOA review integrity/security implications.

### `object-db/` — tách model và query

| File/folder                     | Owner | Review       |
| ------------------------------- | ----- | ------------ |
| `object-db/model/README.md`   | TAI   | THANH        |
| `object-db/model/`            | TAI   | THANH + DANH |
| `object-db/queries/README.md` | TUAN  | TAI + THANH  |
| `object-db/queries/`          | TUAN  | TAI + DANH   |

TAI giữ object model/class design; TUAN giữ OQL/query. Không để hai người cùng sửa một file model/query.

### `tests/`

| File/folder                    | Owner | Review                 |
| ------------------------------ | ----- | ---------------------- |
| `tests/constraint_tests.sql` | KHOA  | TAI + DANH             |
| `tests/order_tests.sql`      | KHOA  | THANH + DANH           |
| `tests/security_tests.sql`   | DANH  | KHOA + THANH           |
| `tests/regression/README.md` | DANH  | THANH                  |
| `tests/regression/`          | DANH  | Tất cả theo artifact |

KHOA sở hữu test database integrity/order. DANH sở hữu regression aggregation và security test vì gắn với embedded/dynamic SQL.

### `report/` — chia trách nhiệm, DANH tích hợp evidence

Hiện tại hai thư mục mới có README nên chưa có file chương riêng. Ownership mặc định:

| Folder/file                   | Owner                          | Quy tắc                       |
| ----------------------------- | ------------------------------ | ------------------------------ |
| `report/chapters/README.md` | THANH                          | Quản lý cấu trúc chương  |
| `report/chapters/`          | Chia theo chương bên dưới | Mỗi chương chỉ 01 author   |
| `report/appendix/README.md` | DANH                           | Quản lý phụ lục/evidence   |
| `report/appendix/`          | DANH                           | DANH tích hợp artifact cuối |

**Phân chương dự kiến:**

| Chương                                                                      | Owner | Review       |
| ----------------------------------------------------------------------------- | ----- | ------------ |
| 1. Giới thiệu + mục tiêu                                                  | THANH | TAI          |
| 2. Phân tích nghiệp vụ + câu hỏi nghiên cứu                           | TAI   | THANH        |
| 3. EER + business rules                                                       | TAI   | THANH        |
| 4. Relational schema + FD + normalization                                     | TAI   | THANH + TUAN |
| 5. Thiết kế vật lý + index                                                | THANH | TUAN + DANH  |
| 6. SQL nâng cao 20+ query                                                    | TUAN  | THANH + DANH |
| 7. Constraint + trigger + procedure/function + dynamic/embedded/recursive SQL | KHOA  | THANH + DANH |
| 8. Object DB + OQL                                                            | TAI   | TUAN         |
| 9. Transaction + concurrency                                                  | KHOA  | THANH        |
| 10. Benchmark + EXPLAIN ANALYZE + thực nghiệm                               | DANH  | THANH + TUAN |
| 11. SQL Injection + bảo mật                                                 | DANH  | KHOA         |
| 12. Kết luận + hạn chế + hướng phát triển                             | THANH | Tất cả     |

> Nếu sau này tạo `report/chapters/chapter-06.md`, owner mặc định là TUAN theo bảng trên. Không tạo một file chương rồi để cả nhóm cùng sửa.

### `slides/`

| File/folder          | Owner | Review   |
| -------------------- | ----- | -------- |
| `slides/README.md` | THANH | Tất cả |
| `slides/`          | THANH | Tất cả |

Các thành viên cung cấp nội dung slide theo chương của mình cho THANH; THANH là người ghép deck cuối để tránh conflict trên file trình chiếu.

---

## 4. File ownership theo nghiệp vụ, nhìn nhanh

```text
TAI
├─ diagrams/*
├─ docs/01-business-analysis.md
├─ docs/02-business-rules.md
├─ docs/03-eer-erd.md
├─ docs/05-data-dictionary.md
├─ docs/06-normalization.md
├─ object-db/model/*
└─ report/chapters: 2, 3, 4, 8

THANH
├─ README.md
├─ PLAN_PHAN_CONG_NHOM_7_DE_TAI_7.md
├─ .env.example / .gitignore / .vscode/*
├─ docs/00, 04, 07
├─ sql/01_schema.sql
├─ object-db integration/review
├─ report/chapters: 1, 5, 12
└─ slides/*

TUAN
├─ docs/08-query-catalog.md
├─ sql/06_queries.sql
├─ sql/07_recursive.sql
├─ object-db/queries/*
└─ report/chapters: 6

KHOA
├─ sql/02_constraints.sql
├─ sql/04_functions.sql
├─ sql/05_triggers.sql
├─ sql/09_transaction_tests.sql
├─ tests/constraint_tests.sql
├─ tests/order_tests.sql
└─ report/chapters: 7, 9

DANH
├─ data/*
├─ app/*
├─ sql/03_seed_small.sql
├─ sql/08_benchmark.sql
├─ tests/security_tests.sql
├─ tests/regression/*
├─ report/appendix/*
└─ report/chapters: 10, 11
```

---

## 5. Các vùng tuyệt đối không cùng sửa

| Vùng                                | Owner duy nhất |
| ------------------------------------ | --------------- |
| Core schema                          | THANH           |
| Constraint/trigger/procedure         | KHOA            |
| Query catalog + query SQL            | TUAN            |
| Generator + Python app               | DANH            |
| EER/ERD + normalization              | TAI             |
| Root README/Git/repo config          | THANH           |
| Slide deck                           | THANH           |
| Report appendix/evidence integration | DANH            |

Nếu cần thay đổi một vùng của người khác, tạo branch riêng và PR vào branch của Owner. Owner quyết định cách merge để tránh conflict.

---

## 6. Quy trình branch để áp dụng ownership

Branch cá nhân:

```text
main
└── develop
    ├── feat/thanh-schema
    ├── feat/tai-modeling
    ├── feat/tuan-queries
    ├── feat/khoa-integrity
    └── feat/danh-data-app
```

Khi làm task nhỏ:

```text
feat/<owner>-<task>
```

Ví dụ:

```text
feat/thanh-schema
feat/tai-eer
feat/tuan-q01-q25
feat/khoa-triggers
feat/danh-generator
```

Quy tắc:

- Branch của ai thì người đó chịu trách nhiệm merge code của mình.
- PR phải ghi file/folder bị ảnh hưởng.
- Nếu PR đụng file không thuộc Owner, phải ghi rõ lý do và tag Owner review.
- Một PR nên tập trung một ownership area.
- Không commit file sinh tự động như `__pycache__`.

---

## 7. Cách chia task trong `sql/06_queries.sql` mà không conflict

`sql/06_queries.sql` chỉ có TUAN sửa trực tiếp. TUAN có thể chia Q01–Q25 cho các thành viên về mặt **nghiệp vụ**, nhưng mọi người gửi SQL qua issue/PR hoặc file nháp riêng, sau đó TUAN tích hợp.

Khuyến nghị file nháp nếu cần làm song song:

```text
sql/query-drafts/
├─ q01-q05-<member>.sql
├─ q06-q10-<member>.sql
├─ q11-q15-<member>.sql
├─ q16-q20-<member>.sql
└─ q21-q25-<member>.sql
```

Sau khi review xong, TUAN merge vào `sql/06_queries.sql`. Có thể xóa draft sau khi tích hợp.

Tương tự, nếu nhiều người cần đề xuất thay đổi `sql/01_schema.sql`, họ gửi migration/patch riêng cho THANH thay vì cùng sửa schema file.

---

## 8. Thứ tự phụ thuộc giữa các owner

```text
TAI: business rules → EER/ERD → relational design → normalization
                                  │
                                  ▼
THANH: core schema / integration ───────────────┐
                                  │             │
                                  ▼             │
KHOA: constraints → routines → triggers ───────┤
                                  │             │
                                  ▼             │
DANH: seed → generator → app/security ─────────┤
                                  │             │
                                  ▼             │
TUAN: queries → recursive → OQL → benchmark review
                                  │
                                  ▼
DANH: benchmark / reproducibility / evidence
                                  │
                                  ▼
THANH: final integration / README / slides
```

Đây là dependency logic, không phải thứ tự Git bắt buộc từng commit. Khi một upstream file thay đổi, downstream owner nhận task review tương ứng.

---

## 9. Quy tắc xử lý conflict nếu bắt buộc phải đụng file của người khác

1. Dừng việc sửa trực tiếp file đó.
2. Tạo issue/task mô tả chính xác đoạn cần thay đổi.
3. Owner tạo hoặc nhận PR thay đổi.
4. Người đề xuất cung cấp test/evidence cho thay đổi.
5. Owner merge sau khi review.
6. Nếu schema thay đổi, THANH cập nhật `sql/01_schema.sql`; TAI cập nhật diagram/docs liên quan; KHOA kiểm tra constraints/triggers; TUAN kiểm tra query; DANH kiểm tra generator/test. Mỗi người sửa **file thuộc ownership của mình**.

---

## 10. Kết luận phân công

Mục tiêu của file này là biến PLAN 12 tuần thành ownership cụ thể trong repository hiện tại. Từ lúc bắt đầu code:

- **TAI:** mô hình và lý thuyết dữ liệu.
- **THANH:** schema lõi, kiến trúc và tích hợp.
- **TUAN:** query và OQL.
- **KHOA:** integrity, routine và transaction test.
- **DANH:** data, Python, security, benchmark và reproducibility.

Nếu một file có owner rõ ràng thì nhóm có thể làm song song mà không cần 2 người cùng chỉnh cùng một file.
