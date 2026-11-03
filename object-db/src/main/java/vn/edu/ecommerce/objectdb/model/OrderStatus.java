package vn.edu.ecommerce.objectdb.model;

import java.util.EnumSet;
import java.util.Set;

public enum OrderStatus {
    PENDING_PAYMENT,
    PAID,
    PROCESSING,
    SHIPPED,
    DELIVERED,
    CANCELLED,
    RETURN_REQUESTED,
    RETURNED;

    private static final Set<OrderStatus> REVENUE_BEARING =
            EnumSet.of(PAID, PROCESSING, SHIPPED, DELIVERED);

    public boolean isRevenueBearing() {
        return REVENUE_BEARING.contains(this);
    }

    public Set<OrderStatus> allowedNextStatuses() {
        switch (this) {
            case PENDING_PAYMENT:
                return EnumSet.of(PAID, CANCELLED);
            case PAID:
                return EnumSet.of(PROCESSING, CANCELLED, RETURN_REQUESTED);
            case PROCESSING:
                return EnumSet.of(SHIPPED, CANCELLED);
            case SHIPPED:
                return EnumSet.of(DELIVERED, RETURN_REQUESTED);
            case DELIVERED:
                return EnumSet.of(RETURN_REQUESTED);
            case RETURN_REQUESTED:
                return EnumSet.of(RETURNED);
            case RETURNED:
            case CANCELLED:
            default:
                return EnumSet.noneOf(OrderStatus.class);
        }
    }
}
