"""Chạy kiểm thử hồi quy tự động và lưu log — Phạm Thành Danh.

Cách chạy (từ thư mục gốc repo, đã có file .env):
    python tests/regression/run_regression.py
    python tests/regression/run_regression.py --yes                 (không hỏi xác nhận)
    python tests/regression/run_regression.py --skip-concurrency    (bỏ T03 hai phiên)

CẢNH BÁO: script XÓA và dựng lại database ecommerce_advanced thành database mẫu (có seed nhỏ).
Nếu đang có bộ 100.000 đơn thì bộ đó sẽ mất; dựng lại bằng data/generator/reset_bench_db.sql + generator.

Các bước (theo tests/regression/README.md):
    00   Dựng database mẫu: data/seed/reset_sample_db.sql (01 → 02 → 03 → 04 → 05)
    10   tests/constraint_tests.sql                          R01, R02
    11   tests/promotion_tests.sql                           R04
    12   tests/order_tests.sql                               R02, R04, R05
    13   sql/09_transaction_tests.sql                        R03
    14   python -m unittest tests.test_dynamic_search -v     R07, R08
    15   tests/security_tests.sql (SQL Injection ở mức MySQL: ghép chuỗi vs tham số)   R07
    20   Dựng lại database mẫu sạch cho T03
    21   tests/concurrency_setup.sql                         R06
    22   T03: session A và session B chạy song song, B bắt đầu sau 2 giây      R06

Kết quả (không ghi đè lần chạy cũ; trùng tên thì tự thêm -2, -3...):
    report/appendix/tests/<YYYYMMDD>/NN_<buoc>.txt   log nguyên văn từng bước (stdout, stderr, exit code)
    tests/regression/<YYYY-MM-DD>.md                 bảng đạt/trượt và chi tiết từng kiểm tra
Mã thoát: 0 nếu tất cả đạt, 1 nếu có bước trượt.
"""

import argparse
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from db_config import db_params  # noqa: E402

MYSQL_MAC_DINH_WINDOWS = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
FILE_RESET = "data/seed/reset_sample_db.sql"


# ---------------------------------------------------------------------------
# Chạy lệnh và ghi log
# ---------------------------------------------------------------------------

def tim_mysql():
    for ung_vien in (os.environ.get("MYSQL_BIN"), shutil.which("mysql"), MYSQL_MAC_DINH_WINDOWS):
        if ung_vien and Path(ung_vien).exists():
            return ung_vien
    raise SystemExit("Không tìm thấy mysql client. Đặt biến MYSQL_BIN trỏ tới mysql.exe, ví dụ:\n"
                     f'  set MYSQL_BIN={MYSQL_MAC_DINH_WINDOWS}')


def tao_file_tuy_chon(params):
    """Ghi user/mật khẩu vào file tạm để mật khẩu không hiện trên dòng lệnh. File bị xóa khi kết thúc."""
    mat_khau = params["password"].replace("\\", "\\\\").replace('"', '\\"')
    f = tempfile.NamedTemporaryFile("w", suffix=".cnf", delete=False, encoding="utf-8")
    f.write("[client]\n")
    f.write(f"user={params['user']}\n")
    f.write(f'password="{mat_khau}"\n')
    f.write(f"host={params['host']}\n")
    f.write(f"port={params['port']}\n")
    f.close()
    return f.name


def giai_ma(b):
    # mysql trên Windows xuất \r\n; bỏ \r để so khớp dòng và để file log không bị \r\r\n
    return b.decode("utf-8", errors="replace").replace("\r", "")


def thu_muc_chua_dung(goc):
    """goc nếu chưa có; nếu đã có thì goc-2, goc-3... để không ghi đè bằng chứng cũ."""
    if not goc.exists():
        return goc
    i = 2
    while Path(f"{goc}-{i}").exists():
        i += 1
    return Path(f"{goc}-{i}")


