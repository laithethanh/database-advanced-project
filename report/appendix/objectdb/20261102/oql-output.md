# Bằng chứng ObjectDB/JPA — OQ01–OQ05

- Thời điểm chạy: **2026-11-02 21:16:11**
- Nơi lưu: `C:\Users\lai the thanh\Desktop\Đồ án CSDL nâng cao\report\appendix\objectdb\20261102\oql-output.md`
- Môi trường: Java **25**, OS **Windows 11 10.0**
- Provider: **ObjectDB 2.9.5 (jakarta)**, Jakarta Persistence 3.1
- CSDL: `target/objectdb/ecommerce.odb` (xóa và tạo mới trước mỗi lần chạy)
- Dữ liệu: bộ mẫu cố định trong `SampleData` (3 khách hàng, 3 người bán, 3 sản phẩm, 5 biến thể, 5 đơn hàng)
- Ghi chú OID: ObjectDB quản lý OID nội bộ; trường `id` là surrogate key JPA, còn `email`, `sku`, `orderNumber` là định danh nghiệp vụ UNIQUE.

## 0. Tóm tắt dữ liệu

- Account: **6**
- Customer: **3**
- Seller: **3**
- Product: **3**
- ProductVariant: **5**
- Order: **5**

## OQ01 — Đơn hàng đã giao của một khách hàng

**OQL**

```text
SELECT o FROM Order o WHERE o.customer.email = $email AND o.status = 'DELIVERED';
```

**JPQL**

```text
SELECT o FROM Order o WHERE o.customer.email = :email AND o.status = :status ORDER BY o.orderNumber
```

**Tham số:** `email = alice@example.com`, `status = DELIVERED`

**Kết quả:** ORD-1001 (status=DELIVERED, grandTotal=1550.00, items=2)

- PASS — OQ01 trả về đúng ORD-1001 (kỳ vọng: `ORD-1001`, thực tế: `ORD-1001`)
## OQ02 — Sản phẩm có ít nhất một biến thể giá cao hơn ngưỡng

**OQL**

```text
SELECT DISTINCT v.product FROM ProductVariant v WHERE v.price > $price;
```

**JPQL**

```text
SELECT DISTINCT v.product FROM ProductVariant v WHERE v.price > :price ORDER BY v.product.name
```

**Tham số:** `price = 1000.00`

**Kết quả:** Laptop Pro (TechOne, status=ACTIVE)

- PASS — OQ02 chỉ trả về Laptop Pro (kỳ vọng: `Laptop Pro`, thực tế: `Laptop Pro`)
## OQ03 — Người bán đang cung cấp SKU được yêu cầu

**OQL**

```text
SELECT s FROM Seller s WHERE s.shopStatus = 'ACTIVE' AND EXISTS v IN s.inventory: v.sku = $sku;
```

**JPQL**

```text
SELECT s FROM Seller s JOIN s.inventory v WHERE s.shopStatus = :shopStatus AND v.sku = :sku ORDER BY s.shopName
```

**Tham số:** `sku = SKU-MOU-BLK`, `shopStatus = ACTIVE`

**Kết quả:** Shop Alpha (ACTIVE)

- PASS — OQ03 chỉ trả về Shop Alpha (kỳ vọng: `Shop Alpha`, thực tế: `Shop Alpha`)
## OQ04 — Tổng giá trị đơn hàng đã ghi nhận của mỗi khách hàng

**OQL**

```text
SELECT STRUCT(email: c.email, ltv: c.lifetimeValue()) FROM Customer c;
```

**JPQL** (hai bước: lấy đủ khách hàng + tổng theo trạng thái)

```text
SELECT c.email FROM Customer c ORDER BY c.email
```

```text
SELECT o.customer.email, SUM(o.grandTotal) FROM Order o WHERE o.status IN :statuses GROUP BY o.customer.email ORDER BY o.customer.email
```

**Tham số:** `statuses = [PAID, PROCESSING, SHIPPED, DELIVERED]`

**Kết quả:**

- `alice@example.com` → **3350.00**
- `bob@example.com` → **50.00**
- `carol@example.com` → **0.00**

- PASS — OQ04 khớp lifetimeValue kỳ vọng (kỳ vọng: `{alice@example.com=3350.00, bob@example.com=50.00, carol@example.com=0.00}`, thực tế: `{alice@example.com=3350.00, bob@example.com=50.00, carol@example.com=0.00}`)
## OQ05 — Đơn hàng đã thanh toán kèm danh sách dòng hàng

