# database-advanced-project
Đồ án CSDL thương mại điện tử và lập trình SQL nâng cao - thiết kế EER, chuẩn hóa dữ liệu, SQL nâng cao, transaction, trigger, procedure/function, dynamic SQL, recursive SQL và thực nghiệm trên 100.000+ đơn hàng.
# Đồ án CSDL Nâng cao – Đề tài 7

## CSDL Thương mại điện tử và Lập trình SQL nâng cao

Đồ án môn **Cơ sở dữ liệu nâng cao** của **Nhóm 7**, tập trung vào phân tích, thiết kế và triển khai CSDL cho hệ thống thương mại điện tử; đồng thời nghiên cứu SQL nâng cao, CSDL hướng đối tượng, transaction và đánh giá hiệu năng.

## 👥 Thành viên

| STT | Thành viên                      | Vai trò chính                                                          |
| --- | --------------------------------- | ------------------------------------------------------------------------ |
| 1   | **Lại Thế Thành**        | Nhóm trưởng, nghiệp vụ, EER, thủ tục/hàm, transaction, báo cáo |
| 2   | **Dương Tấn Tài**       | Phụ thuộc hàm, chuẩn hóa, SQL nâng cao, SQL động, hiệu năng    |
| 3   | **Trần Văn Minh Tuấn**   | SQL nâng cao, CSDL hướng đối tượng, OQL, transaction              |
| 4   | **Nguyễn Mậu Công Khoa** | DDL, constraint, trigger, SQL đệ quy, dữ liệu, thực nghiệm         |
| 5   | **Phạm Thành Danh**       | SQL nhúng, sinh dữ liệu, SQL nâng cao, OQL, runbook, demo            |

**Giảng viên:** *(bổ sung tên)*
**Thời gian:** 12 tuần
**Hạn nộp:** Tuần 12

## 🎯 Mục tiêu

Xây dựng CSDL cho hệ thống thương mại điện tử với quản lý khách hàng, người bán, sản phẩm, biến thể, danh mục, đơn hàng, tồn kho, khuyến mãi và đánh giá; sau đó dùng hệ thống làm môi trường nghiên cứu các kỹ thuật CSDL nâng cao.

## 🔎 Câu hỏi nghiên cứu

> **Làm thế nào để thiết kế, chuẩn hóa và tổ chức transaction cho CSDL thương mại điện tử nhằm đảm bảo tính đúng đắn của dữ liệu, đồng thời vẫn hỗ trợ hiệu quả các truy vấn SQL phức tạp và nghiệp vụ có tính cạnh tranh cao?**

## 🧩 Phạm vi hệ thống

- Khách hàng và người bán.
- Sản phẩm và biến thể sản phẩm.
- Danh mục sản phẩm.
- Đơn hàng và chi tiết đơn hàng.
- Kho và tồn kho.
- Khuyến mãi.
- Đánh giá sản phẩm.

## 🛠️ Công nghệ

- **RDBMS:** MySQL 8.0+
- **SQL nhúng:** Python + PyMySQL hoặc Java + JDBC + MySQL Connector.
- **Sinh dữ liệu:** Python Faker.
- **CSDL hướng đối tượng:** OQL và công cụ thực thi phù hợp.
- **Thiết kế:** diagrams.net / dbdiagram.io.
- **Quản lý mã nguồn:** GitHub.

## 🏗️ Nội dung thực hiện

### 1. Phân tích và thiết kế

- Đặc tả nghiệp vụ, quy tắc dữ liệu và EER.
- Chuyên biệt hóa/tổng quát hóa.
- Lược đồ quan hệ và từ điển dữ liệu.

### 2. Phụ thuộc hàm và chuẩn hóa

- Xác định FD, bao đóng, khóa và phủ tối thiểu.
- Phân tích 3NF/BCNF.
- Xét 4NF khi có phụ thuộc đa trị.
- Lập luận về nối không mất mát và bảo toàn phụ thuộc.

### 3. SQL nâng cao

Xây dựng **20 truy vấn**, bao gồm:

- Truy vấn con và truy vấn con tương quan.
- EXISTS / NOT EXISTS.
- Phép chia quan hệ.
- GROUP BY / HAVING.
- INNER JOIN / OUTER JOIN.
- Window functions.
- CTE và truy vấn đệ quy.
- Thống kê và phân tích dữ liệu.
- So sánh các cách viết bằng EXPLAIN ANALYZE.

### 4. Constraint, Trigger, Procedure và Function

- PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK.
- Trigger kiểm tra không bán vượt tồn kho.
- Procedure đặt hàng.
- Function tính khuyến mãi.
- Function xếp hạng người bán.
- ASSERTION được trình bày ở mức lý thuyết.

### 5. SQL động và SQL Injection

Xây dựng tìm kiếm sản phẩm theo tên, danh mục, khoảng giá, thương hiệu và đánh giá tối thiểu; phân tích SQL Injection và cách phòng tránh bằng parameterized query, validation và truy cập dữ liệu an toàn.

### 6. SQL nhúng

Minh họa kết nối MySQL, thực thi câu lệnh, fetch và cập nhật dữ liệu bằng Python/PyMySQL hoặc Java/JDBC.

