"""

Cách chạy (từ thư mục gốc project):
    python data/generator/generate_data.py
    python data/generator/generate_data.py --customers 10000 --sellers 100 --products 1000 --orders 100000

Nguyên tắc:
- Seed cố định -> chạy lại ra đúng y dữ liệu cũ (tái lập).
- Mọi giá trị đều đi qua tham số %s (parameterized query), không ghép chuỗi SQL.
- Hàng hóa lưu trong 1 transaction; đơn hàng commit theo lô (mặc định 1.000 đơn/lô).
- Đơn hàng đi đúng luật trigger: bắt đầu PENDING_PAYMENT, thanh toán đúng số tiền,
  chuyển trạng thái từng bước, chỉ đánh giá khi đã giao.
- Tồn kho trong bảng inventory là "ảnh chụp hiện tại", không trừ theo đơn lịch sử.
- Muốn chạy lại thì phải reset database trước (nếu không sẽ trùng email/mã).
"""

import argparse
import random
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

import pymysql
from faker import Faker

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from db_config import db_params


# ---------------------------------------------------------------------------
# Dữ liệu cố định dùng để sinh
# ---------------------------------------------------------------------------

# Cây danh mục 3 tầng: tầng 1 -> tầng 2 -> danh sách tầng 3 (tầng 3 là nơi gắn sản phẩm)
CAY_DANH_MUC = {
    "Thời trang": {
        "Áo": ["Áo thun", "Áo sơ mi", "Áo khoác"],
        "Quần": ["Quần jean", "Quần short"],
    },
    "Điện tử": {
        "Điện thoại": ["Điện thoại Android", "iPhone"],
        "Phụ kiện": ["Tai nghe", "Sạc dự phòng"],
    },
    "Nhà cửa": {
        "Nhà bếp": ["Nồi chảo", "Dao kéo"],
        "Trang trí": ["Đèn ngủ", "Tranh treo tường"],
    },
}

THUONG_HIEU = ["Viet Tien", "Canifa", "Samsung", "Xiaomi", "Sunhouse", "Rang Dong", "Owen", "Anker"]
MAU_SAC = ["Den", "Trang", "Xanh", "Do", "Xam"]
KICH_CO = ["S", "M", "L", "XL"]

DUONG_PHO = [
    "Nguyen Hue", "Le Loi", "Tran Hung Dao", "Hai Ba Trung", "Vo Van Tan",
    "Pham Ngu Lao", "Nguyen Trai", "Le Duan", "Ly Tu Trong", "Dong Khoi",
    "Nguyen Dinh Chieu", "Cach Mang Thang 8", "Le Van Sy", "Hoang Dieu",
]
THANH_PHO = [
    # (city, province, postal_code)
    ("TP. Ho Chi Minh", "TP. Ho Chi Minh", "700000"),
    ("Ha Noi", "Ha Noi", "100000"),
    ("Da Nang", "Da Nang", "550000"),
    ("Hai Phong", "Hai Phong", "180000"),
    ("Can Tho", "Can Tho", "900000"),
    ("Hue", "Thua Thien Hue", "530000"),
    ("Nha Trang", "Khanh Hoa", "650000"),
    ("Vung Tau", "Ba Ria - Vung Tau", "790000"),
]
PHUONG = ["Phuong 1", "Phuong 2", "Phuong 3", "Phuong 5", "Phuong 7", "Phuong 10"]
QUAN = ["Quan 1", "Quan 3", "Quan 5", "Quan 7", "Quan Binh Thanh", "Quan Tan Binh", "Quan Go Vap"]

MAU_KHUYEN_MAI = [
    # (code, name, type, value, min_order, max_discount)
    ("DGIAM5",   "Giam 5%",   "PERCENT", 5,      100000,  20000),
    ("DGIAM10",  "Giam 10%",  "PERCENT", 10,     200000,  50000),
    ("DGIAM15",  "Giam 15%",  "PERCENT", 15,     500000,  100000),
    ("DGIAM20",  "Giam 20%",  "PERCENT", 20,     300000,  80000),
    ("DGIAM30",  "Giam 30%",  "PERCENT", 30,     1000000, 200000),
    ("DGIAM10K", "Giam 10K",  "FIXED",   10000,  100000,  None),
    ("DGIAM20K", "Giam 20K",  "FIXED",   20000,  200000,  None),
    ("DGIAM50K", "Giam 50K",  "FIXED",   50000,  500000,  None),
    ("DGIAM99K", "Giam 99K",  "FIXED",   99000,  1000000, None),
    ("DFREESHIP","Free ship",  "FIXED",   30000,  0,       None),
]


