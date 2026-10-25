# Bằng chứng SQL động và SQL nhúng — 25/10/2026

Người chạy: **Phạm Thành Danh**. Output thật, ghi thẳng ra file bằng `cmd /c "python ... > file 2>&1"` (UTF-8).

## Môi trường

| Thuộc tính | Giá trị |
|---|---|
| Máy | Laptop Windows 11 (`laptop-5p18fulb`) |
| MySQL | 8.4.11 |
| Python / thư viện | Python 3.15.0, PyMySQL 1.2.3 (kết nối qua `db_config.py` + `.env`) |
| Database | `ecommerce_advanced` — bộ 100.000 đơn của generator (seed 20261003, không có seed nhỏ), cùng bộ dữ liệu với `report/appendix/queries/20261025/` |
| Thứ tự | Chạy **sau** Q01–Q25 để demo không làm sai số liệu truy vấn |

## `dynamic-search.txt` — `python app\dynamic_search.py`

| Màn | Đầu vào | Ghép chuỗi (không an toàn) | Tham số + whitelist (an toàn) |
|---|---|---|---|
| A | `Áo` (bình thường) | 20 dòng | 20 dòng (lọc giá ≤ 500.000, sắp theo giá) |
| B | `' OR '1'='1' -- ` | **2.511 dòng** — toàn bộ biến thể, `LIMIT 20` bị vô hiệu | 0 dòng |
| C | `khongco' UNION SELECT email, password_hash FROM account -- ` | **10.100 tài khoản bị lộ** (10.000 khách + 100 người bán) | 0 dòng |
| D | Chèn SQL vào ô sắp xếp | (không áp dụng) | 2/2 bị whitelist chặn |

Bảng `product` sau demo còn nguyên 1.000 sản phẩm.

Chi tiết đáng chú ý ở màn A: bản ghép chuỗi tìm `'Áo'` lại trả về **"Dao kéo"** trước. Collation `utf8mb4_0900_ai_ci`
không phân biệt dấu (*accent-insensitive*) nên `'Áo'` khớp với `"ao"` trong "D**ao** kéo". Bản an toàn có thêm điều kiện
giá và sắp xếp nên kết quả đầu là "Áo thun". Đây là hành vi của collation, không phải lỗi bảo mật, nhưng cần biết khi
thiết kế tìm kiếm tiếng Việt.

## `embedded-sql.txt` — `python app\embedded_sql.py` (khách `DCUS000001`)

| Bước | Kết quả |
|---|---|
| 1. Mở giỏ ACTIVE | Dùng giỏ có sẵn `cart_id = 1` (generator đã tạo giỏ đang mở cho một số khách, sẵn 3 món) |
| 2. Thêm 2 món | Quần jean Canifa 00001 (2 biến thể), kho còn 59 và 33 |
| 3. Duyệt giỏ bằng cursor | 5 món, tổng tiền hàng 5.744.000đ |
| 4. Đặt 1.059 cái khi kho còn 59 | Lỗi `1644 insufficient inventory`; **trước = sau: 100.000 đơn, kho 59** → rollback đúng |
| 5. Sửa thành 2 cái, `CALL sp_checkout` | Thành công, `order_id = 100002` |
| 6. Kiểm tra | Đơn `PAID`, 6.371.000 + 30.000 ship = **6.401.000đ**; giỏ `CHECKED_OUT`; tồn kho **59 → 57** |

`order_id` thành công là 100002 chứ không phải 100001: lần checkout thất bại ở bước 4 đã cấp phát giá trị `AUTO_INCREMENT`
100001 trước khi rollback; InnoDB không thu hồi giá trị này, nên khóa tự tăng có khoảng trống — hành vi bình thường.

## Tái lập

Hai file này được chạy hai lần trên hai lần dựng dữ liệu độc lập (cùng seed) trong ngày 25/10 và cho **kết quả giống hệt**:
cùng số dòng bị lộ, cùng giỏ hàng, cùng tồn kho 59 → 57, cùng `order_id = 100002` (chỉ khác `order_number` vì chứa thời điểm đặt).
