public class ManageStudent {
    private Student[] students; // Tập hợp đối tượng dạng mảng
    private int numOfStudent;
    private static final int MAX_SIZE = 50;

    public ManageStudent() {
        this.students = new Student[MAX_SIZE];
        this.numOfStudent = 0;
    }

    // Thêm sinh viên vào tập hợp
    public boolean addStudent(Student s) {
        if (numOfStudent < MAX_SIZE) {
            students[numOfStudent] = s;
            numOfStudent++;
            return true;
        }
        return false;
    }

    // Hiển thị danh sách tập hợp sinh viên
    public void displayAll() {
        System.out.println("================ DANH SÁCH QUẢN LÝ SINH VIÊN ================");
        if (numOfStudent == 0) {
            System.out.println("Danh sách trống!");
            return;
        }
        for (int i = 0; i < numOfStudent; i++) {
            System.out.println((i + 1) + ". " + students[i].toString());
        }
        System.out.println("Tổng số sinh viên: " + numOfStudent);
    }
}