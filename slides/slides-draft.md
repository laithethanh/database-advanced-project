# Slide bảo vệ — bản nháp nội dung

Dùng bản này để dựng slide (PowerPoint/Google Slides/Markdown). Số liệu đã cập nhật từ các thư mục bằng chứng ghi ngày cụ thể; không dùng số ước lượng.

---

## Slide 1 — Tiêu đề

- Đề tài 7: CSDL thương mại điện tử và lập trình SQL nâng cao
- Nhóm 7: Lại Thế Thành, Dương Tấn Tài, Trần Văn Minh Tuấn, Nguyễn Mậu Công Khoa, Phạm Thành Danh

| Thành viên | Phụ trách chính |
|---|---|
| Lại Thế Thành | Trưởng nhóm, core SQL, kiến trúc, tích hợp, Git |
| Dương Tấn Tài | Nghiệp vụ, EER/ERD, chuẩn hóa, data dictionary |
| Trần Văn Minh Tuấn | SQL nâng cao, query catalog, recursive SQL, hiệu năng truy vấn |
| Nguyễn Mậu Công Khoa | Constraint, trigger, procedure/function, transaction |
| Phạm Thành Danh | Generator, embedded/dynamic SQL, security, benchmark, reproducibility |

*Ghi chú: giới thiệu 60 giây, nêu vai trò từng thành viên.*

## Slide 2 — Vấn đề và phạm vi

- Bài toán: giữ đúng tồn kho, tổng tiền, khuyến mãi khi bán hàng
- Rủi ro: oversell, tổng đơn lệch dòng hàng, state transition sai
- Phạm vi: catalog → variant → tồn kho → giỏ → đơn → thanh toán → vận chuyển → review
- Công nghệ: MySQL 8.4.11, Python 3.13 (PyMySQL, Faker), ObjectDB 2.9.5/ODL-OQL trên Java 25

*Ghi chú: 1 phút.*

## Slide 3 — Quy trình nghiệp vụ và tác nhân

- Khách hàng → giỏ → checkout → thanh toán → giao → review
- Người bán → shop, variant, tồn kho
- Nền tảng → catalog, category, promotion, đối tác vận chuyển
- Sơ đồ luồng: 5 bước + nhánh hủy/hoàn

*Ghi chú: dùng sơ đồ trong `docs/03-eer-erd.md`.*

## Slide 4 — EER/ERD và quyết định thiết kế

- Account → Customer/Seller (overlapping specialization)
- Category → Product → ProductVariant (gắn Warehouse)
- Inventory = N:M giữa Seller và Variant, có thuộc tính riêng
- OrderItem tham chiếu Inventory theo khóa ghép `(seller_id, variant_id)`
- Quyết định: catalog dùng chung, snapshot lịch sử trong OrderItem

*Ghi chú: chỉ ra 3 quyết định "đắt tiền" nhất và lý do.*

## Slide 5 — Quy tắc toàn vẹn và chuẩn hóa

- FD, khóa ứng viên, bao đóng, phủ tối tiểu (đầy đủ ở `docs/14-normalization-proof.md`)
- Lõi đạt BCNF; ngoại lệ có kiểm soát: `line_total`, tổng đơn, `used_count`
- 4NF: tách Order/OrderItem/OrderPromotion để tránh MVD chồng nhau
- MySQL không có ASSERTION → mô phỏng bằng trigger + CHECK + Q25

*Ghi chú: nói rõ "ngoại lệ có kiểm soát" là gì và vì sao trung thực hơn gán nhãn BCNF cho tất cả.*

## Slide 6 — Transaction đặt hàng

Sơ đồ 8 bước của `sp_checkout`:

1. Validate đầu vào
2. Khoá cart ACTIVE
3. Tạo order PENDING_PAYMENT
4. Khoá inventory theo `(seller_id, variant_id)` → kiểm tra đủ hàng → trừ kho
5. Ghi order item kèm snapshot
6. Khoá promotion, tính giảm, cập nhật used_count
7. Cập nhật tổng, ghi payment, chuyển PAID, đóng cart, COMMIT
8. EXIT HANDLER → ROLLBACK

