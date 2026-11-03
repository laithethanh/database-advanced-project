package vn.edu.ecommerce.objectdb.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.ManyToOne;

import java.math.BigDecimal;
import java.util.LinkedHashSet;
import java.util.Set;

@Entity
public class ProductVariant {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;

    @Column(nullable = false, unique = true, length = 80)
    private String sku;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal price;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private VariantStatus status = VariantStatus.ACTIVE;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    private Product product;

    @ManyToMany(mappedBy = "inventory", fetch = FetchType.LAZY)
    private Set<Seller> sellers = new LinkedHashSet<>();

    protected ProductVariant() {
    }

    public ProductVariant(String sku, BigDecimal price, VariantStatus status) {
        this.sku = sku;
        this.price = price;
        this.status = status;
    }

    public Long getId() {
        return id;
    }

    public String getSku() {
        return sku;
    }

    public void setSku(String sku) {
        this.sku = sku;
    }

    public BigDecimal getPrice() {
        return price;
    }

    public void setPrice(BigDecimal price) {
        this.price = price;
    }

    public VariantStatus getStatus() {
        return status;
    }

    public void setStatus(VariantStatus status) {
        this.status = status;
    }

    public Product getProduct() {
        return product;
    }

    public void setProduct(Product product) {
        this.product = product;
    }

    public Set<Seller> getSellers() {
        return sellers;
    }

    /** ODL: boolean isAvailable(). */
    public boolean isAvailable() {
        return status == VariantStatus.ACTIVE && price != null && price.signum() > 0;
    }

    @Override
    public String toString() {
        return "ProductVariant{" + sku + ", price=" + price + ", status=" + status + "}";
    }
}
