# Phụ lục báo cáo

Lưu mã SQL, bằng chứng kiểm thử, kế hoạch thực thi và nhật ký tái lập tại đây.

Cấu trúc thư mục dự kiến (tạo khi chạy thực nghiệm):

```text
report/appendix/
├── danh/<run-date>/             # bằng chứng SQL động/nhúng (25/10)
├── queries/<run-date>/          # kết quả Q01–Q25 (25/10)
├── tests/<run-date>/            # log test SQL, transaction (23/10)
├── objectdb/<run-date>/         # output OQ01–OQ05 và mapping JPQL (02/11)
└── logs/<run-date>/             # log generator, thời gian chạy, mã commit
```

Benchmark và metadata môi trường được lưu trong `data/benchmark/<YYYYMMDD-HHMMSS>-<machine>/`.

Quy ước đặt tên file: `<mục>-<mã truy vấn>-<timestamp>.<ext>`, ví dụ `Q01-<YYYYMMDD>-<HHMMSS>.txt`.

Không tạo file bằng tay với số liệu ước lượng; mọi file trong thư mục này phải là output thật của lần chạy. Mỗi lần chạy tạo thư mục riêng theo ngày; chỉ giữ các lần chạy được dẫn trực tiếp trong báo cáo.

Các bằng chứng chính: `queries/20261025/` (Q01–Q25), `tests/20261023/` (test SQL/transaction), `danh/20261025/` (SQL động/nhúng) và `objectdb/20261102/` (ObjectDB 16/16 PASS).