Kết quả kiểm thử:
- Ràng buộc/promotion/order: các case lỗi PASS; T02 rollback giữ nguyên số đơn và tồn kho (`ORDER_DATA_OK=0`).
- T03: A giữ khóa 6 giây, trừ kho 1 → 0, tạo order PAID; B chờ 4,04 giây rồi nhận `ERROR 1644`, không tạo order/payment.
- Kiểm tra cuối: kho 0; CUS2001 đúng 1 order PAID; CUS2002 0 order.

*Ghi chú: nhấn mạnh thứ tự khoá tránh deadlock và khóa tồn kho theo thứ tự cố định.*

## Slide 7 — SQL nâng cao trong Q01–Q25

| Nhóm | Ví dụ |
|---|---|
| JOIN/OUTER/NOT EXISTS | Q03, Q04, Q05, Q13 |
| Phép chia | Q11 |
| Correlated subquery | Q08 |
| GROUP BY/HAVING | Q02, Q07, Q12 |
| Window | Q01/Q15 (DENSE_RANK), Q14 (ROW_NUMBER), Q16 (LAG), Q17 (rolling 30 ngày lịch) |
| Recursive CTE | Q18 (category tree), Q19 (subtree doanh thu), Q20 (breadcrumb) |
| So sánh cách viết | Q21A vs Q21B |
| Kiểm tra bất biến | Q25 (phải 0 dòng) |

*Ghi chú: chỉ giải thích 3 truy vấn đắt giá nhất, không đọc hết 25.*

## Slide 8 — SQL động và SQL nhúng (bảo mật)

- `app/dynamic_search.py`: whitelist `sort`/`direction`, bind parameter cho mọi đầu vào
- Payload `' OR '1'='1` không đổi cấu trúc câu truy vấn, chỉ là giá trị tham số
- `app/embedded_sql.py`: cursor PyMySQL, parameterized query, cập nhật giỏ hàng có kiểm tra dòng
- Test: `python -m unittest tests.test_dynamic_search -v` → 6/6 PASS

Đã chạy thật ngày 25/10 trên database 100.000 đơn (`report/appendix/danh/20261025/`):
- Payload `' OR '1'='1' -- `: bản ghép chuỗi trả 2.511 dòng, bản an toàn trả 0 dòng
- Payload `UNION SELECT email, password_hash FROM account`: bản ghép chuỗi lộ 10.100 tài khoản, bản an toàn 0 dòng
- Sort ngoài whitelist bị từ chối; bảng `product` còn nguyên 1.000 sản phẩm
- `embedded_sql.py`: giỏ 5 món 5.744.000đ; đặt 1.059 cái khi kho còn 59 bị `ERROR 1644` và rollback; đặt 2 cái thành công, tổng 6.401.000đ, kho 59 → 57

Ghi chú: dùng ảnh terminal trong `report/appendix/danh/20261025/` cho phần demo.

## Slide 9 — Mô hình đệ quy và ObjectDB/OQL

- Category tree: recursive CTE theo `parent_id`, có chống lặp bằng `visited` path
- Doanh thu theo subtree danh mục
- ODL: 6 lớp bền vững + struct `OrderLine`
- OQL: OQ01–OQ05 có kết quả mong đợi; `lifetimeValue()`, `revenue()`, `canTransitionTo()`

Ghi chú: output ObjectDB thật nằm trong `report/appendix/objectdb/20261102/oql-output.md` (16/16 PASS).

## Slide 10 — Bộ dữ liệu và phương pháp đo

- Generator seed cố định, mặc định 100.000 đơn, tỉ lệ trạng thái có thể chỉnh qua CLI
- Dữ liệu có: nhiều trạng thái đơn, thanh toán, review, tồn kho thấp, nhóm khách trả lại
- Đo: warmup → `EXPLAIN ANALYZE` baseline → tối ưu index → đo lại → đo storage
- Cùng máy, cùng dữ liệu, ghi lại metadata môi trường

