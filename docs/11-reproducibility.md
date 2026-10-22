# Hướng dẫn tái lập thực nghiệm

## Mục tiêu

Thành viên mới có thể tạo cơ sở dữ liệu từ đầu, nạp dữ liệu mẫu nhỏ, chạy kiểm thử, tạo bộ dữ liệu lớn và đo hiệu năng chỉ bằng tài liệu trong repository.

## Thứ tự thực hiện

```text
1. cài dependency: pip install -r requirements.txt
2. tạo database/schema: sql/01_schema.sql
3. áp dụng ràng buộc: sql/02_constraints.sql
4. nạp dữ liệu mẫu nhỏ: sql/03_seed_small.sql (chỉ dùng cho database mẫu)
5. tạo function/procedure: sql/04_functions.sql
6. tạo trigger: sql/05_triggers.sql
7. chạy constraint_tests.sql, promotion_tests.sql, order_tests.sql
8. chạy sql/06_queries.sql và sql/07_recursive.sql
9. tạo database benchmark riêng: 01 → 02 → 04 → 05 → generator
10. chạy sql/08_benchmark.sql
11. chạy thử nghiệm transaction/concurrency trên 2 phiên kết nối
```

Bước 3–6 phải chạy đúng thứ tự vì trigger và thủ tục giả định các cột/ràng buộc đã tồn tại. Không chạy generator trên database đã có đơn hàng; generator chủ động từ chối để bảo đảm dữ liệu có thể tái lập.

Hai nguồn dữ liệu dùng cho hai mục đích khác nhau, không trộn vào cùng một database:

| Nguồn | Phạm vi | Database |
|---|---|---|
| `sql/03_seed_small.sql` | Dữ liệu mẫu nhỏ: fixture cho `tests/*.sql`, demo, chạy Q01–Q25 trên dữ liệu nhỏ | `ecommerce_advanced` (database mẫu) |
| `data/generator/generate_data.py` | Dữ liệu lớn 100.000 đơn cho benchmark và kiểm chứng query | database benchmark riêng, **không** nạp seed nhỏ |

Fixture do seed nhỏ tạo và các file test phụ thuộc vào: `CUS0001` (khách), `SEL0001` (người bán), `SKU-DEMO-001` (biến thể). Generator sinh mã theo namespace riêng (`DCUS*`, `DSEL*`, `DSKU*`) nên **không** thay thế được seed cho mục đích test.

## Lệnh mẫu

```powershell
mysql -u <user> -p < sql/01_schema.sql
mysql -u <user> -p < sql/02_constraints.sql
mysql -u <user> -p < sql/03_seed_small.sql
mysql -u <user> -p < sql/04_functions.sql
mysql -u <user> -p < sql/05_triggers.sql
mysql -u <user> -p < tests/constraint_tests.sql
mysql -u <user> -p < tests/promotion_tests.sql
mysql -u <user> -p < tests/order_tests.sql
mysql -u <user> -p < sql/06_queries.sql
mysql -u <user> -p < sql/07_recursive.sql
```

Database benchmark phải là database sạch riêng. Chạy `01_schema.sql`, `02_constraints.sql`, `04_functions.sql`, `05_triggers.sql`, sau đó:

```powershell
python data/generator/generate_data.py --orders 100000 --seed 20261003
mysql -u <user> -p < sql/08_benchmark.sql
```

## Nguyên tắc tái lập

- Không đưa thông tin bí mật vào Git; chỉ lưu `.env.example`.
- Trình sinh dữ liệu nhận seed, số lượng bản ghi và tỷ lệ trạng thái qua tham số.
- Kết quả generator phải có đủ trạng thái `PAID`, `PROCESSING`, `SHIPPED`, `DELIVERED`, `CANCELLED`, `RETURNED`, review và một số dòng tồn kho thấp để Q06/Q09/Q22/Q24 có dữ liệu kiểm chứng.
- Ghi phiên bản MySQL, hệ điều hành, CPU/RAM, seed, quy mô bộ dữ liệu và thời gian chạy vào `data/benchmark/<run>/metadata.md`.
- Không điền kết quả benchmark hoặc ảnh chụp cơ sở dữ liệu nếu chưa thực sự chạy.
