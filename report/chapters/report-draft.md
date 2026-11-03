# BÁO CÁO ĐỒ ÁN CSDL NÂNG CAO

## Đề tài 7: CSDL thương mại điện tử và lập trình SQL nâng cao

**Nhóm 7** — Lại Thế Thành, Dương Tấn Tài, Trần Văn Minh Tuấn, Nguyễn Mậu Công Khoa, Phạm Thành Danh.

> Bản báo cáo đã cập nhật số liệu thực nghiệm từ các thư mục bằng chứng ghi ngày cụ thể trong `report/appendix/` và `data/benchmark/`. Không sử dụng số liệu ước lượng; mỗi bảng kết quả đều dẫn tới file output tương ứng.

## Tóm tắt

Đồ án xây dựng một CSDL thương mại điện tử trên MySQL 8.4.11, bao phủ catalog, biến thể theo kho, tồn kho theo người bán, giỏ hàng, đơn hàng, khuyến mãi, thanh toán, vận chuyển và đánh giá. Trọng tâm kỹ thuật gồm: thiết kế EER và chuẩn hóa có kiểm chứng; ràng buộc/trigger bảo vệ bất biến; thủ tục checkout có khóa và transaction; 25 truy vấn nâng cao; SQL động/nhúng an toàn; recursive SQL; mô hình ODL/OQL; và thực nghiệm trên bộ dữ liệu 100.000 đơn hàng.

Kết quả thực nghiệm chính: bộ Q01–Q25 chạy trên 100.000 đơn với Q25 trả 0 vi phạm; T03 hai phiên tranh mua lượng hàng cuối không oversell (B nhận `ERROR 1644` sau 4,04 giây chờ); benchmark 23/10 cải thiện B2 6,7× và B3 108,5× khi thêm chỉ mục có kiểm soát; harness ObjectDB 2.9.5 đạt 16/16 kiểm tra.

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

### 2.3. Vòng đời đơn hàng

State machine của đơn hàng được cài trong trigger `trg_order_validate_update`:

```text
PENDING_PAYMENT → PAID | CANCELLED
PAID            → PROCESSING | CANCELLED
PROCESSING      → SHIPPED | CANCELLED
SHIPPED         → DELIVERED | RETURN_REQUESTED
DELIVERED       → RETURN_REQUESTED
RETURN_REQUESTED→ RETURNED
```

Các chuyển trạng thái khác bị từ chối bằng `SIGNAL SQLSTATE '45000'`. Đơn chỉ được sang `PAID` khi đã có payment `SUCCESS`; đơn sang `PROCESSING/SHIPPED/DELIVERED` phải còn ít nhất một dòng hàng; hủy đơn đã thanh toán/xử lý phải hoàn tồn đúng một lần. Đây là các bất biến được kiểm chứng trong T04 và Q25.

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

### 3.3. Tóm tắt từ điển dữ liệu

| Nhóm | Bảng chính | Định danh nghiệp vụ | Ghi chú |
|---|---|---|---|
| Tài khoản | `account`, `customer`, `seller`, `address` | `email`, `customer_code`, `seller_code` | Kế thừa Account; địa chỉ mặc định có UNIQUE có điều kiện |
| Catalog | `category`, `product`, `product_variant`, `warehouse` | `slug`, `sku`, `warehouse_code` | Category tự tham chiếu; variant gắn product + warehouse |
| Tồn kho | `inventory` | `(seller_id, variant_id)` | Có `quantity_on_hand`, `reserved_quantity`, `reorder_level` |
| Giỏ hàng | `cart`, `cart_item` | `(cart_id, seller_id, variant_id)` | Mỗi khách tối đa một giỏ ACTIVE |
| Đơn hàng | `orders`, `order_item` | `order_number`, `order_item_id` | Snapshot tên/SKU/giá; `line_total` được trigger tính |
| Thanh toán/vận chuyển | `payment`, `shipment` | `payment_reference`, `tracking_number` | Payment SUCCESS phải khớp `grand_total` |
| Khuyến mãi | `promotion`, `order_promotion` | `promotion_code` | Tổng giảm không vượt subtotal; bất biến sau PENDING_PAYMENT |
| Đánh giá | `review` | `(customer_id, product_id)` | Chỉ review sản phẩm trong đơn DELIVERED của đúng khách |