class BoChay:
    def __init__(self, mysql, file_cnf, thu_muc_log):
        self.mysql = mysql
        self.file_cnf = file_cnf
        self.thu_muc_log = thu_muc_log
        self.ket_qua = []   # (ma, ten, dat, checks, ma_R, giay, file_log)

    def lenh_mysql(self, *them):
        # --defaults-extra-file phải đứng đầu tiên
        return [self.mysql, f"--defaults-extra-file={self.file_cnf}", "--default-character-set=utf8mb4", *them]

    def chay(self, lenh, stdin_file=None):
        bd = time.perf_counter()
        stdin = open(ROOT / stdin_file, "rb") if stdin_file else subprocess.DEVNULL
        try:
            p = subprocess.run(lenh, cwd=ROOT, stdin=stdin, capture_output=True)
        finally:
            if stdin_file:
                stdin.close()
        return p.returncode, giai_ma(p.stdout), giai_ma(p.stderr), time.perf_counter() - bd

    def ghi_log(self, ten_file, tieu_de, code, out, err, giay):
        noi_dung = (f"# {tieu_de}\n# Exit code: {code}\n# Thời gian: {giay:.2f} giây\n\n"
                    f"## stdout\n\n{out}\n## stderr\n\n{err}\n")
        (self.thu_muc_log / ten_file).write_text(noi_dung, encoding="utf-8")
        return ten_file

    def buoc_reset(self, ma, ghi_chu):
        code, out, err, giay = self.chay(self.lenh_mysql("-e", f"source {FILE_RESET}"))
        f = self.ghi_log(f"{ma}_reset_sample_db.txt", f"SQL: {FILE_RESET} ({ghi_chu})", code, out, err, giay)
        checks = [("exit code = 0", code == 0, f"exit code {code}"),
                  ("có dòng xác nhận dựng xong", "database mau da dung lai" in out, "")]
        return self.luu(ma, "reset_sample_db", checks, "—", giay, f, err)

    def buoc_sql(self, ma, ten, file_sql, ma_r, kiem_tra=None):
        code, out, err, giay = self.chay(self.lenh_mysql("ecommerce_advanced"), stdin_file=file_sql)
        f = self.ghi_log(f"{ma}_{ten}.txt", f"SQL: {file_sql}", code, out, err, giay)
        checks = [("exit code = 0", code == 0, f"exit code {code}")]
        if re.search(r"\tFAIL$", out, re.M):
            checks.append(("không có dòng FAIL", False, "có dòng FAIL trong output"))
        if kiem_tra:
            checks += kiem_tra(out)
        return self.luu(ma, ten, checks, ma_r, giay, f, err)

    def luu(self, ma, ten, checks, ma_r, giay, file_log, err=""):
        dat = all(ok for _, ok, _ in checks)
        if not dat and err.strip():
            checks.append(("lỗi MySQL/Python (dòng cuối stderr)", False, err.strip().splitlines()[-1][:200]))
        self.ket_qua.append((ma, ten, dat, checks, ma_r, giay, file_log))
        print(f"  [{'ĐẠT  ' if dat else 'TRƯỢT'}] {ma} {ten} ({giay:.1f} s)")
        for mo_ta, ok, chi_tiet in checks:
            if not ok:
                print(f"          - {mo_ta}: {chi_tiet}")
        return dat


# ---------------------------------------------------------------------------
# Đọc output dạng batch của mysql (cột cách nhau bằng tab, dòng đầu là tên cột)
# ---------------------------------------------------------------------------

def dong_sau(out, tien_to_tieu_de):
    """Các giá trị của dòng ngay sau dòng tiêu đề bắt đầu bằng tien_to_tieu_de (None nếu không có)."""
    dong = out.splitlines()
    for i, d in enumerate(dong):
        if d.startswith(tien_to_tieu_de) and i + 1 < len(dong):
            return dong[i + 1].split("\t")
    return None


