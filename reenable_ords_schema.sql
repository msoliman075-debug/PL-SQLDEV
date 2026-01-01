-- ============================================================================
-- Re-enable ORDS Schema
-- ============================================================================
-- Use this script to re-enable a schema after making URL mapping changes
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF

PROMPT ========================================
PROMPT Re-enable ORDS Schema
PROMPT ========================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter the schema name to enable: '
ACCEPT base_path CHAR DEFAULT '/api/' PROMPT 'Enter base path (default /api/): '

-- Re-enable the schema
BEGIN
    DBMS_OUTPUT.PUT_LINE('Enabling schema: &schema_name');
    DBMS_OUTPUT.PUT_LINE('Base path: &base_path');
    
    ORDS.ENABLE_SCHEMA(
        p_schema              => UPPER('&schema_name'),
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => '&base_path',
        p_auto_rest_auth      => FALSE
    );
    
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Schema &schema_name has been enabled');
    DBMS_OUTPUT.PUT_LINE('Base path configured: &base_path');
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Failed to enable schema');
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
        DBMS_OUTPUT.PUT_LINE('Error Message: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/

-- Verify the schema is enabled
SELECT 
    schema_name,
    is_enabled,
    parsing_schema
FROM ORDS_METADATA.ORDS_SCHEMAS
WHERE schema_name = UPPER('&schema_name');
