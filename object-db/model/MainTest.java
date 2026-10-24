public class MainTest {
    public static void main(String[] args) {
        // Khởi tạo hệ thống quản lý
        ManageStudent manager = new ManageStudent();

        // Chuẩn bị dữ liệu object Address (Địa chỉ)
        Address addr1 = new Address("123", "Nguyễn Văn Cừ", "4", "5");
        Address addr2 = new Address("45", "Lê Văn Việt", "Hiệp Phú", "Thủ Đức");

        // Khởi tạo dữ liệu object Student (với quan hệ Has-a gắn Address vào)
        Student s1 = new Student("SV001", "Nguyễn Mậu Công Khoa", addr1, "Công nghệ thông tin");
        Student s2 = new Student("SV002", "Trần Thị B", addr2, "Hệ thống thông tin");

        // Test thêm vào tập hợp (Collection/Array)
        manager.addStudent(s1);
        manager.addStudent(s2);

        // Test hiển thị kết quả quan hệ và tập hợp
        manager.displayAll();
    }
}