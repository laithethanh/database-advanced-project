# DB execution, evidence and handoff runbook

## Clean build

Use MySQL 8.0.18+ (required for `EXPLAIN ANALYZE`) and a disposable database instance. From the repository root, execute in this strict order:

```powershell
mysql -u <user> -p < sql/01_schema.sql
mysql -u <user> -p < sql/02_constraints.sql
mysql -u <user> -p < sql/03_seed_small.sql
mysql -u <user> -p < sql/04_functions.sql
mysql -u <user> -p < sql/05_triggers.sql
mysql -u <user> -p < tests/constraint_tests.sql
mysql -u <user> -p < sql/06_queries.sql
mysql -u <user> -p < sql/07_recursive.sql
```

`sql/01_schema.sql` is immutable and is not modified by this project. The trigger and function scripts must be loaded **after** the small seed because their validation rules correctly reject incomplete catalog rows during bootstrap.

## Large data and benchmark

1. Create another clean database with scripts 01, 02 and 05 (omit `03_seed_small.sql`); copy `.env.example` to `.env` and load its values into the shell without committing it.
2. `pip install -r data/generator/requirements.txt`
3. `python data/generator/generate_data.py --orders 100000 --seed 20261003`
4. Run `sql/08_benchmark.sql`; execute every selected query three warm runs and five timed runs. Save raw plans and calculate median.
5. Apply one candidate index at a time in a database copy, rerun the identical workload, then capture index storage and insert/update cost. Never report a guessed result.

Store `metadata.md`, raw `EXPLAIN ANALYZE` outputs, timings and `SHOW INDEX` output under `data/benchmark/<YYYYMMDD>-<machine>/`.

## Two-session last-stock test

Run `mysql -u <user> -p < tests/concurrency_setup.sql` against a **fresh sample DB**. Then execute the following as close together as possible in two terminals:

```sql
-- Terminal A                         -- Terminal B
CALL sp_checkout(                     CALL sp_checkout(
  (SELECT account_id FROM customer      (SELECT account_id FROM customer
   WHERE customer_code='CUS2001'),       WHERE customer_code='CUS2002'),
  'Concurrent One','0900000101',       'Concurrent Two','0900000102',
  'HCM',0,NULL,@order_a);              'HCM',0,NULL,@order_b);
SELECT @order_a;                       SELECT @order_b;
```

The procedure locks inventory row(s) with `FOR UPDATE` and uses a conditional update, so exactly one call commits. Record both terminal outputs and final `inventory`, `orders`, `payment` rows. Restore the test database after the experiment.

## What must be evidenced by the team

Actual timings, plans, lock waits, screenshots, ObjectDB execution and database-specific error text depend on your MySQL/ObjectDB environment. They are intentionally not fabricated in this repository; capture them using the commands above.
