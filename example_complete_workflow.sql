-- ============================================================================
-- Example: Fix ORA-20049 Error - Complete Workflow
-- ============================================================================
-- This script demonstrates the complete workflow to resolve ORA-20049
-- Modify the variables in the configuration section for your environment
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF
SET ECHO ON

-- ============================================================================
-- CONFIGURATION SECTION - MODIFY THESE VALUES
-- ============================================================================
DEFINE v_schema = 'YOUR_SCHEMA_NAME'
DEFINE v_new_base_path = '/api/v2/'
DEFINE v_module_name = 'YOUR_MODULE'

PROMPT ========================================
PROMPT ORA-20049 Fix - Complete Workflow
PROMPT ========================================
PROMPT Configuration:
PROMPT   Schema: &v_schema
PROMPT   New Base Path: &v_new_base_path
PROMPT   Module: &v_module_name
PROMPT ========================================
PROMPT

-- ============================================================================
-- STEP 1: Backup Current Configuration
-- ============================================================================
PROMPT *** STEP 1: Creating Backup ***

SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 0

SPOOL ords_backup_&v_schema..sql

SELECT 'BEGIN' FROM DUAL;
SELECT '    ORDS.ENABLE_SCHEMA(' FROM DUAL;
SELECT '        p_schema => ''' || schema_name || ''',' FROM DUAL;
SELECT '        p_url_mapping_type => ''BASE_PATH'',' FROM DUAL;
SELECT '        p_auto_rest_auth => FALSE' FROM DUAL;
SELECT '    );' FROM DUAL;
SELECT 'END;' FROM DUAL;
SELECT '/' FROM DUAL;
FROM ORDS_METADATA.ORDS_SCHEMAS
WHERE schema_name = UPPER('&v_schema')
AND is_enabled = 'Y';

SPOOL OFF

SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 100

PROMPT Backup created: ords_backup_&v_schema..sql
PROMPT

-- ============================================================================
-- STEP 2: Display Current Configuration
-- ============================================================================
PROMPT *** STEP 2: Current Configuration ***

SELECT 
    'Schema: ' || schema_name AS info,
    'Status: ' || CASE is_enabled WHEN 'Y' THEN 'ENABLED' ELSE 'DISABLED' END AS status
FROM ORDS_METADATA.ORDS_SCHEMAS
WHERE schema_name = UPPER('&v_schema');

SELECT 
    'Module: ' || m.name AS info,
    'Current Base Path: ' || m.base_path AS path
FROM ORDS_METADATA.ORDS_MODULES m
JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
WHERE s.schema_name = UPPER('&v_schema')
AND m.name = '&v_module_name';

PROMPT

-- ============================================================================
-- STEP 3: Disable Schema
-- ============================================================================
PROMPT *** STEP 3: Disabling Schema ***

DECLARE
    v_schema VARCHAR2(128) := UPPER('&v_schema');
BEGIN
    DBMS_OUTPUT.PUT_LINE('Disabling schema: ' || v_schema);
    
    ORDS.DISABLE_SCHEMA(
        p_schema => v_schema
    );
    
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Schema disabled');
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('This error may occur if schema is already disabled');
        ROLLBACK;
END;
/

PROMPT

-- ============================================================================
-- STEP 4: Verify Schema is Disabled
-- ============================================================================
PROMPT *** STEP 4: Verifying Disabled Status ***

SELECT 
    schema_name,
    is_enabled,
    CASE is_enabled 
        WHEN 'N' THEN 'OK - Schema is disabled and ready for changes'
        WHEN 'Y' THEN 'WARNING - Schema is still enabled!'
    END as verification
FROM ORDS_METADATA.ORDS_SCHEMAS
WHERE schema_name = UPPER('&v_schema');

PROMPT

-- ============================================================================
-- STEP 5: Update URL Mapping
-- ============================================================================
PROMPT *** STEP 5: Updating URL Mapping ***

DECLARE
    v_schema      VARCHAR2(128) := UPPER('&v_schema');
    v_module_name VARCHAR2(255) := '&v_module_name';
    v_base_path   VARCHAR2(255) := '&v_new_base_path';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Updating module: ' || v_module_name);
    DBMS_OUTPUT.PUT_LINE('New base path: ' || v_base_path);
    
    -- Example 1: Update existing module base path
    ORDS.DEFINE_MODULE(
        p_module_name    => v_module_name,
        p_base_path      => v_base_path,
        p_items_per_page => 25,
        p_status         => 'PUBLISHED',
        p_comments       => 'Updated to fix ORA-20049'
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: URL mapping updated');
    
    -- Example 2: If you need to add/update specific templates
    /*
    ORDS.DEFINE_TEMPLATE(
        p_module_name => v_module_name,
        p_pattern     => 'employees/:id',
        p_priority    => 0,
        p_etag_type   => 'HASH',
        p_comments    => 'Employee detail endpoint'
    );
    COMMIT;
    */
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR updating URL mapping: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
        ROLLBACK;
        RAISE;
END;
/

PROMPT

-- ============================================================================
-- STEP 6: Verify Changes
-- ============================================================================
PROMPT *** STEP 6: Verifying URL Mapping Changes ***

SELECT 
    m.name as module_name,
    m.base_path as current_base_path,
    m.status,
    CASE 
        WHEN m.base_path = '&v_new_base_path' THEN 'OK - Path updated successfully'
        ELSE 'WARNING - Path may not have updated'
    END as verification
FROM ORDS_METADATA.ORDS_MODULES m
JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
WHERE s.schema_name = UPPER('&v_schema')
AND m.name = '&v_module_name';

PROMPT

-- ============================================================================
-- STEP 7: Re-enable Schema
-- ============================================================================
PROMPT *** STEP 7: Re-enabling Schema ***

DECLARE
    v_schema    VARCHAR2(128) := UPPER('&v_schema');
    v_base_path VARCHAR2(255) := '&v_new_base_path';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Re-enabling schema: ' || v_schema);
    DBMS_OUTPUT.PUT_LINE('Base path: ' || v_base_path);
    
    ORDS.ENABLE_SCHEMA(
        p_schema              => v_schema,
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => v_base_path,
        p_auto_rest_auth      => FALSE
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Schema re-enabled with new configuration');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR re-enabling schema: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('IMPORTANT: Schema remains disabled!');
        DBMS_OUTPUT.PUT_LINE('To restore, run: @ords_backup_&v_schema..sql');
        ROLLBACK;
        RAISE;
END;
/

PROMPT

-- ============================================================================
-- STEP 8: Final Verification
-- ============================================================================
PROMPT *** STEP 8: Final Verification ***

SELECT 
    'Schema: ' || s.schema_name AS configuration,
    'Status: ' || CASE s.is_enabled WHEN 'Y' THEN 'ENABLED' ELSE 'DISABLED' END AS value
FROM ORDS_METADATA.ORDS_SCHEMAS s
WHERE s.schema_name = UPPER('&v_schema')
UNION ALL
SELECT 
    'Module: ' || m.name AS configuration,
    'Base Path: ' || m.base_path AS value
FROM ORDS_METADATA.ORDS_MODULES m
JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
WHERE s.schema_name = UPPER('&v_schema')
AND m.name = '&v_module_name';

PROMPT
PROMPT ========================================
PROMPT Workflow Complete!
PROMPT ========================================
PROMPT
PROMPT Summary:
PROMPT   1. Backup created: ords_backup_&v_schema..sql
PROMPT   2. Schema disabled
PROMPT   3. URL mapping updated
PROMPT   4. Schema re-enabled
PROMPT   5. Configuration verified
PROMPT
PROMPT Your ORDS schema is now active with the new URL mapping.
PROMPT If you need to rollback, run: @ords_backup_&v_schema..sql
PROMPT ========================================

-- ============================================================================
-- OPTIONAL: Test the Endpoint
-- ============================================================================
PROMPT
PROMPT To test your updated endpoint:
PROMPT   1. Ensure ORDS service is running
PROMPT   2. Access: http://your-server:port&v_new_base_path
PROMPT   3. Verify REST endpoints respond correctly
PROMPT

SET VERIFY ON
SET ECHO OFF
