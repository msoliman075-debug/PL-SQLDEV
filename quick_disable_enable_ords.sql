-- ============================================================================
-- Quick Fix: Disable and Re-enable ORDS Schema
-- ============================================================================
-- This script provides a simple wrapper to disable/enable ORDS schema
-- Use this when you need to quickly disable a schema to make changes
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF

PROMPT ========================================
PROMPT Quick ORDS Schema Disable/Enable Tool
PROMPT ========================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter the schema name to disable: '

-- Disable the schema
BEGIN
    DBMS_OUTPUT.PUT_LINE('Disabling schema: &schema_name');
    
    ORDS.DISABLE_SCHEMA(
        p_schema => UPPER('&schema_name')
    );
    
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Schema &schema_name has been disabled');
    DBMS_OUTPUT.PUT_LINE('You can now make your URL mapping changes');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('To re-enable, run the enable script or execute:');
    DBMS_OUTPUT.PUT_LINE('  ORDS.ENABLE_SCHEMA(p_schema => ''&schema_name'');');
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Failed to disable schema');
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
        DBMS_OUTPUT.PUT_LINE('Error Message: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/