# ---------------------------------------------------------------------------
# Kết nối
# ---------------------------------------------------------------------------

def connect():
    return pymysql.connect(**db_params())


# ---------------------------------------------------------------------------
# Các bước sinh dữ liệu
# ---------------------------------------------------------------------------

def tao_khach_hang(cur, fake, so_luong):
    """Mỗi khách = 1 dòng account + 1 dòng customer. Trả về danh sách account_id."""
    ds_id = []
    for i in range(1, so_luong + 1):
        cur.execute(
            "INSERT INTO account (email, password_hash, full_name, phone) VALUES (%s, %s, %s, %s)",
            (f"khach{i:06d}@example.test", "demo-hash", fake.name(), fake.phone_number()),
        )
        account_id = cur.lastrowid
        cur.execute(
            "INSERT INTO customer (account_id, customer_code) VALUES (%s, %s)",
            (account_id, f"DCUS{i:06d}"),
        )
        ds_id.append(account_id)
    print(f"  [1] Khach hang: {len(ds_id)}")
    return ds_id


def tao_nguoi_ban(cur, fake, so_luong):
    """Mỗi người bán = 1 dòng account + 1 dòng seller (shop ACTIVE). Trả về danh sách account_id."""
    ds_id = []
    for i in range(1, so_luong + 1):
        cur.execute(
            "INSERT INTO account (email, password_hash, full_name, phone) VALUES (%s, %s, %s, %s)",
            (f"shop{i:04d}@example.test", "demo-hash", fake.name(), fake.phone_number()),
        )
        account_id = cur.lastrowid
        cur.execute(
            "INSERT INTO seller (account_id, seller_code, shop_name, shop_status) "
            "VALUES (%s, %s, %s, 'ACTIVE')",
            (account_id, f"DSEL{i:04d}", f"Shop {fake.last_name()} {i:04d}"),
        )
        ds_id.append(account_id)
    print(f"  [2] Nguoi ban: {len(ds_id)}")
    return ds_id


def tao_dia_chi(cur, rng, fake, ds_khach):
    """Mỗi khách có 1-3 địa chỉ giao hàng, địa chỉ đầu tiên là mặc định."""
    dem = 0
    for customer_id in ds_khach:
        so_dc = rng.randint(1, 3)
        for j in range(so_dc):
            city, province, postal = rng.choice(THANH_PHO)
            cur.execute(
                "INSERT INTO address (customer_id, recipient_name, phone, line1, "
                "ward, district, city, province, postal_code, is_default) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (customer_id, fake.name(), fake.phone_number(),
                 f"{rng.randint(1, 999)} {rng.choice(DUONG_PHO)}",
                 rng.choice(PHUONG), rng.choice(QUAN),
                 city, province, postal, j == 0),
            )
            dem += 1
    print(f"  [+] Dia chi: {dem}")


def tao_danh_muc(cur):
    """Tạo cây danh mục 3 tầng. Cha phải tạo trước con. Trả về id các danh mục lá (tầng 3)."""
    ds_la = []
    so_thu_tu = 0

    def them(ten, cha_id):
        nonlocal so_thu_tu
        so_thu_tu += 1
        cur.execute(
            "INSERT INTO category (parent_category_id, name, slug) VALUES (%s, %s, %s)",
            (cha_id, ten, f"dcat-{so_thu_tu:03d}"),
        )
        return cur.lastrowid

    for ten_t1, nhom_t2 in CAY_DANH_MUC.items():
        id_t1 = them(ten_t1, None)                 # tầng 1: không có cha
        for ten_t2, ds_t3 in nhom_t2.items():
            id_t2 = them(ten_t2, id_t1)            # tầng 2: cha là tầng 1
            for ten_t3 in ds_t3:
                ds_la.append((them(ten_t3, id_t2), ten_t3))   # tầng 3: cha là tầng 2
    print(f"  [3] Danh muc: {so_thu_tu} (trong do {len(ds_la)} danh muc la)")
    return ds_la