def dem_pass(out):
    return len(re.findall(r"\tPASS$", out, re.M))


def kiem_tra_bat_bien(out):
    """Mọi kết quả 1 cột tên invalid_* phải bằng 0."""
    dong = out.splitlines()
    checks = []
    for i, d in enumerate(dong):
        if re.fullmatch(r"invalid_\w+", d.strip()) and i + 1 < len(dong):
            gia_tri = dong[i + 1].strip()
            checks.append((f"{d.strip()} = 0", gia_tri == "0", f"= {gia_tri}"))
    return checks


def kt_constraint(out):
    n = dem_pass(out)
    bb = kiem_tra_bat_bien(out)
    return ([("7 case lỗi đều PASS", n >= 7, f"{n} case PASS"),
             ("có 5 truy vấn bất biến invalid_*", len(bb) >= 5, f"{len(bb)} truy vấn")] + bb)


def kt_promotion(out):
    checks = [("4 case lỗi đều PASS", dem_pass(out) >= 4, f"{dem_pass(out)} case PASS")]
    for nhan in ("order_id_a", "order_id_b"):
        r = dong_sau(out, f"{nhan}\tpromo_rows\tpromo_sum\torder_discount_total")
        ok = r is not None and len(r) >= 4 and r[2] == r[3]
        checks.append((f"kịch bản {nhan[-1].upper()}: promo_sum = discount_total của đơn", ok, str(r)))
    r = dong_sau(out, "orders_before\torders_after\tused_before\tused_after")
    ok = r is not None and len(r) >= 4 and r[0] == r[1] and r[2] == r[3]
    checks.append(("case lỗi không để lại đơn, không tăng used_count", ok, str(r)))
    return checks + kiem_tra_bat_bien(out)


def kt_order(out):
    r = dong_sau(out, "orders_before\torders_after\tstock_before\tstock_after")
    ok = r is not None and len(r) >= 4 and r[0] == r[1] and r[2] == r[3]
    return [
        ("7 case lỗi đều PASS", dem_pass(out) >= 7, f"{dem_pass(out)} case PASS"),
        ("fixture_status = FIXTURE_OK", "FIXTURE_OK" in out, ""),
        ("rollback: số đơn và tồn kho trước = sau", ok, str(r)),
        ("ORDER_DATA_OK: 0 vi phạm", re.search(r"^ORDER_DATA_OK\t0$", out, re.M) is not None, ""),
    ]


def kt_transaction(out):
    checks = []
    r = dong_sau(out, "created_order_id\tstock_before\tsubtotal\tgrand_total\titem_sum")
    try:
        ok = r is not None and float(r[2]) == float(r[4]) and float(r[3]) == float(r[2]) + 30000
    except (ValueError, IndexError):
        ok = False
    checks.append(("T01: subtotal = tổng dòng hàng, grand_total = subtotal + 30.000 phí ship", ok, str(r)))
    r = dong_sau(out, "phone_after_savepoint_rollback")
    checks.append(("T05: ROLLBACK TO SAVEPOINT giữ nguyên số điện thoại 0900000001",
                   r == ["0900000001"], str(r)))
    return checks


def kt_security(out):
    checks = []
    for ma, nhan in (("S1", "OR 1=1"), ("S2", "UNION")):
        r = next((d.split("\t") for d in out.splitlines() if d.startswith(ma + " ")), None)
        ok = r is not None and len(r) >= 5 and r[-1] == "PASS"
        chi_tiet = (f"ghép chuỗi {r[1]} dòng / tham số {r[2]} dòng / tổng {r[3]}" if r and len(r) >= 5
                    else "không thấy dòng kết quả")
        checks.append((f"{ma} {nhan}: ghép chuỗi bị khai thác, tham số trả 0 dòng", ok, chi_tiet))
    return checks


