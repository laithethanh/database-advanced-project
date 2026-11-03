package vn.edu.ecommerce.objectdb;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.Persistence;
import vn.edu.ecommerce.objectdb.model.Customer;
import vn.edu.ecommerce.objectdb.model.Order;
import vn.edu.ecommerce.objectdb.model.OrderLine;
import vn.edu.ecommerce.objectdb.model.OrderStatus;
import vn.edu.ecommerce.objectdb.model.Product;
import vn.edu.ecommerce.objectdb.model.ProductVariant;
import vn.edu.ecommerce.objectdb.model.Seller;
import vn.edu.ecommerce.objectdb.query.OqlQueries;
import vn.edu.ecommerce.objectdb.seed.SampleData;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Chạy ObjectDB/JPA và xuất bằng chứng cho OQ01–OQ05.
 *
 * Cách chạy từ thư mục object-db:
 *   mvn -q compile exec:java -Dexec.args=evidence/oql-output.md
 */
public final class Main {

    private static final String OBJECTDB_VERSION = "2.9.5";
    private static final DateTimeFormatter TIMESTAMP =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private final StringBuilder report = new StringBuilder();
    private int passed;
    private int failed;

    public static void main(String[] args) throws Exception {
        Path output = Path.of(args.length > 0 ? args[0] : "evidence/oql-output.md");
        Main app = new Main();
        app.run(output);
    }

    private void run(Path output) throws Exception {
        deleteDatabase();

        header(output);

        EntityManagerFactory emf = Persistence.createEntityManagerFactory("ecommerce-objectdb");
        try (EntityManager em = emf.createEntityManager()) {
            em.getTransaction().begin();
            SampleData.seed(em);
            em.getTransaction().commit();
            em.clear();

            em.getTransaction().begin();
            try {
                writeDatasetSummary(em);
                runOq01(em);
                runOq02(em);
                runOq03(em);
                runOq04(em);
                runOq05(em);
                runBusinessMethods(em);
                writeMapping();
                writeConclusion();
            } finally {
                em.getTransaction().commit();
            }
        } finally {
            emf.close();
        }

        writeFile(output, report.toString());
        System.out.println(report);

        if (failed > 0) {
            throw new IllegalStateException("Có " + failed + " kiểm tra FAIL; xem " + output);
        }
    }

    private void header(Path output) {
        report.append("# Bằng chứng ObjectDB/JPA — OQ01–OQ05\n\n");
        report.append("- Thời điểm chạy: **")
                .append(LocalDateTime.now().format(TIMESTAMP))
                .append("**\n");
        report.append("- Nơi lưu: `").append(output.toAbsolutePath().normalize()).append("`\n");
        report.append("- Môi trường: Java **").append(System.getProperty("java.version"))
                .append("**, OS **").append(System.getProperty("os.name")).append(' ')
                .append(System.getProperty("os.version")).append("**\n");
        report.append("- Provider: **ObjectDB ").append(OBJECTDB_VERSION)
                .append(" (jakarta)**, Jakarta Persistence 3.1\n");
        report.append("- CSDL: `target/objectdb/ecommerce.odb` (xóa và tạo mới trước mỗi lần chạy)\n");
        report.append("- Dữ liệu: bộ mẫu cố định trong `SampleData` (3 khách hàng, 3 người bán, ")
                .append("3 sản phẩm, 5 biến thể, 5 đơn hàng)\n");
        report.append("- Ghi chú OID: ObjectDB quản lý OID nội bộ; trường `id` là surrogate key JPA, ")
                .append("còn `email`, `sku`, `orderNumber` là định danh nghiệp vụ UNIQUE.\n\n");
    }

    private void writeDatasetSummary(EntityManager em) {
        section("0. Tóm tắt dữ liệu");
        tableRow("Account", count(em, "Account"));
        tableRow("Customer", count(em, "Customer"));
        tableRow("Seller", count(em, "Seller"));
        tableRow("Product", count(em, "Product"));
        tableRow("ProductVariant", count(em, "ProductVariant"));
        tableRow("Order", count(em, "Order"));
        report.append('\n');
    }