def tao_san_pham(cur, rng, so_luong, ds_danh_muc_la, ds_nguoi_ban):
    """Sản phẩm -> 2-3 biến thể (màu/size, mỗi biến thể ở 1 kho) -> 1-2 người bán có tồn kho.

    Trả về danh sách hàng đang bán, mỗi phần tử là
    (seller_id, variant_id, giá, tên sản phẩm, sku, product_id) để bước đặt hàng dùng.
    """
    cur.execute("SELECT warehouse_id FROM warehouse WHERE status = 'ACTIVE' ORDER BY warehouse_id")
    ds_kho = [row[0] for row in cur.fetchall()]

    hang_ban = []
    so_bien_the = 0
    for i in range(1, so_luong + 1):
        category_id, ten_loai = rng.choice(ds_danh_muc_la)
        thuong_hieu = rng.choice(THUONG_HIEU)
        ten_sp = f"{ten_loai} {thuong_hieu} {i:05d}"
        cur.execute(
            "INSERT INTO product (category_id, name, slug, description, brand, status) "
            "VALUES (%s, %s, %s, %s, %s, 'ACTIVE')",
            (category_id, ten_sp, f"dprod-{i:06d}", f"San pham mau so {i}", thuong_hieu),
        )
        product_id = cur.lastrowid

        # Chọn 2-3 tổ hợp màu/size KHÁC NHAU cho sản phẩm này
        to_hop = rng.sample([(m, k) for m in MAU_SAC for k in KICH_CO], rng.randint(2, 3))
        for j, (mau, co) in enumerate(to_hop, start=1):
            gia = rng.randint(50, 2000) * 1000                     # 50.000đ - 2.000.000đ
            gia_goc = gia + rng.randint(0, 5) * 10000 if rng.random() < 0.5 else None
            sku = f"DSKU-{i:06d}-{j}"
            cur.execute(
                "INSERT INTO product_variant "
                "(warehouse_id, product_id, sku, color, size, price, compare_at_price, warehouse_quantity) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                (rng.choice(ds_kho), product_id, sku, mau, co,
                 gia, gia_goc, rng.randint(100, 1000)),
            )
            variant_id = cur.lastrowid
            so_bien_the += 1

            # 1-2 người bán khác nhau cùng bán biến thể này
            for seller_id in rng.sample(ds_nguoi_ban, min(len(ds_nguoi_ban), rng.randint(1, 2))):
                cur.execute(
                    "INSERT INTO inventory (seller_id, variant_id, quantity_on_hand, reserved_quantity, reorder_level) "
                    "VALUES (%s, %s, %s, 0, 10)",
                    (seller_id, variant_id, rng.randint(0, 200)),
                )
                hang_ban.append((seller_id, variant_id, gia, ten_sp, sku, product_id))

    print(f"  [4] San pham: {so_luong}, bien the: {so_bien_the}, dong ton kho: {len(hang_ban)}")
    return hang_ban


def tao_khuyen_mai(cur, rng, ds_danh_muc_la, hang_ban):
    """Tạo khuyến mãi từ bảng mẫu, gắn vào sản phẩm và/hoặc danh mục.

    Trả về danh sách (promotion_id, code, type, value, min_order, max_discount)
    để bước đặt hàng dùng.
    """
    ds_product_id = list({item[5] for item in hang_ban})   # index 5 = product_id
    ds_category_id = [cat_id for cat_id, _ in ds_danh_muc_la]
    so_pp = 0
    so_pc = 0

    ds_km = []
    for code, ten, kieu, gia_tri, min_don, max_giam in MAU_KHUYEN_MAI:
        cur.execute(
            "INSERT INTO promotion (code, name, promotion_type, discount_value, "
            "min_order_amount, max_discount, start_at, end_at, status, usage_limit, used_count) "
            "VALUES (%s, %s, %s, %s, %s, %s, '2025-10-01 00:00:00', '2026-12-31 23:59:59', "
            "'ACTIVE', %s, 0)",
            (code, ten, kieu, gia_tri, min_don, max_giam, rng.randint(5000, 100000)),
        )
        pid = cur.lastrowid
        ds_km.append((pid, code, kieu, gia_tri, min_don, max_giam))

        # Gắn vào 2-10 sản phẩm ngẫu nhiên (60% khuyến mãi)
        if rng.random() < 0.6:
            for prod_id in rng.sample(ds_product_id, min(len(ds_product_id), rng.randint(2, 10))):
                cur.execute(
                    "INSERT INTO promotion_product (promotion_id, product_id) VALUES (%s, %s)",
                    (pid, prod_id),
                )
                so_pp += 1

        # Gắn vào 1-3 danh mục ngẫu nhiên (50% khuyến mãi)
        if rng.random() < 0.5:
            for cat_id in rng.sample(ds_category_id, min(len(ds_category_id), rng.randint(1, 3))):
                cur.execute(
                    "INSERT INTO promotion_category (promotion_id, category_id) VALUES (%s, %s)",
                    (pid, cat_id),
                )
                so_pc += 1

    print(f"  [+] Khuyen mai: {len(ds_km)}, gan san pham: {so_pp}, gan danh muc: {so_pc}")
    return ds_km


