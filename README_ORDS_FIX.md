# ORDS URL Mapping Error Fix (ORA-20049)

## Problem Description

When attempting to alter ORDS URL mappings while a schema is enabled, Oracle raises:

```
ORA-20049: Cannot alter the url mapping while the schema is enabled. 
Try disabling the schema first.
```

This error occurs in the ORDS_METADATA.ORDS package and prevents modifications to URL patterns, base paths, or module configurations while the schema is actively serving REST endpoints.

## Root Cause

ORDS enforces a safety mechanism that prevents URL mapping changes on enabled schemas to avoid:
- Runtime conflicts with active REST endpoints
- Potential security vulnerabilities from live configuration changes
- Inconsistent routing during modifications

## Solution

The fix requires three steps:
1. **Disable** the ORDS schema
2. **Modify** the URL mappings
3. **Re-enable** the schema with updated configuration

## Scripts Provided

### 1. `fix_ords_url_mapping.sql` (Comprehensive Solution)
A complete script that handles the entire process with proper error handling and rollback capabilities.

**Features:**
- Checks current schema status
- Automatically disables schema if enabled
- Provides template for URL mapping updates
- Re-enables schema with new configuration
- Includes comprehensive exception handling
- Maintains transaction integrity

**Usage:**
```sql
-- Edit the script to set your values:
-- v_schema_name: Your schema name (e.g., 'HR', 'MYAPP')
-- v_base_path: Your desired base path (e.g., '/api/v2/')
-- v_module_name: Your module name if updating specific module

@fix_ords_url_mapping.sql
```

### 2. `quick_disable_enable_ords.sql` (Quick Disable)
Simple script to quickly disable a schema for manual changes.

**Usage:**
```sql
@quick_disable_enable_ords.sql
-- When prompted, enter your schema name
-- Make your manual changes
-- Run reenable_ords_schema.sql when done
```

### 3. `reenable_ords_schema.sql` (Re-enable Schema)
Re-enables a disabled schema after changes are complete.

**Usage:**
```sql
@reenable_ords_schema.sql
-- When prompted, enter schema name and base path
```

### 4. `ords_diagnostic.sql` (Diagnostic Tool)
Provides detailed information about your ORDS configuration.

**Usage:**
```sql
@ords_diagnostic.sql
```

**Output includes:**
- All enabled/disabled schemas
- Module configurations and base paths
- URL templates and patterns
- Privilege assignments
- Summary statistics

## Manual Step-by-Step Process

If you prefer to execute commands manually:

### Step 1: Check Current Status
```sql
SELECT schema_name, is_enabled 
FROM ORDS_METADATA.ORDS_SCHEMAS 
WHERE schema_name = 'YOUR_SCHEMA';
```

### Step 2: Disable the Schema
```sql
BEGIN
    ORDS.DISABLE_SCHEMA(
        p_schema => 'YOUR_SCHEMA'
    );
    COMMIT;
END;
/
```

### Step 3: Make Your URL Mapping Changes
Example - Update module base path:
```sql
BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'your_module',
        p_base_path      => '/api/v2/',
        p_items_per_page => 25,
        p_status         => 'PUBLISHED'
    );
    COMMIT;
END;
/
```

Or update template:
```sql
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'your_module',
        p_pattern     => 'employees/:id'
    );
    COMMIT;
END;
/
```

### Step 4: Re-enable the Schema
```sql
BEGIN
    ORDS.ENABLE_SCHEMA(
        p_schema              => 'YOUR_SCHEMA',
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => '/api/v2/',
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
END;
/
```

### Step 5: Verify
```sql
SELECT schema_name, is_enabled, parsing_schema
FROM ORDS_METADATA.ORDS_SCHEMAS
WHERE schema_name = 'YOUR_SCHEMA';
```

## Important Considerations

### Transaction Management
- Always COMMIT after successful operations
- ROLLBACK if any step fails
- The provided scripts handle this automatically

### Impact on Active Sessions
- Disabling a schema immediately stops all REST endpoints
- Active API requests will receive 404 errors
- Plan changes during maintenance windows

### Security
- Requires appropriate ORDS privileges
- Execute as ORDS_METADATA owner or privileged user
- Never expose credentials in scripts

### Performance Impact
- Disable/enable operations are fast (milliseconds)
- No impact on other schemas
- Metadata changes don't require ORDS restart

## Common URL Mapping Operations

### Change Base Path
```sql
-- After disabling schema
ORDS.ENABLE_SCHEMA(
    p_schema              => 'MYSCHEMA',
    p_url_mapping_type    => 'BASE_PATH',
    p_url_mapping_pattern => '/new/path/',  -- Changed
    p_auto_rest_auth      => FALSE
);
```

### Update Module Routing
```sql
ORDS.DEFINE_MODULE(
    p_module_name => 'employees_api',
    p_base_path   => '/hr/v2/employees/',  -- Changed
    p_status      => 'PUBLISHED'
);
```

### Modify Template Pattern
```sql
ORDS.DEFINE_TEMPLATE(
    p_module_name => 'employees_api',
    p_pattern     => 'details/:emp_id'  -- Changed from 'info/:id'
);
```

## Troubleshooting

### Error: "Schema not found"
- Verify schema name is uppercase
- Check schema exists: `SELECT * FROM ORDS_METADATA.ORDS_SCHEMAS;`

### Error: "Insufficient privileges"
- Grant required privileges: `GRANT EXECUTE ON ORDS_METADATA.ORDS TO your_user;`
- Or connect as ORDS_METADATA schema owner

### Schema Won't Re-enable
- Check for invalid base path (must start with /)
- Verify no conflicting URL patterns
- Check ORDS error logs

### Changes Not Taking Effect
- Ensure COMMIT was executed
- Verify ORDS is running
- Check for cached routing (restart ORDS if needed)

## Best Practices

1. **Backup Configuration**: Export current ORDS metadata before changes
2. **Test in Development**: Validate URL changes in dev environment first
3. **Documentation**: Keep record of base paths and module configurations
4. **Maintenance Window**: Schedule changes during low-traffic periods
5. **Monitoring**: Watch logs after re-enabling to catch routing issues

## Oracle Documentation References

- [ORA-20049 Documentation](https://docs.oracle.com/error-help/db/ora-20049/)
- [ORDS PL/SQL API Reference](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/)
- Oracle REST Data Services Installation and Configuration Guide

## Target Environment

- **Oracle Database**: 19c or later
- **ORDS Version**: 19.x or later
- **Oracle APEX**: Compatible with all versions

## Author Notes

These scripts follow Oracle PL/SQL best practices:
- Proper BEGIN/END structure
- Comprehensive exception handling
- Explicit transaction management
- No non-Oracle syntax dependencies
- Production-ready error handling

---

**Last Updated**: January 2026  
**Compatibility**: Oracle Database 19c+, ORDS 19.x+