    private void runOq01(EntityManager em) {
        section("OQ01 — Đơn hàng đã giao của một khách hàng");
        report.append("**OQL**\n\n```text\n")
                .append("SELECT o FROM Order o WHERE o.customer.email = $email AND o.status = 'DELIVERED';\n")
                .append("```\n\n");
        report.append("**JPQL**\n\n```text\n").append(OqlQueries.OQ01_JPQL).append("\n```\n\n");
        report.append("**Tham số:** `email = alice@example.com`, `status = DELIVERED`\n\n");

        List<Order> orders = OqlQueries.oq01(em, "alice@example.com", OrderStatus.DELIVERED);
        String actual = orders.stream().map(Order::getOrderNumber).collect(Collectors.joining(", "));
        report.append("**Kết quả:** ").append(orders.isEmpty() ? "(không có)" : formatOrders(orders)).append("\n\n");
        check("OQ01 trả về đúng ORD-1001", "ORD-1001".equals(actual), "ORD-1001", actual);
    }

    private void runOq02(EntityManager em) {
        section("OQ02 — Sản phẩm có ít nhất một biến thể giá cao hơn ngưỡng");
        report.append("**OQL**\n\n```text\n")
                .append("SELECT DISTINCT v.product FROM ProductVariant v WHERE v.price > $price;\n")
                .append("```\n\n");
        report.append("**JPQL**\n\n```text\n").append(OqlQueries.OQ02_JPQL).append("\n```\n\n");
        report.append("**Tham số:** `price = 1000.00`\n\n");

        List<Product> products = OqlQueries.oq02(em, money("1000.00"));
        String actual = products.stream().map(Product::getName).collect(Collectors.joining(", "));
        report.append("**Kết quả:** ").append(products.isEmpty() ? "(không có)" : formatProducts(products)).append("\n\n");
        check("OQ02 chỉ trả về Laptop Pro", "Laptop Pro".equals(actual), "Laptop Pro", actual);
    }

    private void runOq03(EntityManager em) {
        section("OQ03 — Người bán đang cung cấp SKU được yêu cầu");
        report.append("**OQL**\n\n```text\n")
                .append("SELECT s FROM Seller s WHERE s.shopStatus = 'ACTIVE' ")
                .append("AND EXISTS v IN s.inventory: v.sku = $sku;\n")
                .append("```\n\n");
        report.append("**JPQL**\n\n```text\n").append(OqlQueries.OQ03_JPQL).append("\n```\n\n");
        report.append("**Tham số:** `sku = SKU-MOU-BLK`, `shopStatus = ACTIVE`\n\n");

        List<Seller> sellers = OqlQueries.oq03(em, "SKU-MOU-BLK");
        String actual = sellers.stream().map(Seller::getShopName).collect(Collectors.joining(", "));
        report.append("**Kết quả:** ").append(sellers.isEmpty() ? "(không có)" : formatSellers(sellers)).append("\n\n");
        check("OQ03 chỉ trả về Shop Alpha", "Shop Alpha".equals(actual), "Shop Alpha", actual);
    }

    private void runOq04(EntityManager em) {
        section("OQ04 — Tổng giá trị đơn hàng đã ghi nhận của mỗi khách hàng");
        report.append("**OQL**\n\n```text\n")
                .append("SELECT STRUCT(email: c.email, ltv: c.lifetimeValue()) FROM Customer c;\n")
                .append("```\n\n");
        report.append("**JPQL** (hai bước: lấy đủ khách hàng + tổng theo trạng thái)\n\n");
        report.append("```text\n").append(OqlQueries.OQ04_ALL_JPQL).append("\n```\n\n");
        report.append("```text\n").append(OqlQueries.OQ04_JPQL).append("\n```\n\n");
        report.append("**Tham số:** `statuses = [PAID, PROCESSING, SHIPPED, DELIVERED]`\n\n");

        List<OrderStatus> statuses = List.of(
                OrderStatus.PAID, OrderStatus.PROCESSING,
                OrderStatus.SHIPPED, OrderStatus.DELIVERED);
        List<Object[]> rows = OqlQueries.oq04(em, statuses);

        Map<String, BigDecimal> actual = new LinkedHashMap<>();
        for (Object[] row : rows) {
            actual.put((String) row[0], toBigDecimal(row[1]));
        }

        report.append("**Kết quả:**\n\n");
        for (Map.Entry<String, BigDecimal> entry : actual.entrySet()) {
            report.append("- `").append(entry.getKey()).append("` → **")
                    .append(formatMoney(entry.getValue())).append("**\n");
        }
        report.append('\n');

        Map<String, BigDecimal> expected = new LinkedHashMap<>();
        expected.put("alice@example.com", money("3350.00"));
        expected.put("bob@example.com", money("50.00"));
        expected.put("carol@example.com", money("0.00"));
        check("OQ04 khớp lifetimeValue kỳ vọng",
                sameMoneyMap(actual, expected),
                formatMoneyMap(expected), formatMoneyMap(actual));
    }

