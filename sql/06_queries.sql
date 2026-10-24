USE ecommerce_advanced;

-- Q01–Q25 được đặc tả trong docs/08-query-catalog.md.
-- Mỗi query sẽ được bổ sung SQL + expected result + execution plan trong giai đoạn SQL nâng cao.

--------------------------------------------------
-- PHẦN BỔ SUNG: TRUY VẤN KIỂM TRA RÀNG BUỘC & TRẠNG THÁI (KHOA)
--------------------------------------------------

-- Q21: Kiểm tra các giỏ hàng vi phạm quy tắc mỗi khách hàng chỉ có tối đa 1 giỏ hàng ACTIVE
SELECT customer_id, COUNT(*) AS active_cart_count
FROM cart
WHERE status = 'ACTIVE'
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Q22: Kiểm tra các biến thể sản phẩm có số lượng tồn kho khả dụng âm hoặc vi phạm ràng buộc quantity_on_hand >= reserved_quantity
SELECT variant_id, warehouse_id, quantity_on_hand, reserved_quantity
FROM inventory
WHERE quantity_on_hand < reserved_quantity OR quantity_on_hand < 0 OR reserved_quantity < 0;

-- Q23: Thống kê số lượng đơn hàng theo từng trạng thái trong quy trình xử lý đơn hàng (Order State Machine)
SELECT status, COUNT(*) AS total_orders, SUM(grand_total) AS total_revenue
FROM orders
GROUP BY status;

-- Q24: Truy vấn danh sách đánh giá (review) nhưng khách hàng chưa từng mua sản phẩm đó qua chi tiết đơn hàng (OrderItem)
SELECT r.review_id, r.customer_id, r.product_id, r.rating
FROM review r
WHERE NOT EXISTS (
    SELECT 1 
    FROM order_item oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.customer_id = r.customer_id 
      AND oi.variant_id IN (SELECT pv.variant_id FROM product_variant pv WHERE pv.product_id = r.product_id)
      AND o.status = 'DELIVERED'
);

-- Q25: Kiểm tra các sản phẩm có giá khuyến mãi lớn hơn giá niêm yết hoặc giá trị giảm giá không hợp lệ
SELECT variant_id, sku, price, compare_at_price
FROM product_variant
WHERE compare_at_price IS NOT NULL AND compare_at_price < price;

--------------------------------------------------
-- PHẦN BỔ SUNG: TRUY VẤN VÀ KỊCH BẢN GIAO DỊCH (TRANSACTION-RELATED)
--------------------------------------------------

-- Q26: Kịch bản giao dịch đặt hàng và giữ chỗ tồn kho an toàn (Transactional Inventory Reservation & Order Placement)
-- Đảm bảo tính nguyên tử (Atomicity): Nếu tồn kho không đủ hoặc lỗi phát sinh, toàn bộ giao dịch được hoàn tác (ROLLBACK)
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @VariantID INT = 1;
    DECLARE @OrderQty INT = 2;
    
    IF (SELECT (quantity_on_hand - reserved_quantity) FROM inventory WHERE variant_id = @VariantID) >= @OrderQty
    BEGIN
        -- Cập nhật giữ chỗ tồn kho
        UPDATE inventory 
        SET reserved_quantity = reserved_quantity + @OrderQty 
        WHERE variant_id = @VariantID;

        COMMIT TRANSACTION;
        PRINT N'Giao dịch đặt hàng và giữ chỗ tồn kho thành công.';
    END
    ELSE
    BEGIN
        -- Không đủ hàng trong kho -> Hủy giao dịch
        ROLLBACK TRANSACTION;
        PRINT N'Giao dịch thất bại: Không đủ tồn kho khả dụng.';
    END
END TRY
BEGIN CATCH
    -- Xảy ra lỗi hệ thống -> Rollback đảm bảo toàn vẹn dữ liệu
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT N'Lỗi giao dịch: ' + ERROR_MESSAGE();
END CATCH;

-- Q27: Truy vấn kiểm tra mức cô lập giao dịch (Transaction Isolation Level) và trạng thái khóa tài nguyên khi cập nhật thanh toán
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;
    -- Kiểm tra trạng thái đơn hàng trước khi xử lý thanh toán
    SELECT order_id, status, grand_total 
    FROM orders 
    WHERE status = 'PENDING';
COMMIT TRANSACTION;