Chi tiết kiểu dữ liệu, NULL/NOT NULL và ràng buộc từng cột nằm trong `docs/05-data-dictionary.md`.

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

### 5.4. Ví dụ bảo vệ bất biến

Trigger `trg_inventory_no_negative_reserved` chặn `reserved_quantity > quantity_on_hand`; trigger `trg_order_item_validate` tính lại `line_total = quantity × unit_price − line_discount`; trigger `trg_order_validate_update` kiểm tra công thức `grand_total`, khớp `subtotal` với tổng dòng hàng, khớp `discount_total` với `order_promotion`, và state machine. Nhờ vậy, ngay cả khi ứng dụng ghi trực tiếp bằng SQL, các bất biến liên bảng vẫn được bảo vệ. Q25 là lớp kiểm tra độc lập cuối cùng: nếu trigger bị vô hiệu hóa hoặc dữ liệu cũ đã sai, Q25 sẽ trả về các dòng vi phạm thay vì im lặng.

### 5.5. Cách ly, thứ tự khóa và chống deadlock

`sp_checkout` chạy trên InnoDB với mức cách ly mặc định `REPEATABLE READ`. Trước khi mở transaction, thủ tục kiểm tra tham số, chuẩn hóa danh sách mã khuyến mãi vào bảng tạm và xác thực khách hàng/phí ship; các bước này không cần khóa. Trong transaction, thủ tục khóa giỏ `ACTIVE` bằng `SELECT ... FOR UPDATE`, tạo order `PENDING_PAYMENT`, rồi khóa từng dòng `inventory` theo thứ tự `(seller_id, variant_id)` do cursor sắp xếp. Cùng thứ tự khóa giữa mọi checkout làm giảm khả năng deadlock; nếu hai checkout có tập hàng khác nhau, chúng vẫn có thể chờ nhau nhưng không thể cùng đọc rồi cùng trừ một dòng kho.

Sau khi khóa, thủ tục kiểm tra `quantity_on_hand - reserved_quantity >= quantity` và dùng `UPDATE ... WHERE ... >= quantity` kèm `ROW_COUNT() = 1`. Đây là kiểm tra phòng thủ kép: điều kiện trong `WHERE` bảo đảm không trừ âm ngay cả khi có thay đổi bất thường, còn `ROW_COUNT` phát hiện trường hợp dòng đã bị thay đổi và hủy checkout. Promotion cũng được khóa theo `promotion_id` để `used_count` không vượt `usage_limit`. Mọi `SQLEXCEPTION` đi qua `EXIT HANDLER` để `ROLLBACK` rồi `RESIGNAL`, nên lỗi được trả về client thay vì bị nuốt.

Thiết kế không dùng `SERIALIZABLE` vì row lock trên đúng các dòng cần thiết đã đủ cho bất biến tồn kho và ít ảnh hưởng đồng thời hơn. Đánh đổi là thủ tục phải giữ transaction ngắn, không gọi mạng hoặc chờ lâu bên trong; T03 cố ý chèn `SLEEP(6)` để mở rộng cửa sổ tranh chấp và chứng minh session B thực sự bị chặn.

## 6. Truy vấn nâng cao

### 6.1. Danh mục và kết quả

Bộ Q01–Q25 nằm trong `sql/06_queries.sql`; Q18–Q20 nằm trong `sql/07_recursive.sql`. Các nhóm kỹ thuật:

- JOIN/OUTER JOIN, NOT EXISTS, phép chia.
- Correlated subquery, GROUP BY/HAVING.
- Window: DENSE_RANK, ROW_NUMBER, LAG, rolling 30 ngày lịch bằng `RANGE`.
- Recursive CTE cho category tree và doanh thu subtree.
- Q21A/Q21B so sánh hai cách viết.
- Q25 kiểm tra bất biến và phải trả 0 dòng.