Ghi chú: số liệu benchmark 23/10 nằm trong `data/benchmark/20261023-004420-DESKTOP-97LS755/`; lần chạy sau lưu thư mục mới.

## Slide 11 — Kết quả thực nghiệm hiện có

| Hạng mục | Kết quả |
|---|---|
| Test constraint/promotion/order (23/10) | Constraint 7/7 PASS; promotion 4/4 case lỗi PASS; order 7/7 PASS, `ORDER_DATA_OK=0` |
| T03 concurrency | B chờ 4,04 giây, nhận `ERROR 1644`; kho 0; không oversell |
| Q01–Q25 + recursive (25/10) | Q25 = 0 vi phạm; Q11/Q20 giữ bản gốc, khác biệt dữ liệu đã ghi rõ |
| Generator (25/10) | 100.000 đơn, 200.294 dòng hàng, 89.861 payment, 12.425 review, 406,5 s |
| Benchmark (23/10) | B1 1,6×; B2 6,7×; B3 108,5×; B4 không đổi; chi phí ghi +18% |
| ObjectDB (02/11) | 5 OQL (7 kiểm tra) + 9 kiểm tra phương thức; 16/16 PASS |
| App (25/10) | Injection bị vô hiệu; checkout/rollback đúng |

*Ghi chú: số liệu lấy từ `data/benchmark/20261023-004420-DESKTOP-97LS755/`, `report/appendix/queries/20261025/`, `report/appendix/danh/20261025/` và `report/appendix/objectdb/20261102/`.*

## Slide 12 — Demo trực tiếp

1. Tìm kiếm động: lọc theo giá/category/keyword, thử payload SQL injection
2. Thêm vào giỏ, đổi số lượng vượt tồn kho → bị từ chối
3. Checkout: mã khuyến mãi hết lượt → rollback, giỏ còn nguyên
4. Chạy Q25 → 0 dòng vi phạm
5. Chạy 2 session tranh mua lượng hàng cuối → một session phải chờ/không oversell

Ghi chú: chuẩn bị sẵn 2 terminal, DB sẵn sàng, mọi lệnh trong `docs/13-experiment-runbook.md`.

## Slide 13 — Kết luận

- Thiết kế dữ liệu + ràng buộc + trigger + transaction tạo nền tảng đúng đắn
- Bộ truy vấn nâng cao, SQL động/nhúng, recursive SQL, ODL/OQL và generator đã có bằng chứng chạy thật
- Hạn chế: benchmark một máy, dữ liệu tổng hợp 100.000 đơn; Q11 cần diễn giải theo phép chia tập rỗng; invariant liên bảng phải dùng trigger do MySQL thiếu ASSERTION
- Hướng mở rộng: partition theo thời gian, read replica cho báo cáo, cache tồn kho, đo trên dữ liệu lớn hơn

Ghi chú: cảm ơn, mời hỏi.

---

## Phụ lục — kịch bản demo chi tiết

```text
# 0. Chuẩn bị (database mẫu ecommerce_advanced)
python -m pip install -r requirements.txt
mysql -u root -p < sql/01_schema.sql
mysql -u root -p < sql/02_constraints.sql
mysql -u root -p < sql/03_seed_small.sql   # dữ liệu mẫu nhỏ: fixture cho test/demo
mysql -u root -p < sql/04_functions.sql
mysql -u root -p < sql/05_triggers.sql

# 1. SQL động
python -m unittest tests.test_dynamic_search -v

# 2. Ràng buộc
mysql -u root -p ecommerce_advanced < tests/constraint_tests.sql

# 3. Checkout + rollback
mysql -u root -p ecommerce_advanced < tests/order_tests.sql

# 4. Bất biến
mysql -u root -p ecommerce_advanced -e "SOURCE sql/06_queries.sql"   # chạy Q25
```

Các lệnh chi tiết cho generator, benchmark, concurrency và regression nằm trong `docs/13-experiment-runbook.md`.
