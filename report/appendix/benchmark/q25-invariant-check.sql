SELECT 'q25_violations' AS chk, COUNT(*) AS cnt FROM (
  SELECT o.order_id FROM orders o WHERE o.subtotal<>(SELECT COALESCE(SUM(line_total),0) FROM order_item oi WHERE oi.order_id=o.order_id)
  UNION ALL SELECT o.order_id FROM orders o WHERE o.grand_total<>o.subtotal-o.discount_total+o.shipping_fee
  UNION ALL SELECT o.order_id FROM orders o WHERE o.discount_total<>(SELECT COALESCE(SUM(discount_amount),0) FROM order_promotion op WHERE op.order_id=o.order_id)
  UNION ALL SELECT oi.order_item_id FROM order_item oi WHERE oi.line_total<>oi.quantity*oi.unit_price-oi.line_discount
  UNION ALL SELECT i.variant_id FROM inventory i WHERE i.reserved_quantity>i.quantity_on_hand
  UNION ALL SELECT p.payment_id FROM payment p JOIN orders o ON o.order_id=p.order_id WHERE p.status='SUCCESS' AND p.amount<>o.grand_total
  UNION ALL SELECT r.review_id FROM review r WHERE NOT EXISTS (SELECT 1 FROM order_item oi JOIN orders o ON o.order_id=oi.order_id JOIN product_variant v ON v.variant_id=oi.variant_id WHERE oi.order_item_id=r.order_item_id AND o.customer_id=r.customer_id AND v.product_id=r.product_id AND o.status='DELIVERED')
) t;