**OQL**

```text
SELECT STRUCT(number: o.orderNumber, total: o.total(), lines: o.items) FROM Order o WHERE o.status = 'PAID';
```

**JPQL**

```text
SELECT o FROM Order o WHERE o.status = :status ORDER BY o.orderNumber
```

**Tham số:** `status = PAID`

**Kết quả:** 
- `ORD-1002` — total = **1800.00**, 1 dòng:
  - `SKU-LAP-16` x1 @ 1800.00 = 1800.00 — seller `Shop Alpha`

- PASS — OQ05 trả về đúng ORD-1002 (kỳ vọng: `ORD-1002`, thực tế: `ORD-1002`)
- PASS — OQ05 có đúng 1 dòng hàng (kỳ vọng: `1`, thực tế: `1`)
- PASS — OQ05 total = 1800.00 (kỳ vọng: `1800.00`, thực tế: `1800.00`)
## Kiểm chứng phương thức nghiệp vụ trong ODL

- PASS — Account.isActive() của Alice (kỳ vọng: `true`, thực tế: `true`)
- PASS — Customer.lifetimeValue() của Alice (kỳ vọng: `3350.00`, thực tế: `3350.00`)
- PASS — Seller.revenue() của Shop Alpha (kỳ vọng: `3400.00`, thực tế: `3400.00`)
- PASS — Product.activeVariants() của Laptop Pro (kỳ vọng: `2`, thực tế: `2`)
- PASS — ProductVariant.isAvailable() của SKU-LAP-14 (kỳ vọng: `true`, thực tế: `true`)
- PASS — ProductVariant.isAvailable() của SKU-PHN-OLD (kỳ vọng: `false`, thực tế: `false`)
- PASS — Order.total() của ORD-1001 (kỳ vọng: `1550.00`, thực tế: `1550.00`)
- PASS — Order.canTransitionTo("PROCESSING") từ PAID (kỳ vọng: `true`, thực tế: `true`)
- PASS — Order.canTransitionTo("PAID") từ DELIVERED (kỳ vọng: `false`, thực tế: `false`)

## Bảng ánh xạ OQL → JPQL/ObjectDB

| OQL | JPQL thực thi | Ghi chú |
|---|---|---|
| OQ01 | `SELECT o FROM Order o WHERE o.customer.email=:email AND o.status=:status ORDER BY o.orderNumber` | ObjectDB duyệt quan hệ `Order.customer` → `Account.email`. |
| OQ02 | `SELECT DISTINCT v.product FROM ProductVariant v WHERE v.price>:price ORDER BY v.product.name` | `DISTINCT` loại trùng khi một sản phẩm có nhiều biến thể vượt ngưỡng. |
| OQ03 | `SELECT s FROM Seller s JOIN s.inventory v WHERE s.shopStatus=:shopStatus AND v.sku=:sku ORDER BY s.shopName` | `JOIN` trên tập quan hệ nhiều-nhiều `Seller.inventory`. |
| OQ04 | `SELECT c.email FROM Customer c ORDER BY c.email` + `SELECT o.customer.email, SUM(o.grandTotal) FROM Order o WHERE o.status IN :statuses GROUP BY o.customer.email` | ObjectDB 2.9.5 chưa hỗ trợ `CASE`/`COALESCE`; hai kết quả được ghép trong Java để khách hàng không có đơn nhận 0. |
| OQ05 | `SELECT o FROM Order o WHERE o.status=:status ORDER BY o.orderNumber` | JPQL không chiếu trực tiếp tập `items` lồng nhau; `@ElementCollection` EAGER tải kèm danh sách dòng hàng có thứ tự. |

Ánh xạ lớp: `Account→Account`, `Customer→Customer`, `Seller→Seller`, `Product→Product`, `ProductVariant→ProductVariant`, `Order→Order`, `OrderLine→@Embeddable` (có `@ManyToOne Seller`). Các quan hệ hai chiều dùng `@OneToMany`/`@ManyToMany`; `Order.items` dùng `@ElementCollection` + `@OrderColumn`.

## Kết luận

- Tổng số kiểm tra: **16**
- PASS: **16**
- FAIL: **0**
- Kết quả: **ĐẠT**
