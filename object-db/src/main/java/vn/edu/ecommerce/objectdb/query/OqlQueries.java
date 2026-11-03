package vn.edu.ecommerce.objectdb.query;

import jakarta.persistence.EntityManager;
import vn.edu.ecommerce.objectdb.model.Order;
import vn.edu.ecommerce.objectdb.model.OrderStatus;
import vn.edu.ecommerce.objectdb.model.Product;
import vn.edu.ecommerce.objectdb.model.Seller;

import java.math.BigDecimal;
import java.util.List;

/**
 * Nam truy van OQ01-OQ05 duoc chuyen sang JPQL de chay tren ObjectDB.
 * Cac hang so JPQL duoc giu dong bo voi queries/ecommerce.jpql.
 */
public final class OqlQueries {

    public static final String OQ01_JPQL =
            "SELECT o FROM Order o "
                    + "WHERE o.customer.email = :email AND o.status = :status "
                    + "ORDER BY o.orderNumber";

    public static final String OQ02_JPQL =
            "SELECT DISTINCT v.product FROM ProductVariant v "
                    + "WHERE v.price > :price "
                    + "ORDER BY v.product.name";

    public static final String OQ03_JPQL =
            "SELECT s FROM Seller s JOIN s.inventory v "
                    + "WHERE s.shopStatus = :shopStatus AND v.sku = :sku "
                    + "ORDER BY s.shopName";

    public static final String OQ04_ALL_JPQL =
            "SELECT c.email FROM Customer c ORDER BY c.email";

    public static final String OQ04_JPQL =
            "SELECT o.customer.email, SUM(o.grandTotal) "
                    + "FROM Order o "
                    + "WHERE o.status IN :statuses "
                    + "GROUP BY o.customer.email "
                    + "ORDER BY o.customer.email";

    public static final String OQ05_JPQL =
            "SELECT o FROM Order o "
                    + "WHERE o.status = :status "
                    + "ORDER BY o.orderNumber";

    private OqlQueries() {
    }

    public static List<Order> oq01(EntityManager em, String email, OrderStatus status) {
        return em.createQuery(OQ01_JPQL, Order.class)
                .setParameter("email", email)
                .setParameter("status", status)
                .getResultList();
    }

    public static List<Product> oq02(EntityManager em, BigDecimal price) {
        return em.createQuery(OQ02_JPQL, Product.class)
                .setParameter("price", price)
                .getResultList();
    }

    public static List<Seller> oq03(EntityManager em, String sku) {
        return em.createQuery(OQ03_JPQL, Seller.class)
                .setParameter("shopStatus", vn.edu.ecommerce.objectdb.model.ShopStatus.ACTIVE)
                .setParameter("sku", sku)
                .getResultList();
    }

    public static List<Object[]> oq04(EntityManager em, List<OrderStatus> statuses) {
        List<Object[]> sumRows = em.createQuery(OQ04_JPQL, Object[].class)
                .setParameter("statuses", statuses)
                .getResultList();

        java.util.Map<String, BigDecimal> sums = new java.util.LinkedHashMap<>();
        for (Object[] row : sumRows) {
            sums.put((String) row[0], toBigDecimal(row[1]));
        }

        List<String> emails = em.createQuery(OQ04_ALL_JPQL, String.class).getResultList();
        java.util.List<Object[]> rows = new java.util.ArrayList<>();
        for (String email : emails) {
            rows.add(new Object[]{email, sums.getOrDefault(email, BigDecimal.ZERO)});
        }
        return rows;
    }

    private static BigDecimal toBigDecimal(Object value) {
        if (value == null) {
            return BigDecimal.ZERO;
        }
        if (value instanceof BigDecimal) {
            return (BigDecimal) value;
        }
        if (value instanceof Number) {
            return BigDecimal.valueOf(((Number) value).doubleValue());
        }
        return new BigDecimal(value.toString());
    }

    public static List<Order> oq05(EntityManager em, OrderStatus status) {
        return em.createQuery(OQ05_JPQL, Order.class)
                .setParameter("status", status)
                .getResultList();
    }
}
