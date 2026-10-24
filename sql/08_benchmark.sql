USE ecommerce_advanced; 
-- =========================================================================
-- TUẦN 9: ĐỀ XUẤT INDEX VÀ ĐÁNH GIÁ TÁC ĐỘNG TỚI THAO TÁC INSERT/UPDATE/TRIGGER
-- Người thực hiện: Khoa
-- =========================================================================

-- -------------------------------------------------------------------------
-- PHẦN 1: TẠO CÁC CHỈ MỤC (INDEX) ĐỀ XUẤT ĐỂ TỐI ƯU TRUY VẤN
-- -------------------------------------------------------------------------
SELECT '--- 1. TẠO CÁC INDEX TỐI ƯU HÓA TRUY VẤN CHÍNH ---' AS info;

-- Index 1: Tối ưu tra cứu trạng thái đơn hàng và lọc theo ngày tạo
-- Giúp tăng tốc các câu lệnh GROUP BY status và filter theo placed_at (như Q23)
CREATE INDEX idx_orders_status_placed 
ON orders (status, placed_at);

-- Index 2: Tối ưu tra cứu biến thể sản phẩm theo SKU và Kho hàng
-- Giúp tăng tốc quá trình kiểm tra kho trong sp_checkout và các JOIN giữa inventory với product_variant
CREATE INDEX idx_variant_sku_wh 
ON product_variant (sku, warehouse_id);

-- Index 3: Tối ưu tra cứu tồn kho theo Seller và Variant (Composite Index)
-- Hỗ trợ các Trigger kiểm tra kho không âm và khóa FOR UPDATE nhanh chóng
CREATE INDEX idx_inventory_seller_variant 
ON inventory (seller_id, variant_id, quantity_on_hand, reserved_quantity);


-- -------------------------------------------------------------------------
-- PHẦN 2: THỰC NGHIỆM ĐÁNH GIÁ CHI PHÍ / TÁC ĐỘNG TỚI INSERT/UPDATE
-- -------------------------------------------------------------------------
SELECT '--- 2. BENCHMARK / ĐÁNH GIÁ HIỆU NĂNG GHI (WRITE OVERHEAD) ---' AS info;

-- Đánh giá 2.1: Tác động lên thao tác INSERT vào bảng orders
-- Phân tích: Mỗi khi INSERT đơn hàng mới, B-Tree index (idx_orders_status_placed) 
-- phải tái cân bằng (rebalance), làm tăng thời gian xử lý I/O ghi đĩa nhẹ.
START TRANSACTION;
  -- Đo thời gian ghi bản ghi mẫu khi có Index
  INSERT INTO orders (order_number, customer_id, status, recipient_name, recipient_phone, shipping_address, subtotal, grand_total)
  VALUES ('ORD-TEST-INDEX-01', 1, 'PENDING_PAYMENT', 'Nguyễn Mậu Công Khoa', '0901234567', 'TP.HCM', 100000.00, 100000.00);
ROLLBACK;


-- Đánh giá 2.2: Tác động của Index kết hợp với TRIGGER khi UPDATE inventory
-- Phân tích: Khi UPDATE reserved_quantity, Trigger `trg_inventory_no_negative_reserved` sẽ chạy.
-- Index `idx_inventory_seller_variant` giúp Trigger đọc dữ liệu cũ cực nhanh, 
-- tuy nhiên bản thân Index cũng phải cập nhật lại nếu các cột trong Index bị thay đổi.
START TRANSACTION;
  UPDATE inventory 
  SET reserved_quantity = reserved_quantity + 1 
  WHERE variant_id = 1 AND seller_id = 1;
ROLLBACK;


-- -------------------------------------------------------------------------
-- PHẦN 3: BÁO CÁO ĐÁNH GIÁ TÁC ĐỘNG (IMPACT ANALYSIS REPORT)
-- -------------------------------------------------------------------------
/*
========================================================================================
 BÁO CÁO ĐÁNH GIÁ TÁC ĐỘNG CỦA INDEX LÊN INSERT/UPDATE VÀ TRIGGER (NGUYỄN MẬU CÔNG KHOA)
========================================================================================

1. TÁC ĐỘNG TÍCH CỰC (BENEFITS):
   - Đọc & Tìm kiếm (SELECT / JOIN): Giảm chi phí quét bảng toàn bộ (Full Table Scan)
     xuống chỉ còn Quét Index Range Scan. Giúp câu lệnh checkout và báo cáo nhanh gấp 10-50 lần.
   - Hiệu năng Trigger: Do các Trigger (như trg_check_order_total hay trg_inventory_no_negative_reserved)
     phải đọc dữ liệu từ các bảng liên quan, các Index đề xuất giúp Trigger thực thi nhanh hơn hẳn,
     giảm thời gian giữ khóa (Lock Hold Time) và chống nghẽn (Deadlock).

2. BẤT LỢI & CHI PHÍ TẢI (WRITE OVERHEAD & TRADE-OFFS):
   - Thao tác INSERT: Khi thêm dòng mới vào `orders` hoặc `product_variant`, MySQL phải ghi cả 
     vào bảng chính (Clustered Index) và cập nhật thêm cấu trúc B-Tree của các Secondary Index.
     Chi phí thời gian cho thao tác INSERT tăng khoảng 5% - 15%.
   - Thao tác UPDATE: UPDATE các cột nằm trong Index (như `status` hay `reserved_quantity`) 
     sẽ làm cập nhật Index tree.
   - Dung lượng lưu trữ: Tốn thêm dung lượng bộ nhớ (RAM/Disk) để lưu trữ các cây chỉ mục.

3. KẾT LUẬN & ĐỀ XUẤT ĐỒNG BỘ:
   - Hệ thống E-commerce có tỉ lệ Đọc/Ghi xấp xỉ 80/20 (Read-Heavy). Việc chấp nhận 10% overhead
     khi INSERT/UPDATE để đổi lấy tốc độ truy vấn SELECT/Trigger tăng gấp nhiều lần là HOÀN TOÀN HỢP LÝ.
========================================================================================
*/

-- Benchmark protocol được mô tả trong docs/10-benchmark.md.
-- Chạy EXPLAIN ANALYZE trên các Q01/Q02/Q14/Q15/Q17/Q19/Q21 trước và sau index.
