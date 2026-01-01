-- ============================================================================
-- ORDS Configuration Backup Utility
-- ============================================================================
-- Creates a backup of ORDS configuration before making changes
-- Generates rollback script for easy restoration
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TRIMOUT ON
SET TRIMSPOOL ON

ACCEPT schema_name CHAR PROMPT 'Enter schema name to backup: '
ACCEPT backup_file CHAR DEFAULT 'ords_backup_rollback.sql' PROMPT 'Enter backup filename (default: ords_backup_rollback.sql): '

SPOOL &backup_file

SELECT '-- ============================================================================' FROM DUAL;
SELECT '-- ORDS Configuration Backup and Rollback Script' FROM DUAL;
SELECT '-- Generated: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
SELECT '-- Schema: ' || UPPER('&schema_name') FROM DUAL;
SELECT '-- ============================================================================' FROM DUAL;
SELECT '' FROM DUAL;
SELECT 'SET SERVEROUTPUT ON' FROM DUAL;
SELECT 'SET VERIFY OFF' FROM DUAL;
SELECT '' FROM DUAL;

-- Backup schema status
SELECT '-- Current Schema Status' FROM DUAL;
SELECT 'PROMPT Restoring schema status...' FROM DUAL;
SELECT 'BEGIN' FROM DUAL;
SELECT CASE 
    WHEN is_enabled = 'Y' THEN 
        '    -- Schema was ENABLED with the following configuration:' || CHR(10) ||
        '    ORDS.ENABLE_SCHEMA(' || CHR(10) ||
        '        p_schema => ''' || schema_name || ''',' || CHR(10) ||
        '        p_url_mapping_type => ''BASE_PATH'',' || CHR(10) ||
        '        p_auto_rest_auth => FALSE' || CHR(10) ||
        '    );'
    ELSE
        '    -- Schema was DISABLED' || CHR(10) ||
        '    ORDS.DISABLE_SCHEMA(p_schema => ''' || schema_name || ''');'
END || CHR(10) ||
'    COMMIT;' || CHR(10) ||
'    DBMS_OUTPUT.PUT_LINE(''Schema status restored'');' || CHR(10) ||
'END;' || CHR(10) ||
'/'
FROM ORDS_METADATA.ORDS_SCHEMAS
WHERE schema_name = UPPER('&schema_name');

SELECT '' FROM DUAL;
SELECT '-- Modules Configuration Backup' FROM DUAL;

SELECT '/*' || CHR(10) ||
'Module: ' || m.name || CHR(10) ||
'Base Path: ' || m.base_path || CHR(10) ||
'Status: ' || m.status || CHR(10) ||
'Items Per Page: ' || m.items_per_page || CHR(10) ||
'*/' || CHR(10) ||
'BEGIN' || CHR(10) ||
'    ORDS.DEFINE_MODULE(' || CHR(10) ||
'        p_module_name => ''' || m.name || ''',' || CHR(10) ||
'        p_base_path => ''' || m.base_path || ''',' || CHR(10) ||
'        p_items_per_page => ' || m.items_per_page || ',' || CHR(10) ||
'        p_status => ''' || m.status || ''',' || CHR(10) ||
'        p_comments => ''Restored from backup''' || CHR(10) ||
'    );' || CHR(10) ||
'    COMMIT;' || CHR(10) ||
'END;' || CHR(10) ||
'/' || CHR(10)
FROM ORDS_METADATA.ORDS_MODULES m
JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
WHERE s.schema_name = UPPER('&schema_name')
ORDER BY m.name;

SELECT '' FROM DUAL;
SELECT '-- Backup Complete' FROM DUAL;
SELECT 'PROMPT ========================================' FROM DUAL;
SELECT 'PROMPT ORDS Configuration Restoration Complete' FROM DUAL;
SELECT 'PROMPT ========================================' FROM DUAL;

SPOOL OFF

SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 100

PROMPT
PROMPT ========================================
PROMPT Backup Complete!
PROMPT ========================================
PROMPT
PROMPT Backup file created: &backup_file
PROMPT 
PROMPT This file contains a rollback script that can restore
PROMPT the current ORDS configuration for schema: &schema_name
PROMPT
PROMPT To restore from this backup, simply run:
PROMPT   @&backup_file
PROMPT
PROMPT ========================================
