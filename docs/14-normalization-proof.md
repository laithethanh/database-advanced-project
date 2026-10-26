# Chứng minh chuẩn hóa

## 1. Phạm vi chứng minh

Tài liệu này chứng minh dạng chuẩn theo hai lớp:

1. **FD định danh của dữ liệu gốc**: khóa chính, khóa UNIQUE và quan hệ N:M.
2. **Ràng buộc số học/liên bảng**: tổng tiền, bộ đếm, snapshot và điều kiện nghiệp vụ.

Các giá trị dẫn xuất có kiểm soát được phân tích riêng thay vì gán nhãn BCNF một cách máy móc.

## 2. Phủ tối tiểu của các quan hệ tiêu biểu

### 2.1 ACCOUNT

```text
A = account_id, E = email, P = password_hash, N = full_name,
H = phone, S = status, C = created_at, U = updated_at

F = {A → E,P,N,H,S,C,U; E → A,P,N,H,S,C,U}
M = {A → E, A → P, A → N, A → H, A → S, A → C, A → U, E → A}
```

Kiểm tra tối tiểu:

- `E → P,N,H,S,C,U` bị loại vì suy ra từ `E → A` và `A → ...`.
- Không thể bỏ `A → E`: nếu bỏ, `A+` không chứa `E`, mất khóa thay thế.
- Không thể bỏ `E → A`: nếu bỏ, `E+` không chứa `A` và các thuộc tính còn lại.
- Mỗi vế phải chỉ còn một thuộc tính.

Khóa ứng viên: `A`, `E`. Mọi FD trong `M` có vế trái là khóa nên `ACCOUNT` đạt BCNF.

### 2.2 PRODUCT_VARIANT

```text
V = variant_id, W = warehouse_id, P = product_id, K = sku,
C = color, Z = size, G = price, R = compare_at_price,
Q = warehouse_quantity, S = status

F = {V → W,P,K,C,Z,G,R,Q,S; K → V,W,P,C,Z,G,R,Q,S}
M = {V → W, V → P, V → K, V → C, V → Z, V → G,
     V → R, V → Q, V → S, K → V}
```

Khóa ứng viên: `V`, `K` (và khóa tổ hợp `(W,P,C,Z)` theo UNIQUE). Mọi vế trái trong `M` là siêu khóa, nên đạt BCNF theo các FD định danh.

### 2.3 INVENTORY

```text
F = {(S,V) → Q, (S,V) → R, (S,V) → L, (S,V) → U}
```

`(S,V)+ = {S,V,Q,R,L,U}`; không có tập con thực sự nào xác định toàn bộ quan hệ. Khóa duy nhất `(S,V)`, đạt BCNF.

### 2.4 ORDERS

```text
O = order_id, N = order_number, T = subtotal,
D = discount_total, F = shipping_fee, G = grand_total

F = {O → N,C,status,recipient_name,recipient_phone,shipping_address,
         T,D,F,G,placed_at,created_at,updated_at;
     N → O,C,status,recipient_name,recipient_phone,shipping_address,
         T,D,F,G,placed_at,created_at,updated_at;
     T,D,F → G}
M = {O → N, O → C, O → status, O → recipient_name, O → recipient_phone,
     O → shipping_address, O → T, O → D, O → F, O → G,
     O → placed_at, O → created_at, O → updated_at, N → O, T,D,F → G}
```

Khóa ứng viên: `O`, `N`. Hai FD đầu có vế trái là khóa. FD `T,D,F → G` là ràng buộc số học; nếu xem nó là FD của lược đồ thì `ORDERS` có ngoại lệ 3NF/BCNF có kiểm soát. Nếu chỉ xét FD định danh dữ liệu gốc, `ORDERS` đạt BCNF.

### 2.5 ORDER_ITEM

```text
I = order_item_id, O = order_id, S = seller_id, V = variant_id,
Q = quantity, P = unit_price, D = line_discount, T = line_total

F = {I → O,S,V,product_name_snapshot,sku_snapshot,P,Q,D,T;
     (O,S,V) → I,product_name_snapshot,sku_snapshot,P,Q,D,T;
     Q,P,D → T}
M = {I → O, I → S, I → V, I → product_name_snapshot,
     I → sku_snapshot, I → P, I → Q, I → D, I → T,
     (O,S,V) → I, Q,P,D → T}
```

Khóa ứng viên: `I`, `(O,S,V)`. FD `Q,P,D → T` có vế trái không là siêu khóa. Vì vậy nếu xem công thức `line_total = quantity*unit_price - line_discount` là FD, `ORDER_ITEM` **không đạt 3NF/BCNF**. Đây là denormalization có chủ đích, được bảo vệ bởi trigger, CHECK và Q25.

### 2.6 REVIEW