Lần chạy đầy đủ gần nhất trên 100.000 đơn là ngày 25/10/2026 (`report/appendix/queries/20261025/`). Bảng dưới trích các kết quả tiêu biểu:

| Truy vấn | Kỹ thuật | Kết quả trên 100.000 đơn |
|---|---|---|
| Q01 | Top 10 sản phẩm theo doanh thu | 10 dòng, toàn bộ là iPhone |
| Q02 | Doanh thu theo người bán | 100 dòng |
| Q04 | Khách chưa có đơn thanh toán | 2 dòng |
| Q06 | Tồn kho dưới ngưỡng | 206 dòng |
| Q07 | Khách mua ≥ 3 SKU khác nhau | 9.973 dòng |
| Q08 | SKU giá trên trung bình danh mục | 1.244 dòng |
| Q09 | `EXISTS`: khách vừa mua vừa đánh giá | 12.425 dòng, khớp số review |
| Q11 | Phép chia theo thương hiệu (`@brand_name='Demo'`) | 10.000 dòng; `Demo` không có SKU active nên tập chia rỗng khiến mọi khách thỏa mãn |
| Q12 | Người bán đạt ngưỡng doanh thu | 100 dòng |
| Q13 | Danh mục không có sản phẩm trực tiếp | 9 dòng |
| Q14 | Top 3 SKU mỗi danh mục | 39 dòng |
| Q15 | Xếp hạng người bán | 100 dòng |
| Q16 | Doanh thu theo tháng với `LAG` | 12 dòng (10/2025–09/2026) |
| Q17 | Doanh thu trượt 30 ngày lịch | 365 dòng |
| Q21A/Q21B | So sánh hai cách viết top seller | 10 dòng mỗi cách; Q21B nhanh hơn |
| Q22 | Tỷ lệ trả hàng > 20% | 3.125 dòng |
| Q23 | Hiệu quả khuyến mãi | 10 dòng; `DGIAM30` giảm nhiều nhất |
| Q25 | Kiểm tra bất biến | **0 dòng vi phạm** |

Recursive CTE: Q18 trả 22 dòng cây danh mục; Q19 trả 22 dòng doanh thu subtree; Q20 trả 0 dòng trên dữ liệu lớn vì `slug='dien-tu'` không tồn tại trong generator (trên seed nhỏ trả breadcrumb); kiểm tra chu trình 0 dòng. Q11 và Q20 giữ nguyên bản gốc (`'Demo'`, `slug='dien-tu'`); khác biệt dữ liệu đầu vào giữa seed nhỏ và generator là hạn chế cần diễn giải, không phải lỗi truy vấn.

Q25 bắt buộc trả về **0 dòng** vi phạm và đã đạt trong lần chạy 25/10. Các kết quả của những lần chạy cũ không được dùng thay cho lần chạy mới.

### 6.2. Đọc kế hoạch thực thi

Với các truy vấn có lọc chọn lọc cao, `EXPLAIN ANALYZE` cho thấy MySQL chuyển từ quét bảng sang dùng chỉ mục thử nghiệm. Kế hoạch nguyên văn của bốn truy vấn benchmark nằm trong `data/benchmark/20261023-004420-DESKTOP-97LS755/explain-baseline.txt` và `explain-optimized.txt`. B1 vẫn phải đọc nhiều dòng `order_item`/`payment` để tổng hợp nên chỉ nhanh hơn 1,6×; B2 và B3 lọc theo ngày/điện thoại nên hưởng lợi rõ hơn. Đây là lý do báo cáo không thêm chỉ mục tràn lan vào schema chính: lợi ích phải cân bằng với chi phí ghi và dung lượng.

## 7. SQL động, SQL nhúng và bảo mật

### 7.1. Mô hình mối đe dọa và biện pháp

Tài sản cần bảo vệ là dữ liệu sản phẩm, tài khoản và lịch sử đơn hàng. Bề mặt tấn công của trang tìm kiếm gồm từ khóa, category, khoảng giá, cột sắp xếp, chiều sắp xếp và giới hạn số dòng. Kẻ tấn công không cần đăng nhập vẫn có thể thử payload qua các tham số này. Vì vậy, thiết kế coi mọi giá trị nhập là không tin cậy, kể cả khi giao diện chỉ cho chọn từ dropdown.

