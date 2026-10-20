# Hướng dẫn tái lập thực nghiệm

## Mục tiêu

Thành viên mới có thể tạo cơ sở dữ liệu từ đầu, nạp dữ liệu mẫu nhỏ, chạy kiểm thử, tạo bộ dữ liệu lớn và đo hiệu năng chỉ bằng tài liệu trong repository.

## Thứ tự thực hiện

```text
1. tạo database/schema
2. chạy sql/01_schema.sql
3. chạy sql/02_constraints.sql
4. chạy sql/03_seed_small.sql
5. chạy tests/constraint_tests.sql và order_tests.sql
6. chạy trình sinh dữ liệu với seed cố định
7. chạy sql/06_queries.sql và sql/07_recursive.sql
8. đo hiệu năng
9. chạy thử nghiệm transaction/concurrency trên 2 phiên kết nối
```

## Nguyên tắc tái lập

- Không đưa thông tin bí mật vào Git.
- Chỉ lưu `.env.example`, không lưu tệp `.env` thật.
- Trình sinh dữ liệu phải nhận seed và số lượng bản ghi qua tham số.
- Ghi phiên bản MySQL, hệ điều hành, CPU/RAM và quy mô bộ dữ liệu vào nhật ký đo hiệu năng.
