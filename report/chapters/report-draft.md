# BÁO CÁO ĐỒ ÁN CSDL NÂNG CAO

## Đề tài 7: CSDL thương mại điện tử và lập trình SQL nâng cao

**Nhóm 7** — Lại Thế Thành, Dương Tấn Tài, Trần Văn Minh Tuấn, Nguyễn Mậu Công Khoa, Phạm Thành Danh.

> Bản draft này là khung nội dung để nhóm điền kết quả thực nghiệm. Các ô `[CẦN ĐIỀN]` phải được thay bằng output MySQL/ObjectDB thật; không sử dụng số liệu ước lượng.

## Tóm tắt

Đồ án xây dựng một CSDL thương mại điện tử trên MySQL 8.0, bao phủ catalog, biến thể theo kho, tồn kho theo người bán, giỏ hàng, đơn hàng, khuyến mãi, thanh toán, vận chuyển và đánh giá. Trọng tâm kỹ thuật gồm: thiết kế EER và chuẩn hóa có kiểm chứng; ràng buộc/trigger bảo vệ bất biến; thủ tục checkout có khóa và transaction; 25 truy vấn nâng cao; SQL động/nhúng an toàn; recursive SQL; mô hình ODL/OQL; và thực nghiệm trên bộ dữ liệu 100.000 đơn hàng.

Kết quả nổi bật về mặt thiết kế là việc phân biệt rõ **FD của dữ liệu gốc** với **giá trị dẫn xuất có kiểm soát**. Các cột như `line_total`, tổng đơn và `used_count` được materialize có chủ đích, nhưng được bảo vệ bằng trigger/CHECK và kiểm tra Q25. Cách trình bày này trung thực hơn việc gán nhãn toàn bộ lược đồ là BCNF.

## 1. Giới thiệu

### 1.1 Vấn đề

Hệ thống thương mại điện tử cần đồng thời bảo đảm tính đúng đắn của tồn kho, tổng tiền, khuyến mãi và lịch sử đơn hàng, trong khi vẫn hỗ trợ truy vấn phân tích phức tạp. Thiết kế chỉ đủ khóa ngoại sẽ không bảo vệ được các bất biến như không oversell, tổng đơn khớp dòng hàng hoặc review chỉ xuất phát từ đơn đã giao.

### 1.2 Câu hỏi nghiên cứu

Làm thế nào thiết kế và tổ chức transaction cho CSDL thương mại điện tử để bảo toàn dữ liệu, đồng thời vẫn hỗ trợ truy vấn nâng cao và dữ liệu lớn?

### 1.3 Đóng góp

- Lược đồ quan hệ có EER, FK/UNIQUE/CHECK và các invariant liên bảng.
- Checkout nguyên tử có khóa tồn kho theo thứ tự, xử lý promotion và rollback.
- Bộ 25 truy vấn bao phủ subquery, division, window, recursive CTE và kiểm tra bất biến.
- SQL động có whitelist/bind parameter; SQL nhúng PyMySQL.
- Generator tái lập 100.000 đơn với nhiều trạng thái, review và tồn kho thấp.
- Bộ ODL/OQL 6 lớp và 5 truy vấn.

## 2. Phân tích nghiệp vụ

### 2.1 Tác nhân

Khách hàng quản lý giỏ, đặt hàng, thanh toán và review. Người bán quản lý shop, variant và tồn kho. Nền tảng quản lý catalog, category tree, promotion và trạng thái đơn.

### 2.2 Quy tắc cốt lõi

Các nhóm BR-001…BR-094 được đặc tả trong `docs/02-business-rules.md`. Những bất biến quan trọng:

- Tồn kho khả dụng không âm khi checkout.
- `orders.grand_total = subtotal - discount_total + shipping_fee`.
- `subtotal` bằng tổng `order_item.line_total`.
- `discount_total` bằng tổng `order_promotion.discount_amount`.
- Chỉ chuyển trạng thái đơn/shipment theo state machine.
- Chỉ review sản phẩm trong đơn `DELIVERED` của đúng khách hàng.
- Category không tạo chu trình.

MySQL không hỗ trợ `CREATE ASSERTION`; các invariant liên bảng được mô phỏng bằng trigger/thủ tục và kiểm tra lại bằng Q25.

