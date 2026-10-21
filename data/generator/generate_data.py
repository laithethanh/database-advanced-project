"""Trình sinh dữ liệu đo hiệu năng MySQL có tính tái lập (mặc định: 100.000 đơn hàng).

Chạy trên cơ sở dữ liệu trống sau các script 01, 02 và 05. Chương trình chủ ý
không gọi thủ tục đặt hàng: dữ liệu lịch sử số lượng lớn được nạp trực tiếp nhưng vẫn bảo toàn
các bất biến về FK, tổng tiền, tồn kho và vòng đời mà trigger thực thi.
"""
from __future__ import annotations

import argparse
import os
import random
from datetime import datetime, timedelta
from decimal import Decimal

import pymysql
from faker import Faker


def connect():
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.getenv("DB_NAME", "ecommerce_advanced"),
        charset="utf8mb4",
        autocommit=False,
    )


def chunks(rows, size):
    for start in range(0, len(rows), size):
        yield rows[start : start + size]


def scalar(cur, sql, args=()):
    cur.execute(sql, args)
    return cur.fetchone()[0]


def markers(values):
    return ",".join(["%s"] * len(values))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--orders", type=int, default=100_000)
    parser.add_argument("--customers", type=int, default=10_000)
    parser.add_argument("--sellers", type=int, default=100)
    parser.add_argument("--products", type=int, default=1_000)
    parser.add_argument("--seed", type=int, default=20261003)
    parser.add_argument("--chunk-size", type=int, default=1_000)
    parser.add_argument("--cancelled-ratio", type=float, default=0.05)
    parser.add_argument("--delivered-ratio", type=float, default=0.20)
    parser.add_argument("--shipped-ratio", type=float, default=0.10)
    parser.add_argument("--processing-ratio", type=float, default=0.10)
    parser.add_argument("--returned-ratio", type=float, default=0.40)
    parser.add_argument("--review-limit", type=int, default=20_000)
    parser.add_argument("--low-stock-rows", type=int, default=100)
    parser.add_argument("--low-stock-products", type=int, default=20)
    args = parser.parse_args()
    if min(args.orders, args.customers, args.sellers, args.products, args.chunk_size) <= 0:
        parser.error("mọi số lượng phải lớn hơn 0")
    ratios = (args.cancelled_ratio, args.delivered_ratio, args.shipped_ratio, args.processing_ratio, args.returned_ratio)
    if any(ratio < 0 or ratio > 1 for ratio in ratios):
        parser.error("các tỷ lệ trạng thái phải nằm trong [0,1]")
    if args.cancelled_ratio + args.delivered_ratio + args.shipped_ratio + args.processing_ratio > 1:
        parser.error("tổng tỷ lệ trạng thái không được vượt quá 1")
    if args.review_limit < 0 or args.low_stock_rows < 0 or args.low_stock_products < 0:
        parser.error("số lượng review/low-stock không được âm")

    rng = random.Random(args.seed)
    fake = Faker("en_US")
    Faker.seed(args.seed)
    db = connect()
    try:
        with db.cursor() as cur:
            if scalar(cur, "SELECT COUNT(*) FROM orders") != 0:
                raise RuntimeError("cơ sở dữ liệu đích đã có đơn hàng; hãy dùng cơ sở dữ liệu đo hiệu năng mới")
            cur.execute("SELECT warehouse_id FROM warehouse WHERE status='ACTIVE' ORDER BY warehouse_id")
            warehouses = [row[0] for row in cur.fetchall()]
            if not warehouses:
                raise RuntimeError("thiếu dữ liệu khởi tạo kho trong lược đồ")

            accounts = []
            for i in range(args.customers):
                accounts.append((f"bench.customer.{i:06d}@example.test", "benchmark-hash", fake.name(), f"09{i:08d}"[-10:]))
            for i in range(args.sellers):
                accounts.append((f"bench.seller.{i:05d}@example.test", "benchmark-hash", f"Người bán đo hiệu năng {i:04d}", f"08{i:08d}"[-10:]))
            cur.executemany("INSERT INTO account(email,password_hash,full_name,phone) VALUES(%s,%s,%s,%s)", accounts)

            cur.execute("SELECT account_id FROM account WHERE email LIKE 'bench.customer.%' ORDER BY account_id")
            customers = [row[0] for row in cur.fetchall()]
            cur.execute("SELECT account_id FROM account WHERE email LIKE 'bench.seller.%' ORDER BY account_id")
            sellers = [row[0] for row in cur.fetchall()]
            cur.executemany("INSERT INTO customer(account_id,customer_code) VALUES(%s,%s)", [(x, f"BC{x:08d}") for x in customers])
            cur.executemany(
                "INSERT INTO seller(account_id,seller_code,shop_name,shop_status) VALUES(%s,%s,%s,'ACTIVE')",
                [(x, f"BS{x:08d}", f"Cửa hàng đo hiệu năng {x}") for x in sellers],
            )

            cur.executemany(
                "INSERT INTO category(name,slug,status) VALUES(%s,%s,'ACTIVE')",
                [(f"Danh mục gốc đo hiệu năng {i}", f"bench-root-{i}") for i in range(10)],
            )
            cur.execute("SELECT category_id FROM category WHERE slug LIKE 'bench-root-%' ORDER BY category_id")
            roots = [row[0] for row in cur.fetchall()]
            cur.executemany(
                "INSERT INTO category(parent_category_id,name,slug,status) VALUES(%s,%s,%s,'ACTIVE')",
                [(roots[i % len(roots)], f"Danh mục nhánh đo hiệu năng {i}", f"bench-leaf-{i}") for i in range(100)],
            )
            cur.execute("SELECT category_id FROM category WHERE slug LIKE 'bench-leaf-%' ORDER BY category_id")
            categories = [row[0] for row in cur.fetchall()]

            products = [
                (categories[i % len(categories)], f"Sản phẩm đo hiệu năng {i:05d}", f"bench-product-{i:05d}",
                 "Sản phẩm đo hiệu năng được sinh có thể tái lập", f"Thương hiệu {i % 20}", "ACTIVE")
                for i in range(args.products)
            ]
            cur.executemany("INSERT INTO product(category_id,name,slug,description,brand,status) VALUES(%s,%s,%s,%s,%s,%s)", products)
            cur.execute("SELECT product_id,name FROM product WHERE slug LIKE 'bench-product-%' ORDER BY product_id")
            product_rows = cur.fetchall()

            variants = []
            for i, (product_id, _) in enumerate(product_rows):
                for color, size, code in [("Black", "M", "BLK"), ("Blue", "L", "BLU")]:
                    variants.append((
                        warehouses[i % len(warehouses)], product_id, f"BSKU-{i:05d}-{code}", color, size,
                        Decimal(rng.randrange(10000, 500000)), "ACTIVE",
                    ))
            cur.executemany(
                "INSERT INTO product_variant(warehouse_id,product_id,sku,color,size,price,warehouse_quantity,status) "
                "VALUES(%s,%s,%s,%s,%s,%s,100000,%s)",
                variants,
            )
            cur.execute(
                "SELECT v.variant_id,v.product_id,v.sku,v.price,p.name "
                "FROM product_variant v JOIN product p ON p.product_id=v.product_id "
                "WHERE v.sku LIKE 'BSKU-%' ORDER BY v.variant_id"
            )
            variant_rows = cur.fetchall()

            inventory = [
                (seller_id, variant_id, 100000, 0, 100)
                for variant_id, _, _, _, _ in variant_rows
                for seller_id in rng.sample(sellers, min(3, len(sellers)))
            ]
            cur.executemany(
                "INSERT INTO inventory(seller_id,variant_id,quantity_on_hand,reserved_quantity,reorder_level) "
                "VALUES(%s,%s,%s,%s,%s)",
                inventory,
            )
            db.commit()

            inventory_by_variant = {}
            for seller_id, variant_id, *_ in inventory:
                inventory_by_variant.setdefault(variant_id, []).append(seller_id)
            variant_info = {row[0]: row for row in variant_rows}
            variant_ids = list(variant_info)
            return_prone = set(rng.sample(customers, max(1, len(customers) // 10)))
            base = datetime(2025, 1, 1)

            def pick_status(customer_id):
                if customer_id in return_prone and rng.random() < args.returned_ratio:
                    return "RETURNED"
                roll = rng.random()
                if roll < args.cancelled_ratio:
                    return "CANCELLED"
                roll -= args.cancelled_ratio
                if roll < args.delivered_ratio:
                    return "DELIVERED"
                roll -= args.delivered_ratio
                if roll < args.shipped_ratio:
                    return "SHIPPED"
                roll -= args.shipped_ratio
                if roll < args.processing_ratio:
                    return "PROCESSING"
                return "PAID"

            for batch_no, start in enumerate(range(0, args.orders, args.chunk_size), 1):
                count = min(args.chunk_size, args.orders - start)
                orders = []
                status_by_number = {}
                for n in range(start, start + count):
                    customer_id = rng.choice(customers)
                    created = base + timedelta(minutes=rng.randrange(0, 525600))
                    order_number = f"BORD-{args.seed}-{n:09d}"
                    orders.append((
                        order_number, customer_id, "PENDING_PAYMENT", f"Người nhận {customer_id}", "0900000000",
                        "Địa chỉ đo hiệu năng", Decimal("15000"), Decimal("15000"), created, created,
                    ))
                    status_by_number[order_number] = pick_status(customer_id)
                cur.executemany(
                    "INSERT INTO orders(order_number,customer_id,status,recipient_name,recipient_phone,shipping_address,"
                    "subtotal,discount_total,shipping_fee,grand_total,placed_at,created_at) "
                    "VALUES(%s,%s,%s,%s,%s,%s,0,0,%s,%s,%s,%s)",
                    orders,
                )

                first_number = f"BORD-{args.seed}-{start:09d}"
                last_number = f"BORD-{args.seed}-{start + count - 1:09d}"
                cur.execute(
                    "SELECT order_id,order_number FROM orders WHERE order_number BETWEEN %s AND %s ORDER BY order_number",
                    (first_number, last_number),
                )
                id_rows = cur.fetchall()
                if len(id_rows) != count:
                    raise RuntimeError("không thể ánh xạ đầy đủ order_number sang order_id trong batch")
                status_by_id = {order_id: status_by_number[order_number] for order_id, order_number in id_rows}

                item_rows = []
                for order_id, _ in id_rows:
                    for variant_id in rng.sample(variant_ids, rng.randint(1, 3)):
                        _, product_id, sku, price, product_name = variant_info[variant_id]
                        seller_id = rng.choice(inventory_by_variant[variant_id])
                        quantity = rng.randint(1, 3)
                        item_rows.append((
                            order_id, seller_id, variant_id, product_name, sku, price, quantity, 0, price * quantity,
                        ))
                cur.executemany(
                    "INSERT INTO order_item(order_id,seller_id,variant_id,product_name_snapshot,sku_snapshot,"
                    "unit_price,quantity,line_discount,line_total) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)",
                    item_rows,
                )

                cur.execute(
                    "SELECT order_id,grand_total FROM orders WHERE order_number BETWEEN %s AND %s ORDER BY order_number",
                    (first_number, last_number),
                )
                totals = {order_id: amount for order_id, amount in cur.fetchall()}
                cancelled_ids = [order_id for order_id, status in status_by_id.items() if status == "CANCELLED"]
                active_ids = [order_id for order_id, status in status_by_id.items() if status != "CANCELLED"]
                processing_ids = [order_id for order_id, status in status_by_id.items()
                                  if status in ("PROCESSING", "SHIPPED", "DELIVERED", "RETURNED")]
                shipped_ids = [order_id for order_id, status in status_by_id.items()
                               if status in ("SHIPPED", "DELIVERED", "RETURNED")]
                delivered_ids = [order_id for order_id, status in status_by_id.items()
                                 if status in ("DELIVERED", "RETURNED")]
                returned_ids = [order_id for order_id, status in status_by_id.items() if status == "RETURNED"]

                if cancelled_ids:
                    cur.execute(f"UPDATE orders SET status='CANCELLED' WHERE order_id IN ({markers(cancelled_ids)})", cancelled_ids)
                if active_ids:
                    cur.executemany(
                        "INSERT INTO payment(order_id,provider,transaction_ref,amount,status,paid_at) "
                        "VALUES(%s,'BENCHMARK',%s,%s,'SUCCESS',UTC_TIMESTAMP())",
                        [(order_id, f"PAY-{order_id}", totals[order_id]) for order_id in active_ids],
                    )
                    cur.execute(f"UPDATE orders SET status='PAID' WHERE order_id IN ({markers(active_ids)})", active_ids)
                # Các lần chuyển trạng thái sau đi theo đúng state machine của trigger:
                # PENDING_PAYMENT -> PAID -> PROCESSING -> SHIPPED -> DELIVERED -> RETURN_REQUESTED -> RETURNED.
                if processing_ids:
                    cur.execute(f"UPDATE orders SET status='PROCESSING' WHERE order_id IN ({markers(processing_ids)})", processing_ids)
                if shipped_ids:
                    cur.execute(f"UPDATE orders SET status='SHIPPED' WHERE order_id IN ({markers(shipped_ids)})", shipped_ids)
                if delivered_ids:
                    cur.execute(f"UPDATE orders SET status='DELIVERED' WHERE order_id IN ({markers(delivered_ids)})", delivered_ids)
                if returned_ids:
                    cur.execute(f"UPDATE orders SET status='RETURN_REQUESTED' WHERE order_id IN ({markers(returned_ids)})", returned_ids)
                    cur.execute(f"UPDATE orders SET status='RETURNED' WHERE order_id IN ({markers(returned_ids)})", returned_ids)

                if active_ids:
                    cur.execute(
                        f"UPDATE inventory i JOIN ("
                        f"SELECT oi.seller_id,oi.variant_id,SUM(oi.quantity) AS sold_quantity FROM order_item oi "
                        f"JOIN orders o ON o.order_id=oi.order_id WHERE o.order_id IN ({markers(active_ids)}) "
                        f"AND o.status IN ('PAID','PROCESSING','SHIPPED','DELIVERED','RETURNED') "
                        f"GROUP BY oi.seller_id,oi.variant_id"
                        f") sold ON sold.seller_id=i.seller_id AND sold.variant_id=i.variant_id "
                        f"SET i.quantity_on_hand=i.quantity_on_hand-sold.sold_quantity",
                        active_ids,
                    )
                db.commit()
                print(f"committed batch {batch_no}: {start + count}/{args.orders} orders")

            if args.review_limit:
                cur.execute(
                    "INSERT INTO review(product_id,customer_id,order_item_id,rating,title,body,status) "
                    "SELECT v.product_id,o.customer_id,MIN(oi.order_item_id),"
                    "1+MOD(CRC32(CONCAT(o.customer_id,':',v.product_id)),5),"
                    "CONCAT('Đánh giá sản phẩm #',v.product_id),"
                    "CONCAT('Nội dung đánh giá cho đơn hàng #',MIN(o.order_id)),'PUBLISHED' "
                    "FROM orders o JOIN order_item oi ON oi.order_id=o.order_id "
                    "JOIN product_variant v ON v.variant_id=oi.variant_id "
                    "WHERE o.status='DELIVERED' GROUP BY v.product_id,o.customer_id "
                    "ORDER BY MIN(oi.order_item_id) LIMIT %s",
                    (args.review_limit,),
                )
            if args.low_stock_rows:
                cur.execute(
                    f"UPDATE inventory SET reorder_level=quantity_on_hand+50 ORDER BY RAND(%s) LIMIT {int(args.low_stock_rows)}",
                    (args.seed,),
                )
            if args.low_stock_products:
                # '%%' vì PyMySQL áp dụng định dạng % cho câu lệnh có tham số.
                cur.execute(
                    f"UPDATE inventory i JOIN product_variant v ON v.variant_id=i.variant_id "
                    f"JOIN (SELECT product_id FROM product WHERE slug LIKE 'bench-product-%%' "
                    f"ORDER BY RAND(%s) LIMIT {int(args.low_stock_products)}) p ON p.product_id=v.product_id "
                    f"SET i.quantity_on_hand=LEAST(i.quantity_on_hand,1)",
                    (args.seed,),
                )
            db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
