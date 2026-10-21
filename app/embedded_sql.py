"""SQL nhúng trong Python (PyMySQL + cursor) — phiên bản của Phạm Thành Danh.

Mô phỏng một khách hàng mua hàng hoàn toàn bằng code:
    1. Mở (hoặc tạo) giỏ hàng ACTIVE
    2. Thêm 2 sản phẩm còn hàng vào giỏ
    3. Duyệt giỏ hàng bằng cursor, từng dòng một
    4. Thử đặt hàng vượt tồn kho  -> procedure báo lỗi, ROLLBACK, không có gì thay đổi
    5. Sửa lại số lượng hợp lệ    -> đặt hàng thành công bằng CALL sp_checkout
    6. Xem lại đơn vừa tạo và tồn kho sau khi trừ

Cách chạy (từ thư mục gốc project):
    python app/embedded_sql.py
    python app/embedded_sql.py --customer DCUS000002

Chạy lại nhiều lần được: mỗi lần chạy, giỏ cũ đã đặt hàng xong nên sẽ tạo giỏ mới.
"""

import argparse
import getpass

import pymysql


def connect():
    return pymysql.connect(
        host="127.0.0.1", port=3306, user="root",
        password=getpass.getpass("Mat khau MySQL: "),
        database="ecommerce_advanced", charset="utf8mb4",
        autocommit=False,                              # tự quản lý transaction bằng commit/rollback
        cursorclass=pymysql.cursors.DictCursor,
    )


def tien(x):
    """Định dạng số tiền cho dễ đọc: 1250000 -> 1.250.000đ"""
    return f"{int(x):,}".replace(",", ".") + "đ"


# ---------------------------------------------------------------------------
# Các thao tác với database — mọi giá trị đều đi qua tham số %s
# ---------------------------------------------------------------------------

def lay_khach_hang(cur, ma_khach):
    cur.execute(
        "SELECT c.account_id, a.full_name, a.phone FROM customer c "
        "JOIN account a ON a.account_id = c.account_id WHERE c.customer_code = %s",
        (ma_khach,),
    )
    khach = cur.fetchone()                 # lấy đúng 1 dòng (hoặc None nếu không có)
    if khach is None:
        raise LookupError(f"Khong tim thay khach hang {ma_khach}")
    return khach


def mo_gio_hang(cur, customer_id):
    """Trả về cart_id của giỏ ACTIVE; chưa có thì tạo mới."""
    cur.execute(
        "SELECT cart_id FROM cart WHERE customer_id = %s AND status = 'ACTIVE' FOR UPDATE",
        (customer_id,),
    )
    gio = cur.fetchone()
    if gio:
        return gio["cart_id"], False
    cur.execute("INSERT INTO cart (customer_id, status) VALUES (%s, 'ACTIVE')", (customer_id,))
    return cur.lastrowid, True


def tim_hang_con_ton(cur, so_luong_mon):
    """Tìm vài món đang bán được và còn ít nhất 5 cái trong kho."""
    cur.execute(
        "SELECT i.seller_id, i.variant_id, p.name, v.sku, v.price, "
        "       i.quantity_on_hand - i.reserved_quantity AS con_lai "
        "FROM inventory i "
        "JOIN product_variant v ON v.variant_id = i.variant_id "
        "JOIN product p ON p.product_id = v.product_id "
        "JOIN seller s ON s.account_id = i.seller_id "
        "WHERE s.shop_status = 'ACTIVE' AND v.status = 'ACTIVE' AND p.status = 'ACTIVE' "
        "  AND i.quantity_on_hand - i.reserved_quantity >= 5 "
        "ORDER BY i.variant_id, i.seller_id LIMIT %s",
        (so_luong_mon,),
    )
    return cur.fetchall()


def them_vao_gio(cur, cart_id, seller_id, variant_id, so_luong):
    """Thêm món vào giỏ; nếu món đã có thì cộng dồn số lượng."""
    if so_luong <= 0:
        raise ValueError("So luong phai lon hon 0")
    cur.execute(
        "INSERT INTO cart_item (cart_id, seller_id, variant_id, quantity) VALUES (%s, %s, %s, %s) "
        "AS moi ON DUPLICATE KEY UPDATE quantity = cart_item.quantity + moi.quantity",
        (cart_id, seller_id, variant_id, so_luong),
    )


def doi_so_luong(cur, cart_id, seller_id, variant_id, so_luong):
    if so_luong <= 0:
        raise ValueError("So luong phai lon hon 0")
    cur.execute(
        "UPDATE cart_item SET quantity = %s WHERE cart_id = %s AND seller_id = %s AND variant_id = %s",
        (so_luong, cart_id, seller_id, variant_id),
    )
    if cur.rowcount != 1:                  # rowcount = số dòng bị ảnh hưởng
        raise LookupError("Mon nay khong co trong gio")