# Trạng thái cuối cùng của đơn và tỉ lệ xuất hiện (tổng = 100)
TRANG_THAI_DON = ["PENDING_PAYMENT", "CANCELLED", "PAID", "PROCESSING", "SHIPPED", "DELIVERED", "RETURNED"]
TI_LE_DON      = [5,                  5,           30,     15,           15,        25,          5]

# Đường đi hợp lệ của đơn sau khi đã thanh toán (theo trigger của Khoa, không được nhảy cóc)
DUONG_DI = ["PAID", "PROCESSING", "SHIPPED", "DELIVERED", "RETURN_REQUESTED", "RETURNED"]


def tao_mot_don(cur, rng, fake, seed, so_thu_tu, customer_id, hang_ban, da_danh_gia, dem, ds_km):
    """Tạo 1 đơn hàng đi đúng luật của database:

    1. Tạo đơn PENDING_PAYMENT với subtotal = 0 (trigger bắt buộc đơn mới bắt đầu từ 0).
    2. Thêm 1-3 món. Trigger TỰ cộng subtotal và grand_total cho đơn.
    3. Nếu đơn đã thanh toán: ghi payment đúng bằng grand_total, rồi đổi sang PAID.
    4. Đi tiếp từng bước PROCESSING -> SHIPPED -> DELIVERED ... cho tới trạng thái cuối.
    5. Đơn DELIVERED: thêm vận đơn (shipment), có thể thêm đánh giá (review).
    """
    trang_thai_cuoi = rng.choices(TRANG_THAI_DON, weights=TI_LE_DON)[0]

    # Thời điểm đặt: ngẫu nhiên trong 1 năm, từ 01/10/2025
    ngay_dat = datetime(2025, 10, 1) + timedelta(minutes=rng.randint(0, 365 * 24 * 60))
    phi_ship = rng.choice([0, 15000, 30000])

    # --- Bước 1: đơn mới, subtotal = 0, grand_total = phí ship ---
    cur.execute(
        "INSERT INTO orders (order_number, customer_id, status, recipient_name, recipient_phone, "
        "shipping_address, subtotal, discount_total, shipping_fee, grand_total, placed_at, created_at) "
        "VALUES (%s, %s, 'PENDING_PAYMENT', %s, %s, %s, 0, 0, %s, %s, %s, %s)",
        (f"DORD-{seed}-{so_thu_tu:07d}", customer_id, fake.name(), fake.phone_number(),
         fake.address().replace("\n", ", "), phi_ship, phi_ship, ngay_dat, ngay_dat),
    )
    order_id = cur.lastrowid

    # --- Bước 2: thêm 1-3 món khác nhau ---
    cac_mon = rng.sample(hang_ban, rng.randint(1, 3))
    tien_hang = 0
    for seller_id, variant_id, gia, ten_sp, sku, product_id in cac_mon:
        so_luong = rng.randint(1, 3)
        cur.execute(
            "INSERT INTO order_item (order_id, seller_id, variant_id, product_name_snapshot, "
            "sku_snapshot, unit_price, quantity, line_discount, line_total) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, 0, %s)",
            (order_id, seller_id, variant_id, ten_sp, sku, gia, so_luong, gia * so_luong),
        )
        tien_hang += gia * so_luong
    dem["mon"] += len(cac_mon)

    # --- Đơn chưa thanh toán hoặc bị hủy trước khi trả tiền ---
    if trang_thai_cuoi == "PENDING_PAYMENT":
        return
    if trang_thai_cuoi == "CANCELLED":
        cur.execute("UPDATE orders SET status = 'CANCELLED' WHERE order_id = %s", (order_id,))
        return

    # --- Bước 2b: áp dụng khuyến mãi (~30% đơn thanh toán) ---
    giam_gia = 0
    if ds_km and rng.random() < 0.3:
        km = rng.choice(ds_km)
        promotion_id, ma_km, kieu_km, gia_tri, min_don, max_giam = km
        if tien_hang >= min_don:
            if kieu_km == "PERCENT":
                giam_gia = int(tien_hang * gia_tri / 100)
                if max_giam and giam_gia > max_giam:
                    giam_gia = int(max_giam)
            else:
                giam_gia = int(gia_tri)
            giam_gia = min(giam_gia, tien_hang)
            cur.execute(
                "INSERT INTO order_promotion (order_id, promotion_id, discount_amount, "
                "promotion_code_snapshot) VALUES (%s, %s, %s, %s)",
                (order_id, promotion_id, giam_gia, ma_km),
            )
            cur.execute(
                "UPDATE orders SET discount_total = %s, "
                "grand_total = subtotal - %s + shipping_fee WHERE order_id = %s",
                (giam_gia, giam_gia, order_id),
            )
            cur.execute(
                "UPDATE promotion SET used_count = used_count + 1 WHERE promotion_id = %s",
                (promotion_id,),
            )
            dem["khuyen_mai"] += 1

    # --- Bước 3: thanh toán. Số tiền PHẢI bằng grand_total, trigger sẽ kiểm tra ---
    tong_tien = tien_hang - giam_gia + phi_ship
    ngay_tra = ngay_dat + timedelta(minutes=rng.randint(1, 60))
    cur.execute(
        "INSERT INTO payment (order_id, provider, transaction_ref, amount, status, paid_at) "
        "VALUES (%s, %s, %s, %s, 'SUCCESS', %s)",
        (order_id, rng.choice(["MOMO", "VNPAY", "COD", "BANK"]), f"DPAY-{seed}-{so_thu_tu:07d}",
         tong_tien, ngay_tra),
    )
    dem["thanh_toan"] += 1

    # --- Bước 4: đi từng bước trên đường hợp lệ cho tới trạng thái cuối ---
    if trang_thai_cuoi == "RETURNED":
        diem_dung = DUONG_DI.index("RETURNED")
    else:
        diem_dung = DUONG_DI.index(trang_thai_cuoi)

    for buoc in DUONG_DI[: diem_dung + 1]:
        cur.execute("UPDATE orders SET status = %s WHERE order_id = %s", (buoc, order_id))

        if buoc == "SHIPPED" and trang_thai_cuoi == "SHIPPED":
            # Đơn đang giao: vận đơn ở trạng thái IN_TRANSIT
            cur.execute(
                "INSERT INTO shipment (order_id, carrier, tracking_number, status, shipped_at) "
                "VALUES (%s, %s, %s, 'IN_TRANSIT', %s)",
                (order_id, rng.choice(["GHN", "GHTK", "VNPost"]), f"DTRK-{seed}-{so_thu_tu:07d}",
                 ngay_tra + timedelta(days=1)),
            )
        if buoc == "DELIVERED":
            # --- Bước 5: đã giao -> có vận đơn DELIVERED, có thể có đánh giá ---
            cur.execute(
                "INSERT INTO shipment (order_id, carrier, tracking_number, status, shipped_at, delivered_at) "
                "VALUES (%s, %s, %s, 'DELIVERED', %s, %s)",
                (order_id, rng.choice(["GHN", "GHTK", "VNPost"]), f"DTRK-{seed}-{so_thu_tu:07d}",
                 ngay_tra + timedelta(days=1), ngay_tra + timedelta(days=rng.randint(2, 6))),
            )
            seller_id, variant_id, gia, ten_sp, sku, product_id = cac_mon[0]
            # Mỗi khách chỉ đánh giá 1 sản phẩm 1 lần (UNIQUE customer_id + product_id)
            if trang_thai_cuoi == "DELIVERED" and rng.random() < 0.5 \
                    and (customer_id, product_id) not in da_danh_gia:
                cur.execute(
                    "SELECT order_item_id FROM order_item WHERE order_id = %s AND variant_id = %s",
                    (order_id, variant_id),
                )
                order_item_id = cur.fetchone()[0]
                cur.execute(
                    "INSERT INTO review (product_id, customer_id, order_item_id, rating, title) "
                    "VALUES (%s, %s, %s, %s, %s)",
                    (product_id, customer_id, order_item_id,
                     rng.choices([1, 2, 3, 4, 5], weights=[3, 5, 12, 35, 45])[0], "Danh gia tu dong"),
                )
                da_danh_gia.add((customer_id, product_id))
                dem["danh_gia"] += 1


