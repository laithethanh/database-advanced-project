package vn.edu.ecommerce.objectdb.seed;

import jakarta.persistence.EntityManager;
import vn.edu.ecommerce.objectdb.model.AccountStatus;
import vn.edu.ecommerce.objectdb.model.Customer;
import vn.edu.ecommerce.objectdb.model.Order;
import vn.edu.ecommerce.objectdb.model.OrderLine;
import vn.edu.ecommerce.objectdb.model.OrderStatus;
import vn.edu.ecommerce.objectdb.model.Product;
import vn.edu.ecommerce.objectdb.model.ProductStatus;
import vn.edu.ecommerce.objectdb.model.ProductVariant;
import vn.edu.ecommerce.objectdb.model.Seller;
import vn.edu.ecommerce.objectdb.model.ShopStatus;
import vn.edu.ecommerce.objectdb.model.VariantStatus;

import java.math.BigDecimal;

/**
 * Du lieu mau co dinh, du nho de kiem chung 5 truy van OQ01-OQ05.
 *
 * Ket qua ky vong:
 * - OQ01 (alice@example.com): ORD-1001.
 * - OQ02 (price > 1000): Laptop Pro.
 * - OQ03 (SKU-MOU-BLK): Shop Alpha.
 * - OQ04: alice = 3350.00, bob = 50.00, carol = 0.00.
 * - OQ05 (PAID): ORD-1002, 1 dong hang.
 */
public final class SampleData {

    private SampleData() {
    }

    public static final class Data {
        public Customer alice;
        public Customer bob;
        public Customer carol;
        public Seller alpha;
        public Seller beta;
        public Seller gamma;
        public Product laptop;
        public Product mouse;
        public Product phone;
        public ProductVariant lap14;
        public ProductVariant lap16;
        public ProductVariant mouseBlack;
        public ProductVariant mouseWhite;
        public ProductVariant phoneOld;
        public Order order1001;
        public Order order1002;
        public Order order1003;
        public Order order1004;
        public Order order1005;
    }

    public static Data seed(EntityManager em) {
        Data d = new Data();

        d.laptop = new Product("Laptop Pro", "TechOne", ProductStatus.ACTIVE);
        d.mouse = new Product("Wireless Mouse", "TechOne", ProductStatus.ACTIVE);
        d.phone = new Product("Old Phone", "Retro", ProductStatus.INACTIVE);

        d.lap14 = new ProductVariant("SKU-LAP-14", money("1500.00"), VariantStatus.ACTIVE);
        d.lap16 = new ProductVariant("SKU-LAP-16", money("1800.00"), VariantStatus.ACTIVE);
        d.mouseBlack = new ProductVariant("SKU-MOU-BLK", money("25.00"), VariantStatus.ACTIVE);
        d.mouseWhite = new ProductVariant("SKU-MOU-WHT", money("30.00"), VariantStatus.ACTIVE);
        d.phoneOld = new ProductVariant("SKU-PHN-OLD", money("200.00"), VariantStatus.INACTIVE);

        d.laptop.addVariant(d.lap14);
        d.laptop.addVariant(d.lap16);
        d.mouse.addVariant(d.mouseBlack);
        d.mouse.addVariant(d.mouseWhite);
        d.phone.addVariant(d.phoneOld);

        em.persist(d.laptop);
        em.persist(d.mouse);
        em.persist(d.phone);

        d.alice = new Customer("alice@example.com", "Alice Nguyen", AccountStatus.ACTIVE);
        d.bob = new Customer("bob@example.com", "Bob Tran", AccountStatus.ACTIVE);
        d.carol = new Customer("carol@example.com", "Carol Le", AccountStatus.ACTIVE);

        d.alpha = new Seller("alpha@example.com", "Alpha Owner", ShopStatus.ACTIVE, "Shop Alpha");
        d.beta = new Seller("beta@example.com", "Beta Owner", ShopStatus.ACTIVE, "Shop Beta");
        d.gamma = new Seller("gamma@example.com", "Gamma Owner", ShopStatus.SUSPENDED, "Shop Gamma");

        d.alpha.addInventory(d.lap14);
        d.alpha.addInventory(d.lap16);
        d.alpha.addInventory(d.mouseBlack);
        d.beta.addInventory(d.lap14);
        d.beta.addInventory(d.mouseWhite);
        d.gamma.addInventory(d.phoneOld);

        em.persist(d.alice);
        em.persist(d.bob);
        em.persist(d.carol);
        em.persist(d.alpha);
        em.persist(d.beta);
        em.persist(d.gamma);

        d.order1001 = order(d.alice, "ORD-1001", OrderStatus.DELIVERED,
                line(d.alpha, "SKU-LAP-14", 1, "1500.00"),
                line(d.alpha, "SKU-MOU-BLK", 2, "25.00"));
        d.order1002 = order(d.alice, "ORD-1002", OrderStatus.PAID,
                line(d.alpha, "SKU-LAP-16", 1, "1800.00"));
        d.order1003 = order(d.alice, "ORD-1003", OrderStatus.CANCELLED,
                line(d.beta, "SKU-MOU-WHT", 1, "30.00"));
        d.order1004 = order(d.bob, "ORD-1004", OrderStatus.SHIPPED,
                line(d.alpha, "SKU-MOU-BLK", 2, "25.00"));
        d.order1005 = order(d.bob, "ORD-1005", OrderStatus.PENDING_PAYMENT,
                line(d.beta, "SKU-MOU-WHT", 1, "30.00"));

        em.persist(d.order1001);
        em.persist(d.order1002);
        em.persist(d.order1003);
        em.persist(d.order1004);
        em.persist(d.order1005);

        em.flush();
        return d;
    }

    private static Order order(Customer customer, String number, OrderStatus status, OrderLine... lines) {
        Order order = new Order(number, status);
        for (OrderLine line : lines) {
            order.addItem(line);
        }
        order.setGrandTotal(order.total());
        customer.addOrder(order);
        return order;
    }

    private static OrderLine line(Seller seller, String sku, long quantity, String unitPrice) {
        return OrderLine.of(sku, quantity, money(unitPrice), seller);
    }

    private static BigDecimal money(String value) {
        return new BigDecimal(value).setScale(2);
    }
}
