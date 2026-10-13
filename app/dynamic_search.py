"""Dynamic search design: whitelist identifiers, bind values as parameters."""

ALLOWED_SORTS = {"name": "p.name", "price": "v.price", "created_at": "p.created_at"}
ALLOWED_DIRECTIONS = {"asc": "ASC", "desc": "DESC"}


def build_search_sql(sort: str = "name", direction: str = "asc"):
    if sort not in ALLOWED_SORTS or direction not in ALLOWED_DIRECTIONS:
        raise ValueError("invalid sort option")
    sql = (
        "SELECT p.product_id, p.name, v.variant_id, v.sku, v.price, w.name AS warehouse_name "
        "FROM product p JOIN product_variant v ON v.product_id = p.product_id "
        "JOIN warehouse w ON w.warehouse_id = v.warehouse_id "
        "WHERE p.status = 'ACTIVE' AND v.status = 'ACTIVE' AND w.status = 'ACTIVE' "
        "ORDER BY " + ALLOWED_SORTS[sort] + " " + ALLOWED_DIRECTIONS[direction]
    )
    return sql
