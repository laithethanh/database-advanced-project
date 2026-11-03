package vn.edu.ecommerce.objectdb.model;

import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OrderColumn;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "orders")
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;

    @Column(nullable = false, unique = true, length = 40)
    private String orderNumber;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private OrderStatus status = OrderStatus.PENDING_PAYMENT;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal grandTotal = BigDecimal.ZERO;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    private Customer customer;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "order_lines", joinColumns = @JoinColumn(name = "order_id"))
    @OrderColumn(name = "line_no")
    private List<OrderLine> items = new ArrayList<>();

    protected Order() {
    }

    public Order(String orderNumber, OrderStatus status) {
        this.orderNumber = orderNumber;
        this.status = status;
    }

    public Long getId() {
        return id;
    }

    public String getOrderNumber() {
        return orderNumber;
    }

    public void setOrderNumber(String orderNumber) {
        this.orderNumber = orderNumber;
    }

    public OrderStatus getStatus() {
        return status;
    }

    public void setStatus(OrderStatus status) {
        this.status = status;
    }

    public BigDecimal getGrandTotal() {
        return grandTotal;
    }

    public void setGrandTotal(BigDecimal grandTotal) {
        this.grandTotal = grandTotal;
    }

    public Customer getCustomer() {
        return customer;
    }

    public void setCustomer(Customer customer) {
        this.customer = customer;
    }

    public List<OrderLine> getItems() {
        return items;
    }

    public void addItem(OrderLine line) {
        items.add(line);
    }

    /** ODL: decimal total(). */
    public BigDecimal total() {
        BigDecimal total = BigDecimal.ZERO;
        for (OrderLine line : items) {
            total = total.add(line.getLineTotal());
        }
        return total;
    }

    /** ODL: boolean canTransitionTo(string nextStatus). */
    public boolean canTransitionTo(String nextStatus) {
        if (nextStatus == null) {
            return false;
        }
        try {
            return canTransitionTo(OrderStatus.valueOf(nextStatus.trim().toUpperCase()));
        } catch (IllegalArgumentException ex) {
            return false;
        }
    }

    public boolean canTransitionTo(OrderStatus nextStatus) {
        return nextStatus != null && status != null && status.allowedNextStatuses().contains(nextStatus);
    }

    @Override
    public String toString() {
        return "Order{" + orderNumber + ", status=" + status + ", grandTotal=" + grandTotal
                + ", lines=" + items.size() + "}";
    }
}
