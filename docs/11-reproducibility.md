# Reproducibility runbook

## Mục tiêu

Một thành viên mới phải có thể tạo database từ đầu, seed dữ liệu nhỏ, chạy test, tạo dataset lớn và chạy benchmark chỉ bằng tài liệu trong repository.

## Thứ tự

```text
1. tạo database/schema
2. chạy sql/01_schema.sql
3. chạy sql/02_constraints.sql
4. chạy sql/03_seed_small.sql
5. chạy tests/constraint_tests.sql và order_tests.sql
6. chạy generator với seed cố định
7. chạy sql/06_queries.sql + sql/07_recursive.sql
8. chạy benchmark
9. chạy transaction/concurrency trên 2 session
```

## Nguyên tắc tái lập

- Không commit secret.
- Lưu `.env.example`, không lưu `.env` thật.
- Generator phải nhận seed và số lượng bản ghi.
- Ghi MySQL version, OS, CPU/RAM và dataset cardinality trong benchmark log.
