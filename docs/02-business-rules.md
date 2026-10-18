# Quy tắc nghiệp vụ và toàn vẹn dữ liệu

## A. Tài khoản và actor

| ID | Quy tắc | Cơ chế đề xuất |
| --- | --- | --- |
| BR-001 | Email tài khoản là duy nhất, không rỗng | UNIQUE, NOT NULL |
| BR-002 | Customer và Seller là subtype của Account; một Account có thể đồng thời là Customer và Seller | EER overlapping specialization + FK 1:1 |
| BR-003 | Seller phải ở trạng thái active mới được bán | CHECK + trigger/procedure |
| BR-004 | Seller phải có shop name duy nhất | UNIQUE |

## B. Catalog

| ID | Quy tắc | Cơ chế đề xuất |
| --- | --- | --- |
| BR-010 | Product thuộc đúng một Seller | FK |
| BR-011 | Product phải có tên và trạng thái hợp lệ | NOT NULL + CHECK |
| BR-012 | SKU của variant phải là duy nhất trên toàn hệ thống | UNIQUE |
| BR-013 | Giá niêm yết và giá bán không âm; giá bán không vượt giá niêm yết nếu dùng cả hai | CHECK |
| BR-014 | Variant thuộc đúng một Product và đúng một Warehouse | FK |
| BR-015 | Variant phải có SKU; combination (warehouse_id, product_id, color, size) không được trùng | UNIQUE(warehouse_id, product_id, color, size) |
| BR-016 | Variant chỉ lưu metadata giá/thuộc tính; số lượng tồn kho không được lưu ở variant | model rule / trigger |
| BR-017 | Category có tối đa một parent trực tiếp | FK tự tham chiếu |
| BR-018 | Category không được tạo chu trình | trigger/procedure |
| BR-019 | Product chỉ được gán category đang active | FK + trigger |

## C. Cart

| ID | Quy tắc | Cơ chế đề xuất |
| --- | --- | --- |
| BR-020 | Customer có tối đa một cart ACTIVE tại một thời điểm | partial unique index / trigger |
| BR-021 | CartItem chỉ chứa variant đang bán được và có inventory tương ứng | FK + trigger |
| BR-022 | Quantity của CartItem phải > 0 | CHECK |
| BR-023 | Một cart không có hai dòng cho cùng seller/variant | UNIQUE(cart_id, seller_id, variant_id) |

## D. Inventory

| ID | Quy tắc | Cơ chế đề xuất |
| --- | --- | --- |
| BR-030 | Inventory được xác định bởi (seller_id, warehouse_id, variant_id) | UNIQUE(seller_id, warehouse_id, variant_id) |
| BR-031 | Quantity on hand và reserved quantity không âm | CHECK |
| BR-032 | Reserved quantity không vượt quantity on hand | CHECK |
| BR-033 | Khi đặt hàng thành công, hệ thống không được làm tồn kho khả dụng âm | transaction + locking |
| BR-034 | Một variant có thể tồn tại ở nhiều warehouse; stock thực tế được lưu trong Inventory | model rule |
| BR-035 | Mọi thay đổi tồn kho do order phải nằm trong transaction và có kiểm soát concurrency | row lock / atomic update |
| BR-036 | ProductVariant không lưu `warehouse_quantity`; lượng tồn là dữ liệu của Inventory | design rule |

## E. Order

| ID | Quy tắc | Cơ chế đề xuất |
| --- | --- | --- |
| BR-040 | Order thuộc đúng một Customer | FK |
| BR-041 | Order phải có ít nhất một OrderItem | trigger / application validation |
| BR-042 | OrderItem lưu snapshot unit_price và SKU/giá trị tại thời điểm đặt hàng; thay đổi giá sau đó không sửa lịch sử | snapshot columns |
| BR-043 | Quantity OrderItem > 0 | CHECK |
| BR-044 | Line total = quantity × unit_price − line_discount | trigger / application logic |
| BR-045 | Subtotal bằng tổng line_total trước discount/shipping | trigger / aggregate |
| BR-046 | Grand total = subtotal − discount_total + shipping_fee; không được âm | CHECK + trigger |
| BR-047 | Order number là duy nhất | UNIQUE |
| BR-048 | Chỉ transition theo state machine hợp lệ | trigger / application state machine |
| BR-049 | Hủy đơn phải hoàn phần tồn đã reserve theo đúng transaction | transaction + trigger |
| BR-050 | Không xóa cứng order đã phát sinh giao dịch; dùng status/soft lifecycle | business rule |
| BR-051 | Order lưu snapshot địa chỉ người nhận và cho phép liên kết với address_id (nullable) | address_id + snapshot columns |

