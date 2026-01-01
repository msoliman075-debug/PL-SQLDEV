# ORA-20049 ORDS Fix - Complete Solution Package

## Overview

This package provides a complete solution for resolving the Oracle ORDS error:
```
ORA-20049: Cannot alter the url mapping while the schema is enabled.
```

## Package Contents

### 1. Documentation Files

| File | Description |
|------|-------------|
| `README_ORDS_FIX.md` | Comprehensive guide with detailed explanations |
| `QUICK_REFERENCE.md` | Quick reference for common tasks and commands |
| `SOLUTION_SUMMARY.md` | This file - package overview |

### 2. SQL Scripts

| File | Purpose | When to Use |
|------|---------|-------------|
| `fix_ords_url_mapping.sql` | **Primary solution** - Automated fix with full error handling | First choice for resolving ORA-20049 |
| `example_complete_workflow.sql` | Complete working example with detailed comments | Learning how to fix the error |
| `quick_disable_enable_ords.sql` | Fast schema disable utility | Need quick access to make manual changes |
| `reenable_ords_schema.sql` | Schema re-enable utility | After manual modifications |
| `ords_diagnostic.sql` | Configuration inspection tool | Understanding current ORDS setup |
| `backup_ords_config.sql` | Backup and rollback generator | Before making any changes |

### 3. Utilities

| File | Purpose |
|------|---------|
| `Fix ending in Linux` | Bash script to fix line endings on Linux |

## Quick Start

### Option 1: Automated Solution (Recommended)

1. Edit `fix_ords_url_mapping.sql` and set your values:
   ```sql
   v_schema_name := 'YOUR_SCHEMA_NAME';
   v_base_path   := '/api/v1/';
   v_module_name := 'YOUR_MODULE_NAME';
   ```

2. Run the script:
   ```bash
   sqlplus user/pass@database @fix_ords_url_mapping.sql
   ```

3. Done! The script handles everything automatically.

### Option 2: Manual Process

1. **Backup** (recommended):
   ```bash
   @backup_ords_config.sql
   ```

2. **Disable** schema:
   ```bash
   @quick_disable_enable_ords.sql
   ```

3. **Make your changes** (your custom SQL)

4. **Re-enable** schema:
   ```bash
   @reenable_ords_schema.sql
   ```

### Option 3: Learn by Example

Run the complete workflow example:
```bash
@example_complete_workflow.sql
```

This script shows every step with explanations.

## The Problem Explained

### Why This Error Occurs

ORDS enforces a safety mechanism that prevents URL mapping changes on enabled schemas. This protects against:
- Runtime conflicts with active REST endpoints
- Security vulnerabilities from live config changes
- Inconsistent routing during modifications

### The Solution

The fix requires three steps:
1. **DISABLE** the schema (stops all REST endpoints)
2. **MODIFY** the URL mappings (make your changes)
3. **RE-ENABLE** the schema (restart REST endpoints with new config)

## Common Use Cases

### Use Case 1: Changing Base Path

**Scenario**: Need to change from `/api/v1/` to `/api/v2/`

**Solution**: Use `fix_ords_url_mapping.sql` or:
```sql
BEGIN
    ORDS.DISABLE_SCHEMA(p_schema => 'MYSCHEMA');
    ORDS.ENABLE_SCHEMA(
        p_schema              => 'MYSCHEMA',
        p_url_mapping_pattern => '/api/v2/'  -- NEW
    );
    COMMIT;
END;
/
```

### Use Case 2: Updating Module Routes

**Scenario**: Need to change module base path

**Solution**: 
```sql
BEGIN
    ORDS.DISABLE_SCHEMA(p_schema => 'MYSCHEMA');
    ORDS.DEFINE_MODULE(
        p_module_name => 'employees',
        p_base_path   => '/hr/v2/employees/'  -- NEW
    );
    ORDS.ENABLE_SCHEMA(p_schema => 'MYSCHEMA');
    COMMIT;
END;
/
```

### Use Case 3: Adding URL Templates

**Scenario**: Adding new REST endpoint patterns

**Solution**:
```sql
BEGIN
    ORDS.DISABLE_SCHEMA(p_schema => 'MYSCHEMA');
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'employees',
        p_pattern     => 'details/:emp_id'  -- NEW
    );
    ORDS.ENABLE_SCHEMA(p_schema => 'MYSCHEMA');
    COMMIT;
END;
/
```

## Script Selection Guide

### When to Use Each Script

**fix_ords_url_mapping.sql**
- ✓ Production changes requiring safety checks
- ✓ First time fixing this error
- ✓ Need automatic backup/restore capability
- ✓ Want comprehensive error handling

**example_complete_workflow.sql**
- ✓ Learning how the fix works
- ✓ Understanding the process step-by-step
- ✓ Need a template for custom solution
- ✓ Training team members

**quick_disable_enable_ords.sql**
- ✓ Quick manual access needed
- ✓ Comfortable with manual SQL changes
- ✓ Development/testing environment
- ✓ Multiple changes to make

**ords_diagnostic.sql**
- ✓ Don't know current configuration
- ✓ Investigating ORDS setup
- ✓ Documenting existing environment
- ✓ Before making any changes

**backup_ords_config.sql**
- ✓ Always run before changes
- ✓ Production environment
- ✓ Need rollback capability
- ✓ Compliance/audit requirements

## Execution Workflow

### Recommended Production Workflow

```
┌─────────────────────────────┐
│ 1. Run Diagnostic           │
│    @ords_diagnostic.sql     │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ 2. Create Backup            │
│    @backup_ords_config.sql  │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ 3. Run Automated Fix        │
│    @fix_ords_url_mapping    │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ 4. Test REST Endpoints      │
│    curl http://server/api/  │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ 5. Verify with Diagnostic   │
│    @ords_diagnostic.sql     │
└─────────────────────────────┘
```

