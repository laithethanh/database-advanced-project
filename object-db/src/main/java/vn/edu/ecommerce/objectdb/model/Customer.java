package vn.edu.ecommerce.objectdb.model;

import jakarta.persistence.CascadeType;
import jakarta.persistence.DiscriminatorValue;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.OneToMany;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Entity
@DiscriminatorValue("CUSTOMER")
public class Customer extends Account {

    @OneToMany(mappedBy = "customer", cascade = CascadeType.ALL, orphanRemoval = true,
            fetch = FetchType.LAZY)
    private List<Order> orders = new ArrayList<>();

    protected Customer() {
    }

    public Customer(String email, String fullName, AccountStatus status) {
        super(email, fullName, status);
    }

    public List<Order> getOrders() {
        return orders;
    }

    public void addOrder(Order order) {
        orders.add(order);
        order.setCustomer(this);
    }

    /**
     * ODL: decimal lifetimeValue().
     * Tong grandTotal cua cac don da ghi nhan (PAID, PROCESSING, SHIPPED, DELIVERED).
     * Khach hang khong co don nao tra ve 0.
     */
    public BigDecimal lifetimeValue() {
        BigDecimal total = BigDecimal.ZERO;
        for (Order order : orders) {
            if (order.getStatus() != null && order.getStatus().isRevenueBearing()) {
                total = total.add(order.getGrandTotal());
            }
        }
        return total;
    }
}
