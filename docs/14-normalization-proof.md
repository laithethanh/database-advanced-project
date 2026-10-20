# Bổ sung chứng minh chuẩn hóa

## Cơ sở phủ tối thiểu

Với mỗi quan hệ cơ sở, tách FD sao cho vế phải chỉ còn một thuộc tính. Một số phụ thuộc tiêu biểu trong phủ gồm `account_id→email`, `email→account_id`, `variant_id→sku`, `sku→variant_id`, `(seller_id,variant_id)→quantity_on_hand`, `(seller_id,variant_id)→reserved_quantity`, `order_id→order_number`, `order_number→order_id` và `(order_id,seller_id,variant_id)→order_item_id`. Các thuộc tính không liệt kê ở vế trái cũng được xác định bởi khóa chính/khóa ứng viên UNIQUE đã khai báo của quan hệ tương ứng. Không thể rút gọn thêm vế trái: hai thuộc tính trong khóa tồn kho/chi tiết đơn hàng xác định các chiều dữ liệu khác nhau.

## Khóa và dạng chuẩn

Các khóa ứng viên trong `06-normalization.md` suy ra trực tiếp từ phủ trên cùng các ràng buộc UNIQUE. Trong `account`, `email` là khóa thay thế; trong `product_variant`, `sku` là khóa thay thế; trong `orders`, `order_number` là khóa thay thế. Mọi FD không tầm thường trong các quan hệ lõi đều có vế trái là siêu khóa, vì vậy chúng đạt BCNF theo các phụ thuộc đã khai báo. Các quan hệ kết hợp (`inventory`, `cart_item`, `promotion_product`, `promotion_category`, `order_promotion`) không có vế trái phụ thuộc không khóa và cũng đạt BCNF.

`order_item` chủ ý lưu bản chụp giá/tên/SKU vì nó mô hình hóa sự kiện bán hàng trong quá khứ. Các giá trị này mô tả dòng hàng tại thời điểm đặt đơn, không phụ thuộc vào dữ liệu danh mục có thể thay đổi. Việc lặp dữ liệu lịch sử có kiểm soát này ngăn sai lệch cập nhật trong lịch sử kiểm toán.

## Phép nối không mất mát và bảo toàn phụ thuộc

Các bảng kiểu con phân rã `Account` không mất mát vì `customer.account_id` và `seller.account_id` là tham chiếu PK/FK tới `account`. Ánh xạ N:M không mất mát vì mỗi bảng trung gian chứa hai khóa được tham chiếu. Có thể khôi phục đơn hàng bằng `orders ⋈ order_item` không mất mát nhờ FK `order_item.order_id` không được phép NULL; mức chi tiết từng dòng vẫn được giữ rõ ràng. Khai báo FK/PK/UNIQUE bảo toàn các phụ thuộc khóa tại từng bảng, trong khi các điều kiện liên quan nhiều dòng (tổng tiền, trạng thái hợp lệ, điều kiện đánh giá và tồn kho) được thực thi có chủ ý bằng trigger/procedure vì FD SQL không thể biểu diễn chúng.

## 4NF

Các dữ kiện đa trị độc lập được tách riêng: biến thể sản phẩm được lưu thành các dòng thay vì danh sách màu/size trong sản phẩm; khuyến mãi có các bảng trung gian sản phẩm/danh mục riêng; tồn kho theo người bán được lưu qua bảng trung gian `inventory`. Vì vậy, không có quan hệ nào lưu cặp thuộc tính đa trị độc lập gây bất thường 4NF.
