# Cấu trúc dự án

```text
database-advanced-project/
├── docs/
│   ├── 00-project-structure.md
│   ├── 01-business-analysis.md
│   ├── 02-business-rules.md
│   ├── 03-eer-erd.md
│   ├── 04-relational-schema.md
│   ├── 05-data-dictionary.md
│   ├── 06-normalization.md
│   ├── 07-requirements-backlog.md
│   ├── 08-query-catalog.md
│   ├── 09-transaction-concurrency.md
│   ├── 10-benchmark.md
│   ├── 11-reproducibility.md
│   ├── 12-query-execution-notes.md
│   ├── 13-experiment-runbook.md
│   └── 14-normalization-proof.md
├── diagrams/
│   ├── eer.mmd
│   ├── erd.mmd
│   └── relational-schema.dbml
├── sql/
│   ├── 01_schema.sql
│   ├── 02_constraints.sql
│   ├── 03_seed_small.sql
│   ├── 04_functions.sql
│   ├── 05_triggers.sql
│   ├── 06_queries.sql
│   ├── 07_recursive.sql
│   ├── 08_benchmark.sql
│   └── 09_transaction_tests.sql
├── data/
│   ├── generator/
│   │   ├── generate_data.py
│   │   └── requirements.txt
│   ├── seed/
│   └── benchmark/
├── app/
│   ├── embedded_sql.py
│   ├── dynamic_search.py
│   └── requirements.txt
├── object-db/
│   ├── model/
│   └── queries/
├── tests/
│   ├── concurrency_setup.sql
│   ├── concurrency_session_a.sql
│   ├── concurrency_session_b.sql
│   ├── constraint_tests.sql
│   ├── order_tests.sql
│   ├── promotion_tests.sql
│   ├── security_tests.sql
│   ├── test_dynamic_search.py
│   └── regression/
├── report/
│   ├── chapters/
│   │   ├── report-outline.md
│   │   └── report-draft.md
│   └── appendix/
├── slides/
│   ├── slide-outline.md
│   └── slides-draft.md
├── .env.example
├── .gitignore
├── db_config.py
├── requirements.txt
├── README.md
└── PLAN_PHAN_CONG_NHOM_7_DE_TAI_7.md
```

## Quy ước thư mục

| Khu vực | Mục đích |
|---|---|
| `docs/` | Phân tích nghiệp vụ, thiết kế, lý thuyết và thực nghiệm |
| `diagrams/` | Nguồn sơ đồ có thể tái tạo bằng Mermaid/dbdiagram |
| `sql/` | DDL, constraint, routine, query, benchmark, transaction |
| `data/` | Generator và dữ liệu phục vụ seed/benchmark |
| `app/` | SQL nhúng, dynamic SQL và demo chống injection |
| `object-db/` | Mô hình lớp và OQL |
| `tests/` | Test tính toàn vẹn, nghiệp vụ và regression |
| `report/` | Nội dung báo cáo cuối kỳ |
| `slides/` | Slide bảo vệ |

Thứ tự triển khai chính: `01_schema.sql` → `02_constraints.sql` → seed nhỏ → routines/triggers → queries → recursive → benchmark/transaction.

Vai trò hai nguồn dữ liệu: `03_seed_small.sql` nạp dữ liệu mẫu nhỏ cho database mẫu (fixture test, demo, chạy Q01–Q25 trên dữ liệu nhỏ); `data/generator/generate_data.py` sinh dữ liệu lớn cho database benchmark riêng (các lần chạy mới không nạp seed nhỏ; lần 22/10 có nạp seed nhỏ, xem metadata).
