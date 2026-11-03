package vn.edu.ecommerce.objectdb.model;

import jakarta.persistence.Column;
import jakarta.persistence.DiscriminatorValue;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;

import java.math.BigDecimal;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.Set;

@Entity
@DiscriminatorValue("SELLER")
public class Seller extends Account {

    @Column(nullable = false, unique = true, length = 150)
    private String shopName;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ShopStatus shopStatus = ShopStatus.PENDING;

    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
            name = "seller_inventory",
            joinColumns = @JoinColumn(name = "seller_id"),
            inverseJoinColumns = @JoinColumn(name = "variant_id"))
    private Set<ProductVariant> inventory = new LinkedHashSet<>();

    protected Seller() {
    }

    public Seller(String email, String fullName, ShopStatus shopStatus, String shopName) {
        super(email, fullName, AccountStatus.ACTIVE);
        this.shopStatus = shopStatus;
        this.shopName = shopName;
    }

    public String getShopName() {
        return shopName;
    }

    public void setShopName(String shopName) {
        this.shopName = shopName;
    }

    public ShopStatus getShopStatus() {
        return shopStatus;
    }

    public void setShopStatus(ShopStatus shopStatus) {
        this.shopStatus = shopStatus;
    }

    public Set<ProductVariant> getInventory() {
        return inventory;
    }

    public void addInventory(ProductVariant variant) {
        inventory.add(variant);
        variant.getSellers().add(this);
    }

    /**
     * ODL: decimal revenue().
     *
     * Trong mo hinh doi tuong, Seller khong giu tap Order (don hang thuoc Customer).
     * Vi vay ham nghiep vu nhan them extent Order. Khi can, co the viet JPQL tong hop
     * doanh thu theo nguoi ban dua tren OrderLine.seller.
     */
    public BigDecimal revenue(Collection<Order> allOrders) {
        BigDecimal total = BigDecimal.ZERO;
        for (Order order : allOrders) {
            if (order.getStatus() == null || !order.getStatus().isRevenueBearing()) {
                continue;
            }
            for (OrderLine line : order.getItems()) {
                if (isSameSeller(line.getSeller())) {
                    total = total.add(line.getLineTotal());
                }
            }
        }
        return total;
    }

    private boolean isSameSeller(Seller other) {
        if (other == null) {
            return false;
        }
        if (this == other) {
            return true;
        }
        return getId() != null && getId().equals(other.getId());
    }
}
