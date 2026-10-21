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

Kết quả thực tế (chạy ngày 2026-10-21 trên MySQL 8.4.11): toàn bộ Q01–Q25 và các truy vấn đệ quy chạy
**không lỗi**; Q25 trả về **0 dòng** cả trên dữ liệu mẫu nhỏ lẫn trên bộ 100.000 đơn
(`report/appendix/tests/06-queries-sample.txt`, `report/appendix/benchmark/q25-invariant-check.sql`).

## 7. SQL động, SQL nhúng và bảo mật

`app/dynamic_search.py` dùng whitelist cho sort/direction và bind parameter cho keyword, category, price, brand, rating. `tests/test_dynamic_search.py` kiểm tra payload injection vẫn nằm trong params, sort/direction lạ bị từ chối và sort theo giá dùng đúng `v.price`.

`app/embedded_sql.py` minh họa cursor PyMySQL, parameterized query, cập nhật giỏ hàng có kiểm tra tồn tại dòng và gọi checkout.

Kết quả chạy thật (`report/appendix/tests/09-app-dynamic-embedded.txt`):

- Payload `'; DROP TABLE product; --` trong keyword → trả về 0 dòng, không lỗi, bảng `product` còn nguyên.
- Ba giá trị sort ngoài whitelist đều bị từ chối trước khi tạo câu lệnh SQL.
- `change_cart_quantity` đổi số lượng 1 → 2; `checkout` tạo đơn `PAID` với `subtotal = 200.000`,
  `shipping_fee = 30.000`, `grand_total = 230.000`, 1 payment, 1 dòng hàng.
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

Kết quả thực tế (`report/appendix/tests/03-order-tests.txt`, `08-concurrency-two-sessions.txt`):

- Rollback: `orders_after = orders_before` (2 = 2), `stock_after = stock_before` (18 = 18), giỏ vẫn
  `ACTIVE`, `promotion.used_count` không đổi → không còn đơn mồ côi hay tồn kho bị trừ dở.
- T03: session B bị **block ~4,2 s** trên khóa dòng `inventory` (session A giữ khóa 6 s), sau đó mới tạo được đơn.
  Session C bị từ chối với `insufficient inventory` → **không oversell**.
- Trạng thái cuối: tồn kho 0, số `payment` = số đơn `PAID` = 4, không có dòng thanh toán mồ côi.

## 10. Dữ liệu lớn và benchmark

Generator tạo 100.000 đơn với seed cố định (`--seed 20261003`, 6,5 phút), nhiều trạng thái, review và tồn kho thấp. `sql/08_benchmark.sql` chạy baseline và optimized với `EXPLAIN ANALYZE`, đo metadata và chi phí ghi/dung lượng.

Kết quả thực tế (`report/appendix/benchmark/`):

| Truy vấn đo | Baseline | Sau khi thêm 3 chỉ mục thử nghiệm |
|---|---|---|
| Doanh thu theo sản phẩm | 3.588 ms / 3.509 ms | 3.612 ms |
| Doanh thu theo người bán theo khoảng thời gian | 2.280 ms / 2.319 ms | 2.285 ms |
| Quét tồn kho dưới ngưỡng đặt lại | 0,18 ms (table scan) | 3,08 ms (covering index scan) |
| Chi phí ghi 10.000 INSERT | 799,53 ms | 1.048,40 ms (+31%) |

Kết luận: lược đồ chỉ mục sẵn có đã đủ cho các truy vấn phân tích chính; các chỉ mục thử nghiệm không được
trình tối ưu chọn và làm tăng chi phí ghi nên **không đưa vào schema chính**. Với bài toán quét tồn kho quy
mô lớn, hướng đúng là dùng bảng tổng hợp theo ngày.

## 11. Kết luận và hạn chế

Đồ án đã có đầy đủ artifact cho thiết kế, ràng buộc, transaction, truy vấn, SQL động/nhúng, recursive SQL, ODL/OQL và generator. Hạn chế chính là các kết quả benchmark/ObjectDB/concurrency cần được chạy thật và điền vào báo cáo; một số invariant liên bảng phải dùng trigger vì MySQL không hỗ trợ ASSERTION.

## Phụ lục cần bổ sung

Đã có sẵn trong repository (`report/appendix/`):

- `benchmark/00-environment.md` — metadata môi trường, quy mô dữ liệu 100.000 đơn.
- `benchmark/01-baseline.txt`, `02-optimized.txt` — kế hoạch thực thi `EXPLAIN ANALYZE` nguyên văn.
- `benchmark/03-write-cost.md` — chi phí ghi và dung lượng khi thêm chỉ mục.
- `benchmark/q25-invariant-check.sql` — truy vấn kiểm tra bất biến (0 vi phạm).
- `benchmark/04-query-coverage-100k.txt` — số dòng trả về của các truy vấn kiểm chứng dữ liệu.
- `tests/01…07-*.txt` — output constraint/promotion/order/transaction/concurrency và mẫu kết quả truy vấn.
- `tests/08-concurrency-two-sessions.txt` — bằng chứng khóa dòng và không oversell.
- `tests/09-app-dynamic-embedded.txt` — bằng chứng SQL động/SQL nhúng chống injection.
- `tests/regression/2026-10-21.md` — báo cáo hồi quy đầy đủ.

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

# PHỤ LỤC B — Bảng kết quả kiểm thử (đã chạy thật)

| Tệp test | Số case | Kết quả |
|---|---|---|
| `tests/constraint_tests.sql` | 7 | 7/7 PASS; 5 truy vấn bất biến = 0 |
| `tests/promotion_tests.sql` | 4 + 2 kịch bản | 4/4 PASS; A: 20.000/110.000; B: 100.000/30.000 |
| `tests/order_tests.sql` | 7 | 7/7 PASS; rollback giữ nguyên đơn/tồn kho/giỏ; `ORDER_DATA_OK` = 0 |
| `sql/09_transaction_tests.sql` | T01, T04, T05 | T01 tạo đơn PAID đúng tổng; T05 savepoint hoàn tác đúng |
| `tests/concurrency_setup.sql` + 2 phiên | T03 | B chờ khóa ~4,2 s; C `insufficient inventory`; tồn kho cuối 0 |
| `python -m unittest tests.test_dynamic_search -v` | 6 | 6/6 PASS |

# PHỤ LỤC C — Độ phủ truy vấn trên 100.000 đơn

| Truy vấn | Số dòng trả về | Ý nghĩa |
|---|---|---|
| Q06 (SKU tồn thấp) | 216 | Có dữ liệu tồn kho thấp để kiểm chứng |
| Q09 (khách đã đánh giá) | 20.000 | Review sinh từ đơn DELIVERED |
| Q15 (xếp hạng người bán) | 100 | DENSE_RANK trên 100 người bán |
| Q19 (doanh thu cây danh mục) | 110 | 10 gốc + 100 nhánh |
| Q22 (tỷ lệ hoàn trả) | 981 | Nhóm khách hàng "return-prone" |
| Q24 (sản phẩm sắp hết) | 20 | Sản phẩm nhiều biến thể nhưng tồn thấp |
| Q25 (vi phạm bất biến) | 0 | Bắt buộc — dữ liệu sạch bất biến |
