# Oracle Audit Log Framework

A comprehensive Oracle PL/SQL solution for creating audit tables and triggers to track INSERT, UPDATE, and DELETE operations with old and new values.

## Files Included

| File | Description |
|------|-------------|
| `audit_pkg.pks` | Package specification for AUDIT_PKG |
| `audit_pkg.pkb` | Package body implementation |
| `audit_example_usage.sql` | Complete example demonstrating all features |
| `generate_audit_ddl.sql` | Standalone DDL generator (no package required) |

## Quick Start

### Option 1: Using the Package (Recommended)

```sql
-- 1. Install the package
@audit_pkg.pks
@audit_pkg.pkb

-- 2. Create audit infrastructure for your table
BEGIN
    audit_pkg.create_audit_table(p_table_name => 'EMPLOYEES');
    audit_pkg.create_audit_trigger(p_table_name => 'EMPLOYEES');
END;
/
```

### Option 2: Generate DDL Only

Edit `generate_audit_ddl.sql` and set your table name:
```sql
DEFINE source_table_name = 'EMPLOYEES'
DEFINE source_table_owner = 'HR'
```
Then run the script to output the DDL.

## Audit Table Structure

The generated audit table includes:

| Column | Type | Description |
|--------|------|-------------|
| `AUDIT_ID` | NUMBER | Primary key (sequence-generated) |
| `DML_TYPE` | VARCHAR2(6) | INSERT, UPDATE, or DELETE |
| `DML_TIMESTAMP` | TIMESTAMP(6) | When the change occurred |
| `DML_USER` | VARCHAR2(128) | Oracle user who made the change |
| `SESSION_ID` | NUMBER | Database session ID |
| `CLIENT_HOST` | VARCHAR2(64) | Client machine hostname |
| `CLIENT_IP` | VARCHAR2(40) | Client IP address |
| `MODULE` | VARCHAR2(64) | Application module name |
| `ACTION` | VARCHAR2(64) | Application action |
| `OLD_<column>` | (varies) | Original value before change |
| `NEW_<column>` | (varies) | New value after change |

## Key Features

- **Autonomous Transactions**: Audit commits independently, won't rollback with main transaction
- **Session Context Capture**: Tracks user, host, IP, module, and action
- **LOB Support**: Handles CLOB/BLOB columns (stored as VARCHAR2 excerpts)
- **Column Exclusion**: Optionally exclude sensitive columns from auditing
- **DDL Preview**: Generate DDL without executing for review
- **Clean Uninstall**: Drop all audit objects with single procedure call

## Package Procedures

### `create_audit_table`
Creates the audit log table with appropriate columns.

```sql
audit_pkg.create_audit_table(
    p_table_name   => 'EMPLOYEES',      -- Required
    p_table_owner  => USER,             -- Optional (default: current user)
    p_audit_suffix => '_AUDIT_LOG'      -- Optional (default: '_AUDIT_LOG')
);
```

### `create_audit_trigger`
Creates the AFTER trigger on the source table.

```sql
audit_pkg.create_audit_trigger(
    p_table_name      => 'EMPLOYEES',          -- Required
    p_table_owner     => USER,                 -- Optional
    p_audit_suffix    => '_AUDIT_LOG',         -- Optional
    p_trigger_suffix  => '_AUDIT_TRG',         -- Optional
    p_exclude_columns => 'PASSWORD,SECRET_KEY' -- Optional
);
```

### `drop_audit_objects`
Removes audit table, trigger, and sequence.

```sql
audit_pkg.drop_audit_objects(
    p_table_name => 'EMPLOYEES'
);
```

### `get_audit_ddl` / `get_trigger_ddl`
Returns DDL as CLOB without executing.

```sql
DECLARE
    l_ddl CLOB;
BEGIN
    l_ddl := audit_pkg.get_audit_ddl(p_table_name => 'EMPLOYEES');
    DBMS_OUTPUT.PUT_LINE(l_ddl);
END;
/
```

## Sample Audit Queries

### View all changes to a table
```sql
SELECT * FROM employees_audit_log ORDER BY dml_timestamp DESC;
```

### Count changes by operation type
```sql
SELECT dml_type, COUNT(*) AS change_count
  FROM employees_audit_log
 GROUP BY dml_type;
```

### Find salary changes
```sql
SELECT dml_timestamp,
       dml_user,
       old_employee_id,
       old_salary,
       new_salary,
       new_salary - old_salary AS change_amount
  FROM employees_audit_log
 WHERE old_salary != new_salary
   AND dml_type = 'UPDATE';
```

### Changes by a specific user
```sql
SELECT *
  FROM employees_audit_log
 WHERE dml_user = 'ADMIN'
   AND dml_timestamp >= SYSDATE - 7;
```

## Execution Impact

| Aspect | Impact |
|--------|--------|
| **Trigger Type** | AFTER (fires after DML completes) |
| **Row-Level** | FOR EACH ROW processing |
| **Transaction** | Autonomous (independent commit) |
| **Performance** | Minimal overhead per row |
| **Storage** | One audit row per source row DML |

## Best Practices

1. **Partitioning**: For high-volume tables, consider partitioning the audit table by `DML_TIMESTAMP`
2. **Archiving**: Implement periodic archival of old audit records
3. **Indexing**: Add indexes based on your query patterns
4. **Exclusions**: Exclude frequently-updated timestamp columns if not needed
5. **Monitoring**: Monitor audit table growth and adjust storage accordingly

## Requirements

- Oracle Database 19c or higher
- CREATE TABLE, CREATE SEQUENCE, CREATE TRIGGER privileges
- Execute privilege on DBMS_OUTPUT (for logging)

## License

MIT License - Free for enterprise and personal use.