def tao_don_hang(conn, rng, fake, seed, so_don, ds_khach, hang_ban, kich_thuoc_lo, ds_km):
    """Tạo nhiều đơn, cứ mỗi lô (mặc định 1.000 đơn) thì commit một lần.

    Commit theo lô vì 100.000 đơn trong 1 transaction duy nhất sẽ rất nặng;
    nếu lỗi giữa chừng thì chỉ lô đang làm bị rollback, các lô trước đã an toàn.
    """
    da_danh_gia = set()
    dem = {"mon": 0, "thanh_toan": 0, "danh_gia": 0, "khuyen_mai": 0}
    bat_dau = time.perf_counter()
    with conn.cursor() as cur:
        for n in range(1, so_don + 1):
            tao_mot_don(cur, rng, fake, seed, n, rng.choice(ds_khach), hang_ban, da_danh_gia, dem, ds_km)
            if n % kich_thuoc_lo == 0 or n == so_don:
                conn.commit()
                print(f"      ... da luu {n}/{so_don} don ({time.perf_counter() - bat_dau:.1f} giay)")
    print(f"  [5] Don hang: {so_don}, dong hang: {dem['mon']}, "
          f"thanh toan: {dem['thanh_toan']}, khuyen mai: {dem['khuyen_mai']}, "
          f"danh gia: {dem['danh_gia']}")


