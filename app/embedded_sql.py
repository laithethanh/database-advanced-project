"""Small embedded-SQL program using PyMySQL cursors and bound parameters."""
from __future__ import annotations

import argparse
import os
from typing import Any
import pymysql


def connection() -> pymysql.connections.Connection:
    return pymysql.connect(host=os.environ["DB_HOST"], port=int(os.getenv("DB_PORT", "3306")), user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"], database=os.getenv("DB_NAME", "ecommerce_advanced"), charset="utf8mb4",
        autocommit=False, cursorclass=pymysql.cursors.DictCursor)


def find_products(keyword: str) -> list[dict[str, Any]]:
    with connection() as db:
        with db.cursor() as cursor:  # Python DB-API cursor; values are parameterized.
            cursor.execute("SELECT product_id,name,slug,status FROM product WHERE status='ACTIVE' AND name LIKE %s ORDER BY name LIMIT 100", (f"%{keyword}%",))
            return cursor.fetchall()


def change_cart_quantity(cart_id: int, seller_id: int, variant_id: int, quantity: int) -> None:
    if quantity <= 0: raise ValueError("quantity must be positive")
    with connection() as db:
        try:
            with db.cursor() as cursor:
                cursor.execute("UPDATE cart_item SET quantity=%s WHERE cart_id=%s AND seller_id=%s AND variant_id=%s", (quantity,cart_id,seller_id,variant_id))
                if cursor.rowcount != 1: raise LookupError("cart item not found")
            db.commit()
        except Exception:
            db.rollback()
            raise


def checkout(customer_id: int, recipient_name: str, recipient_phone: str, shipping_address: str, shipping_fee: int, promotion_code: str | None) -> int:
    with connection() as db:
        try:
            with db.cursor() as cursor:
                cursor.execute("CALL sp_checkout(%s,%s,%s,%s,%s,%s,@new_order_id)", (customer_id,recipient_name,recipient_phone,shipping_address,shipping_fee,promotion_code))
                cursor.execute("SELECT @new_order_id AS order_id")
                order_id = cursor.fetchone()["order_id"]
            db.commit()
            return order_id
        except Exception:
            db.rollback()
            raise


def main() -> None:
    parser=argparse.ArgumentParser(); parser.add_argument("keyword", nargs="?", default="Demo")
    for row in find_products(parser.parse_args().keyword): print(row)


if __name__ == "__main__": main()
