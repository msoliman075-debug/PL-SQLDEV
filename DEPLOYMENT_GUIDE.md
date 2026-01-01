# Deployment and Migration Guide

## Table of Contents
1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Installation Methods](#installation-methods)
3. [Post-Installation Validation](#post-installation-validation)
4. [Rollback Procedures](#rollback-procedures)
5. [Migration from Other Systems](#migration-from-other-systems)
6. [Performance Tuning](#performance-tuning)
7. [Monitoring and Maintenance](#monitoring-and-maintenance)

---

## Pre-Deployment Checklist

### Environment Requirements

- [ ] Oracle Database 19c or higher
- [ ] Minimum 500 MB free space in target tablespace
- [ ] System privileges: CREATE TABLE, CREATE SEQUENCE, CREATE INDEX, CREATE PROCEDURE
- [ ] DBMS_OUTPUT enabled for testing
- [ ] Sufficient rollback segment space (at least 100 MB)

### Pre-Installation Tasks

```sql
-- 1. Check Oracle version
SELECT banner FROM v$version WHERE banner LIKE 'Oracle%';

-- 2. Check available tablespace
SELECT tablespace_name, 
       ROUND(SUM(bytes)/1024/1024, 2) AS free_mb
FROM   dba_free_space
WHERE  tablespace_name = 'USERS'
GROUP BY tablespace_name;

-- 3. Verify privileges
SELECT privilege 
FROM   user_sys_privs
WHERE  privilege IN ('CREATE TABLE', 'CREATE SEQUENCE', 
                     'CREATE INDEX', 'CREATE PROCEDURE');

-- 4. Check existing objects (ensure no conflicts)
SELECT object_name, object_type
FROM   user_objects
WHERE  object_name LIKE 'FND_PROFILE%'
ORDER BY object_name;
```

### Backup Strategy

```sql
-- Export existing profile data (if upgrading)
expdp username/password@database \
  schemas=YOUR_SCHEMA \
  dumpfile=fnd_profile_backup_$(date +%Y%m%d).dmp \
  logfile=fnd_profile_backup_$(date +%Y%m%d).log \
  directory=DATA_PUMP_DIR

-- Or use traditional export
exp username/password@database \
  file=fnd_profile_backup_$(date +%Y%m%d).dmp \
  log=fnd_profile_backup_$(date +%Y%m%d).log \
  owner=YOUR_SCHEMA \
  tables=FND_PROFILE_OPTIONS,FND_PROFILE_OPTION_VALUES
```

---

## Installation Methods

### Method 1: Full Installation (Recommended for New Installations)

```bash
# Connect to database
sqlplus username/password@database

# Run master installation script
SQL> @00_install_master.sql
```

This will install:
- Tables
- Sequences
- Indexes
- Package (spec and body)
- Views
- Sample data
- Run validation tests

**Expected Duration:** 2-5 minutes

### Method 2: Component-by-Component Installation

```bash
# For more control, install each component separately
sqlplus username/password@database

SQL> @01_fnd_profile_options.sql
SQL> @02_fnd_profile_option_values.sql
SQL> @03_sequences.sql
SQL> @04_indexes.sql
SQL> @05_fnd_profile_pkg_spec.sql
SQL> @06_fnd_profile_pkg_body.sql
SQL> @07_views.sql

# Optional: Load sample data
SQL> @08_sample_data_and_tests.sql
```

### Method 3: Production Installation (Without Sample Data)

```sql
-- Install core objects only
@01_fnd_profile_options.sql
@02_fnd_profile_option_values.sql
@03_sequences.sql
@04_indexes.sql
@05_fnd_profile_pkg_spec.sql
@06_fnd_profile_pkg_body.sql
@07_views.sql

-- Skip sample data and tests
-- @08_sample_data_and_tests.sql
```

### Method 4: Silent Installation (for automation)

```bash
#!/bin/bash
# deploy_fnd_profile.sh

DB_USER="your_user"
DB_PASS="your_password"
DB_CONNECT="your_database"
INSTALL_DIR="/path/to/sql/scripts"

sqlplus -S ${DB_USER}/${DB_PASS}@${DB_CONNECT} <<EOF
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

@${INSTALL_DIR}/00_install_master.sql

EXIT;
EOF

if [ $? -eq 0 ]; then
    echo "FND_PROFILE installation completed successfully"
    exit 0
else
    echo "FND_PROFILE installation failed"
    exit 1
fi
```

---

## Post-Installation Validation

### Validation Script

```sql
-- ============================================================================
-- POST-INSTALLATION VALIDATION
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200

PROMPT ========================================
PROMPT VALIDATING FND_PROFILE INSTALLATION
PROMPT ========================================

-- 1. Check tables
PROMPT
PROMPT 1. Checking Tables...
SELECT 'FND_PROFILE_OPTIONS' AS table_name,
       COUNT(*) AS row_count,
       status
FROM   user_tables t,
       (SELECT COUNT(*) AS cnt FROM fnd_profile_options) c
WHERE  t.table_name = 'FND_PROFILE_OPTIONS'
GROUP BY status
UNION ALL
SELECT 'FND_PROFILE_OPTION_VALUES' AS table_name,
       COUNT(*) AS row_count,
       status
FROM   user_tables t,
       (SELECT COUNT(*) AS cnt FROM fnd_profile_option_values) c
WHERE  t.table_name = 'FND_PROFILE_OPTION_VALUES'
GROUP BY status;

-- 2. Check sequences
PROMPT
PROMPT 2. Checking Sequences...
SELECT sequence_name, 
       last_number,
       increment_by
FROM   user_sequences
WHERE  sequence_name IN ('FND_PROFILE_OPTIONS_S', 'FND_PROFILE_OPTION_VALUES_S')
ORDER BY sequence_name;

-- 3. Check indexes
PROMPT
PROMPT 3. Checking Indexes...
SELECT index_name,
       table_name,
       status,
       num_rows
FROM   user_indexes
WHERE  table_name IN ('FND_PROFILE_OPTIONS', 'FND_PROFILE_OPTION_VALUES')
ORDER BY table_name, index_name;

-- 4. Check package
PROMPT
PROMPT 4. Checking Package...
SELECT object_name,
       object_type,
       status
FROM   user_objects
WHERE  object_name = 'FND_PROFILE'
ORDER BY object_type;

-- 5. Check views
PROMPT
PROMPT 5. Checking Views...
SELECT view_name
FROM   user_views
WHERE  view_name LIKE 'FND_PROFILE%'
ORDER BY view_name;

-- 6. Validate package compilation
PROMPT
PROMPT 6. Validating Package Compilation...
SELECT object_name,
       object_type,
       status
FROM   user_objects
WHERE  object_name = 'FND_PROFILE'
AND    status != 'VALID';

-- 7. Test basic functionality
PROMPT
PROMPT 7. Testing Basic Functionality...
DECLARE
    l_result VARCHAR2(2000);
    l_test_passed BOOLEAN := TRUE;
BEGIN
    -- Test 1: Check if profile exists
    IF NOT fnd_profile.defined('DEFAULT_DATE_FORMAT') THEN
        DBMS_OUTPUT.PUT_LINE('FAIL: Profile DEFAULT_DATE_FORMAT not found');
        l_test_passed := FALSE;
    ELSE
        DBMS_OUTPUT.PUT_LINE('PASS: Profile DEFAULT_DATE_FORMAT exists');
    END IF;
    
    -- Test 2: Get profile value
    l_result := fnd_profile.value('DEFAULT_DATE_FORMAT');
    IF l_result IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('PASS: Retrieved value: ' || l_result);
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL: Could not retrieve value');
        l_test_passed := FALSE;
    END IF;
    
    -- Test 3: Session cache
    fnd_profile.put('TEST_PROFILE', 'TEST_VALUE');
    l_result := fnd_profile.value('TEST_PROFILE');
    IF l_result = 'TEST_VALUE' THEN
        DBMS_OUTPUT.PUT_LINE('PASS: Session cache working');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL: Session cache not working');
        l_test_passed := FALSE;
    END IF;
    
    IF l_test_passed THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('ALL TESTS PASSED');
        DBMS_OUTPUT.PUT_LINE('========================================');
    ELSE
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('SOME TESTS FAILED - REVIEW INSTALLATION');
        DBMS_OUTPUT.PUT_LINE('========================================');
    END IF;
END;
/

PROMPT
PROMPT ========================================
PROMPT VALIDATION COMPLETE
PROMPT ========================================
```

---

## Rollback Procedures

### Complete Rollback Script

```sql
-- ============================================================================
-- ROLLBACK SCRIPT - Use with caution!
-- This will completely remove the FND_PROFILE system
-- ============================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ========================================
PROMPT STARTING ROLLBACK OF FND_PROFILE SYSTEM
PROMPT ========================================

-- Drop views
PROMPT Dropping views...
DROP VIEW fnd_profile_summary_v;
DROP VIEW fnd_profile_audit_v;
DROP VIEW fnd_profile_user_values_v;
DROP VIEW fnd_profile_hierarchy_v;
DROP VIEW fnd_profile_option_values_vl;
DROP VIEW fnd_profile_options_vl;

-- Drop package
PROMPT Dropping package...
DROP PACKAGE fnd_profile;

-- Drop indexes
PROMPT Dropping indexes...
DROP INDEX fnd_profile_opt_values_n6;
DROP INDEX fnd_profile_opt_values_n5;
DROP INDEX fnd_profile_opt_values_n4;
DROP INDEX fnd_profile_opt_values_n3;
DROP INDEX fnd_profile_opt_values_n2;
DROP INDEX fnd_profile_opt_values_n1;
DROP INDEX fnd_profile_options_n4;
DROP INDEX fnd_profile_options_n3;
DROP INDEX fnd_profile_options_n2;
DROP INDEX fnd_profile_options_n1;

-- Drop tables (cascades foreign keys)
PROMPT Dropping tables...
DROP TABLE fnd_profile_option_values CASCADE CONSTRAINTS;
DROP TABLE fnd_profile_options CASCADE CONSTRAINTS;

-- Drop sequences
PROMPT Dropping sequences...
DROP SEQUENCE fnd_profile_option_values_s;
DROP SEQUENCE fnd_profile_options_s;

PROMPT ========================================
PROMPT ROLLBACK COMPLETE
PROMPT ========================================

-- Verify cleanup
SELECT object_name, object_type
FROM   user_objects
WHERE  object_name LIKE 'FND_PROFILE%'
ORDER BY object_name;
```

### Partial Rollback (Keep Data)

```sql
-- Keep tables and data, but remove package and views
DROP VIEW fnd_profile_summary_v;
DROP VIEW fnd_profile_audit_v;
DROP VIEW fnd_profile_user_values_v;
DROP VIEW fnd_profile_hierarchy_v;
DROP VIEW fnd_profile_option_values_vl;
DROP VIEW fnd_profile_options_vl;
DROP PACKAGE fnd_profile;

-- Reinstall package and views
@05_fnd_profile_pkg_spec.sql
@06_fnd_profile_pkg_body.sql
@07_views.sql
```

---

## Migration from Other Systems

### Migration from Flat Configuration Tables

```sql
-- Example: Migrating from a simple config table
-- Assumes you have: CONFIG_TABLE(config_name, config_value, user_id)

-- Step 1: Create mapping of old config names to new profile names
CREATE TABLE config_profile_mapping (
    old_config_name VARCHAR2(100),
    new_profile_name VARCHAR2(240),
    profile_description VARCHAR2(2000)
);

-- Step 2: Insert mappings
INSERT INTO config_profile_mapping VALUES 
    ('date_fmt', 'DEFAULT_DATE_FORMAT', 'User date format preference');
INSERT INTO config_profile_mapping VALUES 
    ('page_size', 'ROWS_PER_PAGE', 'Number of rows per page');
-- Add more mappings...

COMMIT;

-- Step 3: Create profile options
INSERT INTO fnd_profile_options (
    profile_option_id,
    profile_option_name,
    user_profile_option_name,
    description,
    enabled_flag,
    start_date_active,
    user_changeable_flag,
    user_visible_flag,
    read_only_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
)
SELECT fnd_profile_options_s.NEXTVAL,
       m.new_profile_name,
       m.new_profile_name,
       m.profile_description,
       'Y',
       SYSDATE,
       'Y',
       'Y',
       'N',
       SYSDATE,
       0,
       SYSDATE,
       0
FROM   config_profile_mapping m;

COMMIT;

-- Step 4: Migrate user values
INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    level_value,
    profile_option_value,
    enabled_flag,
    start_date_active,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
)
SELECT fnd_profile_option_values_s.NEXTVAL,
       po.profile_option_id,
       10004,  -- User level
       c.user_id,
       c.config_value,
       'Y',
       SYSDATE,
       SYSDATE,
       c.user_id,
       SYSDATE,
       c.user_id
FROM   config_table c,
       config_profile_mapping m,
       fnd_profile_options po
WHERE  c.config_name = m.old_config_name
AND    m.new_profile_name = po.profile_option_name
AND    c.user_id IS NOT NULL;

COMMIT;

-- Step 5: Migrate site defaults
INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    profile_option_value,
    enabled_flag,
    start_date_active,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
)
SELECT fnd_profile_option_values_s.NEXTVAL,
       po.profile_option_id,
       10001,  -- Site level
       c.config_value,
       'Y',
       SYSDATE,
       SYSDATE,
       0,
       SYSDATE,
       0
FROM   config_table c,
       config_profile_mapping m,
       fnd_profile_options po
WHERE  c.config_name = m.old_config_name
AND    m.new_profile_name = po.profile_option_name
AND    c.user_id IS NULL;

COMMIT;

-- Step 6: Validation
SELECT po.profile_option_name,
       COUNT(*) AS value_count
FROM   fnd_profile_options po,
       fnd_profile_option_values pov
WHERE  po.profile_option_id = pov.profile_option_id
GROUP BY po.profile_option_name
ORDER BY po.profile_option_name;
```

---

## Performance Tuning

### Gather Statistics

```sql
-- Gather table statistics after initial load
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => USER,
        tabname => 'FND_PROFILE_OPTIONS',
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        method_opt => 'FOR ALL COLUMNS SIZE AUTO',
        cascade => TRUE
    );
    
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => USER,
        tabname => 'FND_PROFILE_OPTION_VALUES',
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        method_opt => 'FOR ALL COLUMNS SIZE AUTO',
        cascade => TRUE
    );
END;
/
```

### Enable Query Result Cache (Oracle 11g+)

```sql
-- Enable result cache for VALUE function
CREATE OR REPLACE FUNCTION fnd_profile.value(...) 
    RETURN VARCHAR2 
    RESULT_CACHE
IS
...
```

### Partitioning for Large Installations

```sql
-- For installations with millions of profile values
ALTER TABLE fnd_profile_option_values
MODIFY PARTITION BY LIST (level_id)
(
    PARTITION p_site VALUES (10001) TABLESPACE users,
    PARTITION p_application VALUES (10002) TABLESPACE users,
    PARTITION p_responsibility VALUES (10003) TABLESPACE users,
    PARTITION p_user VALUES (10004) TABLESPACE large_data,
    PARTITION p_server VALUES (10005) TABLESPACE users,
    PARTITION p_org VALUES (10006) TABLESPACE users
);

-- Rebuild indexes locally
ALTER INDEX fnd_profile_opt_values_n3 REBUILD LOCAL;
```

---

## Monitoring and Maintenance

### Health Check Script

```sql
-- Run weekly to monitor system health
SELECT 'Profile Options' AS metric,
       COUNT(*) AS count
FROM   fnd_profile_options
WHERE  enabled_flag = 'Y'
UNION ALL
SELECT 'Profile Values',
       COUNT(*)
FROM   fnd_profile_option_values
WHERE  enabled_flag = 'Y'
UNION ALL
SELECT 'User-Level Values',
       COUNT(*)
FROM   fnd_profile_option_values
WHERE  enabled_flag = 'Y'
AND    level_id = 10004
UNION ALL
SELECT 'Expired Options',
       COUNT(*)
FROM   fnd_profile_options
WHERE  enabled_flag = 'Y'
AND    end_date_active < SYSDATE
UNION ALL
SELECT 'Invalid Objects',
       COUNT(*)
FROM   user_objects
WHERE  object_name = 'FND_PROFILE'
AND    status != 'VALID';
```

### Maintenance Schedule

**Daily:**
- Monitor growth of fnd_profile_option_values table
- Check for invalid objects

**Weekly:**
- Gather statistics on tables
- Review slow queries in AWR/ADDM

**Monthly:**
- Archive expired profile values
- Analyze space usage
- Review and optimize indexes

**Quarterly:**
- Full backup of profile data
- Review and clean up obsolete profiles
- Performance tuning review

---

## Troubleshooting Common Issues

### Issue 1: Package Compilation Errors

```sql
-- Show compilation errors
SELECT * FROM user_errors
WHERE name = 'FND_PROFILE'
ORDER BY sequence;

-- Recompile
ALTER PACKAGE fnd_profile COMPILE;
ALTER PACKAGE fnd_profile COMPILE BODY;
```

### Issue 2: Slow Performance

```sql
-- Check missing indexes
SELECT table_name
FROM   user_tables
WHERE  table_name IN ('FND_PROFILE_OPTIONS', 'FND_PROFILE_OPTION_VALUES')
MINUS
SELECT table_name
FROM   user_indexes
WHERE  table_name IN ('FND_PROFILE_OPTIONS', 'FND_PROFILE_OPTION_VALUES');

-- Rebuild fragmented indexes
ALTER INDEX fnd_profile_opt_values_n3 REBUILD ONLINE;
```

### Issue 3: Table Space Issues

```sql
-- Monitor table growth
SELECT segment_name,
       ROUND(bytes/1024/1024, 2) AS size_mb
FROM   user_segments
WHERE  segment_name IN ('FND_PROFILE_OPTIONS', 'FND_PROFILE_OPTION_VALUES')
ORDER BY bytes DESC;

-- Move to larger tablespace if needed
ALTER TABLE fnd_profile_option_values MOVE TABLESPACE large_data;
```

---

## Support and Documentation

For issues during deployment:
1. Check the validation script output
2. Review error logs in ${ORACLE_BASE}/diag
3. Consult the README.md for usage examples
4. Review ERD_AND_ARCHITECTURE.md for design details

---

**End of Deployment Guide**