    private void runOq05(EntityManager em) {
        section("OQ05 — Đơn hàng đã thanh toán kèm danh sách dòng hàng");
        report.append("**OQL**\n\n```text\n")
                .append("SELECT STRUCT(number: o.orderNumber, total: o.total(), lines: o.items) ")
                .append("FROM Order o WHERE o.status = 'PAID';\n")
                .append("```\n\n");
        report.append("**JPQL**\n\n```text\n").append(OqlQueries.OQ05_JPQL).append("\n```\n\n");
        report.append("**Tham số:** `status = PAID`\n\n");

        List<Order> orders = OqlQueries.oq05(em, OrderStatus.PAID);
        report.append("**Kết quả:** ");
        if (orders.isEmpty()) {
            report.append("(không có)");
        } else {
            report.append('\n');
            for (Order order : orders) {
                report.append("- `").append(order.getOrderNumber()).append("` — total = **")
                        .append(formatMoney(order.total())).append("**, ")
                        .append(order.getItems().size()).append(" dòng:\n");
                for (OrderLine line : order.getItems()) {
                    report.append("  - `").append(line.getSku()).append("` x")
                            .append(line.getQuantity()).append(" @ ")
                            .append(formatMoney(line.getUnitPrice())).append(" = ")
                            .append(formatMoney(line.getLineTotal()))
                            .append(" — seller `")
                            .append(line.getSeller() == null ? "?" : line.getSeller().getShopName())
                            .append("`\n");
                }
            }
        }
        report.append('\n');

        String numbers = orders.stream().map(Order::getOrderNumber).collect(Collectors.joining(", "));
        boolean oneLine = orders.size() == 1 && orders.get(0).getItems().size() == 1;
        boolean totalOk = orders.size() == 1 && orders.get(0).total().compareTo(money("1800.00")) == 0;
        check("OQ05 trả về đúng ORD-1002", "ORD-1002".equals(numbers), "ORD-1002", numbers);
        check("OQ05 có đúng 1 dòng hàng", oneLine, "1", String.valueOf(orders.isEmpty() ? 0 : orders.get(0).getItems().size()));
        check("OQ05 total = 1800.00", totalOk, "1800.00", orders.isEmpty() ? "n/a" : formatMoney(orders.get(0).total()));
    }

