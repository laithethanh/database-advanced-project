# Phụ lục báo cáo

Lưu bằng chứng thực nghiệm (output thật của MySQL client/Python), kế hoạch thực thi và nhật ký tái lập tại đây.

```text
report/appendix/
├── danh/
│   ├── 20261025/            # SQL động + SQL Injection, SQL nhúng trên 100.000 đơn (bản chính, kèm ảnh terminal)
│   ├── 20261023/            # cùng hai demo, lần chạy của Thành trên máy Thành
│   ├── *.txt, *.png         # lần chạy đầu 22/10 (bản generator đầu)
│   └── nhat-ky-dong-gop.md  # nhật ký đóng góp của Danh: việc, commit, PR, bằng chứng
├── queries/
│   ├── 20261025/            # Q01–Q25 + đệ quy trên 100.000 đơn, tổng quan và dấu vân tay dữ liệu (bản chính)
│   └── 20261023/            # lần chạy đối chiếu
├── tests/
│   ├── 20261023/            # test SQL, transaction, unittest, T03 chạy tay, log generator/benchmark (Thành)
│   └── 20261103/            # kiểm thử hồi quy tự động 10/10 đạt, gồm T03 và security_tests (tóm tắt: tests/regression/2026-11-03.md)
└── objectdb/
    └── 20261102/            # ObjectDB/OQL 16/16 PASS
```

Benchmark và metadata môi trường nằm ở `data/benchmark/<thư mục lần chạy>/`; lần đo chính là
`data/benchmark/20261103-danh-win/` (cùng bộ dữ liệu với `queries/20261025/`, có biểu đồ `benchmark-chart.png`).
Danh mục các lần đo: `data/benchmark/README.md`.

## Bằng chứng chính dùng trong báo cáo

| Chương báo cáo | Bằng chứng | Ghi chú |
|---|---|---|
| 5, 9 — ràng buộc, transaction, T03 | `tests/20261103/` (hồi quy tự động), `tests/20261023/` | T03: `tests/20261103/22_*` và bản chạy tay `tests/20261023/71_*`; log `tests/20261023/21_*` là script cũ |
| 6 — Q01–Q25, đệ quy | `queries/20261025/` | Q11/Q20 giữ nguyên, diễn giải trong README của thư mục |
| 7 — SQL động/nhúng, SQL Injection | `danh/20261025/`, `tests/20261103/14_*`, `15_*` | Bước 15 là `tests/security_tests.sql` chạy trong MySQL |
| 8 — ObjectDB | `objectdb/20261102/oql-output.md` | |
| 10 — dữ liệu lớn, benchmark | `data/benchmark/20261103-danh-win/` | Tái lập: dấu vân tay trùng `queries/20261025/` |

## Quy ước

- Không tạo file bằng tay với số liệu ước lượng; mọi file ở đây phải là output thật của lần chạy.
- Mỗi lần chạy tạo thư mục riêng theo ngày (`YYYYMMDD`, trùng thì thêm `-2`); không ghi đè hay sửa tay kết quả cũ.
- Mỗi thư mục có `README.md` ghi môi trường (máy, MySQL, Python, thư viện), lệnh đã chạy và kết quả chính.
- Ảnh chụp terminal để cùng thư mục với log mà ảnh minh họa.
- Chỉ giữ các lần chạy được dẫn trong báo cáo hoặc dùng để đối chiếu.
- Không commit `.env`, mật khẩu hay database dump.
