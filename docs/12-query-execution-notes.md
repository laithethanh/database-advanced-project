# Query execution notes and evidence template

`sql/06_queries.sql` is the authoritative SQL. The table below supplies the required business statement and expected result; paste actual result screenshots/CSV and plans into `report/appendix/` after running the dataset.

| Query | Business question | Expected result / validation |
|---|---|---|
| Q01 | Which products create most recognized revenue? | Descending revenue; rank ties share a rank. |
| Q02 | What revenue and order count belongs to each seller? | Includes sellers with zero revenue. |
| Q03–Q05 | Which seller/customer/SKU has no sale history? | Set difference; may be empty on a mature dataset. |
| Q06 | Which seller SKU needs replenishment? | Available stock is at or below reorder level. |
| Q07 | Which customers meet a breadth-of-purchase threshold? | Every row has at least `@min_skus` distinct variants. |
| Q08 | Which SKU is premium inside its category? | Price exceeds that category's active-variant average. |
| Q09 | Which delivered purchasers left a review? | Every row has matching delivered order item and review. |
| Q10 | Which seller has no assortment under a category branch? | Recursive category scope is used. |
| Q11 | Who bought every active SKU for a brand? | Relational-division result; empty brand set makes all customers qualify, so set a real brand. |
| Q12–Q13 | Who meets revenue threshold / which category is empty? | Aggregate threshold and outer-join anti-result. |
| Q14–Q15 | What is the category/Seller ranking? | At most 3 SKUs per category; seller ties share dense rank. |
| Q16–Q17 | How does revenue trend over time? | Chronological monthly change and rolling 30-day total. |
| Q18–Q20 | What is the category tree, subtree revenue and breadcrumb? | Depth/path is acyclic; root subtree revenue includes all descendants. |
| Q21 | Which equivalent top-seller formulation is cheaper? | Q21A/Q21B return same rows; compare actual plan, not an assumed winner. |
| Q22–Q24 | Who returns too often / which promotion works / which product is low-stock? | Check each derived aggregate against source rows. |
| Q25 | Are protected invariants violated? | Must return **zero rows**. |

## Evidence procedure

1. Run each query on small seed data; store the result with date, Git revision and row count.
2. For Q01, Q06, Q14, Q15, Q17, Q19 and Q21 run `EXPLAIN ANALYZE <query>` against benchmark data. Save unedited textual plans.
3. For Q21, assert Q21A and Q21B produce identical rows before comparing timings.
4. Do not fabricate actual results or timings. The files provide expected results only until the team runs MySQL.
