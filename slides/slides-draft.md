# Slide bảo vệ — bản nháp nội dung

Dùng bản này để dựng slide (PowerPoint/Google Slides/Markdown). Các mục `[CẦN ĐIỀN]` là số liệu thực nghiệm phải chụp từ MySQL/ObjectDB; không điền số ước lượng.

---

## Slide 1 — Tiêu đề

- Đề tài 7: CSDL thương mại điện tử và lập trình SQL nâng cao
- Nhóm 7: Lại Thế Thành, Dương Tấn Tài, Trần Văn Minh Tuấn, Nguyễn Mậu Công Khoa, Phạm Thành Danh
- Bảng ma trận đóng góp (mỗi người 1 phần, điền sau khi chốt)

*Ghi chú: giới thiệu 60 giây, nêu vai trò từng thành viên.*

## Slide 2 — Vấn đề và phạm vi

- Bài toán: giữ đúng tồn kho, tổng tiền, khuyến mãi khi bán hàng
- Rủi ro: oversell, tổng đơn lệch dòng hàng, state transition sai
- Phạm vi: catalog → variant → tồn kho → giỏ → đơn → thanh toán → vận chuyển → review
- Công nghệ: MySQL 8.0, Python 3.13 (PyMySQL, Faker), ObjectDB/ODL-OQL

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

Kết quả kiểm thử SQL sẽ được điền từ lần chạy mới nhất:
- Ràng buộc: tất cả case phải trả PASS, các truy vấn bất biến trả 0 vi phạm.
- Rollback: số đơn, tồn kho, giỏ và `used_count` phải giữ nguyên.
- Không oversell: một session chờ khóa, session còn lại bị từ chối `insufficient inventory`.

*Ghi chú: nhấn mạnh thứ tự khoá tránh deadlock và khóa tồn kho theo thứ tự cố định.*

## Slide 7 — SQL nâng cao trong Q01–Q25

| Nhóm | Ví dụ |
|---|---|
| JOIN/OUTER/NOT EXISTS | Q03, Q11 |
| Phép chia | Q09 |
| Correlated subquery | Q12, Q14 |
| Window | Q13 (DENSE_RANK), Q15 (LAG), Q17 (rolling 30 ngày lịch) |
| Recursive CTE | Q18 (category tree), Q19/Q20 (subtree doanh thu) |
| So sánh cách viết | Q21A vs Q21B |
| Kiểm tra bất biến | Q25 (phải 0 dòng) |

*Ghi chú: chỉ giải thích 3 truy vấn đắt giá nhất, không đọc hết 25.*

## Slide 8 — SQL động và SQL nhúng (bảo mật)

- `app/dynamic_search.py`: whitelist `sort`/`direction`, bind parameter cho mọi đầu vào
- Payload `' OR '1'='1` không đổi cấu trúc câu truy vấn, chỉ là giá trị tham số
- `app/embedded_sql.py`: cursor PyMySQL, parameterized query, cập nhật giỏ hàng có kiểm tra dòng
- Test: `python -m unittest tests.test_dynamic_search -v` → 6/6 PASS

Đã chạy thật ngày 22/10 (`report/appendix/danh/sql-injection-demo.txt`, `report/appendix/danh/embedded-sql-demo.txt`):
- Payload `'; DROP TABLE product; --` → 0 dòng, không lỗi, bảng `product` còn nguyên
- Các giá trị sort ngoài whitelist đều bị từ chối trước khi tạo SQL
- `checkout` qua PyMySQL tạo đơn `PAID`; lần đặt vượt tồn kho bị rollback, dữ liệu trước/sau không đổi

Ghi chú: dùng ảnh terminal trong `report/appendix/danh/` cho phần demo.

## Slide 9 — Mô hình đệ quy và ObjectDB/OQL

- Category tree: recursive CTE theo `parent_id`, có chống lặp bằng `visited` path
- Doanh thu theo subtree danh mục
- ODL: 6 lớp bền vững + struct `OrderLine`
- OQL: OQ01–OQ05 có kết quả mong đợi; `lifetimeValue()`, `revenue()`, `canTransitionTo()`

Ghi chú: `[CẦN ĐIỀN output ObjectDB thật]`

## Slide 10 — Bộ dữ liệu và phương pháp đo

- Generator seed cố định, mặc định 100.000 đơn, tỉ lệ trạng thái có thể chỉnh qua CLI
- Dữ liệu có: nhiều trạng thái đơn, thanh toán, review, tồn kho thấp, nhóm khách trả lại
- Đo: warmup → `EXPLAIN ANALYZE` baseline → tối ưu index → đo lại → đo storage
- Cùng máy, cùng dữ liệu, ghi lại metadata môi trường

Ghi chú: số liệu benchmark 22/10 nằm trong `data/benchmark/20261022-danh-win/`; lần chạy sau lưu thư mục mới.

## Slide 11 — Kết quả thực nghiệm hiện có

| Hạng mục | Kết quả |
|---|---|
| Script SQL 01→05 + test | Script sẵn sàng; kết quả test SQL cập nhật theo lần chạy mới |
| Test constraint/promotion/order | `[điền từ output lần chạy mới]` |
| Concurrency 2 session | `[điền từ output lần chạy mới]` |
| Q01–Q25 + recursive | Q25 bắt buộc 0 dòng; output lưu theo run-date |
| Generator (22/10) | 100.000 đơn, 200.176 dòng hàng, 89.920 thanh toán, 12.423 review, 492,9 s |
| Benchmark (22/10) | B1 1,6×; B2 5,5×; B3 ~305×; B4 không đổi; chi phí ghi +8% |
| App (22/10) | Injection bị vô hiệu; checkout/rollback đúng |

*Ghi chú: số liệu 22/10 lấy từ `data/benchmark/20261022-danh-win/` và `report/appendix/danh/`; các mục còn lại chờ lần chạy mới.*

## Slide 12 — Demo trực tiếp

1. Tìm kiếm động: lọc theo giá/category/keyword, thử payload SQL injection
2. Thêm vào giỏ, đổi số lượng vượt tồn kho → bị từ chối
3. Checkout: mã khuyến mãi hết lượt → rollback, giỏ còn nguyên
4. Chạy Q25 → 0 dòng vi phạm
5. Chạy 2 session tranh mua lượng hàng cuối → một session phải chờ/không oversell

Ghi chú: chuẩn bị sẵn 2 terminal, DB sẵn sàng, mọi lệnh trong `docs/13-experiment-runbook.md`.

## Slide 13 — Kết luận

- Thiết kế dữ liệu + ràng buộc + trigger + transaction tạo nền tảng đúng đắn
- Bộ truy vấn nâng cao, SQL động/nhúng, recursive SQL, ODL/OQL và generator đã sẵn sàng
- Hạn chế: kết quả test SQL/concurrency/ObjectDB cần chạy lại theo run-date; invariant liên bảng phải dùng trigger do MySQL thiếu ASSERTION
- Hướng mở rộng: partition theo thời gian, read replica cho báo cáo, cache tồn kho

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