    private void runBusinessMethods(EntityManager em) {
        section("Kiểm chứng phương thức nghiệp vụ trong ODL");

        Customer alice = first(em.createQuery(
                        "SELECT DISTINCT c FROM Customer c LEFT JOIN FETCH c.orders WHERE c.email = :email",
                        Customer.class)
                .setParameter("email", "alice@example.com")
                .getResultList());
        Product laptop = first(em.createQuery(
                        "SELECT DISTINCT p FROM Product p LEFT JOIN FETCH p.variants WHERE p.name = :name",
                        Product.class)
                .setParameter("name", "Laptop Pro")
                .getResultList());
        Seller alpha = first(em.createQuery(
                        "SELECT DISTINCT s FROM Seller s LEFT JOIN FETCH s.inventory WHERE s.shopName = :name",
                        Seller.class)
                .setParameter("name", "Shop Alpha")
                .getResultList());
        List<Order> allOrders = em.createQuery("SELECT o FROM Order o", Order.class).getResultList();
        Order order1001 = first(em.createQuery(
                        "SELECT o FROM Order o WHERE o.orderNumber = :number", Order.class)
                .setParameter("number", "ORD-1001")
                .getResultList());
        Order order1002 = first(em.createQuery(
                        "SELECT o FROM Order o WHERE o.orderNumber = :number", Order.class)
                .setParameter("number", "ORD-1002")
                .getResultList());
        ProductVariant lap14 = first(em.createQuery(
                        "SELECT v FROM ProductVariant v WHERE v.sku = :sku", ProductVariant.class)
                .setParameter("sku", "SKU-LAP-14")
                .getResultList());
        ProductVariant phoneOld = first(em.createQuery(
                        "SELECT v FROM ProductVariant v WHERE v.sku = :sku", ProductVariant.class)
                .setParameter("sku", "SKU-PHN-OLD")
                .getResultList());

        check("Account.isActive() của Alice", alice.isActive(), "true", String.valueOf(alice.isActive()));
        check("Customer.lifetimeValue() của Alice",
                alice.lifetimeValue().compareTo(money("3350.00")) == 0,
                "3350.00", formatMoney(alice.lifetimeValue()));
        check("Seller.revenue() của Shop Alpha",
                alpha.revenue(allOrders).compareTo(money("3400.00")) == 0,
                "3400.00", formatMoney(alpha.revenue(allOrders)));
        check("Product.activeVariants() của Laptop Pro",
                laptop.activeVariants().size() == 2,
                "2", String.valueOf(laptop.activeVariants().size()));
        check("ProductVariant.isAvailable() của SKU-LAP-14",
                lap14.isAvailable(), "true", String.valueOf(lap14.isAvailable()));
        check("ProductVariant.isAvailable() của SKU-PHN-OLD",
                !phoneOld.isAvailable(), "false", String.valueOf(phoneOld.isAvailable()));
        check("Order.total() của ORD-1001",
                order1001.total().compareTo(money("1550.00")) == 0,
                "1550.00", formatMoney(order1001.total()));
        check("Order.canTransitionTo(\"PROCESSING\") từ PAID",
                order1002.canTransitionTo("PROCESSING"),
                "true", String.valueOf(order1002.canTransitionTo("PROCESSING")));
        check("Order.canTransitionTo(\"PAID\") từ DELIVERED",
                !order1001.canTransitionTo("PAID"),
                "false", String.valueOf(order1001.canTransitionTo("PAID")));
        report.append('\n');
    }

    private void writeMapping() {
        section("Bảng ánh xạ OQL → JPQL/ObjectDB");
        report.append("| OQL | JPQL thực thi | Ghi chú |\n");
        report.append("|---|---|---|\n");
        report.append("| OQ01 | `SELECT o FROM Order o WHERE o.customer.email=:email AND o.status=:status ORDER BY o.orderNumber` | ObjectDB duyệt quan hệ `Order.customer` → `Account.email`. |\n");
        report.append("| OQ02 | `SELECT DISTINCT v.product FROM ProductVariant v WHERE v.price>:price ORDER BY v.product.name` | `DISTINCT` loại trùng khi một sản phẩm có nhiều biến thể vượt ngưỡng. |\n");
        report.append("| OQ03 | `SELECT s FROM Seller s JOIN s.inventory v WHERE s.shopStatus=:shopStatus AND v.sku=:sku ORDER BY s.shopName` | `JOIN` trên tập quan hệ nhiều-nhiều `Seller.inventory`. |\n");
        report.append("| OQ04 | `SELECT c.email FROM Customer c ORDER BY c.email` + `SELECT o.customer.email, SUM(o.grandTotal) FROM Order o WHERE o.status IN :statuses GROUP BY o.customer.email` | ObjectDB 2.9.5 chưa hỗ trợ `CASE`/`COALESCE`; hai kết quả được ghép trong Java để khách hàng không có đơn nhận 0. |\n");
        report.append("| OQ05 | `SELECT o FROM Order o WHERE o.status=:status ORDER BY o.orderNumber` | JPQL không chiếu trực tiếp tập `items` lồng nhau; `@ElementCollection` EAGER tải kèm danh sách dòng hàng có thứ tự. |\n");
        report.append('\n');
        report.append("Ánh xạ lớp: `Account→Account`, `Customer→Customer`, `Seller→Seller`, ")
                .append("`Product→Product`, `ProductVariant→ProductVariant`, `Order→Order`, ")
                .append("`OrderLine→@Embeddable` (có `@ManyToOne Seller`). Các quan hệ hai chiều dùng ")
                .append("`@OneToMany`/`@ManyToMany`; `Order.items` dùng `@ElementCollection` + `@OrderColumn`.\n\n");
    }

