# Quy tắc nghiệp vụ và toàn vẹn dữ liệu

## A. Tài khoản và actor

| ID     | Quy tắc                                                                                                 | Cơ chế đề xuất                     |
| ------ | -------------------------------------------------------------------------------------------------------- | --------------------------------------- |
| BR-001 | Email tài khoản là duy nhất, không rỗng                                                            | `UNIQUE`, `NOT NULL`                |
| BR-002 | Customer và Seller là subtype của Account; một Account có thể đồng thời là Customer và Seller | EER overlapping specialization + FK 1:1 |
| BR-003 | Seller phải ở trạng thái active mới được bán                                                    | CHECK + procedure/trigger               |
| BR-004 | Seller phải có shop name duy nhất                                                                     | `UNIQUE`                              |

## B. Catalog

| ID     | Quy tắc                                                                                             | Cơ chế                     |
| ------ | ---------------------------------------------------------------------------------------------------- | ---------------------------- |
| BR-010 | Product thuộc đúng một Seller                                                                    | FK                           |
| BR-011 | Product phải có tên và trạng thái hợp lệ                                                     | NOT NULL + CHECK             |
| BR-012 | SKU là duy nhất toàn hệ thống                                                                   | UNIQUE                       |
| BR-013 | Giá niêm yết và giá bán không âm; giá bán không vượt giá niêm yết nếu dùng cả hai | CHECK                        |
| BR-014 | Variant thuộc đúng một Product                                                                   | FK                           |
| BR-015 | Variant phải có SKU; combination màu/size của cùng Product không được trùng                | UNIQUE(Product, color, size) |
| BR-016 | Category có tối đa một parent trực tiếp                                                        | FK tự tham chiếu           |
| BR-017 | Category không được tạo chu trình                                                              | trigger/procedure            |
| BR-018 | Product chỉ được gán category đang active                                                      | FK + trigger                 |

## C. Cart

| ID     | Quy tắc                                                       |
| ------ | -------------------------------------------------------------- |
| BR-020 | Customer có tối đa một cart ACTIVE tại một thời điểm. |
| BR-021 | CartItem chỉ chứa variant đang bán được.                |
| BR-022 | Quantity của CartItem phải > 0.                              |
| BR-023 | Một cart không có hai dòng cho cùng variant.              |

## D. Inventory

| ID     | Quy tắc                                                                                        |
| ------ | ----------------------------------------------------------------------------------------------- |
| BR-030 | Inventory được xác định bởi (Warehouse, Variant).                                        |
| BR-031 | Quantity on hand và reserved quantity không âm.                                              |
| BR-032 | Reserved quantity không vượt quantity on hand.                                               |
| BR-033 | Khi đặt hàng thành công, hệ thống không được làm tồn kho khả dụng âm.           |
| BR-034 | Một variant có thể tồn tại ở nhiều warehouse.                                            |
| BR-035 | Mọi thay đổi tồn kho do order phải nằm trong transaction và có kiểm soát concurrency. |

## E. Order

| ID     | Quy tắc                                                                                                                 |
| ------ | ------------------------------------------------------------------------------------------------------------------------ |
| BR-040 | Order thuộc đúng một Customer.                                                                                       |
| BR-041 | Order phải có ít nhất một OrderItem.                                                                                |
| BR-042 | OrderItem lưu snapshot unit_price tại thời điểm đặt hàng; thay đổi giá Product về sau không sửa lịch sử. |
| BR-043 | Quantity OrderItem > 0.                                                                                                  |
| BR-044 | Line total = quantity × unit price − line discount theo chính sách.                                                  |
| BR-045 | Subtotal bằng tổng line total trước cấp order discount/shipping.                                                    |
| BR-046 | Grand total = subtotal − discount + shipping fee + các khoản được mô hình hóa. Không được âm.              |
| BR-047 | Order number là duy nhất.                                                                                              |
| BR-048 | Chỉ transition theo state machine hợp lệ.                                                                             |
| BR-049 | Hủy đơn phải hoàn phần tồn đã reserve theo đúng transaction.                                                  |
| BR-050 | Không xóa cứng order đã phát sinh giao dịch; dùng status/soft lifecycle.                                         |

## F. Promotion

| ID     | Quy tắc                                                                                                     |
| ------ | ------------------------------------------------------------------------------------------------------------ |
| BR-060 | Promotion có start_at < end_at.                                                                             |
| BR-061 | Promotion chỉ áp dụng khi ACTIVE và thời điểm hiện tại nằm trong hiệu lực.                       |
| BR-062 | Discount percent nằm trong [0,100]; fixed amount không âm.                                                |
| BR-063 | Không áp dụng promotion ngoài scope product/category đã cấu hình.                                    |
| BR-064 | Coupon code, nếu có, là duy nhất.                                                                        |
| BR-065 | Không cho tổng discount làm grand total âm.                                                              |
| BR-066 | OrderPromotion lưu snapshot discount đã áp dụng để lịch sử không phụ thuộc cách tính sau này. |

## G. Payment và shipment

| ID     | Quy tắc                                                                        |
| ------ | ------------------------------------------------------------------------------- |
| BR-070 | Payment thuộc một Order; payment reference từ gateway là duy nhất khi có. |
| BR-071 | Không chuyển Order sang PAID nếu payment chưa thành công.                 |
| BR-072 | Shipment chỉ được tạo khi order đủ điều kiện fulfillment.             |
| BR-073 | Tracking number duy nhất khi có.                                              |
| BR-074 | Shipment state phải chuyển theo transition hợp lệ.                          |

## H. Review

| ID     | Quy tắc                                                                                  |
| ------ | ----------------------------------------------------------------------------------------- |
| BR-080 | Rating nằm trong [1,5].                                                                  |
| BR-081 | Customer phải có OrderItem của product trong order đã DELIVERED mới được review. |
| BR-082 | Một customer chỉ có một review cho một product theo chính sách hiện tại.         |
| BR-083 | Review không hợp lệ phải bị từ chối trước khi commit.                            |

## I. Transaction và concurrency

| ID     | Quy tắc                                                                                                                                |
| ------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| BR-090 | Đặt hàng là một đơn vị nguyên tử: tạo order + items + promotion + payment/shipment liên quan + inventory phải nhất quán. |
| BR-091 | Nếu bất kỳ bước lõi nào thất bại thì rollback toàn bộ phần transaction đó.                                               |
| BR-092 | Hai session cùng mua số lượng cuối không được tạo oversell.                                                                   |
| BR-093 | Cập nhật inventory phải khóa đúng dòng hoặc dùng atomic update có điều kiện.                                               |
| BR-094 | Trigger/procedure không được để invariant bị vi phạm sau statement/transaction.                                                 |

## J. Quy tắc kỹ thuật

- PK dùng kiểu số nguyên unsigned cho bảng lõi; mã nghiệp vụ như `order_number`, `sku` có UNIQUE riêng.
- Tiền dùng `DECIMAL`, không dùng FLOAT/DOUBLE cho giá trị tài chính.
- Thời gian dùng `DATETIME` và lưu UTC ở tầng ứng dụng/database theo thống nhất của nhóm.
- Xóa dữ liệu master phải cân nhắc lịch sử; order và order item giữ lại để audit.
- Dữ liệu đầu vào dynamic SQL phải bind parameter; tên cột/sort direction phải qua whitelist.