## 3. Thiết kế dữ liệu

### 3.1 EER và lược đồ quan hệ

Account là lớp cha của Customer và Seller theo hướng overlapping specialization. Product thuộc Category; ProductVariant gắn Warehouse và Product. Inventory là quan hệ N:M có thuộc tính giữa Seller và ProductVariant. Orders thuộc Customer; OrderItem tham chiếu Inventory theo `(seller_id, variant_id)`. Promotion có phạm vi product/category riêng. Review tham chiếu OrderItem, Product và Customer.

Chi tiết EER/ERD nằm trong `docs/03-eer-erd.md`, lược đồ quan hệ trong `docs/04-relational-schema.md`, từ điển dữ liệu trong `docs/05-data-dictionary.md`.

### 3.2 Quyết định thiết kế đáng chú ý

- Catalog dùng chung, không gắn seller trực tiếp vào Product.
- Variant gắn warehouse; cùng một tổ hợp sản phẩm/màu/size ở kho khác là variant khác.
- Tồn kho theo người bán nằm ở `inventory`, không dùng `warehouse_quantity` thay thế.
- Snapshot tên/SKU/giá trong OrderItem bảo vệ lịch sử.
- CartItem và OrderItem tham chiếu Inventory bằng khóa ghép để bảo đảm người bán thực sự có variant.

## 4. Phụ thuộc hàm và chuẩn hóa

### 4.1 FD và khóa

Các FD tiêu biểu, bao đóng, khóa ứng viên và phủ tối tiểu được trình bày trong `docs/14-normalization-proof.md`. Ví dụ:

```text
ACCOUNT: A → E,P,N,H,S,C,U;  E → A,P,N,H,S,C,U
Khóa: A, E

INVENTORY: (seller_id, variant_id) → quantity_on_hand, reserved_quantity, reorder_level, updated_at
Khóa: (seller_id, variant_id)

ORDER_ITEM: order_item_id → order_id,...,line_total
            (order_id,seller_id,variant_id) → order_item_id
            quantity,unit_price,line_discount → line_total
```

### 4.2 Kết luận chuẩn hóa

- Các quan hệ lõi đạt BCNF theo FD định danh dữ liệu gốc.
- `order_item.line_total` là ngoại lệ 3NF/BCNF nếu xem công thức số học là FD.
- `orders` totals là giá trị materialize; nếu xem công thức `subtotal - discount_total + shipping_fee → grand_total` là FD thì cũng là ngoại lệ có kiểm soát.
- `promotion.used_count` là bộ đếm dẫn xuất từ `order_promotion`.
- Snapshot lịch sử không tạo FD từ dữ liệu catalog hiện tại.

### 4.3 4NF và nối không mất mát

Nếu gộp order, order item và promotion vào một quan hệ, ta có hai MVD độc lập `order_id ->> order_item_id` và `order_id ->> promotion_id`, vi phạm 4NF. Lược đồ tách thành `order_item` và `order_promotion`; phép phân rã không mất mát theo định lý MVD. Các MVD product/color/size và promotion/product/category cũng được tách tương ứng.

## 5. Triển khai ràng buộc và transaction

### 5.1 Ràng buộc

`sql/02_constraints.sql` bổ sung CHECK cho chuỗi không rỗng, giá/tiền không âm, công thức `line_total`, công thức `grand_total`, unique active cart và unique default address.

### 5.2 Trigger

`sql/05_triggers.sql` kiểm tra:

- category/product/warehouse/seller còn hoạt động;
- reserved không vượt on-hand;
- order item chỉ sửa khi đơn `PENDING_PAYMENT`;
- state machine của order/shipment;
- review chỉ sau khi giao;
- promotion chỉ ghi khi đơn pending và tổng giảm không vượt subtotal;
- hoàn tồn đúng một lần khi hủy đơn đã thanh toán/xử lý.

### 5.3 Checkout

`sp_checkout` thực hiện:

