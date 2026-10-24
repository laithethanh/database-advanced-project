public class Student {
    private String id;
    private String name;
    private Address address; // Quan hệ "Has-a": Sinh viên chứa một đối tượng Address
    private String major;

    public Student() {}

    public Student(String id, String name, Address address, String major) {
        this.id = id;
        this.name = name;
        this.address = address;
        this.major = major;
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public Address getAddress() { return address; }
    public void setAddress(Address address) { this.address = address; }
    public String getMajor() { return major; }
    public void setMajor(String major) { this.major = major; }

    @Override
    public String toString() {
        return "Mã SV: " + id + " | Tên: " + name + " | Địa chỉ: " + (address != null ? address.toString() : "N/A") + " | Chuyên ngành: " + major;
    }
}