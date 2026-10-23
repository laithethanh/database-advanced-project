# Kết quả Q01–Q25 ngày 24/10/2026

> Trạng thái: **chưa chạy**. Chỉ lưu output thật từ database 100.000 đơn.

## Môi trường

- Máy:
- MySQL:
- Python:
- Commit:
- Số đơn:
- Số order_item:
- Số payment:
- Số review:

## File cần tạo

| File | Nội dung |
|---|---|
| `06_queries_100k.txt` | Q01–Q17, Q21A, Q21B, Q22–Q25 |
| `07_recursive_100k.txt` | Q18–Q20 |

Không tạo file bằng tay. Dùng `TEE` của MySQL client sau khi chạy trên database 100.000 đơn.

## Cách chạy

Kết nối MySQL, sau đó:

```sql
TEE report/appendix/queries/20261024/06_queries_100k.txt;
SOURCE sql/06_queries.sql;
NOTEE;

TEE report/appendix/queries/20261024/07_recursive_100k.txt;
SOURCE sql/07_recursive.sql;
NOTEE;
```

Phải chạy trên database sạch đã sinh 100.000 đơn, không nạp `sql/03_seed_small.sql`.

## Kiểm tra

- [ ] Đủ Q01–Q25, gồm Q21A và Q21B.
- [ ] Q25 trả về `0` dòng vi phạm.
- [ ] Output không bị lẫn kết quả của database mẫu.
- [ ] Đã ghi số đơn/order_item/payment/review thực tế.
- [ ] Đã ghi commit và phiên bản MySQL.

## Ghi chú

- Thời gian chạy Q:
- Truy vấn chậm hoặc lỗi:
- Sai khác so với ngày 23/10:
