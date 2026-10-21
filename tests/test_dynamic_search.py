from decimal import Decimal
import unittest

from app.dynamic_search import build_search_sql


class DynamicSearchTests(unittest.TestCase):
    def test_keyword_is_bound_not_interpolated(self):
        attack = "' OR 1=1 --"
        sql, params = build_search_sql(keyword=attack)
        self.assertNotIn(attack, sql)
        self.assertEqual(params[:2], [f"%{attack}%", f"%{attack}%"])
        self.assertIn("%s", sql)

    def test_sort_whitelist_rejects_injection(self):
        for value in ("name; DROP TABLE product", "price DESC", "unknown"):
            with self.assertRaises(ValueError):
                build_search_sql(sort=value)

    def test_direction_whitelist_rejects_injection(self):
        for value in ("desc;--", "asc, (SELECT 1)", "sideways"):
            with self.assertRaises(ValueError):
                build_search_sql(direction=value)

    def test_price_sort_uses_selected_alias(self):
        sql, _ = build_search_sql(sort="price", direction="desc")
        self.assertIn("ORDER BY v.price DESC", sql)

    def test_invalid_ranges_are_rejected(self):
        with self.assertRaises(ValueError):
            build_search_sql(min_price=Decimal("-1"))
        with self.assertRaises(ValueError):
            build_search_sql(min_price=Decimal("10"), max_price=Decimal("5"))
        with self.assertRaises(ValueError):
            build_search_sql(min_rating=Decimal("6"))
        with self.assertRaises(ValueError):
            build_search_sql(limit=0)
        with self.assertRaises(ValueError):
            build_search_sql(limit=101)

    def test_filters_are_parameterized(self):
        sql, params = build_search_sql(
            keyword="phone", category_id=2, min_price=Decimal("10"),
            max_price=Decimal("20"), brand="Demo", min_rating=Decimal("4"),
            limit=25,
        )
        self.assertIn("p.category_id = %s", sql)
        self.assertIn("v.price >= %s", sql)
        self.assertIn("v.price <= %s", sql)
        self.assertIn("p.brand = %s", sql)
        self.assertIn("COALESCE(r.average_rating, 0) >= %s", sql)
        self.assertNotIn("phone", sql)
        self.assertEqual(params[-1], 25)
        self.assertEqual(len(params), 8)


if __name__ == "__main__":
    unittest.main()