1. Validate customer, phí ship, người nhận, danh sách mã.
2. Khóa cart ACTIVE và kiểm tra item còn bán được.
3. Tạo order PENDING_PAYMENT.
4. Khóa inventory theo `(seller_id, variant_id)`, kiểm tra đủ hàng, trừ kho.
5. Ghi order item với snapshot.
6. Khóa promotion theo `promotion_id`, tính giảm, cập nhật used_count.
7. Cập nhật tổng, ghi payment, chuyển PAID, đóng cart, commit.
8. `EXIT HANDLER` rollback toàn bộ nếu lỗi.

## 6. Truy vấn nâng cao

Bộ Q01–Q25 nằm trong `sql/06_queries.sql`; Q18–Q20 nằm trong `sql/07_recursive.sql`. Các nhóm kỹ thuật:

- JOIN/OUTER JOIN, NOT EXISTS, phép chia.
- Correlated subquery, GROUP BY/HAVING.
- Window: DENSE_RANK, ROW_NUMBER, LAG, rolling 30 ngày lịch bằng `RANGE`.
- Recursive CTE cho category tree và doanh thu subtree.
- Q21A/Q21B so sánh hai cách viết.
- Q25 kiểm tra bất biến và phải trả 0 dòng.

Kết quả Q01–Q25 và các truy vấn đệ quy được lưu lại sau mỗi lần chạy; Q25 bắt buộc trả về **0 dòng** vi phạm.
Các kết quả của những lần chạy cũ đã được dọn khỏi repo và không dùng lại trong báo cáo.

## 7. SQL động, SQL nhúng và bảo mật

`app/dynamic_search.py` dùng whitelist cho sort/direction và bind parameter cho keyword, category, price. `tests/test_dynamic_search.py` kiểm tra payload injection vẫn nằm trong params, sort/direction lạ bị từ chối, sort theo giá dùng đúng `v.price` và các khoảng giá/giới hạn không hợp lệ bị từ chối trước khi ghép câu lệnh.

`app/embedded_sql.py` minh họa cursor PyMySQL, parameterized query, cập nhật giỏ hàng có kiểm tra tồn tại dòng và gọi checkout.

Kết quả demo ngày 22/10 (`report/appendix/danh/sql-injection-demo.txt`, `report/appendix/danh/embedded-sql-demo.txt`):

- Payload `'; DROP TABLE product; --` trong keyword → trả về 0 dòng, không lỗi, bảng `product` còn nguyên.
- Các giá trị sort ngoài whitelist đều bị từ chối trước khi tạo câu lệnh SQL.
- `checkout` qua PyMySQL tạo đơn `PAID`; lần đặt vượt tồn kho bị rollback, số đơn và tồn kho trước/sau không đổi.
- `python -m unittest tests.test_dynamic_search -v` → 6/6 PASS.

## 8. CSDL hướng đối tượng

`object-db/model/ecommerce.odl` khai báo 6 lớp và struct `OrderLine`; `object-db/queries/ecommerce.oql` có 5 truy vấn OQL kèm kết quả mong đợi. Các phương thức `lifetimeValue()`, `revenue()`, `activeVariants()`, `isAvailable()`, `total()`, `canTransitionTo()` thể hiện hành vi nghiệp vụ.

Kết quả ObjectDB thực tế: `[CẦN ĐIỀN môi trường, output 5 truy vấn, mapping JPQL]` — phần này cần chạy trên
ObjectDB/JPA thật vì máy này chỉ có MySQL.

## 9. Transaction và đồng thời

Các kịch bản:

- T01 checkout thành công.
- T02 rollback sau khi đã tạo order/trừ kho bằng mã hết lượt (`tests/order_tests.sql`, mã `LIMIT0`).
- T03 hai session tranh mua lượng hàng cuối.
- T04 chuyển trạng thái sai.
- T05 savepoint.
- T06 nhiều mã, một mã lỗi.

Các kịch bản được chạy lại theo `docs/13-experiment-runbook.md`; mỗi lần chạy lưu output vào
`report/appendix/tests/<run-date>/`. Không dùng số liệu của lần chạy cũ. Yêu cầu kiểm chứng: rollback không
để lại đơn mồ côi hoặc tồn kho bị trừ dở; hai session tranh mua lượng hàng cuối phải không oversell.

## 10. Dữ liệu lớn và benchmark

Hai nguồn dữ liệu được dùng tách biệt, trên hai database khác nhau:

