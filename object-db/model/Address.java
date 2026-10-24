public class Address {
    private String number;
    private String street;
    private String ward;
    private String district;

    public Address() {}

    public Address(String number, String street, String ward, String district) {
        this.number = number;
        this.street = street;
        this.ward = ward;
        this.district = district;
    }

    // Getter và Setter
    public String getNumber() { return number; }
    public void setNumber(String number) { this.number = number; }
    public String getStreet() { return street; }
    public void setStreet(String street) { this.street = street; }
    public String getWard() { return ward; }
    public void setWard(String ward) { this.ward = ward; }
    public String getDistrict() { return district; }
    public void setDistrict(String district) { this.district = district; }

    @Override
    public String toString() {
        return number + " " + street + ", P." + ward + ", Q." + district;
    }
}