def xem_gio_hang(cur, cart_id):
    """Duyệt kết quả bằng cursor TỪNG DÒNG MỘT (for row in cur), cộng tiền bằng Python."""
    cur.execute(
        "SELECT p.name, v.sku, ci.quantity, v.price, ci.quantity * v.price AS thanh_tien "
        "FROM cart_item ci "
        "JOIN product_variant v ON v.variant_id = ci.variant_id "
        "JOIN product p ON p.product_id = v.product_id "
        "WHERE ci.cart_id = %s ORDER BY v.sku",
        (cart_id,),
    )
    tong = 0
    for dong in cur:                       # cursor trả về từng dòng
        print(f"      - {dong['name']} ({dong['sku']}) x{dong['quantity']} = {tien(dong['thanh_tien'])}")
        tong += dong["thanh_tien"]
    print(f"      Tong tien hang: {tien(tong)}")


def dat_hang(cur, khach, phi_ship):
    """Gọi procedure sp_checkout. Tham số OUT được đọc qua biến phiên @order_id."""
    cur.execute(
        "CALL sp_checkout(%s, %s, %s, %s, %s, %s, @order_id)",
        (khach["account_id"], khach["full_name"], khach["phone"], "123 Duong Demo, TP.HCM", phi_ship, None),
    )
    cur.execute("SELECT @order_id AS order_id")
    return cur.fetchone()["order_id"]


def chup_trang_thai(cur, mon):
    """Đếm số đơn và tồn kho của 1 món — để so trước/sau khi lỗi."""
    cur.execute("SELECT COUNT(*) AS so_don FROM orders")
    so_don = cur.fetchone()["so_don"]
    cur.execute(
        "SELECT quantity_on_hand FROM inventory WHERE seller_id = %s AND variant_id = %s",
        (mon["seller_id"], mon["variant_id"]),
    )
    return so_don, cur.fetchone()["quantity_on_hand"]


# ---------------------------------------------------------------------------
# Kịch bản demo
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--customer", default="DCUS000001", help="ma khach hang (customer_code)")
    args = parser.parse_args()

    conn = connect()
    try:
        with conn.cursor() as cur:
            khach = lay_khach_hang(cur, args.customer)
            print(f"\n[1] Khach hang: {khach['full_name']} (id {khach['account_id']})")

            cart_id, moi_tao = mo_gio_hang(cur, khach["account_id"])
            print(f"    Gio hang ACTIVE: cart_id = {cart_id} ({'vua tao moi' if moi_tao else 'da co san'})")

            mon = tim_hang_con_ton(cur, 2)
            print("\n[2] Them 2 mon con hang vao gio:")
            for m in mon:
                them_vao_gio(cur, cart_id, m["seller_id"], m["variant_id"], 1)
                print(f"      + {m['name']} ({m['sku']}), gia {tien(m['price'])}, kho con {m['con_lai']}")
            conn.commit()

            print("\n[3] Duyet gio hang bang cursor:")
            xem_gio_hang(cur, cart_id)

            # --- Bước 4: cố tình mua vượt tồn kho ---
            m0 = mon[0]
            qua_nhieu = m0["con_lai"] + 1000
            doi_so_luong(cur, cart_id, m0["seller_id"], m0["variant_id"], qua_nhieu)
            conn.commit()
            truoc = chup_trang_thai(cur, m0)
            print(f"\n[4] Thu dat {qua_nhieu} cai '{m0['name']}' trong khi kho chi con {m0['con_lai']}:")
            try:
                dat_hang(cur, khach, 30000)
                print("      !!! Khong mong doi: dat hang thanh cong")
            except pymysql.MySQLError as loi:
                conn.rollback()
                print(f"      Bi tu choi: loi {loi.args[0]} - {loi.args[1]}")
            sau = chup_trang_thai(cur, m0)
            print(f"      Truoc: {truoc[0]} don, kho {truoc[1]}  |  Sau: {sau[0]} don, kho {sau[1]}"
                  f"  -> {'KHONG THAY DOI (rollback dung)' if truoc == sau else 'CO THAY DOI (sai!)'}")

            # --- Bước 5: sửa lại hợp lệ rồi đặt hàng ---
            doi_so_luong(cur, cart_id, m0["seller_id"], m0["variant_id"], 2)
            conn.commit()
            print("\n[5] Sua lai thanh 2 cai roi dat hang:")
            xem_gio_hang(cur, cart_id)
            order_id = dat_hang(cur, khach, 30000)
            conn.commit()
            print(f"      Dat hang thanh cong! order_id = {order_id}")

            # --- Bước 6: xem lại kết quả ---
            cur.execute(
                "SELECT order_number, status, subtotal, shipping_fee, grand_total FROM orders WHERE order_id = %s",
                (order_id,),
            )
            don = cur.fetchone()
            print(f"\n[6] Don {don['order_number']}: trang thai {don['status']}, tien hang {tien(don['subtotal'])}"
                  f" + ship {tien(don['shipping_fee'])} = {tien(don['grand_total'])}")
            cur.execute("SELECT status FROM cart WHERE cart_id = %s", (cart_id,))
            print(f"    Gio hang sau khi dat: {cur.fetchone()['status']}")
            print(f"    Ton kho '{m0['name']}': {sau[1]} -> {chup_trang_thai(cur, m0)[1]} (da tru 2)")
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