Biện pháp chính là tách cấu trúc SQL khỏi dữ liệu. Keyword, category và giá đi qua placeholder `%s` của PyMySQL; tên cột và `ASC`/`DESC` không thể tham số hóa nên lấy từ whitelist cố định. `gioi_han` bị ép về số nguyên trong khoảng 1–100; giá âm và khoảng giá đảo bị từ chối trước khi chạy. Cách này vừa chặn injection vừa tránh truy vấn quá lớn. Với SQL nhúng, cùng nguyên tắc được áp dụng: mọi giá trị truyền qua tham số, transaction do ứng dụng quản lý bằng `commit`/`rollback`, và lỗi từ `sp_checkout` được bắt để in trạng thái trước/sau.

`app/dynamic_search.py` dùng whitelist cho sort/direction và bind parameter cho keyword, category, price. `tests/test_dynamic_search.py` kiểm tra payload injection vẫn nằm trong params, sort/direction lạ bị từ chối, sort theo giá dùng đúng `v.price` và các khoảng giá/giới hạn không hợp lệ bị từ chối trước khi ghép câu lệnh.

`app/embedded_sql.py` minh họa cursor PyMySQL, parameterized query, cập nhật giỏ hàng có kiểm tra tồn tại dòng và gọi checkout.

### 7.2. Kết quả kiểm chứng

Kết quả demo ngày 25/10 trên database 100.000 đơn (`report/appendix/danh/20261025/`):

- Payload `' OR '1'='1' -- ` khi ghép chuỗi trả **2.511 dòng** (toàn bộ biến thể), bản an toàn trả **0 dòng**; payload `UNION SELECT email, password_hash FROM account` làm lộ **10.100 tài khoản** ở bản ghép chuỗi, bản an toàn trả 0 dòng.
- Các giá trị sort ngoài whitelist đều bị từ chối trước khi tạo câu lệnh SQL; bảng `product` sau demo còn nguyên 1.000 sản phẩm.
- `embedded_sql.py` duyệt giỏ 5 món, tổng 5.744.000đ; lần đặt 1.059 cái khi kho còn 59 bị `ERROR 1644` và rollback (số đơn và tồn kho trước/sau không đổi); sửa thành 2 cái thì checkout thành công, đơn `PAID` tổng 6.401.000đ, tồn kho 59 → 57.
- `python -m unittest tests.test_dynamic_search -v` → 6/6 PASS.

Lưu ý: collation `utf8mb4_0900_ai_ci` không phân biệt dấu, nên từ khóa `Ao` có thể khớp `Dao` trong “Dao kéo”; đây là hành vi collation, không phải lỗi injection. Bản an toàn thêm điều kiện giá và sắp xếp nên kết quả đầu tiên là “Áo thun”.

## 8. CSDL hướng đối tượng

### 8.1. Mô hình và truy vấn

`object-db/model/ecommerce.odl` khai báo 6 lớp và struct `OrderLine`; `object-db/queries/ecommerce.oql` có 5 truy vấn OQL kèm kết quả mong đợi. Các phương thức `lifetimeValue()`, `revenue()`, `activeVariants()`, `isAvailable()`, `total()`, `canTransitionTo()` thể hiện hành vi nghiệp vụ.

