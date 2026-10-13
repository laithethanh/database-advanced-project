"""PyMySQL embedded SQL entry point; use parameterized queries only."""

import os
import pymysql


def find_products(keyword: str):
    connection = pymysql.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ["DB_NAME"],
        cursorclass=pymysql.cursors.DictCursor,
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT product_id, name, slug, status FROM product "
                "WHERE status = 'ACTIVE' AND name LIKE %s ORDER BY name LIMIT 100",
                (f"%{keyword}%",),
            )
            return cursor.fetchall()
    finally:
        connection.close()
