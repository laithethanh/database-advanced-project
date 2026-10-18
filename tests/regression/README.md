# Regression manifest

Execute on a newly built sample DB in this order: `constraint_tests.sql`, `order_tests.sql`, `09_transaction_tests.sql`, then `concurrency_setup.sql` in a fresh rebuild for T03. Pass criteria:

| ID | Expected outcome |
|---|---|
| R01 | Negative price, duplicate SKU, FK violation and over-reservation are rejected. |
| R02 | Q25 and positive audit queries return zero rows/zero counts. |
| R03 | Valid checkout commits one PAID order whose totals equal its lines. |
| R04 | Invalid coupon and insufficient stock roll back every checkout change. |
| R05 | Invalid order/shipment transitions are rejected; cancelling restores seller stock once. |
| R06 | T03 permits exactly one of two last-stock checkouts. |
| R07 | Dynamic-search payload remains bound data; invalid whitelist values fail before SQL execution. |

Create `tests/regression/<run-date>.md` with MySQL version, script revision, pass/fail, exact error text and terminal screenshot links. Do not commit credentials or large raw datasets.