def tao_gio_hang(cur, rng, ds_khach, hang_ban):
    """Tạo giỏ hàng ACTIVE cho ~30% khách, mỗi giỏ 1-4 sản phẩm."""
    so_gio = 0
    so_mon = 0
    for customer_id in ds_khach:
        if rng.random() > 0.3:
            continue
        cur.execute(
            "INSERT INTO cart (customer_id, status) VALUES (%s, 'ACTIVE')",
            (customer_id,),
        )
        cart_id = cur.lastrowid
        so_gio += 1

        cac_mon = rng.sample(hang_ban, min(len(hang_ban), rng.randint(1, 4)))
        for seller_id, variant_id, gia, ten_sp, sku, product_id in cac_mon:
            cur.execute(
                "INSERT INTO cart_item (cart_id, seller_id, variant_id, quantity) "
                "VALUES (%s, %s, %s, %s)",
                (cart_id, seller_id, variant_id, rng.randint(1, 3)),
            )
            so_mon += 1
    print(f"  [+] Gio hang: {so_gio}, mon trong gio: {so_mon}")


# ---------------------------------------------------------------------------
# Chương trình chính
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Sinh du lieu gia cho ecommerce_advanced")
    parser.add_argument("--customers", type=int, default=10)
    parser.add_argument("--sellers", type=int, default=5)
    parser.add_argument("--products", type=int, default=20)
    parser.add_argument("--orders", type=int, default=50)
    parser.add_argument("--batch", type=int, default=1000, help="so don moi lan commit")
    parser.add_argument("--seed", type=int, default=20261003)
    args = parser.parse_args()

    rng = random.Random(args.seed)   # bộ sinh số ngẫu nhiên riêng, cố định theo seed
    Faker.seed(args.seed)
    fake = Faker("vi_VN")

    conn = connect()
    bat_dau = time.perf_counter()
    try:
        # Phần 1: khách, người bán, địa chỉ, danh mục, sản phẩm, khuyến mãi -> 1 transaction
        with conn.cursor() as cur:
            ds_khach = tao_khach_hang(cur, fake, args.customers)
            ds_ban = tao_nguoi_ban(cur, fake, args.sellers)
            tao_dia_chi(cur, rng, fake, ds_khach)
            ds_la = tao_danh_muc(cur)
            hang_ban = tao_san_pham(cur, rng, args.products, ds_la, ds_ban)
            ds_km = tao_khuyen_mai(cur, rng, ds_la, hang_ban)
        conn.commit()

        # Phần 2: đơn hàng (có áp khuyến mãi) -> commit theo từng lô
        tao_don_hang(conn, rng, fake, args.seed, args.orders, ds_khach, hang_ban, args.batch, ds_km)

        # Phần 3: giỏ hàng -> 1 transaction
        with conn.cursor() as cur:
            tao_gio_hang(cur, rng, ds_khach, hang_ban)
        conn.commit()

        print(f"Xong! Tong thoi gian: {time.perf_counter() - bat_dau:.1f} giay")
    except Exception:
        conn.rollback()
        print("Co loi -> lo dang lam da bi rollback.")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
