# ORDS Module Privileges - Understanding and Resolution

## Problem Summary

When the `SURETY` user attempts to query ORDS metadata tables directly:

```sql
SELECT s.parsing_schema, m.name, m.uri_prefix, m.status
FROM ords_metadata.ords_modules m
JOIN ords_metadata.ords_schemas s ON m.schema_id = s.id
WHERE s.parsing_schema = 'SURETY';
```

**Error:** `ORA-01031: insufficient privileges`

However, the same query works when executed as `SYS`.

## Root Cause

This is **expected behavior** by Oracle ORDS design. The `ORDS_METADATA` schema contains internal metadata tables that are not directly accessible to regular users. Instead, Oracle provides a set of **public synonym views** that allow users to query their own ORDS objects safely.

### ORDS Privilege Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ORDS_METADATA Schema                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  ords_modules   │  │  ords_schemas   │  │  ords_templates │  │
│  │  (Internal)     │  │  (Internal)     │  │  (Internal)     │  │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘  │
│           │                    │                    │           │
│  ┌────────▼────────────────────▼────────────────────▼────────┐  │
│  │              USER_ORDS_* Views (Filtered by Schema)       │  │
│  │  - USER_ORDS_MODULES                                      │  │
│  │  - USER_ORDS_TEMPLATES                                    │  │
│  │  - USER_ORDS_HANDLERS                                     │  │
│  │  - USER_ORDS_PARAMETERS                                   │  │
│  │  - USER_ORDS_PRIVILEGES                                   │  │
│  └────────┬─────────────────────────────────────────────────┘  │
└───────────┼─────────────────────────────────────────────────────┘
            │
            │ PUBLIC SYNONYMS
            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     User Schema (SURETY)                        │
│                                                                 │
│   Can access: USER_ORDS_MODULES, USER_ORDS_TEMPLATES, etc.      │
│   Cannot access: ords_metadata.ords_modules (direct)            │
└─────────────────────────────────────────────────────────────────┘
```

## Solutions

### Solution 1: Use USER_ORDS Views (Recommended)

Oracle provides these views specifically for schema users to query their own ORDS metadata:

| View Name | Description |
|-----------|-------------|
| `USER_ORDS_MODULES` | ORDS modules defined in the current schema |
| `USER_ORDS_TEMPLATES` | URI templates within modules |
| `USER_ORDS_HANDLERS` | HTTP handlers (GET, POST, PUT, DELETE) |
| `USER_ORDS_PARAMETERS` | Handler parameters |
| `USER_ORDS_PRIVILEGES` | ORDS privileges and roles |
| `USER_ORDS_SCHEMAS` | ORDS-enabled schema information |
| `USER_ORDS_SERVICES` | AutoREST enabled objects |
| `USER_ORDS_ROLES` | ORDS roles |
| `USER_ORDS_URL_MAPPINGS` | URL mapping patterns |

**Example Query (Run as SURETY):**

```sql
-- Query modules in current schema
SELECT name, uri_prefix, status, items_per_page
FROM user_ords_modules;

-- Query templates
SELECT module_name, uri_template, priority
FROM user_ords_templates;

-- Query handlers
SELECT module_name, uri_template, method, source_type
FROM user_ords_handlers;
```

### Solution 2: Grant Direct Access (DBA Required)

If there is a legitimate business need for the `SURETY` user to query ORDS metadata across all schemas (e.g., for administration purposes), a DBA can grant explicit privileges:

```sql
-- Run as SYS or ORDS_METADATA owner
-- Grants SELECT on internal tables
GRANT SELECT ON ords_metadata.ords_modules TO surety;
GRANT SELECT ON ords_metadata.ords_schemas TO surety;
GRANT SELECT ON ords_metadata.ords_templates TO surety;
GRANT SELECT ON ords_metadata.ords_handlers TO surety;
GRANT SELECT ON ords_metadata.ords_parameters TO surety;
```

**⚠️ Warning:** Granting direct access to `ORDS_METADATA` tables:
- Exposes metadata for ALL schemas, not just SURETY
- Should only be done for administrative users
- May need to be re-applied after ORDS upgrades

### Solution 3: Create a Custom View (DBA Required)

For controlled cross-schema access, create a custom view:

```sql
-- Run as SYS
CREATE OR REPLACE VIEW surety.v_all_ords_modules AS
SELECT s.parsing_schema, m.name, m.uri_prefix, m.status, m.items_per_page
FROM ords_metadata.ords_modules m
JOIN ords_metadata.ords_schemas s ON m.schema_id = s.id
WHERE s.parsing_schema IN ('SURETY', 'OTHER_ALLOWED_SCHEMA');

GRANT SELECT ON surety.v_all_ords_modules TO surety;
```

## Verification Scripts

See the accompanying SQL scripts:
- `01_user_ords_queries.sql` - Standard queries using USER_ORDS views
- `02_dba_grants.sql` - DBA grant scripts for direct access
- `03_diagnostic_queries.sql` - Diagnostic queries to check ORDS configuration

## Best Practices

1. **Use USER_ORDS Views** - Always prefer the provided USER_ORDS views for schema-level access
2. **Minimal Privileges** - Only grant direct ORDS_METADATA access when absolutely necessary
3. **Audit Access** - If granting direct access, ensure proper auditing is in place
4. **Document Grants** - Keep track of any custom grants for ORDS upgrades

## References

- [Oracle ORDS Documentation](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/)
- [ORDS PL/SQL API](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/22.4/orddg/ORDS-reference.html)
- [ORA-01031 Error Documentation](https://docs.oracle.com/error-help/db/ora-01031/)