Kết quả ObjectDB thực tế đã được chạy bằng harness Maven/JPA trong `object-db/` trên Java 25 với ObjectDB 2.9.5 (jakarta). Bộ dữ liệu mẫu cố định gồm 3 khách hàng, 3 người bán, 3 sản phẩm, 5 biến thể và 5 đơn hàng. Kết quả: OQ01 trả `ORD-1001`; OQ02 trả `Laptop Pro`; OQ03 trả `Shop Alpha`; OQ04 trả Alice `3350.00`, Bob `50.00`, Carol `0.00`; OQ05 trả `ORD-1002` với 1 dòng `SKU-LAP-16`, total `1800.00`. Bảy kiểm tra từ 5 truy vấn (OQ05 có 3 kiểm tra) và chín kiểm tra phương thức nghiệp vụ đều đạt, tổng cộng **16/16 PASS**. Output đầy đủ và bảng ánh xạ OQL → JPQL nằm trong `report/appendix/objectdb/20261102/oql-output.md`; dạng JPQL thực thi nằm trong `object-db/queries/ecommerce.jpql`. Do ObjectDB 2.9.5 chưa hỗ trợ `CASE`/`COALESCE`, OQ04 dùng hai truy vấn (lấy đủ khách hàng và tổng theo trạng thái) rồi ghép trong Java.

### 8.2. Ánh xạ ODL/JPA và bài học

Lớp `OrderLine` là ví dụ rõ nhất về việc mô hình đối tượng phải giữ đủ ngữ nghĩa quan hệ. Ban đầu dòng hàng chỉ tham chiếu biến thể, nên doanh thu theo người bán có nguy cơ cộng trùng khi hai người bán cùng bán một SKU. Bản sửa thêm quan hệ `Seller seller` với `@ManyToOne(optional=false)` và `@JoinColumn(name="seller_id", nullable=false)`, đồng thời constructor `OrderLine.of(...)` nhận `Seller`. Nhờ đó mỗi dòng hàng có đúng người bán tại thời điểm đặt, và `Seller.revenue(Collection<Order>)` lọc theo `isSameSeller(line.getSeller())` thay vì suy ra từ sản phẩm.

Tương tự, `Product.activeVariants()` trả `Set<ProductVariant>` thay vì `List` để tránh trùng lặp khi một biến thể xuất hiện qua nhiều đường ánh xạ. Các thay đổi này không làm thay đổi kết quả OQL nhưng làm mô hình đúng hơn và giữ 16/16 kiểm tra. Harness cũng xác nhận `persistence.xml` dùng namespace JPA 2.1 tương thích ObjectDB 2.9.5, còn code dùng API Jakarta 3.1; cảnh báo `sun.misc.Unsafe` trên Java 25 không ảnh hưởng kết quả.

## 9. Transaction và đồng thời

### 9.1. Danh mục kịch bản

Các kịch bản:

- T01 checkout thành công.
- T02 rollback sau khi đã tạo order/trừ kho bằng mã hết lượt (`tests/order_tests.sql`, mã `LIMIT0`).
- T03 hai session tranh mua lượng hàng cuối.
- T04 chuyển trạng thái sai.
- T05 savepoint.
- T06 nhiều mã, một mã lỗi.

### 9.2. Kết quả T03

Kết quả T03 trên database riêng `ecommerce_t03` (schema + seed nhỏ, không dùng database 100.000 đơn):

| Hạng mục | Kết quả |
|---|---|
| Setup | `CUS2001`/`CUS2002` mỗi người 1 giỏ, `available_stock = 1` |
| Session A | khóa inventory, trừ 1 → 0, tạo order `PAID` tổng `100000.00`, 1 payment |
| Session B | bắt đầu sau 2 giây, chờ khóa **4,04 giây**, nhận `ERROR 1644 (45000): insufficient inventory` |
| Kiểm tra cuối | kho 0; `CUS2001` có 1 order PAID; `CUS2002` có 0 order PAID; 1 payment SUCCESS |

Kịch bản chứng minh không oversell: hai phiên không thể cùng trừ một đơn vị tồn kho cuối; B không để lại order/payment mồ côi. Log T03 ngày 23/10 là log của script cũ, không dùng làm bằng chứng không oversell.

Các kịch bản T01, T04, T05, T06 có output tại `report/appendix/tests/20261023/`; T02 nằm trong `tests/order_tests.sql` với `ORDER_DATA_OK=0`. Mỗi lần chạy mới lưu output vào `report/appendix/tests/<run-date>/`.

### 9.3. Vì sao T03 chứng minh không oversell

