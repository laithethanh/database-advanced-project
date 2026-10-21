"""Tìm kiếm sản phẩm bằng SQL động + demo SQL Injection — phiên bản của Phạm Thành Danh.

Cách chạy (từ thư mục gốc project):
    python app/dynamic_search.py

File gồm 2 cách viết tìm kiếm để so sánh:
1. tim_kiem_khong_an_toan(): ghép chuỗi người dùng nhập thẳng vào câu SQL  -> BỊ TẤN CÔNG ĐƯỢC.
2. tao_cau_tim_kiem():      giá trị đi qua tham số %s, tên cột lấy từ whitelist -> AN TOÀN.

Chỉ chạy trên database thử nghiệm ở máy mình (ecommerce_advanced).
"""

import getpass

import pymysql


def connect():
    return pymysql.connect(
        host="127.0.0.1", port=3306, user="root",
        password=getpass.getpass("Mat khau MySQL: "),
        database="ecommerce_advanced", charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,     # mỗi dòng kết quả là một dict {tên cột: giá trị}
    )


# ---------------------------------------------------------------------------
# 1. CÁCH SAI: ghép chuỗi
# ---------------------------------------------------------------------------

def tim_kiem_khong_an_toan(cur, tu_khoa):
    """KHÔNG BAO GIỜ viết thế này trong thực tế. Chỉ để minh họa lỗ hổng."""
    sql = (
        "SELECT p.name AS ten, v.price AS gia "
        "FROM product p JOIN product_variant v ON v.product_id = p.product_id "
        "WHERE p.name LIKE '%" + tu_khoa + "%' LIMIT 20"      # <-- chữ người dùng nhập bị dán thẳng vào SQL
    )
    cur.execute(sql)
    return sql, cur.fetchall()


# ---------------------------------------------------------------------------
# 2. CÁCH ĐÚNG: SQL động an toàn
# ---------------------------------------------------------------------------

# Whitelist: người dùng chỉ được CHỌN tên, không được tự gõ tên cột/chiều sắp xếp.
COT_SAP_XEP = {"ten": "p.name", "gia": "v.price", "moi_nhat": "p.created_at"}
CHIEU_SAP_XEP = {"tang": "ASC", "giam": "DESC"}


def tao_cau_tim_kiem(tu_khoa=None, danh_muc_id=None, gia_tu=None, gia_den=None,
                     sap_xep="ten", chieu="tang", gioi_han=20):
    """Ghép câu SQL theo bộ lọc người dùng chọn. Trả về (câu SQL, danh sách tham số).

    - Phần ĐIỀU KIỆN thay đổi tùy bộ lọc (đó là "SQL động"),
      nhưng GIÁ TRỊ luôn nằm trong danh sách tham số, chỗ của nó trong SQL chỉ là %s.
    - Tên cột sắp xếp và ASC/DESC không truyền bằng tham số được, nên lấy từ whitelist.
    """
    if sap_xep not in COT_SAP_XEP:
        raise ValueError(f"Khong cho phep sap xep theo: {sap_xep!r}")
    if chieu not in CHIEU_SAP_XEP:
        raise ValueError(f"Chieu sap xep khong hop le: {chieu!r}")
    if not 1 <= int(gioi_han) <= 100:
        raise ValueError("gioi_han phai tu 1 den 100")
    if gia_tu is not None and gia_den is not None and gia_tu > gia_den:
        raise ValueError("gia_tu khong duoc lon hon gia_den")

    dieu_kien = ["p.status = 'ACTIVE'", "v.status = 'ACTIVE'"]
    tham_so = []

    if tu_khoa:
        dieu_kien.append("p.name LIKE %s")
        tham_so.append(f"%{tu_khoa}%")
    if danh_muc_id is not None:
        dieu_kien.append("p.category_id = %s")
        tham_so.append(danh_muc_id)
    if gia_tu is not None:
        dieu_kien.append("v.price >= %s")
        tham_so.append(gia_tu)
    if gia_den is not None:
        dieu_kien.append("v.price <= %s")
        tham_so.append(gia_den)

    sql = (
        "SELECT p.product_id, p.name AS ten, v.sku, v.price AS gia "
        "FROM product p JOIN product_variant v ON v.product_id = p.product_id "
        "WHERE " + " AND ".join(dieu_kien) + " "
        "ORDER BY " + COT_SAP_XEP[sap_xep] + " " + CHIEU_SAP_XEP[chieu] + " "
        "LIMIT %s"
    )
    tham_so.append(int(gioi_han))
    return sql, tham_so


def tim_kiem_an_toan(cur, **bo_loc):
    sql, tham_so = tao_cau_tim_kiem(**bo_loc)
    cur.execute(sql, tham_so)        # PyMySQL tự escape từng tham số, không ghép chuỗi
    return sql, tham_so, cur.fetchall()


# ---------------------------------------------------------------------------
# Demo
# ---------------------------------------------------------------------------

def in_ket_qua(rows, so_dong=3):
    print(f"   -> {len(rows)} dong")
    for r in rows[:so_dong]:
        print(f"      {r}")


def main():
    conn = connect()
    try:
        with conn.cursor() as cur:
            print("\n===== A. Tim kiem binh thuong voi tu khoa 'Áo' =====")
            sql, rows = tim_kiem_khong_an_toan(cur, "Áo")
            print("[Khong an toan]"); in_ket_qua(rows)
            sql, ts, rows = tim_kiem_an_toan(cur, tu_khoa="Áo", gia_den=500000, sap_xep="gia")
            print("[An toan, loc gia <= 500.000, sap theo gia]"); in_ket_qua(rows)

            tan_cong_1 = "' OR '1'='1' -- "
            print(f"\n===== B. Tan cong 1: lay TOAN BO san pham. Nhap: {tan_cong_1!r} =====")
            sql, rows = tim_kiem_khong_an_toan(cur, tan_cong_1)
            print(f"[Khong an toan] Cau SQL thuc te:\n   {sql}"); in_ket_qua(rows)
            sql, ts, rows = tim_kiem_an_toan(cur, tu_khoa=tan_cong_1)
            print(f"[An toan] Tham so gui di: {ts}"); in_ket_qua(rows)

            tan_cong_2 = "khongco' UNION SELECT email, password_hash FROM account -- "
            print(f"\n===== C. Tan cong 2: an cap email tai khoan. Nhap: {tan_cong_2!r} =====")
            sql, rows = tim_kiem_khong_an_toan(cur, tan_cong_2)
            print(f"[Khong an toan] Cau SQL thuc te:\n   {sql}"); in_ket_qua(rows)
            sql, ts, rows = tim_kiem_an_toan(cur, tu_khoa=tan_cong_2)
            print(f"[An toan] Tham so gui di: {ts}"); in_ket_qua(rows)

            print("\n===== D. Tan cong qua o sap xep (khong dung tham so duoc) -> whitelist chan =====")
            for gia_tri_xau in ["gia; DROP TABLE product", "(SELECT password_hash FROM account LIMIT 1)"]:
                try:
                    tao_cau_tim_kiem(sap_xep=gia_tri_xau)
                except ValueError as loi:
                    print(f"   Bi chan: {loi}")

            cur.execute("SELECT COUNT(*) AS so_san_pham FROM product")
            print(f"\nBang product van con nguyen: {cur.fetchone()['so_san_pham']} san pham")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
