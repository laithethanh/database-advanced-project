"""Benchmark truy vấn trước/sau khi thêm index — Phạm Thành Danh.

Cách chạy (từ thư mục gốc project, sau khi đã có dữ liệu 100.000 đơn):
    python data/benchmark/run_benchmark.py
    python data/benchmark/run_benchmark.py --runs 7 --warmup 3      (mặc định)
    python data/benchmark/run_benchmark.py --keep-indexes            (giữ lại index thử nghiệm)

Quy trình:
    1. Ghi môi trường + số dòng + dung lượng bảng
    2. BASELINE: mỗi truy vấn làm nóng vài lần, đo nhiều lần, lấy TRUNG VỊ + chạy EXPLAIN ANALYZE
    3. Tạo index thử nghiệm, ANALYZE TABLE
    4. OPTIMIZED: đo lại y hệt
    5. Đo cái giá: dung lượng index tăng thêm, thời gian ghi chậm đi bao nhiêu
    6. Xóa index thử nghiệm (để schema giống bản của nhóm), ghi báo cáo ra file

Kết quả ghi vào data/benchmark/<ngày>-danh-win/:
    benchmark-results.md   bảng tổng hợp
    explain-baseline.txt   kế hoạch thực thi nguyên văn trước khi thêm index
    explain-optimized.txt  kế hoạch thực thi nguyên văn sau khi thêm index
"""

import argparse
import getpass
import statistics
import time
from datetime import datetime
from pathlib import Path

import pymysql

TRANG_THAI_CO_DOANH_THU = "('PAID','PROCESSING','SHIPPED','DELIVERED')"

# Mỗi truy vấn: mã, mô tả, câu SQL, index thử nghiệm (None = không thêm, dùng làm đối chứng)
TRUY_VAN = [
    {
        "ma": "B1",
        "mo_ta": "Top 10 san pham theo doanh thu (quet toan bo don)",
        "sql": (
            "SELECT p.product_id, p.name, SUM(oi.line_total) AS doanh_thu "
            "FROM orders o JOIN order_item oi ON oi.order_id = o.order_id "
            "JOIN product_variant v ON v.variant_id = oi.variant_id "
            "JOIN product p ON p.product_id = v.product_id "
            f"WHERE o.status IN {TRANG_THAI_CO_DOANH_THU} "
            "GROUP BY p.product_id, p.name ORDER BY doanh_thu DESC LIMIT 10"
        ),
        "tham_so": lambda ts: (),
        "index_ten": "idx_bench_oi_variant_order_total",
        "index_sql": "CREATE INDEX idx_bench_oi_variant_order_total ON order_item (variant_id, order_id, line_total)",
        "bang": "order_item",
    },
    {
        "ma": "B2",
        "mo_ta": "Doanh thu theo ngay trong thang 03/2026 (bang payment)",
        "sql": (
            "SELECT DATE(paid_at) AS ngay, COUNT(*) AS so_giao_dich, SUM(amount) AS doanh_thu "
            "FROM payment WHERE status = 'SUCCESS' AND paid_at >= %s AND paid_at < %s "
            "GROUP BY DATE(paid_at) ORDER BY ngay"
        ),
        "tham_so": lambda ts: ("2026-03-01 00:00:00", "2026-04-01 00:00:00"),
        "index_ten": "idx_bench_payment_status_paid",
        "index_sql": "CREATE INDEX idx_bench_payment_status_paid ON payment (status, paid_at, amount)",
        "bang": "payment",
    },
    {
        "ma": "B3",
        "mo_ta": "Tra cuu don theo so dien thoai nguoi nhan (cham soc khach hang)",
        "sql": (
            "SELECT order_id, order_number, status, grand_total, created_at "
            "FROM orders WHERE recipient_phone = %s"
        ),
        "tham_so": lambda ts: (ts["sdt"],),
        "index_ten": "idx_bench_orders_recipient_phone",
        "index_sql": "CREATE INDEX idx_bench_orders_recipient_phone ON orders (recipient_phone)",
        "bang": "orders",
    },
    {
        "ma": "B4",
        "mo_ta": "10 don gan nhat cua 1 khach (doi chung: da co index san)",
        "sql": (
            "SELECT order_id, order_number, status, grand_total, created_at "
            "FROM orders WHERE customer_id = %s ORDER BY created_at DESC LIMIT 10"
        ),
        "tham_so": lambda ts: (ts["khach"],),
        "index_ten": None,
        "index_sql": None,
        "bang": "orders",
    },
]