Cả hai phiên cùng đi qua `sp_checkout` và cùng cần khóa dòng `inventory` của `SKU-DEMO-001` tại `SEL0001`. Session A khóa dòng này trước, trừ kho và giữ khóa trong 6 giây trước khi commit. Session B không thể đọc dòng kho để kiểm tra trong lúc A chưa commit, nên bị chặn 4,04 giây. Sau khi A commit, B đọc lại và thấy `quantity_on_hand - reserved_quantity = 0`, do đó `SIGNAL SQLSTATE '45000'` với thông điệp `insufficient inventory`. Toàn bộ transaction B rollback, nên order `PENDING_PAYMENT` và payment (nếu đã ghi) không tồn tại.

Điểm quan trọng là B không dựa vào việc đọc trước rồi ghi sau; nó khóa, kiểm tra và cập nhật trong cùng transaction. Nếu chỉ kiểm tra bằng `SELECT` thường rồi mới `UPDATE`, hai phiên có thể cùng thấy kho còn 1 và cùng trừ, dẫn đến oversell hoặc kho âm. Việc A giữ khóa 6 giây chỉ để kéo dài cửa sổ tranh chấp; trong vận hành thật, thời gian giữ khóa được giữ ngắn.

## 10. Dữ liệu lớn và benchmark

### 10.1. Phương pháp và kết quả

Hai nguồn dữ liệu được dùng tách biệt, trên hai database khác nhau:

| Nguồn | Nội dung | Phạm vi sử dụng |
|---|---|---|
| `sql/03_seed_small.sql` | Dữ liệu mẫu nhỏ (vài dòng cho mỗi bảng, fixture `CUS0001`/`SEL0001`/`SKU-DEMO-001`) | Database mẫu `ecommerce_advanced`: test, demo, chạy Q01–Q25 trên dữ liệu nhỏ |
| `data/generator/generate_data.py` | Dữ liệu lớn 100.000 đơn (seed cố định, mã theo namespace `DCUS*`/`DSEL*`/`DSKU*`) | Database benchmark riêng: benchmark và kiểm chứng query; các lần chạy mới dùng database sạch không seed |

Generator tạo 100.000 đơn với seed cố định (`--seed 20261003`), nhiều trạng thái, review và tồn kho thấp. Lần chạy 25/10/2026 trên database sạch (không nạp seed nhỏ) mất **406,5 giây**, tạo 100.000 đơn, 200.294 dòng hàng, 89.861 payment, 44.783 shipment, 12.425 review, 10.000 khách, 100 người bán, 1.000 sản phẩm, 2.511 biến thể, 3.750 dòng tồn kho và 22 danh mục. Tổng tiền và vân tay dữ liệu trùng khớp qua hai lần chạy độc lập; chi tiết trong `report/appendix/queries/20261025/README.md`.

Benchmark ngày 23/10/2026 chạy bằng `data/benchmark/run_benchmark.py`: warmup 3 lần, đo 7 lần, lấy trung vị; `EXPLAIN ANALYZE` baseline, tạo chỉ mục thử nghiệm, đo optimized và chi phí ghi/dung lượng. Metadata: 100.000 đơn, 200.329 dòng hàng, 89.908 payment.

Kết quả thực tế (`data/benchmark/20261023-004420-DESKTOP-97LS755/benchmark-results.md`):

| Mã | Truy vấn đo | Trước | Sau khi thêm chỉ mục thử nghiệm | Nhanh hơn |
|---|---|---|---|---|
| B1 | Top 10 sản phẩm theo doanh thu | 3.297,26 ms | 2.074,29 ms | 1,6× |
| B2 | Doanh thu theo ngày trong tháng 03/2026 | 97,69 ms | 14,69 ms | 6,7× |
| B3 | Tra cứu đơn theo số điện thoại người nhận | 88,69 ms | 0,82 ms | 108,5× |
| B4 | 10 đơn gần nhất của một khách (đối chứng) | 1,27 ms | 1,22 ms | ~không đổi |
| — | Chi phí ghi 89.908 dòng `payment` | 4.449,21 ms | 5.251,58 ms | +18% |

