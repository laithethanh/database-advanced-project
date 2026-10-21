# Phụ lục báo cáo

Lưu mã SQL, bằng chứng kiểm thử, kế hoạch thực thi và nhật ký tái lập tại đây.

Cấu trúc thư mục dự kiến (tạo khi chạy thực nghiệm):

```text
report/appendix/
├── benchmark/
│   ├── 00-environment.md        # metadata MySQL, quy mô dữ liệu, seed
│   ├── 01-baseline/             # output EXPLAIN ANALYZE trước khi tối ưu
│   ├── 02-optimized/           # output EXPLAIN ANALYZE sau khi tạo chỉ mục
│   └── 03-write-cost.md         # chi phí INSERT và dung lượng chỉ mục
├── queries/                     # kết quả Q01–Q25 + kế hoạch thực thi
├── tests/                       # log constraint/promotion/order/concurrency
├── objectdb/                    # output OQ01–OQ05 và mapping JPQL
└── logs/                        # log generator, thời gian chạy, mã commit
```

Quy ước đặt tên file: `<mục>-<mã truy vấn>-<timestamp>.<ext>`, ví dụ `Q01-20261021-143000.txt`.

Không tạo file bằng tay với số liệu ước lượng; mọi file trong thư mục này phải là output thật của lần chạy.