## F. Promotion

| ID | Quy tắc | Cơ chế đề xuất |
| --- | --- | --- |
| BR-060 | Promotion có start_at < end_at | CHECK |
| BR-061 | Promotion chỉ áp dụng khi ACTIVE và thời điểm hiện tại nằm trong hiệu lực | trigger / application logic |
| BR-062 | Discount percent nằm trong [0,100]; fixed amount không âm | CHECK |
| BR-063 | Không áp dụng promotion ngoài scope product/category đã cấu hình | trigger / application logic |
| BR-064 | Coupon code, nếu có, là duy nhất | UNIQUE |
| BR-065 | Không cho tổng discount làm grand total âm | CHECK |
| BR-066 | OrderPromotion lưu snapshot discount đã áp dụng để lịch sử không phụ thuộc cách tính sau này | snapshot table |
| BR-067 | Mỗi lần redeem promotion phải có record trong promotion_usage để audit và tránh race condition | separate usage table |

## G. Payment và shipment

| ID | Quy tắc | Cơ chế đề xuất |
| --- | --- | --- |
| BR-070 | Payment thuộc một Order; payment reference từ gateway là duy nhất khi có | FK + UNIQUE |
| BR-071 | Không chuyển Order sang PAID nếu payment chưa thành công | trigger / application logic |
| BR-072 | Shipment chỉ được tạo khi order đủ điều kiện fulfillment | trigger / application logic |
| BR-073 | Tracking number duy nhất khi có | UNIQUE |
| BR-074 | Shipment state phải chuyển theo transition hợp lệ | state machine |

## H. Review

| ID | Quy tắc | Cơ chế đề xuất |
| --- | --- | --- |
| BR-080 | Rating nằm trong [1,5] | CHECK |
| BR-081 | Customer phải có OrderItem của product trong order đã DELIVERED mới được review | trigger / application logic |
| BR-082 | Một customer chỉ có một review cho một product theo chính sách hiện tại | UNIQUE(customer_id, product_id) |
| BR-083 | Review không hợp lệ phải bị từ chối trước khi commit | trigger / validation |

## I. Transaction và concurrency

| ID | Quy tắc | Cơ chế đề xuất |
| --- | --- | --- |
| BR-090 | Checkout là một đơn vị nguyên tử: tạo order + items + promotion + payment + inventory phải nhất quán | transaction |
| BR-091 | Nếu bất kỳ bước lõi nào thất bại thì rollback toàn bộ phần transaction đó | rollback semantics |
| BR-092 | Hai session cùng mua số lượng cuối không được tạo oversell | locking / atomic update |
| BR-093 | Cập nhật inventory phải khóa đúng dòng hoặc dùng atomic update có điều kiện | row lock / conditional update |
| BR-094 | Trigger/procedure không được để invariant bị vi phạm sau statement/transaction | validation layer |

## J. Quy tắc kỹ thuật

- PK dùng kiểu số nguyên unsigned cho bảng lõi; mã nghiệp vụ như order_number, sku có UNIQUE riêng.
- Tiền dùng DECIMAL, không dùng FLOAT/DOUBLE cho giá trị tài chính.
- Thời gian dùng DATETIME và lưu UTC ở tầng ứng dụng/database theo thống nhất của nhóm.
- Xóa dữ liệu master phải cân nhắc lịch sử; order và order item giữ lại để audit.
- Dữ liệu đầu vào dynamic SQL phải bind parameter; tên cột/sort direction phải qua whitelist.
- Variant chỉ chứa metadata và giá, không chứa lượng tồn kho; lượng tồn thuộc Inventory.
- PromotionUsage được dùng để audit và phát hiện race condition khi nhi��u checkout cùng lúc.
- Order lưu snapshot dữ liệu để bảo toàn lịch sử dù dữ liệu nguồn (address, price, promotion, product) có thay đổi sau đó.