def connect():
    return pymysql.connect(
        host="127.0.0.1", port=3306, user="root",
        password=getpass.getpass("Mat khau MySQL: "),
        database="ecommerce_advanced", charset="utf8mb4", autocommit=True,
    )


def gia_tri(cur, sql, args=()):
    cur.execute(sql, args)
    return cur.fetchone()[0]


def ms(giay):
    return f"{giay * 1000:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def kb(byte):
    return f"{byte / 1024:,.0f}".replace(",", ".") + " KB"


def dung_luong_index(cur, bang):
    cur.execute("ANALYZE TABLE " + bang)          # tên bảng lấy từ danh sách cố định ở trên
    cur.fetchall()
    cur.execute(
        "SELECT index_length FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = %s",
        (bang,),
    )
    return cur.fetchone()[0]


def xoa_index_thu_nghiem(cur):
    for q in TRUY_VAN:
        if q["index_ten"]:
            cur.execute(
                "SELECT COUNT(*) FROM information_schema.statistics "
                "WHERE table_schema = DATABASE() AND table_name = %s AND index_name = %s",
                (q["bang"], q["index_ten"]),
            )
            if cur.fetchone()[0]:
                cur.execute(f"DROP INDEX {q['index_ten']} ON {q['bang']}")


def do_mot_truy_van(cur, q, ts, warmup, runs):
    """Làm nóng, đo nhiều lần, chạy EXPLAIN ANALYZE. Trả về (danh sách thời gian, số dòng, plan)."""
    args = q["tham_so"](ts)
    for _ in range(warmup):
        cur.execute(q["sql"], args)
        cur.fetchall()
    thoi_gian = []
    so_dong = 0
    for _ in range(runs):
        bat_dau = time.perf_counter()
        cur.execute(q["sql"], args)
        so_dong = len(cur.fetchall())
        thoi_gian.append(time.perf_counter() - bat_dau)
    cur.execute("EXPLAIN ANALYZE " + q["sql"], args)
    plan = "\n".join(row[0] for row in cur.fetchall())
    return thoi_gian, so_dong, plan


def do_ca_bo(cur, ts, warmup, runs, nhan):
    ket_qua = {}
    for q in TRUY_VAN:
        thoi_gian, so_dong, plan = do_mot_truy_van(cur, q, ts, warmup, runs)
        ket_qua[q["ma"]] = {"tg": thoi_gian, "dong": so_dong, "plan": plan}
        print(f"   [{nhan}] {q['ma']}: trung vi {ms(statistics.median(thoi_gian))} ms, {so_dong} dong")
    return ket_qua