| Nguồn | Nội dung | Phạm vi sử dụng |
|---|---|---|
| `sql/03_seed_small.sql` | Dữ liệu mẫu nhỏ (vài dòng cho mỗi bảng, fixture `CUS0001`/`SEL0001`/`SKU-DEMO-001`) | Database mẫu `ecommerce_advanced`: test, demo, chạy Q01–Q25 trên dữ liệu nhỏ |
| `data/generator/generate_data.py` | Dữ liệu lớn 100.000 đơn (seed cố định, mã theo namespace `DCUS*`/`DSEL*`/`DSKU*`) | Database benchmark riêng, **không** nạp seed nhỏ: benchmark và kiểm chứng query |

Generator tạo 100.000 đơn với seed cố định (`--seed 20261003`), nhiều trạng thái, review và tồn kho thấp.
Benchmark ngày 22/10 chạy bằng `data/benchmark/run_benchmark.py`: warmup, `EXPLAIN ANALYZE` baseline, tạo chỉ
mục thử nghiệm, đo optimized và chi phí ghi/dung lượng.

Kết quả thực tế (`data/benchmark/20261022-danh-win/benchmark-results.md`):

| Mã | Truy vấn đo | Trước | Sau khi thêm chỉ mục thử nghiệm | Nhanh hơn |
|---|---|---|---|---|
| B1 | Top 10 sản phẩm theo doanh thu | 1.494,68 ms | 937,74 ms | 1,6× |
| B2 | Doanh thu theo ngày trong tháng 03/2026 | 39,41 ms | 7,12 ms | 5,5× |
| B3 | Tra cứu đơn theo số điện thoại người nhận | 38,11 ms | 0,12 ms | ~305× |
| B4 | 10 đơn gần nhất của một khách (đối chứng) | 0,39 ms | 0,55 ms | ~không đổi |
| — | Chi phí ghi 89.923 dòng `payment` | 1.975,19 ms | 2.136,96 ms | +8% |

Kết luận: chỉ mục mới cải thiện rõ các truy vấn có điều kiện lọc chọn lọc cao (B2, B3) nhưng chỉ cải thiện
hạn chế với truy vấn tổng hợp toàn bộ dữ liệu (B1). Các chỉ mục thử nghiệm đã được xóa sau khi đo và **không
đưa vào schema chính**; nếu triển khai thật, ưu tiên cân nhắc chỉ mục cho B3/B2 thay vì thêm chỉ mục tràn lan.

## 11. Kết luận và hạn chế

Đồ án đã có đầy đủ artifact cho thiết kế, ràng buộc, transaction, truy vấn, SQL động/nhúng, recursive SQL, ODL/OQL và generator. Benchmark ngày 22/10 đã có bằng chứng; các kết quả test SQL, concurrency, Q01–Q25 và ObjectDB cần được chạy lại và lưu theo từng lần chạy. Một số invariant liên bảng phải dùng trigger vì MySQL không hỗ trợ ASSERTION.

## Phụ lục cần bổ sung

Đã có sẵn trong repository:

- `data/benchmark/20261022-danh-win/metadata.md` — metadata môi trường, quy mô dữ liệu và tái lập generator.
- `data/benchmark/20261022-danh-win/benchmark-results.md`, `benchmark-analysis.md` — số liệu benchmark trước/sau chỉ mục và nhận xét.
- `data/benchmark/20261022-danh-win/explain-baseline.txt`, `explain-optimized.txt` — kế hoạch thực thi `EXPLAIN ANALYZE` nguyên văn.
- `report/appendix/danh/sql-injection-demo.txt` — bằng chứng SQL động/SQL Injection ngày 22/10.
- `report/appendix/danh/embedded-sql-demo.txt` — bằng chứng SQL nhúng/cursor ngày 22/10.

Các kết quả test SQL, concurrency, Q01–Q25 và regression của những lần chạy cũ đã được dọn khỏi repo. Mỗi lần chạy mới lưu vào `report/appendix/tests/<run-date>/` và `report/appendix/queries/<run-date>/`.

Còn phải bổ sung trước khi nộp:

