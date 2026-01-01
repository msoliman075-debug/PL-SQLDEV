# ORDS ORA-20049 Quick Reference Guide

## Error Summary
```
ORA-20049: Cannot alter the url mapping while the schema is enabled.
Try disabling the schema first.
```

## Quick Fix (3 Commands)

```sql
-- 1. Disable schema
BEGIN
    ORDS.DISABLE_SCHEMA(p_schema => 'YOUR_SCHEMA');
    COMMIT;
END;
/

-- 2. Make your changes
BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name => 'your_module',
        p_base_path   => '/new/path/'
    );
    COMMIT;
END;
/

-- 3. Re-enable schema
BEGIN
    ORDS.ENABLE_SCHEMA(
        p_schema              => 'YOUR_SCHEMA',
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => '/new/path/',
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
END;
/
```

## Available Scripts

| Script | Purpose | Use When |
|--------|---------|----------|
| `fix_ords_url_mapping.sql` | Complete automated solution | First-time fix or production changes |
| `quick_disable_enable_ords.sql` | Fast disable | Need to quickly disable for manual work |
| `reenable_ords_schema.sql` | Re-enable after changes | After manual modifications |
| `ords_diagnostic.sql` | View configuration | Investigating current setup |
| `backup_ords_config.sql` | Create backup | Before any changes |
| `example_complete_workflow.sql` | Full example with comments | Learning the process |

## Script Execution Order

### Recommended Workflow
```bash
# 1. Check current state
@ords_diagnostic.sql

# 2. Create backup
@backup_ords_config.sql

# 3. Run complete fix
@fix_ords_url_mapping.sql
```

### Manual Workflow
```bash
# 1. Disable
@quick_disable_enable_ords.sql

# 2. Make your manual changes in SQL
# (your custom ORDS.DEFINE_MODULE, etc.)

# 3. Re-enable
@reenable_ords_schema.sql

# 4. Verify
@ords_diagnostic.sql
```

## Common Scenarios

### Scenario 1: Change Base Path
```sql
-- Disable first
EXEC ORDS.DISABLE_SCHEMA('MYSCHEMA');

-- Then re-enable with new path
BEGIN
    ORDS.ENABLE_SCHEMA(
        p_schema              => 'MYSCHEMA',
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => '/api/v2/',  -- NEW PATH
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
END;
/
```

### Scenario 2: Update Module
```sql
-- Disable schema
EXEC ORDS.DISABLE_SCHEMA('MYSCHEMA');

-- Update module
BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name => 'employees_api',
        p_base_path   => '/hr/employees/',  -- NEW PATH
        p_status      => 'PUBLISHED'
    );
    COMMIT;
END;
/

-- Re-enable schema
EXEC ORDS.ENABLE_SCHEMA(p_schema => 'MYSCHEMA');
```

### Scenario 3: Add New Template
```sql
-- Disable schema
EXEC ORDS.DISABLE_SCHEMA('MYSCHEMA');

-- Add template
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'employees_api',
        p_pattern     => 'details/:emp_id'  -- NEW PATTERN
    );
    COMMIT;
END;
/

-- Re-enable schema
EXEC ORDS.ENABLE_SCHEMA(p_schema => 'MYSCHEMA');
```

## Verification Queries

### Check Schema Status
```sql
SELECT schema_name, is_enabled 
FROM ORDS_METADATA.ORDS_SCHEMAS 
WHERE schema_name = 'YOUR_SCHEMA';
```

### Check Module Configuration
```sql
SELECT m.name, m.base_path, m.status
FROM ORDS_METADATA.ORDS_MODULES m
JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
WHERE s.schema_name = 'YOUR_SCHEMA';
```

### Check All URL Patterns
```sql
SELECT 
    s.schema_name,
    m.name as module,
    m.base_path,
    t.uri_template
FROM ORDS_METADATA.ORDS_TEMPLATES t
JOIN ORDS_METADATA.ORDS_MODULES m ON t.module_id = m.id
JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
WHERE s.schema_name = 'YOUR_SCHEMA'
ORDER BY m.name, t.uri_template;
```

## Troubleshooting

### Problem: "Schema not found"
**Solution:** Use uppercase schema name
```sql
-- Wrong
ORDS.DISABLE_SCHEMA(p_schema => 'myschema');

-- Correct
ORDS.DISABLE_SCHEMA(p_schema => 'MYSCHEMA');
```

### Problem: "Insufficient privileges"
**Solution:** Grant ORDS execution privilege
```sql
-- As privileged user
GRANT EXECUTE ON ORDS_METADATA.ORDS TO your_user;
```

### Problem: Changes not taking effect
**Solution:** Verify commit and ORDS service
```sql
-- Always commit
COMMIT;

-- Check if ORDS service needs restart (rarely needed)
-- Restart ORDS standalone or application server
```

### Problem: Can't re-enable schema
**Solution:** Check for invalid base path
```sql
-- Base path must start with /
-- Wrong
p_url_mapping_pattern => 'api/v2'

-- Correct
p_url_mapping_pattern => '/api/v2/'
```

## Best Practices Checklist

- [ ] Backup configuration before changes
- [ ] Test changes in development environment first
- [ ] Schedule changes during maintenance window
- [ ] Use uppercase for schema names
- [ ] Always COMMIT after successful operations
- [ ] Verify schema status after re-enabling
- [ ] Test REST endpoints after changes
- [ ] Document base paths and module names
- [ ] Keep rollback script ready
- [ ] Monitor ORDS logs after changes

## Emergency Rollback

If something goes wrong:

```sql
-- 1. Check backup file
-- Run the backup script created earlier
@ords_backup_YOUR_SCHEMA.sql

-- 2. Or manually disable problematic schema
BEGIN
    ORDS.DISABLE_SCHEMA(p_schema => 'YOUR_SCHEMA');
    COMMIT;
END;
/

-- 3. Contact DBA if issues persist
```

## Key ORDS Procedures

| Procedure | Purpose |
|-----------|---------|
| `ORDS.ENABLE_SCHEMA` | Enable REST services for a schema |
| `ORDS.DISABLE_SCHEMA` | Disable REST services for a schema |
| `ORDS.DEFINE_MODULE` | Create/update module (collection of templates) |
| `ORDS.DEFINE_TEMPLATE` | Create/update URL template pattern |
| `ORDS.DEFINE_HANDLER` | Create/update HTTP handler (GET/POST/etc.) |
| `ORDS.DELETE_MODULE` | Remove module and all templates |
| `ORDS.DELETE_SCHEMA` | Remove schema from ORDS |

## Support Resources

- Oracle Documentation: https://docs.oracle.com/error-help/db/ora-20049/
- ORDS User Guide: https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/
- Oracle APEX Community: https://apex.oracle.com/community

## Notes

- **Impact**: Disabling schema stops all REST endpoints immediately
- **Duration**: Disable/enable operations are typically < 1 second
- **Scope**: Changes only affect the specified schema
- **Persistence**: Configuration changes are stored in ORDS_METADATA tables
- **Restart**: ORDS service restart NOT required for configuration changes

---
**Version**: 1.0  
**Last Updated**: January 2026  
**Oracle Version**: 19c+  
**ORDS Version**: 19.x+
