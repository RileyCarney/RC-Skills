# Stored Procedures — SQL

You are an expert in stored procedures, user-defined functions, and triggers for encapsulating server-side logic in PostgreSQL, MySQL, and SQL Server.

## Overview

Stored procedures and functions are named, reusable blocks of SQL and procedural code stored inside the database. They encapsulate complex operations, reduce network round-trips, enforce business rules close to the data, and enable triggers for automatic reactions to data changes. The tradeoff is tighter coupling to the database engine and reduced portability.

## Core Concepts

### Procedures vs Functions

| Aspect | Procedure | Function |
|--------|-----------|----------|
| Return value | None (uses OUT params or result sets) | Returns a scalar, row, or table |
| Transaction control | Can COMMIT/ROLLBACK internally | Cannot (runs within caller's transaction) |
| Usable in SELECT | No | Yes (scalar/table functions) |
| Side effects | Expected (DML, DDL) | Allowed but discouraged for pure functions |

PostgreSQL blurred this distinction: before v11, only functions existed (via `CREATE FUNCTION`). v11 added `CREATE PROCEDURE` with transaction control.

### Language Options

| Engine | Languages |
|--------|-----------|
| PostgreSQL | SQL, PL/pgSQL, PL/Python, PL/Perl, PL/v8 (JavaScript) |
| MySQL | SQL (only procedural SQL) |
| SQL Server | T-SQL, CLR (.NET) |

### Volatility Categories (PostgreSQL)

| Category | Meaning | Optimizer effect |
|----------|---------|-----------------|
| `IMMUTABLE` | Same inputs always produce same output, no side effects | Can be constant-folded, used in indexes |
| `STABLE` | Same result within a single statement, reads data | Can be optimized within a query |
| `VOLATILE` | May return different results on each call, may have side effects | Called for every row (default) |

## Implementation Patterns

### Basic Stored Procedure (PostgreSQL)

```sql
CREATE OR REPLACE PROCEDURE transfer_funds(
  p_from_account int,
  p_to_account   int,
  p_amount       numeric
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_balance numeric;
BEGIN
  -- Check balance
  SELECT balance INTO v_balance
  FROM accounts WHERE id = p_from_account FOR UPDATE;

  IF v_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient funds: balance=%, requested=%', v_balance, p_amount;
  END IF;

  UPDATE accounts SET balance = balance - p_amount WHERE id = p_from_account;
  UPDATE accounts SET balance = balance + p_amount WHERE id = p_to_account;

  INSERT INTO transactions (from_account, to_account, amount, created_at)
  VALUES (p_from_account, p_to_account, p_amount, now());

  COMMIT;
END;
$$;

-- Call it
CALL transfer_funds(1, 2, 100.00);
```

### Table-Returning Function (PostgreSQL)

```sql
CREATE OR REPLACE FUNCTION get_overdue_invoices(p_days int DEFAULT 30)
RETURNS TABLE (
  invoice_id   int,
  customer_name text,
  amount       numeric,
  days_overdue int
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    i.id,
    c.name,
    i.total_amount,
    (current_date - i.due_date)::int
  FROM invoices i
  JOIN customers c ON c.id = i.customer_id
  WHERE i.status = 'unpaid'
    AND i.due_date < current_date - p_days
  ORDER BY i.due_date;
$$;

-- Use like a table
SELECT * FROM get_overdue_invoices(60) WHERE amount > 1000;
```

### Stored Procedure (MySQL)

```sql
DELIMITER //

CREATE PROCEDURE transfer_funds(
  IN p_from_account INT,
  IN p_to_account   INT,
  IN p_amount       DECIMAL(15,2)
)
BEGIN
  DECLARE v_balance DECIMAL(15,2);

  START TRANSACTION;

  SELECT balance INTO v_balance
  FROM accounts WHERE id = p_from_account FOR UPDATE;

  IF v_balance < p_amount THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Insufficient funds';
  END IF;

  UPDATE accounts SET balance = balance - p_amount WHERE id = p_from_account;
  UPDATE accounts SET balance = balance + p_amount WHERE id = p_to_account;

  COMMIT;
END //

DELIMITER ;

CALL transfer_funds(1, 2, 100.00);
```

### Trigger for Audit Logging

```sql
-- PostgreSQL: automatic audit trail
CREATE OR REPLACE FUNCTION audit_trigger_fn()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO audit_log (
    table_name, operation, row_id, old_data, new_data, changed_at, changed_by
  ) VALUES (
    TG_TABLE_NAME,
    TG_OP,
    COALESCE(NEW.id, OLD.id),
    CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
    CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END,
    now(),
    current_user
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_orders_audit
  AFTER INSERT OR UPDATE OR DELETE ON orders
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn();
```

### Trigger for Derived Column Maintenance

```sql
-- Keep a search_text column in sync automatically
CREATE OR REPLACE FUNCTION update_search_text()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.search_text := lower(NEW.first_name || ' ' || NEW.last_name || ' ' || COALESCE(NEW.email, ''));
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_search_text
  BEFORE INSERT OR UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_search_text();
```

### Error Handling

```sql
-- PostgreSQL: structured exception handling
CREATE OR REPLACE FUNCTION safe_divide(a numeric, b numeric)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN a / b;
EXCEPTION
  WHEN division_by_zero THEN
    RETURN NULL;
  WHEN numeric_value_out_of_range THEN
    RAISE WARNING 'Overflow in safe_divide(%, %)', a, b;
    RETURN NULL;
END;
$$;
```

```sql
-- MySQL: handler-based error handling
DELIMITER //
CREATE PROCEDURE safe_insert(IN p_id INT, IN p_name VARCHAR(100))
BEGIN
  DECLARE EXIT HANDLER FOR 1062  -- duplicate key
  BEGIN
    SELECT 'Duplicate entry, skipped' AS message;
  END;

  INSERT INTO items (id, name) VALUES (p_id, p_name);
  SELECT 'Inserted successfully' AS message;
END //
DELIMITER ;
```

### Dynamic SQL Inside Procedures

```sql
-- PostgreSQL: EXECUTE with format() for safety
CREATE OR REPLACE FUNCTION search_table(
  p_table text,
  p_column text,
  p_value text
)
RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
  -- format() with %I escapes identifiers, %L escapes literals
  RETURN QUERY EXECUTE format(
    'SELECT * FROM %I WHERE %I = %L',
    p_table, p_column, p_value
  );
END;
$$;
```

### Scheduled Cleanup Procedure

```sql
CREATE OR REPLACE PROCEDURE cleanup_expired_sessions()
LANGUAGE plpgsql
AS $$
DECLARE
  v_deleted int;
BEGIN
  LOOP
    DELETE FROM sessions
    WHERE id IN (
      SELECT id FROM sessions
      WHERE expires_at < now() - interval '7 days'
      LIMIT 1000
    );
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RAISE NOTICE 'Deleted % expired sessions', v_deleted;
    COMMIT;  -- commit each batch

    EXIT WHEN v_deleted = 0;
    PERFORM pg_sleep(0.05);
  END LOOP;
END;
$$;
```

## Core Philosophy

Stored procedures and functions exist to place logic where it is most effective: next to the data. When a business operation requires reading multiple tables, validating constraints, performing conditional updates, and logging the result, executing that logic inside the database eliminates network round-trips, keeps the entire operation within a single transaction, and leverages the database engine's concurrency controls. The tradeoff is clear — database-resident logic is harder to test, version, and debug than application code — but for operations where atomicity and proximity to data are paramount, the tradeoff is worth it.

The distinction between procedures and functions is not just syntactic — it reflects a design intent. Functions are computations: they take inputs, return outputs, and ideally have no side effects. They can be used in SELECT expressions, WHERE clauses, and index definitions. Procedures are workflows: they orchestrate multiple DML statements, can control transactions (COMMIT/ROLLBACK), and produce side effects. Conflating the two — writing a function that modifies data or a procedure that returns a computed value — creates confusion about intent and limits how the database engine can optimize the call.

Triggers extend this model by automating reactions to data changes. A well-designed trigger is invisible to the application: it maintains derived columns, enforces complex constraints, or writes audit logs without the application needing to know. But triggers that perform heavy logic, call external services, or cascade into other triggers create hidden performance costs and debugging nightmares. The rule of thumb is: triggers should be lightweight, deterministic, and free of side effects beyond the table they maintain.

## Anti-Patterns

- **Mega-procedures that handle every edge case** — a 500-line procedure that validates, transforms, inserts, updates, logs, and sends notifications is impossible to test, debug, or modify safely. Break it into focused sub-procedures or move orchestration logic to the application layer.

- **Using VOLATILE functions where STABLE or IMMUTABLE applies** — mislabeling volatility prevents the optimizer from caching results within a query or folding constant expressions. Worse, labeling a volatile function as IMMUTABLE and using it in an index can corrupt the index.

- **Building dynamic SQL with string concatenation** — constructing queries with `||` and user-provided values inside procedures is a SQL injection vector. Use `EXECUTE ... USING` (PostgreSQL) or `format(%I, %L)` to safely parameterize dynamic SQL.

- **Trigger cascades across multiple tables** — a trigger on table A that inserts into table B, whose trigger updates table C, whose trigger modifies table A creates circular dependencies, unpredictable execution order, and performance that is nearly impossible to profile.

- **Storing all business logic in the database** — moving every validation rule, workflow, and computation into stored procedures couples the application to a specific database engine, makes testing require a live database, and eliminates the ability to unit test logic in isolation.

## Best Practices

1. **Keep procedures focused** — one procedure, one responsibility. Avoid 500-line mega-procedures that handle every edge case.
2. **Use functions for computations, procedures for workflows** — if it returns a value and has no side effects, make it a function. If it orchestrates DML across tables, make it a procedure.
3. **Mark volatility correctly** — an `IMMUTABLE` function used in an index expression must genuinely be immutable. A wrong label can produce corrupt indexes.
4. **Parameterize, never concatenate** — use `EXECUTE ... USING` or `format(%I, %L)` for dynamic SQL. Never build SQL strings with `||` and user input.
5. **Version control all database code** — store procedures, functions, and triggers in migration files or a dedicated `sql/` directory.
6. **Minimize trigger complexity** — triggers that call other triggers or perform expensive operations create hidden performance costs and debugging nightmares. Keep them lightweight.
7. **Log errors, do not swallow them** — catching exceptions is fine, but always log enough context to diagnose failures.

## Common Pitfalls

- **Trigger cascades** — a trigger on table A inserts into table B, whose trigger updates table A. Circular triggers cause infinite loops or hard-to-debug ordering issues.
- **Security definer vs invoker** — `SECURITY DEFINER` functions run with the creator's privileges. A poorly written function can be a privilege escalation vector. Always set `search_path` explicitly.
- **Performance of row-level triggers on bulk operations** — a trigger that does a SELECT per row will be catastrophic on a million-row INSERT. Consider statement-level triggers or batch the logic.
- **Testing difficulty** — stored procedures are harder to unit test than application code. Use frameworks like pgTAP (PostgreSQL) or create dedicated test schemas.
- **Portability loss** — PL/pgSQL procedures do not run on MySQL and vice versa. If database portability matters, keep logic in the application layer.
- **Hidden dependencies** — dropping a table that a procedure references does not fail until the procedure runs. Use dependency tracking and test in CI.
- **RETURN QUERY pitfall** — in PL/pgSQL, forgetting `RETURN` at the end of a function that uses `RETURN QUERY` leads to an empty result set with no error.
