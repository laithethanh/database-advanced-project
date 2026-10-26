# Phụ thuộc hàm và chuẩn hóa

## 1. Quy ước

Với quan hệ `R(X)`, `X → Y` nghĩa là mỗi giá trị của `X` xác định duy nhất một giá trị của `Y`. Bao đóng `X+` là tập thuộc tính suy ra được từ `X` bằng các FD và luật Armstrong. Một khóa ứng viên `K` thỏa `K+ = R` và không có tập con thực sự nào của `K` có bao đóng bằng `R`.

Thiết kế ưu tiên tách các nhóm dữ kiện độc lập, nhưng vẫn giữ một số giá trị dẫn xuất có kiểm soát để bảo toàn lịch sử và giảm chi phí đọc. Vì vậy báo cáo phân biệt rõ:

- **FD của dữ liệu gốc**: quyết định dạng chuẩn của quan hệ.
- **Giá trị dẫn xuất có kiểm soát**: dư thừa có chủ đích, được bảo vệ bằng `CHECK`, trigger hoặc transaction.
- **Giá trị snapshot**: dữ kiện lịch sử, không phụ thuộc dữ liệu danh mục hiện tại.

## 2. FD tiêu biểu và bao đóng

### ACCOUNT

Ký hiệu gọn: `A=account_id, E=email, P=password_hash, N=full_name, H=phone, S=status, C=created_at, U=updated_at`.

```text
A → E,P,N,H,S,C,U
E → A,P,N,H,S,C,U
```

Suy ra `A+ = {A,E,P,N,H,S,C,U}` và `E+ = {E,A,P,N,H,S,C,U}`. Khóa ứng viên: `A`, `E`.

Phủ tối tiểu có thể viết:

```text
A → E, A → P, A → N, A → H, A → S, A → C, A → U
E → A
```

Các FD `E → P,N,H,S,C,U` là dư thừa nhờ `E → A` và `A → ...`.

### PRODUCT_VARIANT

Ký hiệu: `V=variant_id, W=warehouse_id, P=product_id, K=sku, C=color, Z=size, G=price, R=compare_at_price, Q=warehouse_quantity, S=status`.

```text
V → W,P,K,C,Z,G,R,Q,S
K → V,W,P,C,Z,G,R,Q,S
```

Khóa ứng viên: `V`, `K`. Phủ tối tiểu tương tự ACCOUNT: `V → ...`, `K → V`, các thuộc tính còn lại phụ thuộc trực tiếp vào `V`. Ràng buộc `UNIQUE(warehouse_id, product_id, color, size)` tạo thêm một khóa ứng viên; nó không làm thay đổi kết luận BCNF vì vế trái vẫn là khóa.

### INVENTORY

```text
(S, V) → Q, R, L, U
```

Trong đó `S=seller_id`, `V=variant_id`, `Q=quantity_on_hand`, `R=reserved_quantity`, `L=reorder_level`, `U=updated_at`. Bao đóng `(S,V)+ = {S,V,Q,R,L,U}`. Khóa ứng viên duy nhất là `(S,V)`; mọi thuộc tính không khóa phụ thuộc toàn bộ khóa.

### ORDERS

Ký hiệu: `O=order_id, N=order_number, C=customer_id, S=status, T=subtotal, D=discount_total, F=shipping_fee, G=grand_total`.

```text
O → N,C,S,recipient_name,recipient_phone,shipping_address,T,D,F,G,placed_at,created_at,updated_at
N → O,C,S,...,T,D,F,G,placed_at,created_at,updated_at
T,D,F → G          (ràng buộc số học: G = T - D + F)
```

Khóa ứng viên: `O`, `N`. Các FD `O → ...`, `N → O` là đủ cho phủ tối tiểu; `T,D,F → G` là FD số học có kiểm soát, không phải FD độc lập của dữ liệu gốc.

### ORDER_ITEM

Ký hiệu: `I=order_item_id, O=order_id, S=seller_id, V=variant_id, Q=quantity, P=unit_price, D=line_discount, T=line_total`.

```text
I → O,S,V,product_name_snapshot,sku_snapshot,P,Q,D,T
(O,S,V) → I,product_name_snapshot,sku_snapshot,P,Q,D,T
Q,P,D → T          (công thức line_total = Q*P - D)
```

Khóa ứng viên: `I` và `(O,S,V)`. Hai FD đầu có vế trái là khóa. FD thứ ba có vế trái **không** là khóa, nên nếu xem công thức là FD của lược đồ thì `order_item` không đạt 3NF/BCNF. Đây là ngoại lệ có chủ đích được trình bày ở mục 4.

### Các quan hệ còn lại

`CART_ITEM(cart_id, seller_id, variant_id, quantity)` có khóa ghép và không có thuộc tính không khóa phụ thuộc bộ phận. `ORDER_PROMOTION(order_id, promotion_id, discount_amount, snapshot)` có khóa ghép; `discount_amount` là snapshot tại thời điểm áp dụng. `REVIEW` có khóa `review_id` và khóa thay thế `(customer_id, product_id)`. `PROMOTION` có khóa `promotion_id`, khóa thay thế `code`; `used_count` là bộ đếm dẫn xuất có kiểm soát.