def do_chi_phi_ghi(cur, conn, lan):
    """Chép toàn bộ bảng payment sang bảng tạm, đo thời gian khi KHÔNG và CÓ index thử nghiệm."""
    so_dong = gia_tri(cur, "SELECT COUNT(*) FROM payment")
    ket_qua = {}
    for co_index in (False, True):
        thoi_gian = []
        for _ in range(lan):
            cur.execute("DROP TABLE IF EXISTS payment_bench")
            cur.execute("CREATE TABLE payment_bench LIKE payment")
            if co_index:
                cur.execute("CREATE INDEX idx_bench_w ON payment_bench (status, paid_at, amount)")
            bat_dau = time.perf_counter()
            cur.execute(
                "INSERT INTO payment_bench (order_id, provider, transaction_ref, amount, status, paid_at, created_at) "
                "SELECT order_id, provider, transaction_ref, amount, status, paid_at, created_at FROM payment"
            )
            thoi_gian.append(time.perf_counter() - bat_dau)
        ket_qua[co_index] = statistics.median(thoi_gian)
    cur.execute("DROP TABLE IF EXISTS payment_bench")
    return so_dong, ket_qua[False], ket_qua[True]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--warmup", type=int, default=3)
    parser.add_argument("--runs", type=int, default=7)
    parser.add_argument("--keep-indexes", action="store_true")
    args = parser.parse_args()

    thu_muc = Path(__file__).resolve().parent / f"{datetime.now():%Y%m%d}-danh-win"
    thu_muc.mkdir(parents=True, exist_ok=True)

    conn = connect()
    bat_dau_tong = time.perf_counter()
    try:
        with conn.cursor() as cur:
            cur.execute("SET SESSION information_schema_stats_expiry = 0")
            # ---- 1. Môi trường ----
            moi_truong = {
                "MySQL": gia_tri(cur, "SELECT VERSION()"),
                "Muc co lap": gia_tri(cur, "SELECT @@transaction_isolation"),
                "innodb_buffer_pool_size": f"{gia_tri(cur, 'SELECT @@innodb_buffer_pool_size'):,} byte",
                "So don (orders)": gia_tri(cur, "SELECT COUNT(*) FROM orders"),
                "So dong hang (order_item)": gia_tri(cur, "SELECT COUNT(*) FROM order_item"),
                "So thanh toan (payment)": gia_tri(cur, "SELECT COUNT(*) FROM payment"),
            }
            cur.execute("SELECT recipient_phone, customer_id FROM orders WHERE order_id = 50000")
            sdt, khach = cur.fetchone()
            ts = {"sdt": sdt, "khach": khach}
            print("[1] Moi truong:", moi_truong)

            xoa_index_thu_nghiem(cur)    # đảm bảo bắt đầu sạch
            index_truoc = {q["bang"]: dung_luong_index(cur, q["bang"]) for q in TRUY_VAN}

            # ---- 2. Baseline ----
            print(f"[2] BASELINE (lam nong {args.warmup} lan, do {args.runs} lan moi truy van)")
            truoc = do_ca_bo(cur, ts, args.warmup, args.runs, "truoc")

            # ---- 3. Tạo index ----
            print("[3] Tao index thu nghiem")
            thoi_gian_tao = {}
            for q in TRUY_VAN:
                if q["index_sql"]:
                    bd = time.perf_counter()
                    cur.execute(q["index_sql"])
                    thoi_gian_tao[q["ma"]] = time.perf_counter() - bd
                    print(f"   {q['index_ten']}: {ms(thoi_gian_tao[q['ma']])} ms")
            index_sau = {q["bang"]: dung_luong_index(cur, q["bang"]) for q in TRUY_VAN}

            # ---- 4. Optimized ----
            print("[4] OPTIMIZED")
            sau = do_ca_bo(cur, ts, args.warmup, args.runs, "sau")

            # ---- 5. Chi phí ghi ----
            print("[5] Do chi phi ghi (chep bang payment sang bang tam, 3 lan moi truong hop)")
            so_dong_ghi, ghi_khong, ghi_co = do_chi_phi_ghi(cur, conn, 3)
            print(f"   khong index: {ms(ghi_khong)} ms | co index: {ms(ghi_co)} ms")

            # ---- 6. Dọn dẹp ----
            if not args.keep_indexes:
                xoa_index_thu_nghiem(cur)
                print("[6] Da xoa index thu nghiem (schema tro ve nhu cu)")
    finally:
        conn.close()

    # ---- Ghi file ----
    tong_gio = time.perf_counter() - bat_dau_tong
    dong = [
        "# Benchmark trước/sau khi thêm index — máy của Danh",
        "",
        f"Chạy lúc {datetime.now():%d/%m/%Y %H:%M}, tổng thời gian {tong_gio:.0f} giây. "
        f"Mỗi truy vấn làm nóng {args.warmup} lần, đo {args.runs} lần, lấy **trung vị** "
        "(thời gian tính cả gửi truy vấn và nhận kết quả về Python).",
        "",
        "## Môi trường",
        "",
        "| Thuộc tính | Giá trị |",
        "|---|---|",
    ]
    dong += [f"| {k} | {v} |" for k, v in moi_truong.items()]
    dong += [
        "", "## Kết quả thời gian", "",
        "| Mã | Truy vấn | Index thử nghiệm | Trước (ms) | Sau (ms) | Nhanh hơn | Plan sau có dùng index mới? | Số dòng |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for q in TRUY_VAN:
        t = statistics.median(truoc[q["ma"]]["tg"])
        s = statistics.median(sau[q["ma"]]["tg"])
        dung = "—" if not q["index_ten"] else ("Có" if q["index_ten"] in sau[q["ma"]]["plan"] else "**Không**")
        dong.append(
            f"| {q['ma']} | {q['mo_ta']} | {q['index_ten'] or '(không thêm — đối chứng)'} | "
            f"{ms(t)} | {ms(s)} | {t / s:.1f}x | {dung} | {sau[q['ma']]['dong']} |"
        )
    dong += [
        "", "Chi tiết từng lần đo (ms):", "",
    ]
    for q in TRUY_VAN:
        dong.append(f"- {q['ma']} trước: " + ", ".join(ms(x) for x in truoc[q["ma"]]["tg"]))
        dong.append(f"- {q['ma']} sau: " + ", ".join(ms(x) for x in sau[q["ma"]]["tg"]))
    dong += [
        "", "## Cái giá của index", "",
        "| Bảng | Dung lượng index trước | Sau khi thêm | Tăng thêm |",
        "|---|---|---|---|",
    ]
    for bang in dict.fromkeys(q["bang"] for q in TRUY_VAN if q["index_ten"]):
        dong.append(f"| {bang} | {kb(index_truoc[bang])} | {kb(index_sau[bang])} | "
                    f"+{kb(index_sau[bang] - index_truoc[bang])} |")
    dong += [
        "",
        "Thời gian tạo index: " + ", ".join(f"{m} {ms(t)} ms" for m, t in thoi_gian_tao.items()) + ".",
        "",
        f"Chi phí ghi: chép {so_dong_ghi:,} dòng `payment` sang bảng tạm (trung vị 3 lần) — "
        f"không có index thử nghiệm **{ms(ghi_khong)} ms**, có index **{ms(ghi_co)} ms** "
        f"(**{(ghi_co / ghi_khong - 1) * 100:+.0f}%**).",
        "",
        f"Index thử nghiệm {'được GIỮ LẠI' if args.keep_indexes else 'đã được xóa sau khi đo'}.",
        "Kế hoạch thực thi nguyên văn: `explain-baseline.txt`, `explain-optimized.txt`.",
    ]
    (thu_muc / "benchmark-results.md").write_text("\n".join(dong) + "\n", encoding="utf-8")
    for ten, bo in (("explain-baseline.txt", truoc), ("explain-optimized.txt", sau)):
        noi_dung = []
        for q in TRUY_VAN:
            noi_dung += [f"===== {q['ma']}: {q['mo_ta']} =====", q["sql"], "", bo[q["ma"]]["plan"], ""]
        (thu_muc / ten).write_text("\n".join(noi_dung), encoding="utf-8")
    print(f"\nXong sau {tong_gio:.0f} giay. Ket qua ghi o: {thu_muc}")


if __name__ == "__main__":
    main()