- Output đầy đủ Q01–Q25 trên bộ dữ liệu 100.000 đơn (ảnh/CSV từng truy vấn).
- Output ObjectDB/OQ01–OQ05 và bảng ánh xạ JPQL.
- Ảnh chụp terminal cho các phiên demo.
- Nhật ký đóng góp nhóm và bảng phân công việc.

---

# PHỤ LỤC A — Danh mục ràng buộc và trigger (trích từ MySQL 8.4.11)

## A.1. Ràng buộc CHECK và UNIQUE bổ sung (`sql/02_constraints.sql`)

| Bảng | Ràng buộc | Ý nghĩa |
|---|---|---|
| account | `chk_account_email_not_blank`, `chk_account_full_name_not_blank`, `chk_account_password_not_blank` | Chuỗi bắt buộc không rỗng |
| customer / seller | `chk_customer_code_not_blank`, `chk_seller_code_not_blank`, `chk_seller_shop_name_not_blank` | Mã và tên shop không rỗng |
| category / product | `chk_category_name_not_blank`, `chk_category_slug_not_blank`, `chk_product_name_not_blank`, `chk_product_slug_not_blank` | Tên/slug không rỗng |
| product_variant | `chk_variant_price_nonnegative`, `chk_variant_compare_price`, `chk_variant_sku_not_blank` | Giá ≥ 0, giá so sánh ≥ giá bán |
| warehouse | `chk_warehouse_code_not_blank`, `chk_warehouse_name_not_blank` | Mã/tên kho không rỗng |
| address | `chk_address_recipient_not_blank`, `chk_address_phone_not_blank`, `chk_address_line1_not_blank`, `chk_address_city_not_blank`, `chk_address_province_not_blank` | Địa chỉ đầy đủ |
| cart / cart_item | `uq_cart_one_active_per_customer` (cột sinh tự động), `chk_cart_item_quantity` | Một giỏ ACTIVE/khách; số lượng > 0 |
| address | `uq_address_one_default_per_customer` (cột sinh tự động) | Một địa chỉ mặc định/khách |
| inventory | `chk_inventory_values` | `reserved_quantity ≤ quantity_on_hand` |
| promotion | `chk_promotion_window`, `chk_promotion_discount`, `chk_promotion_min_order`, `chk_promotion_max_discount`, `chk_promotion_percent`, `chk_promotion_name_not_blank`, `chk_promotion_code_not_blank` | Cửa sổ thời gian hợp lệ, giảm giá ≥ 0, PERCENT ≤ 100 |
| orders | `chk_order_totals_nonnegative`, `chk_order_discount_not_over_subtotal`, `chk_order_grand_total_formula`, `chk_order_recipient_not_blank` | Tổng ≥ 0, giảm ≤ subtotal, `grand_total = subtotal − discount + shipping` |
| order_item | `chk_order_item_values`, `chk_order_item_line_total_formula`, `chk_order_item_snapshot_not_blank` | `line_total = quantity × unit_price − line_discount`, snapshot không rỗng |
| order_promotion | `chk_order_promotion_discount_nonnegative` | Giảm giá không âm |
| payment / shipment | `chk_payment_amount`, `chk_payment_provider_not_blank`, `chk_shipment_carrier_not_blank` | Số tiền ≥ 0, nhà cung cấp không rỗng |
| review | `chk_review_rating`, `uq_review_customer_product` | Điểm 1–5, mỗi khách đánh giá mỗi sản phẩm một lần |

Tổng cộng: **41 ràng buộc CHECK** bổ sung (ngoài 1 CHECK có sẵn trong `sql/01_schema.sql`) và **2 UNIQUE**
dựa trên cột sinh tự động (`generated always as ... stored`) vì MySQL chưa hỗ trợ UNIQUE có điều kiện.

## A.2. Danh mục trigger (`sql/05_triggers.sql`) — 32 trigger