Dung lượng chỉ mục tăng thêm 8.752 KB (`order_item`), 3.600 KB (`payment`) và 3.600 KB (`orders`); thời gian tạo ba chỉ mục lần lượt 1.706,52 ms, 581,38 ms và 898,10 ms.

Kết luận: chỉ mục mới cải thiện rõ các truy vấn có điều kiện lọc chọn lọc cao (B2, B3) nhưng chỉ cải thiện
hạn chế với truy vấn tổng hợp toàn bộ dữ liệu (B1), đồng thời làm chi phí ghi tăng 18%. Các chỉ mục thử nghiệm đã được xóa sau khi đo và **không
đưa vào schema chính**; nếu triển khai thật, ưu tiên cân nhắc chỉ mục cho B3/B2 thay vì thêm chỉ mục tràn lan.

### 10.2. Độ tin cậy và giới hạn của phép đo

- Benchmark chạy trên một máy Windows 11, buffer pool 128 MB; chưa đo trên phần cứng khác hoặc MySQL phiên bản khác.
- Mỗi truy vấn được warmup 3 lần và đo 7 lần, lấy trung vị; số liệu vẫn có thể dao động khi hệ điều hành hoặc ổ đĩa bận.
- Dữ liệu 100.000 đơn là dữ liệu tổng hợp có seed cố định, không phải dữ liệu sản xuất; phân bố trạng thái và độ chọn lọc có thể khác thực tế.
- Chi phí ghi được đo bằng cách chép 89.908 dòng `payment` sang bảng tạm; đây là proxy, không phải benchmark OLTP đầy đủ.
- Kết quả Q01–Q25 và benchmark đến từ hai lần sinh dữ liệu độc lập (25/10 và 23/10), nên số dòng `order_item`/`payment` chênh lệch nhỏ; không so sánh trực tiếp từng con số giữa hai lần chạy.

### 10.3. Diễn giải và khuyến nghị

B3 là truy vấn tra cứu đơn theo số điện thoại người nhận, có độ chọn lọc cao; chỉ mục thử nghiệm giúp giảm từ 88,69 ms xuống 0,82 ms, tức khoảng 108,5×. B2 lọc theo khoảng ngày trong một tháng nên cũng hưởng lợi lớn (6,7×). B1 vẫn phải tổng hợp gần như toàn bộ `order_item` và `payment` để tính top 10, nên chỉ mục không loại bỏ được khối lượng đọc; mức 1,6× chủ yếu đến từ việc giảm chi phí truy cập. B4 đã có chỉ mục phù hợp nên gần như không đổi (1,27 ms so với 1,22 ms), đúng kỳ vọng và là đối chứng cho thấy không phải truy vấn nào cũng cần chỉ mục mới.

Chi phí ghi tăng 18% là đánh đổi thực tế: mỗi chỉ mục thêm phải được cập nhật khi chèn/xóa dòng. Dung lượng tăng thêm 8.752 KB cho `order_item`, 3.600 KB cho `payment` và 3.600 KB cho `orders`, trong khi thời gian tạo chỉ mục lần lượt 1.706,52 ms, 581,38 ms và 898,10 ms. Vì vậy báo cáo không đưa các chỉ mục thử nghiệm vào schema chính; nếu triển khai thật, nên thêm chỉ mục cho B3/B2 sau khi đo trên dữ liệu sản xuất, đồng thời cân nhắc partition theo thời gian cho bảng đơn hàng và read replica cho báo cáo.

## 11. Kết luận và hạn chế

Đồ án đã có đầy đủ artifact cho thiết kế, ràng buộc, transaction, truy vấn, SQL động/nhúng, recursive SQL, ODL/OQL và generator. Bằng chứng thực nghiệm hiện có: test SQL ngày 23/10, Q01–Q25 ngày 25/10 (Q25 = 0 vi phạm), T03 (không oversell), benchmark ngày 23/10 và ObjectDB ngày 02/11 (16/16 PASS). Một số invariant liên bảng phải dùng trigger vì MySQL không hỗ trợ ASSERTION.