## 3. Khóa ứng viên

| Quan hệ | Khóa ứng viên |
|---|---|
| Account | `account_id`, `email` |
| Seller | `account_id`, `seller_code`, `shop_name` |
| ProductVariant | `variant_id`, `sku`, `(warehouse_id, product_id, color, size)` |
| Inventory | `(seller_id, variant_id)` |
| CartItem | `(cart_id, seller_id, variant_id)` |
| PromotionProduct | `(promotion_id, product_id)` |
| PromotionCategory | `(promotion_id, category_id)` |
| Order | `order_id`, `order_number` |
| OrderItem | `order_item_id`, `(order_id, seller_id, variant_id)` |
| OrderPromotion | `(order_id, promotion_id)` |
| Review | `review_id`, `(customer_id, product_id)` |

## 4. Dạng chuẩn và các ngoại lệ có kiểm soát

### 4.1 Quan hệ đạt 3NF/BCNF

Các bảng danh mục, khóa ngoại, bảng kết hợp và bảng sự kiện còn lại có mọi FD không tầm thường với vế trái là siêu khóa. Vì vậy chúng đạt BCNF theo các FD dữ liệu gốc đã khai báo.

### 4.2 `order_item.line_total`

Nếu coi `Q,P,D → line_total` là FD, quan hệ vi phạm 3NF/BCNF. Nhóm giữ `line_total` vì:

- là snapshot tài chính của dòng hàng, cần đọc nhanh khi lập hóa đơn/báo cáo;
- được tính lại bởi trigger trước khi ghi;
- được đối chiếu bởi `CHECK (line_total = quantity*unit_price - line_discount)` và Q25.

Đây là **denormalization có kiểm soát**, không phải kết luận sai rằng quan hệ đạt BCNF. Nếu cần BCNF tuyệt đối, có thể bỏ `line_total` và dùng view/generated column; thiết kế hiện tại chọn đánh đổi có kiểm chứng.

### 4.3 `orders` totals và `promotion.used_count`

- `orders.subtotal`, `discount_total`, `grand_total` được materialize từ `order_item` và `order_promotion`. Nếu chỉ xét FD định danh của dữ liệu gốc, chúng phụ thuộc khóa `order_id` nên không phá BCNF. Nếu xem công thức `subtotal - discount_total + shipping_fee → grand_total` như một FD số học, `orders` cũng là ngoại lệ 3NF/BCNF có kiểm soát giống `order_item`.
- `promotion.used_count` là bộ đếm materialize từ `order_promotion`; nó không tạo FD nội bộ mới nhưng là dữ liệu dẫn xuất liên quan hệ và phải khớp với số dòng `order_promotion`.
- Các bất biến `grand_total = subtotal - discount_total + shipping_fee`, `subtotal = SUM(order_item.line_total)`, `discount_total = SUM(order_promotion.discount_amount)` và `used_count` không vượt `usage_limit` được bảo vệ bởi trigger/`CHECK` và transaction checkout.

### 4.4 Snapshot lịch sử

`product_name_snapshot`, `sku_snapshot`, `unit_price`, `promotion_code_snapshot` và `discount_amount` mô tả sự kiện tại thời điểm bán. Chúng không phụ thuộc dữ liệu hiện tại của Product/Promotion, nên không tạo FD `variant_id → snapshot` trên toàn thời gian. Việc lặp có kiểm soát này bảo vệ lịch sử kiểm toán.

## 5. 4NF và phụ thuộc đa trị

Một MVD `X ->> Y` biểu diễn hai tập giá trị độc lập cùng phụ thuộc `X`. Thiết kế tránh lưu hai MVD độc lập trong cùng một quan hệ:

- Product có nhiều màu và nhiều kích thước: mỗi tổ hợp được biểu diễn bằng một dòng `product_variant`, không lưu hai danh sách màu/size trong `product`.
- Order có nhiều dòng hàng và nhiều khuyến mãi: `order_item` và `order_promotion` là hai quan hệ riêng. Nếu gộp thành `order_fact(order_id, order_item_id, promotion_id)` sẽ có `order_id ->> order_item_id` và `order_id ->> promotion_id`, vi phạm 4NF.
- Promotion áp dụng cho nhiều product và nhiều category: `promotion_product` và `promotion_category` tách biệt, không lưu hai tập đa trị trong `promotion`.

Vì vậy không có quan hệ nào trong lược đồ lưu hai MVD độc lập trên cùng khóa.

## 6. Kết luận

- Lõi lược đồ đạt BCNF theo các FD dữ liệu gốc.
- `order_item.line_total` là ngoại lệ 3NF/BCNF có chủ đích nếu xem công thức số học là FD.
- Các tổng tiền, bộ đếm và snapshot là dư thừa có kiểm soát; tính đúng đắn được bảo vệ bằng trigger, `CHECK`, FK và transaction.
- Thiết kế đạt 4NF nhờ tách các tập đa trị độc lập thành bảng riêng.