    private void writeConclusion() {
        section("Kết luận");
        int total = passed + failed;
        report.append("- Tổng số kiểm tra: **").append(total).append("**\n");
        report.append("- PASS: **").append(passed).append("**\n");
        report.append("- FAIL: **").append(failed).append("**\n");
        report.append("- Kết quả: **").append(failed == 0 ? "ĐẠT" : "KHÔNG ĐẠT").append("**\n");
    }

    private void section(String title) {
        report.append("## ").append(title).append("\n\n");
    }

    private void tableRow(String label, long value) {
        report.append("- ").append(label).append(": **").append(value).append("**\n");
    }

    private void check(String label, boolean condition, String expected, String actual) {
        if (condition) {
            passed++;
        } else {
            failed++;
        }
        report.append("- ").append(condition ? "PASS" : "FAIL")
                .append(" — ").append(label)
                .append(" (kỳ vọng: `").append(expected)
                .append("`, thực tế: `").append(actual).append("`)\n");
    }

    private static <T> T first(List<T> values) {
        if (values.isEmpty()) {
            throw new IllegalStateException("Không tìm thấy bản ghi mong đợi");
        }
        return values.get(0);
    }

    private static long count(EntityManager em, String entity) {
        return em.createQuery("SELECT COUNT(e) FROM " + entity + " e", Long.class)
                .getResultList()
                .get(0);
    }

    private static String formatOrders(List<Order> orders) {
        return orders.stream()
                .map(order -> order.getOrderNumber()
                        + " (status=" + order.getStatus()
                        + ", grandTotal=" + formatMoney(order.getGrandTotal())
                        + ", items=" + order.getItems().size() + ")")
                .collect(Collectors.joining("; "));
    }

    private static String formatProducts(List<Product> products) {
        return products.stream()
                .map(product -> product.getName() + " (" + product.getBrand()
                        + ", status=" + product.getStatus() + ")")
                .collect(Collectors.joining("; "));
    }

    private static String formatSellers(List<Seller> sellers) {
        return sellers.stream()
                .map(seller -> seller.getShopName() + " (" + seller.getShopStatus() + ")")
                .collect(Collectors.joining("; "));
    }

    private static boolean sameMoneyMap(Map<String, BigDecimal> actual, Map<String, BigDecimal> expected) {
        if (!actual.keySet().equals(expected.keySet())) {
            return false;
        }
        for (Map.Entry<String, BigDecimal> entry : expected.entrySet()) {
            BigDecimal value = actual.get(entry.getKey());
            if (value == null || value.compareTo(entry.getValue()) != 0) {
                return false;
            }
        }
        return true;
    }

    private static String formatMoneyMap(Map<String, BigDecimal> values) {
        return values.entrySet().stream()
                .map(entry -> entry.getKey() + "=" + formatMoney(entry.getValue()))
                .collect(Collectors.joining(", ", "{", "}"));
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

    private static BigDecimal money(String value) {
        return new BigDecimal(value).setScale(2);
    }

    private static String formatMoney(BigDecimal value) {
        return value == null ? "null" : value.setScale(2, RoundingMode.HALF_UP).toPlainString();
    }

    private static void deleteDatabase() throws IOException {
        Path dir = Path.of("target", "objectdb").toAbsolutePath().normalize();
        if (!Files.exists(dir)) {
            return;
        }
        try (Stream<Path> walk = Files.walk(dir)) {
            List<Path> paths = walk.sorted(Comparator.reverseOrder()).collect(Collectors.toList());
            for (Path path : paths) {
                Files.deleteIfExists(path);
            }
        } catch (IOException ex) {
            throw new UncheckedIOException("Không thể xóa CSDL ObjectDB cũ: " + dir, ex);
        }
    }

    private static void writeFile(Path output, String content) throws IOException {
        Path parent = output.toAbsolutePath().normalize().getParent();
        if (parent != null) {
            Files.createDirectories(parent);
        }
        Files.writeString(output, content, StandardCharsets.UTF_8);
    }
}
