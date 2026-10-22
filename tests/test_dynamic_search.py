from decimal import Decimal
import unittest

from app.dynamic_search import tao_cau_tim_kiem


class DynamicSearchTests(unittest.TestCase):
    def test_keyword_is_bound_not_interpolated(self):
        attack = "' OR 1=1 --"
        sql, params = tao_cau_tim_kiem(tu_khoa=attack)
        self.assertNotIn(attack, sql)
        self.assertEqual(params[0], f"%{attack}%")
        self.assertIn("%s", sql)

    def test_sort_whitelist_rejects_injection(self):
        for value in ("ten; DROP TABLE product", "gia DESC", "khong_co"):
            with self.assertRaises(ValueError):
                tao_cau_tim_kiem(sap_xep=value)

    def test_direction_whitelist_rejects_injection(self):
        for value in ("desc;--", "asc, (SELECT 1)", "sideways"):
            with self.assertRaises(ValueError):
                tao_cau_tim_kiem(chieu=value)

    def test_price_sort_uses_selected_alias(self):
        sql, _ = tao_cau_tim_kiem(sap_xep="gia", chieu="giam")
        self.assertIn("ORDER BY v.price DESC", sql)

    def test_invalid_ranges_are_rejected(self):
        with self.assertRaises(ValueError):
            tao_cau_tim_kiem(gia_tu=Decimal("-1"))
        with self.assertRaises(ValueError):
            tao_cau_tim_kiem(gia_den=Decimal("-1"))
        with self.assertRaises(ValueError):
            tao_cau_tim_kiem(gia_tu=Decimal("10"), gia_den=Decimal("5"))
        with self.assertRaises(ValueError):
            tao_cau_tim_kiem(gioi_han=0)
        with self.assertRaises(ValueError):
            tao_cau_tim_kiem(gioi_han=101)

    def test_filters_are_parameterized(self):
        sql, params = tao_cau_tim_kiem(
            tu_khoa="phone", danh_muc_id=2, gia_tu=Decimal("10"),
            gia_den=Decimal("20"), gioi_han=25,
        )
        self.assertIn("p.category_id = %s", sql)
        self.assertIn("v.price >= %s", sql)
        self.assertIn("v.price <= %s", sql)
        self.assertIn("p.name LIKE %s", sql)
        self.assertNotIn("phone", sql)
        self.assertEqual(params[-1], 25)
        self.assertEqual(len(params), 5)


if __name__ == "__main__":
    unittest.main()
