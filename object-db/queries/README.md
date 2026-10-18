# OQL query set

`ecommerce.oql` contains five OQL queries. For ObjectDB/JPA evidence, use these JPQL equivalents:

| OQL | JPQL shape |
|---|---|
| OQ01 | `SELECT o FROM Order o WHERE o.customer.email=:email AND o.status='DELIVERED'` |
| OQ02 | `SELECT DISTINCT v.product FROM ProductVariant v WHERE v.price>:price` |
| OQ03 | `SELECT s FROM Seller s JOIN s.inventory v WHERE v.sku=:sku` |
| OQ04 | `SELECT c.email, SUM(o.grandTotal) FROM Customer c JOIN c.orders o WHERE o.status IN (...) GROUP BY c.email` |
| OQ05 | Fetch `Order` and `JOIN FETCH o.items`; JPQL does not natively project a nested collection like OQL. |

Capture ObjectDB/JPQL results and generated SQL (if ORM is used) in the appendix. The OQL specifications remain independent from execution technology.
