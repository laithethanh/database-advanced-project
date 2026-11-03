package vn.edu.ecommerce.objectdb.model;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

@Entity
public class Product {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;

    @Column(nullable = false, length = 255)
    private String name;

    @Column(length = 120)
    private String brand;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ProductStatus status = ProductStatus.DRAFT;

    @OneToMany(mappedBy = "product", cascade = CascadeType.ALL, orphanRemoval = true,
            fetch = FetchType.LAZY)
    private List<ProductVariant> variants = new ArrayList<>();

    protected Product() {
    }

    public Product(String name, String brand, ProductStatus status) {
        this.name = name;
        this.brand = brand;
        this.status = status;
    }

    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getBrand() {
        return brand;
    }

    public void setBrand(String brand) {
        this.brand = brand;
    }

    public ProductStatus getStatus() {
        return status;
    }

    public void setStatus(ProductStatus status) {
        this.status = status;
    }

    public List<ProductVariant> getVariants() {
        return variants;
    }

    public void addVariant(ProductVariant variant) {
        variants.add(variant);
        variant.setProduct(this);
    }

    /** ODL: set<ProductVariant> activeVariants(). */
    public Set<ProductVariant> activeVariants() {
        Set<ProductVariant> result = new LinkedHashSet<>();
        for (ProductVariant variant : variants) {
            if (variant.getStatus() == VariantStatus.ACTIVE) {
                result.add(variant);
            }
        }
        return result;
    }

    @Override
    public String toString() {
        return "Product{" + name + ", brand=" + brand + ", status=" + status + "}";
    }
}
