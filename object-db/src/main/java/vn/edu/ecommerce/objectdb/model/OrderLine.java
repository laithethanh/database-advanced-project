package vn.edu.ecommerce.objectdb.model;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;

import java.math.BigDecimal;
import java.util.Objects;

/**
 * ODL: struct OrderLine. Đây là kiểu giá trị (value type), không có OID riêng;
 * các dòng hàng được lưu lồng trong Order theo thứ tự. Trường seller tham chiếu
 * người bán chịu trách nhiệm cho dòng hàng, tương ứng order_item.seller_id.
 */
@Embeddable
public class OrderLine {

    @Column(nullable = false, length = 80)
    private String sku;

    @Column(nullable = false)
    private long quantity;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal unitPrice;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal lineTotal;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "seller_id", nullable = false)
    private Seller seller;

    protected OrderLine() {
    }

    public OrderLine(String sku, long quantity, BigDecimal unitPrice, BigDecimal lineTotal, Seller seller) {
        this.sku = sku;
        this.quantity = quantity;
        this.unitPrice = unitPrice;
        this.lineTotal = lineTotal;
        this.seller = seller;
    }

    public static OrderLine of(String sku, long quantity, BigDecimal unitPrice, Seller seller) {
        return new OrderLine(sku, quantity, unitPrice,
                unitPrice.multiply(BigDecimal.valueOf(quantity)), seller);
    }

    public String getSku() {
        return sku;
    }

    public long getQuantity() {
        return quantity;
    }

    public BigDecimal getUnitPrice() {
        return unitPrice;
    }

    public BigDecimal getLineTotal() {
        return lineTotal;
    }

    public Seller getSeller() {
        return seller;
    }

    public void setSeller(Seller seller) {
        this.seller = seller;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (!(other instanceof OrderLine)) {
            return false;
        }
        OrderLine that = (OrderLine) other;
        return quantity == that.quantity
                && Objects.equals(sku, that.sku)
                && Objects.equals(unitPrice, that.unitPrice)
                && Objects.equals(lineTotal, that.lineTotal);
    }

    @Override
    public int hashCode() {
        return Objects.hash(sku, quantity, unitPrice, lineTotal);
    }

    @Override
    public String toString() {
        return sku + " x" + quantity + " @ " + unitPrice + " = " + lineTotal;
    }
}