SQL_KIEM_TRA_T03 = (
    "SELECT i.quantity_on_hand AS stock, "
    "(SELECT COUNT(*) FROM orders o JOIN customer c ON c.account_id = o.customer_id "
    " WHERE c.customer_code = 'CUS2001' AND o.status = 'PAID') AS cus2001_paid, "
    "(SELECT COUNT(*) FROM orders o JOIN customer c ON c.account_id = o.customer_id "
    " WHERE c.customer_code = 'CUS2002') AS cus2002_orders "
    "FROM inventory i JOIN product_variant v ON v.variant_id = i.variant_id "
    "JOIN seller s ON s.account_id = i.seller_id "
    "WHERE v.sku = 'SKU-DEMO-001' AND s.seller_code = 'SEL0001'"
)


def chay_t03(bc):
    def mo(file_sql):
        f = open(ROOT / file_sql, "rb")
        p = subprocess.Popen(bc.lenh_mysql("ecommerce_advanced"), cwd=ROOT, stdin=f,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return p, f

    bd = time.perf_counter()
    pa, fa = mo("tests/concurrency_session_a.sql")
    time.sleep(2)
    bd_b = time.perf_counter()
    pb, fb = mo("tests/concurrency_session_b.sql")
    out_b, err_b = pb.communicate()
    giay_b = time.perf_counter() - bd_b
    out_a, err_a = pa.communicate()
    giay = time.perf_counter() - bd
    fa.close()
    fb.close()
    out_a, err_a, out_b, err_b = map(giai_ma, (out_a, err_a, out_b, err_b))

    code_v, out_v, err_v, _ = bc.chay(bc.lenh_mysql("ecommerce_advanced", "-e", SQL_KIEM_TRA_T03))
    r = dong_sau(out_v, "stock\tcus2001_paid\tcus2002_orders")

    ten_file = "22_concurrency_two_sessions.txt"
    (bc.thu_muc_log / ten_file).write_text(
        "# T03 hai phiên tranh mua đơn vị hàng cuối cùng (SKU-DEMO-001 của SEL0001, tồn kho = 1)\n\n"
        "- Session A: tests/concurrency_session_a.sql — checkout cho CUS2001, giữ khóa 6 giây rồi COMMIT.\n"
        "- Session B: tests/concurrency_session_b.sql — bắt đầu sau 2 giây, CALL sp_checkout cho CUS2002.\n\n"
        f"- Session A exit code: {pa.returncode}\n"
        f"- Session B exit code: {pb.returncode} (mong đợi khác 0: lỗi 1644 insufficient inventory)\n"
        f"- Thời gian session B (gồm chờ khóa): {giay_b:.2f} giây\n\n"
        f"## Session A stdout\n\n{out_a}\n## Session A stderr\n\n{err_a}\n"
        f"## Session B stdout\n\n{out_b}\n## Session B stderr\n\n{err_b}\n"
        f"## Kiểm tra sau T03 (exit code {code_v})\n\n{out_v}\n{err_v}\n",
        encoding="utf-8")

    bc.luu("22", "concurrency_two_sessions", [
        ("session A checkout và COMMIT thành công (exit 0)", pa.returncode == 0, f"exit {pa.returncode}"),
        ("session B bị từ chối: ERROR 1644 insufficient inventory",
         pb.returncode != 0 and "1644" in err_b and "insufficient inventory" in err_b,
         err_b.strip()[:150] or f"exit {pb.returncode}, không có lỗi"),
        ("session B phải chờ khóa của A (≥ 2 giây)", giay_b >= 2, f"{giay_b:.2f} giây"),
        ("sau cùng: tồn kho 0, CUS2001 có 1 đơn PAID, CUS2002 không có đơn", r == ["0", "1", "0"],
         str(r) if r else (err_v.strip()[:150] or "không đọc được kết quả")),
    ], "R06", giay, ten_file, err_a if pa.returncode else "")


# ---------------------------------------------------------------------------
# Chương trình chính
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Chạy kiểm thử hồi quy trên database mẫu và lưu log.")
    parser.add_argument("--yes", action="store_true", help="không hỏi xác nhận trước khi xóa database")
    parser.add_argument("--skip-concurrency", action="store_true", help="bỏ bước T03 hai phiên")
    parser.add_argument("--label", default=None, help="tên thư mục log, mặc định YYYYMMDD")
    args = parser.parse_args()

    params = db_params()
    if params["database"] != "ecommerce_advanced":
        raise SystemExit("Các file SQL dùng cố định database ecommerce_advanced; đặt DB_NAME=ecommerce_advanced trong .env.")
    if not args.yes:
        tl = input("Database ecommerce_advanced sẽ bị XÓA và dựng lại thành database mẫu. Tiếp tục? (y/N): ")
        if tl.strip().lower() != "y":
            raise SystemExit("Đã hủy.")

    bay_gio = datetime.now()
    ten_goc = args.label or f"{bay_gio:%Y%m%d}"
    thu_muc_log = thu_muc_chua_dung(ROOT / "report" / "appendix" / "tests" / ten_goc)
    hau_to = thu_muc_log.name[len(ten_goc):]          # "" hoặc "-2", "-3"...
    file_bao_cao = ROOT / "tests" / "regression" / f"{bay_gio:%Y-%m-%d}{('-' + args.label) if args.label else ''}{hau_to}.md"

    mysql = tim_mysql()
    file_cnf = tao_file_tuy_chon(params)
    bd_tong = time.perf_counter()
    bc = BoChay(mysql, file_cnf, thu_muc_log)
    try:
        code, ver, err, _ = bc.chay(bc.lenh_mysql("-N", "-e", "SELECT VERSION()"))
        if code != 0:
            raise SystemExit("Không kết nối được MySQL: " + (err.strip().splitlines() or ["?"])[-1])
        mysql_version = ver.strip()
        thu_muc_log.mkdir(parents=True)
        commit, ban_nhap = "không xác định", ""
        if shutil.which("git"):
            code, sha, _, _ = bc.chay(["git", "rev-parse", "--short", "HEAD"])
            if code == 0:
                commit = sha.strip()
                _, st, _, _ = bc.chay(["git", "status", "--porcelain"])
                ban_nhap = " (có thay đổi chưa commit)" if st.strip() else ""
        print(f"MySQL {mysql_version}, commit {commit}{ban_nhap}")
        print(f"Log: {thu_muc_log}")

        print("[1] Dựng database mẫu")
        co_db = bc.buoc_reset("00", "01 → 02 → 03 → 04 → 05")
        if co_db:
            print("[2] Kiểm thử SQL")
            bc.buoc_sql("10", "constraint_tests", "tests/constraint_tests.sql", "R01, R02", kt_constraint)
            bc.buoc_sql("11", "promotion_tests", "tests/promotion_tests.sql", "R04", kt_promotion)
            bc.buoc_sql("12", "order_tests", "tests/order_tests.sql", "R02, R04, R05", kt_order)
            bc.buoc_sql("13", "transaction_tests", "sql/09_transaction_tests.sql", "R03", kt_transaction)

        print("[3] SQL động: unittest Python + kiểm thử SQL Injection trên MySQL")
        code, out, err, giay = bc.chay([sys.executable, "-m", "unittest", "tests.test_dynamic_search", "-v"])
        f = bc.ghi_log("14_python_unittest.txt", "python -m unittest tests.test_dynamic_search -v", code, out, err, giay)
        m = re.search(r"^Ran (\d+) tests?", err + out, re.M)
        so_test = int(m.group(1)) if m else 0
        bc.luu("14", "python_unittest", [
            ("exit code = 0", code == 0, f"exit code {code}"),
            ("chạy đủ 6 test", so_test >= 6, f"{so_test} test"),
            ("kết quả OK", re.search(r"^OK", err + out, re.M) is not None, ""),
        ], "R07, R08", giay, f, err if code else "")
        if co_db:
            bc.buoc_sql("15", "security_tests", "tests/security_tests.sql", "R07", kt_security)

        if not args.skip_concurrency:
            print("[4] T03 hai phiên tranh mua đơn vị cuối cùng (khoảng 10 giây)")
            if bc.buoc_reset("20", "database mẫu sạch cho T03"):
                if bc.buoc_sql("21", "concurrency_setup", "tests/concurrency_setup.sql", "R06"):
                    chay_t03(bc)
    finally:
        try:
            os.remove(file_cnf)
        except OSError:
            pass

    # ---- Báo cáo tóm tắt ----
    tong_giay = time.perf_counter() - bd_tong
    so_dat = sum(1 for k in bc.ket_qua if k[2])
    du_buoc = 7 if args.skip_concurrency else 10
    dat_het = so_dat == len(bc.ket_qua) == du_buoc
    rel_log = thu_muc_log.relative_to(ROOT).as_posix()
    dong = [
        f"# Kết quả kiểm thử hồi quy — {bay_gio:%d/%m/%Y %H:%M}",
        "",
        f"Chạy tự động bằng `python tests/regression/run_regression.py`"
        f"{' --skip-concurrency' if args.skip_concurrency else ''}. "
        f"**{so_dat}/{du_buoc} bước đạt — {'TẤT CẢ ĐẠT' if dat_het else 'CÓ BƯỚC TRƯỢT HOẶC CHƯA CHẠY'}.** "
        f"Tổng thời gian {tong_giay:.0f} giây.",
        "",
        "| Thuộc tính | Giá trị |",
        "|---|---|",
        f"| MySQL | {mysql_version} |",
        f"| Python | {platform.python_version()} |",
        f"| Hệ điều hành | {platform.platform()} |",
        f"| Commit | `{commit}`{ban_nhap} |",
        f"| Log nguyên văn | `{rel_log}/` |",
        "",
        "| Bước | Nội dung | Tiêu chí | Kết quả | Thời gian | Log |",
        "|---|---|---|---|---|---|",
    ]
    for ma, ten, dat, checks, ma_r, giay, file_log in bc.ket_qua:
        dong.append(f"| {ma} | {ten} | {ma_r} | {'✅ Đạt' if dat else '❌ Trượt'} | {giay:.1f} s | "
                    f"[{file_log}](../../{rel_log}/{file_log}) |")
    dong += ["", "## Chi tiết từng kiểm tra", ""]
    for ma, ten, dat, checks, ma_r, giay, file_log in bc.ket_qua:
        dong.append(f"**{ma} {ten}**")
        dong.append("")
        for mo_ta, ok, chi_tiet in checks:
            dong.append(f"- {'✅' if ok else '❌'} {mo_ta}" + (f" — `{chi_tiet}`" if chi_tiet else ""))
        dong.append("")
    dong += [
        "## Ghi chú",
        "",
        "- R09 (generator đủ trạng thái, review, tồn kho thấp) không chạy ở đây vì cần database 100.000 đơn; xem",
        "  `report/appendix/queries/20261025/README.md` và `data/benchmark/20261103-danh-win/README.md`.",
        "- T04 và T06 chạy thủ công: `report/appendix/tests/20261023/67_manual_t04_t06.txt`.",
        f"- Ảnh chụp terminal: `{rel_log}/regression-terminal.png`.",
        "- Sau khi chạy, `ecommerce_advanced` là database mẫu (seed nhỏ + dữ liệu do test tạo ra).",
    ]
    file_bao_cao.write_text("\n".join(dong) + "\n", encoding="utf-8")
    print(f"\n{so_dat}/{du_buoc} bước đạt. Báo cáo: {file_bao_cao.relative_to(ROOT)}")
    sys.exit(0 if dat_het else 1)


if __name__ == "__main__":
    main()