| Bảng | Trigger (BEFORE/AFTER) | Bảo vệ |
|---|---|---|
| product | `trg_product_validate_category` (B-INS), `trg_product_validate_category_update` (B-UPD) | Danh mục phải ACTIVE |
| product_variant | `trg_product_variant_validate_product` (B-INS), `trg_product_variant_validate_product_update` (B-UPD) | Sản phẩm/kho phải ACTIVE khi đổi |
| cart_item | `trg_cart_item_validate_variant` (B-INS), `trg_cart_item_validate_variant_update` (B-UPD) | Biến thể bán được, giỏ phải ACTIVE |
| inventory | `trg_inventory_no_negative_reserved` (B-INS), `trg_inventory_no_negative_reserved_update` (B-UPD) | Không giữ chỗ vượt tồn kho |
| order_item | `trg_order_item_validate` (B-INS), `trg_order_item_validate_update` (B-UPD) | Tính lại `line_total` |
| order_item | `trg_order_item_immutable_insert/update/delete` (B) | Chỉ sửa dòng hàng khi đơn PENDING_PAYMENT |
| order_item | `trg_order_item_after_insert/update/delete` (A) | Cập nhật `orders.subtotal` và `grand_total` |
| orders | `trg_order_validate_insert` (B-INS), `trg_order_validate_update` (B-UPD) | Công thức tổng, state machine, khớp tổng dòng hàng, cần payment SUCCESS khi PAID |
| orders | `trg_order_restore_stock_on_cancel` (A-UPD) | Hoàn tồn **một lần** khi hủy đơn đã PAID/PROCESSING |
| category | `trg_category_no_cycle_insert` (B-INS), `trg_category_no_cycle_update` (B-UPD) | Không tạo chu trình danh mục |
| review | `trg_review_validate` (B-INS), `trg_review_validate_update` (B-UPD) | Review phải từ đơn DELIVERED của đúng khách/sản phẩm |
| shipment | `trg_shipment_validate_insert` (B-INS), `trg_shipment_validate_update` (B-UPD) | Đơn đã trả tiền mới tạo shipment; state machine vận chuyển |
| payment | `trg_payment_validate_amount_insert` (B-INS), `trg_payment_validate_amount_update` (B-UPD) | Số tiền SUCCESS = `grand_total` |
| order_promotion | `trg_order_promotion_validate_insert` (B-INS), `trg_order_promotion_validate_update` (B-UPD), `trg_order_promotion_immutable_delete` (B-DEL) | Chỉ áp mã khi đơn PENDING_PAYMENT |
| order_promotion | `trg_order_promotion_sum_insert` (A-INS), `trg_order_promotion_sum_update` (A-UPD) | Tổng giảm không vượt subtotal |

## A.3. Thủ tục và hàm (`sql/04_functions.sql`)

| Đối tượng | Loại | Chức năng |
|---|---|---|
| `fn_promotion_discount(subtotal, type, value, max_discount)` | Hàm | Tính tiền giảm, cap theo `max_discount` và theo subtotal |
| `sp_checkout(customer, name, phone, address, fee, codes, OUT order_id)` | Thủ tục | Đặt hàng nguyên tử: khóa giỏ → tạo đơn → khóa tồn kho → trừ kho → ghi dòng hàng → áp mã → thanh toán → commit, có `EXIT HANDLER` rollback |
| `sp_seller_ranking(from, to, limit)` | Thủ tục | Xếp hạng người bán bằng SQL động (`PREPARE`/`EXECUTE` + placeholder) |

# PHỤ LỤC B — Mẫu ghi kết quả kiểm thử

Bảng dưới đây được điền từ output của lần chạy mới nhất; không dùng lại số liệu của lần chạy cũ.

| Tệp test | Số case | Kết quả |
|---|---|---|
| `tests/constraint_tests.sql` | 7 | `[điền từ output]` |
| `tests/promotion_tests.sql` | 4 + 2 kịch bản | `[điền từ output]` |
| `tests/order_tests.sql` | 7 | `[điền từ output]` |
| `sql/09_transaction_tests.sql` | T01, T04, T05 | `[điền từ output]` |
| `tests/concurrency_setup.sql` + 2 phiên | T03 | `[điền từ output]` |
| `python -m unittest tests.test_dynamic_search -v` | 6 | 6/6 PASS |

# PHỤ LỤC C — Độ phủ truy vấn trên dữ liệu lớn

Số dòng trả về của Q01–Q25 sẽ được cập nhật từ lần chạy mới nhất. Q25 bắt buộc trả về **0 dòng vi phạm**.