Hạn chế chính: Q11 giữ nguyên `@brand_name := 'Demo'`; khi dữ liệu lớn không có SKU của thương hiệu này, tập chia rỗng khiến mọi khách hàng đều thỏa mãn — đây là đúng logic phép chia cho tập rỗng và cần được diễn giải rõ, không phải lỗi truy vấn. Q20 giữ `slug='dien-tu'`, nên có thể trả rỗng trên dữ liệu generator; đây là hạn chế dữ liệu đầu vào. Benchmark chỉ chạy trên một máy, một cấu hình buffer pool; chưa đo trên phần cứng khác hoặc dữ liệu lớn hơn 100.000 đơn. Báo cáo/slide vẫn cần hoàn thiện hình ảnh demo và nhật ký đóng góp nhóm.

## Phụ lục và bằng chứng

Đã có sẵn trong repository:

- `data/benchmark/20261023-004420-DESKTOP-97LS755/metadata.md` — metadata môi trường, quy mô dữ liệu và tái lập generator.
- `data/benchmark/20261023-004420-DESKTOP-97LS755/benchmark-results.md` — số liệu benchmark trước/sau chỉ mục và nhận xét.
- `data/benchmark/20261023-004420-DESKTOP-97LS755/explain-baseline.txt`, `explain-optimized.txt` — kế hoạch thực thi `EXPLAIN ANALYZE` nguyên văn.
- `report/appendix/queries/20261025/` — output Q01–Q25 (Q11/Q20 giữ bản gốc) và recursive SQL trên 100.000 đơn, kèm README môi trường và phát hiện.

- `report/appendix/tests/20261023/` — test SQL và transaction của lần chạy 23/10 (không dùng log T03 cũ).
- `report/appendix/danh/20261025/` — bằng chứng SQL động/SQL Injection và SQL nhúng ngày 25/10.
- `report/appendix/objectdb/20261102/oql-output.md` — bằng chứng ObjectDB 2.9.5, 16/16 PASS.

Còn phải bổ sung trước khi nộp:

- Ảnh chụp terminal cho các phiên demo (có thể dùng ảnh đã có trong `data/benchmark/` và `report/appendix/danh/`).
- Nhật ký đóng góp nhóm và bảng phân công việc.
- Rà soát hình thức báo cáo (mục lục, đánh số bảng/hình, tài liệu tham khảo).

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
| `tests/constraint_tests.sql` | 7 | 7/7 PASS; 5 bất biến trả `0` |
| `tests/promotion_tests.sql` | 4 + 2 kịch bản | 4/4 case lỗi PASS; A đúng `20000/110000`, B đúng `100000/30000` |
| `tests/order_tests.sql` | 7 | 7/7 PASS; `orders/stock` không đổi; `ORDER_DATA_OK=0` |
| `sql/09_transaction_tests.sql` | T01, T05 (T03/T04/T06 chạy thủ công) | T01 và T05 PASS; T04/T06 PASS ở log thủ công |
| `tests/concurrency_setup.sql` + 2 phiên | T03 | A giữ khóa 6 giây; B chờ 4,04 giây rồi nhận `ERROR 1644`; kho 0; CUS2001 đúng 1 order PAID; CUS2002 0 order |
| `python -m unittest tests.test_dynamic_search -v` | 6 | 6/6 PASS |

Bằng chứng test SQL/transaction/regression ngày 23/10: `report/appendix/tests/20261023/`.

# PHỤ LỤC C — Độ phủ truy vấn trên dữ liệu lớn

Q01–Q25 đã chạy trên 100.000 đơn; output đầy đủ tại `report/appendix/queries/20261025/06_queries_100k.txt` và `07_recursive_100k.txt`. Q25 trả về **0 dòng vi phạm**. Q11 và Q20 giữ nguyên bản gốc (`@brand_name='Demo'`, `slug='dien-tu'`); Q11 tạo tập chia rỗng, Q20 trả rỗng trên dữ liệu lớn (trên seed nhỏ trả breadcrumb); kiểm tra chu trình 0 dòng. Đây là khác biệt dữ liệu đầu vào, không phải lỗi truy vấn.
