# Phụ lục báo cáo

Lưu mã SQL, bằng chứng kiểm thử, kế hoạch thực thi và nhật ký tái lập tại đây.

Cấu trúc thư mục dự kiến (tạo khi chạy thực nghiệm):

```text
report/appendix/
├── danh/                        # bằng chứng SQL động/nhúng ngày 22/10
├── queries/<run-date>/          # kết quả Q01–Q25 + kế hoạch thực thi
├── tests/<run-date>/            # log constraint/promotion/order/concurrency
├── objectdb/<run-date>/         # output OQ01–OQ05 và mapping JPQL
└── logs/<run-date>/             # log generator, thời gian chạy, mã commit
```

Benchmark và metadata môi trường được lưu trong `data/benchmark/<YYYYMMDD>-<machine>/`.

Quy ước đặt tên file: `<mục>-<mã truy vấn>-<timestamp>.<ext>`, ví dụ `Q01-<YYYYMMDD>-<HHMMSS>.txt`.

Không tạo file bằng tay với số liệu ước lượng; mọi file trong thư mục này phải là output thật của lần chạy. Không giữ kết quả của các lần chạy cũ trong repo; mỗi lần chạy tạo thư mục riêng theo ngày.
