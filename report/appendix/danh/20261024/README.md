# Bằng chứng SQL động và SQL nhúng ngày 24/10/2026

> Trạng thái: **chưa chạy**. Lưu output thật; không chép số liệu ngày 23/10.

## Môi trường

- Máy:
- MySQL:
- Python:
- PyMySQL:
- Commit:
- Database:

## File cần tạo

| File | Ứng dụng | Nội dung cần ghi |
|---|---|---|
| `dynamic-search.txt` | `app/dynamic_search.py` | Số dòng bị lộ bởi truy vấn ghép chuỗi; truy vấn parameterized trả `0`; whitelist chặn 2/2 chèn `ORDER BY` |
| `embedded-sql.txt` | `app/embedded_sql.py` | Mở giỏ, thêm hàng, checkout vượt kho bị rollback, checkout hợp lệ tạo order `PAID`, tồn kho trước/sau |

## Cách chạy

Chạy trên database 100.000 đơn nếu muốn số liệu đại diện:

```powershell
python app\dynamic_search.py 2>&1 |
  Tee-Object -FilePath report\appendix\danh\20261024\dynamic-search.txt

python app\embedded_sql.py 2>&1 |
  Tee-Object -FilePath report\appendix\danh\20261024\embedded-sql.txt
```

Với database mẫu nhỏ, `embedded_sql.py` phải dùng khách hàng có trong seed:

```powershell
python app\embedded_sql.py --customer CUS0001 2>&1 |
  Tee-Object -FilePath report\appendix\danh\20261024\embedded-sql.txt
```

## Kết quả cần ghi

### SQL động

- Số dòng/sản phẩm/tài khoản bị lộ ở bản ghép chuỗi.
- Số dòng ở bản parameterized.
- Số payload bị whitelist chặn.
- Kết luận: không đưa input người dùng trực tiếp vào SQL.

### SQL nhúng

- Tồn kho trước và sau khi checkout vượt kho.
- Xác nhận rollback: số đơn không đổi, tồn kho không đổi.
- Order ID và trạng thái của checkout hợp lệ.
- Tồn kho trước/sau checkout hợp lệ.

## Ghi chú

- Không ghi đè bằng chứng 22/10 ở thư mục cha `report/appendix/danh/`.
- Dùng `.txt`; repo ignore `*.log`.
- Nếu output tiếng Việt bị lỗi mã hóa, ghi lại và dùng `chcp 65001` hoặc chạy lại với PyMySQL/UTF-8.