```text
R = review_id, P = product_id, C = customer_id, OI = order_item_id
F = {R → P,C,OI,rating,title,body,status,created_at,updated_at;
     (C,P) → R,P,C,OI,rating,title,body,status,created_at,updated_at}
M = {R → P, R → C, R → OI, R → rating, R → title, R → body,
     R → status, R → created_at, R → updated_at, (C,P) → R}
```

Khóa ứng viên: `R`, `(C,P)`; mọi FD có vế trái là khóa, đạt BCNF.

## 3. Nối không mất mát

### 3.1 Tách Account thành Customer/Seller

`CUSTOMER` và `SELLER` có khóa chính `account_id` là FK tới `ACCOUNT`. Phép nối `ACCOUNT ⋈ CUSTOMER` theo `account_id` không mất mát vì `account_id` là khóa của `CUSTOMER`; tương tự với `SELLER`. Việc một tài khoản có thể xuất hiện ở cả hai bảng biểu diễn chuyên biệt hóa overlapping.

### 3.2 Tách Orders và OrderItem

Trong quan hệ phổ quát `OrderFacts`, `order_id` xác định thuộc tính đơn hàng và là khóa của phần `ORDERS`. Khi tách:

```text
ORDERS(order_id, customer_id, status, totals, ...)
ORDER_ITEM(order_item_id, order_id, seller_id, variant_id, ...)
```

`ORDERS ∩ ORDER_ITEM = {order_id}` và `order_id` là khóa của `ORDERS`, nên phép nối là lossless theo định lý phân rã nhị phân.

### 3.3 Bảng N:M

`INVENTORY`, `CART_ITEM`, `PROMOTION_PRODUCT`, `PROMOTION_CATEGORY`, `ORDER_PROMOTION` chứa đầy đủ các khóa của hai thực thể tham gia. Phép chiếu/nối lại theo các khóa này không tạo tổ hợp giả vì mỗi dòng trung gian là một cặp có thật; các FK tương ứng bảo toàn liên kết.

### 3.4 Tách OrderItem và OrderPromotion

Nếu lưu chung `OrderFact(order_id, order_item_id, promotion_id, ...)`, một đơn có 3 dòng hàng và 2 khuyến mãi sẽ sinh 6 tổ hợp dù dòng hàng và khuyến mãi độc lập. Tách thành `ORDER_ITEM` và `ORDER_PROMOTION` loại bỏ tổ hợp giả; đây là phép phân rã 4NF không mất mát.

## 4. Bảo toàn phụ thuộc

- Khóa chính, UNIQUE và FK bảo toàn các FD định danh trong từng bảng và liên kết giữa bảng.
- Các FD số học như `line_total`, `grand_total` được bảo toàn bằng trigger trước khi ghi và CHECK sau khi ghi.
- Các phụ thuộc tổng hợp như `subtotal = SUM(order_item.line_total)` và `discount_total = SUM(order_promotion.discount_amount)` không biểu diễn được bằng FD chuẩn trên một quan hệ; chúng được bảo toàn bằng trigger, transaction checkout và kiểm tra Q25.
- Các điều kiện trạng thái, review eligibility, category cycle và tồn kho là invariant liên bảng, được thực thi bằng trigger/procedure. Đây là phần bổ sung cho lý thuyết chuẩn hóa, không thay thế chứng minh FD.

## 5. Chứng minh 4NF

Xét quan hệ giả định:

```text
OrderFact(order_id, order_item_id, promotion_id)
```

Với mỗi đơn, tập dòng hàng và tập khuyến mãi là hai tập đa trị độc lập:

```text
order_id ->> order_item_id
order_id ->> promotion_id
```

Hai MVD này có vế trái không phải siêu khóa, nên `OrderFact` vi phạm 4NF. Phân rã:

```text
R1(order_id, order_item_id)
R2(order_id, promotion_id)
```

là phân rã 4NF không mất mát theo định lý phân rã MVD. Lược đồ thực tế tách tương tự thành `ORDER_ITEM` và `ORDER_PROMOTION`, đồng thời bổ sung thuộc tính riêng của từng sự kiện.

Các trường hợp khác:

- `PRODUCT` không lưu trực tiếp danh sách màu và kích thước; `PRODUCT_VARIANT` biểu diễn từng tổ hợp.
- `PROMOTION` không lưu đồng thời tập product và tập category; hai bảng trung gian tách biệt.
- `CATEGORY` là cây cha-con 1:N, không phải MVD.

Do đó không còn quan hệ nào lưu hai MVD độc lập trên cùng khóa.

## 6. Kết luận

- Các quan hệ lõi đạt BCNF theo FD định danh dữ liệu gốc.
- `ORDER_ITEM.line_total` và (nếu xem công thức là FD) `ORDERS.grand_total` là ngoại lệ 3NF/BCNF có kiểm soát.
- Tổng tiền, bộ đếm và snapshot là dư thừa có chủ đích, được bảo vệ bằng trigger/CHECK/transaction.
- Lược đồ đạt 4NF nhờ tách các tập đa trị độc lập.