### 7. SQL đệ quy

Sử dụng WITH RECURSIVE trên MySQL 8.0+ để duyệt cây danh mục và tổng hợp doanh thu theo nhánh.

### 8. CSDL hướng đối tượng và OQL

Dự kiến 4–6 lớp: KhachHang, SanPham, DonHang, ChiTietDonHang, KhuyenMai, DanhGia. Thực hiện tối thiểu **5 truy vấn OQL** và so sánh với SQL.

### 9. Transaction và đồng thời

Thực nghiệm đặt hàng thành công, lỗi giữa transaction dẫn đến rollback, và hai phiên đồng thời đặt sản phẩm cuối cùng; ghi log và phân tích kết quả.

### 10. Thực nghiệm và tối ưu hóa

- Tối thiểu khoảng **100.000 đơn hàng** cho kiểm thử chính.
- Có thể mở rộng lên hàng triệu bản ghi cho benchmark.
- Đo trước/sau tối ưu và phân tích EXPLAIN ANALYZE.
- Đánh giá ảnh hưởng của index đến truy vấn và chi phí cập nhật.
- Ghi lại số liệu để có thể tái lập.

## 📁 Cấu trúc repository dự kiến

    .
    ├── README.md
    ├── docs/
    │   ├── eer/
    │   ├── relational-schema/
    │   ├── data-dictionary/
    │   └── normalization/
    ├── database/
    │   ├── 01_schema.sql
    │   ├── 02_constraints.sql
    │   ├── 03_triggers.sql
    │   ├── 04_procedures.sql
    │   ├── 05_functions.sql
    │   ├── 06_recursive_queries.sql
    │   └── 07_queries.sql
    ├── data/
    ├── embedded-sql/
    ├── object-db/
    ├── experiments/
    ├── scripts/
    ├── slides/
    └── report/

## 📊 Tiến độ 12 tuần

| Thời gian  | Nội dung                                                                     |
| ----------- | ----------------------------------------------------------------------------- |
| Tuần 1–2  | Chọn đề tài, câu hỏi nghiên cứu, phạm vi, tài liệu và phân công |
| Tuần 3     | Đặc tả nghiệp vụ, EER và ràng buộc                                    |
| Tuần 4–5  | Phụ thuộc hàm, khóa, chuẩn hóa và lược đồ quan hệ                 |
| Tuần 6–8  | CSDL quan hệ, SQL nâng cao, dữ liệu và kiểm thử                        |
| Tuần 9–10 | CSDL hướng đối tượng, OQL và SQL nhúng/động                         |
| Tuần 11    | Transaction, đồng thời và thực nghiệm                                   |
| Tuần 12    | Báo cáo, slide, demo và bảo vệ                                           |

## 📦 Sản phẩm

- Báo cáo khoảng **20–30 trang** không tính phụ lục.
- Slide thuyết trình.
- Mã nguồn và script CSDL.
- DDL, constraint, trigger, procedure, function và 20 truy vấn SQL.
- Dữ liệu mẫu và script sinh dữ liệu.
- Bộ truy vấn OQL.
- Script SQL nhúng.
- Kịch bản transaction và kết quả thực nghiệm.
- Bảng/đồ thị đánh giá hiệu năng.
- Nhật ký thực nghiệm, runbook và biên bản làm việc nhóm.

## 🚀 Hướng dẫn chạy

### Yêu cầu

- MySQL 8.0+.
- Python 3.x nếu dùng script Python.
- Git.

### Quy trình tổng quát

    git clone <repository-url></repository>
    cd <repository-folder></repository>
    pip install -r requirements.txt

Chạy các script trong thư mục database theo thứ tự và sử dụng runbook để tái lập thực nghiệm.

## ✅ Checklist

- [ ] Đặc tả nghiệp vụ, EER và lược đồ quan hệ hoàn chỉnh.
- [ ] FD, bao đóng, khóa, phủ tối thiểu và chuẩn hóa được chứng minh.
- [ ] Đủ 20 truy vấn SQL và có EXPLAIN ANALYZE.
- [ ] Có CHECK, trigger, procedure/function và SQL động.
- [ ] Có phân tích SQL Injection và SQL nhúng.
- [ ] Có WITH RECURSIVE.
- [ ] Có 4–6 lớp và tối thiểu 5 truy vấn OQL.
- [ ] Có transaction thành công, rollback và cạnh tranh.
- [ ] Có dữ liệu lớn, benchmark và kết quả trước/sau tối ưu.
- [ ] Có runbook tái lập.

## 📚 Tài liệu tham khảo

- **Database System Concepts** – Silberschatz, Korth, Sudarshan.
- **Fundamentals of Database Systems** – Elmasri & Navathe.
- **Database Systems: A Practical Approach to Design, Implementation, and Management** – Connolly & Begg.
- MySQL 8.0 Documentation.
- Tài liệu OQL / ObjectDB cho phần CSDL hướng đối tượng.

## 📌 Trạng thái

**Đang phát triển – Đồ án môn CSDL Nâng cao, Đề tài 7.**

Repository này dùng để quản lý mã nguồn, script CSDL, dữ liệu, tài liệu và kết quả thực nghiệm của Nhóm 7.
