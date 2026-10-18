"""Safe optional-filter product search for MySQL/PyMySQL.

Identifiers cannot be parameter-bound, so sort choices are a closed whitelist.
Every user value is bound through PyMySQL placeholders; never interpolate it.
"""
from __future__ import annotations

import argparse
import os
from decimal import Decimal
from typing import Any

import pymysql

ALLOWED_SORTS = {"name": "p.name", "price": "min_price", "created_at": "p.created_at", "rating": "average_rating"}
ALLOWED_DIRECTIONS = {"asc": "ASC", "desc": "DESC"}


def build_search_sql(*, keyword: str | None = None, category_id: int | None = None,
                     min_price: Decimal | None = None, max_price: Decimal | None = None,
                     brand: str | None = None, min_rating: Decimal | None = None,
                     sort: str = "name", direction: str = "asc", limit: int = 50) -> tuple[str, list[Any]]:
    if sort not in ALLOWED_SORTS or direction not in ALLOWED_DIRECTIONS:
        raise ValueError("invalid sort option")
    if not 1 <= limit <= 100:
        raise ValueError("limit must be from 1 to 100")
    if (min_price is not None and min_price < 0) or (max_price is not None and max_price < 0):
        raise ValueError("price cannot be negative")
    if min_price is not None and max_price is not None and min_price > max_price:
        raise ValueError("min_price cannot exceed max_price")
    if min_rating is not None and not Decimal("1") <= min_rating <= Decimal("5"):
        raise ValueError("min_rating must be from 1 to 5")

    conditions = ["p.status = 'ACTIVE'", "v.status = 'ACTIVE'", "w.status = 'ACTIVE'"]
    params: list[Any] = []
    if keyword:
        conditions.append("(p.name LIKE %s OR p.description LIKE %s)")
        params.extend([f"%{keyword}%", f"%{keyword}%"])
    if category_id is not None:
        conditions.append("p.category_id = %s")
        params.append(category_id)
    if min_price is not None:
        conditions.append("v.price >= %s")
        params.append(min_price)
    if max_price is not None:
        conditions.append("v.price <= %s")
        params.append(max_price)
    if brand:
        conditions.append("p.brand = %s")
        params.append(brand)
    if min_rating is not None:
        conditions.append("COALESCE(r.average_rating, 0) >= %s")
        params.append(min_rating)

    sql = f"""
SELECT p.product_id,p.name,p.slug,p.brand,v.variant_id,v.sku,v.color,v.size,v.price,
       w.name AS warehouse_name,COALESCE(r.average_rating,0) AS average_rating
FROM product p
JOIN product_variant v ON v.product_id=p.product_id
JOIN warehouse w ON w.warehouse_id=v.warehouse_id
LEFT JOIN (
  SELECT product_id,AVG(rating) AS average_rating FROM review WHERE status='PUBLISHED' GROUP BY product_id
) r ON r.product_id=p.product_id
WHERE {' AND '.join(conditions)}
ORDER BY {ALLOWED_SORTS[sort]} {ALLOWED_DIRECTIONS[direction]}, p.product_id, v.variant_id
LIMIT %s"""
    params.append(limit)
    return sql, params


def search_products(**filters: Any) -> list[dict[str, Any]]:
    sql, params = build_search_sql(**filters)
    connection = pymysql.connect(host=os.environ["DB_HOST"], port=int(os.getenv("DB_PORT", "3306")),
        user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"], database=os.getenv("DB_NAME", "ecommerce_advanced"),
        charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor)
    try:
        with connection.cursor() as cursor:
            cursor.execute(sql, params)
            return cursor.fetchall()
    finally:
        connection.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Safe product search")
    parser.add_argument("--keyword"); parser.add_argument("--category-id", type=int); parser.add_argument("--min-price", type=Decimal)
    parser.add_argument("--max-price", type=Decimal); parser.add_argument("--brand"); parser.add_argument("--min-rating", type=Decimal)
    parser.add_argument("--sort", default="name", choices=ALLOWED_SORTS); parser.add_argument("--direction", default="asc", choices=ALLOWED_DIRECTIONS)
    parser.add_argument("--limit", type=int, default=50)
    args = vars(parser.parse_args())
    for row in search_products(**args): print(row)


if __name__ == "__main__": main()