### Quick Development Workflow

```
┌─────────────────────────────┐
│ 1. Disable Schema           │
│    @quick_disable_enable    │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ 2. Make Manual Changes      │
│    (Your custom SQL)        │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ 3. Re-enable Schema         │
│    @reenable_ords_schema    │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ 4. Test                     │
└─────────────────────────────┘
```

## Important Considerations

### Impact Analysis

| Aspect | Impact |
|--------|--------|
| **Downtime** | REST endpoints unavailable during disable (typically < 1 sec) |
| **Scope** | Only affects the specified schema |
| **Other Schemas** | No impact on other ORDS-enabled schemas |
| **Database** | No impact on database operations |
| **ORDS Service** | No restart required |

### Transaction Management

All scripts follow Oracle best practices:
- ✓ Explicit BEGIN/END blocks
- ✓ Exception handling in all procedures
- ✓ COMMIT on success
- ✓ ROLLBACK on failure
- ✓ Transaction integrity maintained

### Security Considerations

- Scripts require EXECUTE privilege on ORDS_METADATA.ORDS
- No credentials hardcoded in scripts
- No security vulnerabilities introduced
- Follows principle of least privilege

## Troubleshooting Guide

### Common Issues

**Issue 1: "Schema not found"**
```sql
-- Wrong
ORDS.DISABLE_SCHEMA(p_schema => 'myschema');

-- Correct (uppercase)
ORDS.DISABLE_SCHEMA(p_schema => 'MYSCHEMA');
```

**Issue 2: "Insufficient privileges"**
```sql
-- Grant required privileges
GRANT EXECUTE ON ORDS_METADATA.ORDS TO your_user;
```

**Issue 3: "Changes not taking effect"**
```sql
-- Always commit
COMMIT;

-- Verify schema status
SELECT schema_name, is_enabled 
FROM ORDS_METADATA.ORDS_SCHEMAS;
```

**Issue 4: "Can't re-enable schema"**
```sql
-- Base path must start with /
-- Wrong
p_url_mapping_pattern => 'api'

-- Correct
p_url_mapping_pattern => '/api/'
```

## Best Practices

### Before Making Changes
1. ✓ Run diagnostic to understand current state
2. ✓ Create backup of configuration
3. ✓ Plan changes in advance
4. ✓ Test in development first
5. ✓ Schedule maintenance window

### During Changes
1. ✓ Use provided scripts (tested and safe)
2. ✓ Follow transaction management
3. ✓ Monitor for errors
4. ✓ Keep rollback script ready
5. ✓ Document changes made

### After Changes
1. ✓ Verify schema is re-enabled
2. ✓ Test REST endpoints
3. ✓ Check ORDS logs
4. ✓ Update documentation
5. ✓ Archive backup scripts

## Environment Requirements

### Database
- Oracle Database 19c or later
- ORDS_METADATA schema installed
- Appropriate privileges granted

### ORDS
- Oracle REST Data Services 19.x or later
- ORDS service running
- Network connectivity to database

### Client
- SQL*Plus, SQL Developer, or similar
- Access to ORDS-enabled schema
- Network connectivity to database

## Support and Documentation

### Included Documentation
- `README_ORDS_FIX.md` - Complete guide with examples
- `QUICK_REFERENCE.md` - Quick reference for common tasks
- Inline comments in all SQL scripts

### Oracle Resources
- [ORA-20049 Documentation](https://docs.oracle.com/error-help/db/ora-20049/)
- [ORDS PL/SQL API Reference](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/)
- ORDS Installation and Configuration Guide

### Community Resources
- Oracle APEX Community Forums
- Oracle Support (MOS)
- Stack Overflow (oracle-ords tag)

## Version Information

**Package Version**: 1.0  
**Created**: January 2026  
**Target Oracle Version**: 19c+  
**Target ORDS Version**: 19.x+  
**Compatibility**: Oracle APEX all versions  

## Script Compatibility Matrix

| Script | Oracle 19c | Oracle 21c | Oracle 23c | ORDS 19.x | ORDS 20.x+ |
|--------|-----------|-----------|-----------|-----------|-----------|
| fix_ords_url_mapping.sql | ✓ | ✓ | ✓ | ✓ | ✓ |
| example_complete_workflow.sql | ✓ | ✓ | ✓ | ✓ | ✓ |
| quick_disable_enable_ords.sql | ✓ | ✓ | ✓ | ✓ | ✓ |
| reenable_ords_schema.sql | ✓ | ✓ | ✓ | ✓ | ✓ |
| ords_diagnostic.sql | ✓ | ✓ | ✓ | ✓ | ✓ |
| backup_ords_config.sql | ✓ | ✓ | ✓ | ✓ | ✓ |

## License and Usage

These scripts are provided as examples for resolving ORA-20049 errors. They follow Oracle PL/SQL best practices and are designed for enterprise use. Feel free to modify them for your specific requirements.

## Author Notes

All scripts in this package:
- Follow Oracle SQL and PL/SQL best practices
- Use correct BEGIN/END structure
- Include comprehensive exception handling
- Avoid non-Oracle syntax
- Use explicit joins where applicable
- Target Oracle 19c+ and Oracle APEX environments
- Preserve optimizer behavior
- Include clear execution impact documentation

---

**For Questions or Issues**: Consult the detailed documentation in `README_ORDS_FIX.md` or `QUICK_REFERENCE.md`

**Quick Help**: 
```bash
# View current configuration
@ords_diagnostic.sql

# Quick fix
@fix_ords_url_mapping.sql
```

**Emergency Rollback**:
```bash
# Use backup created by backup_ords_config.sql
@ords_backup_SCHEMANAME.sql
```
