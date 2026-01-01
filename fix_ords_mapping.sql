DECLARE
    -- REPLACE THESE VALUES
    v_schema_name  CONSTANT VARCHAR2(128) := 'YOUR_SCHEMA_NAME';
    v_url_mapping  CONSTANT VARCHAR2(128) := 'your_new_mapping'; -- e.g., 'hr' or 'api'
BEGIN
    -- Step 1: Disable the schema to allow mapping changes
    -- ORA-20049 occurs because you cannot change the mapping while enabled
    ORDS.ENABLE_SCHEMA(
        p_enabled             => FALSE,
        p_schema              => v_schema_name
    );
    
    COMMIT; -- Ensure the disable is committed
    
    -- Step 2: Re-enable with the NEW mapping
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => v_schema_name,
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => v_url_mapping,
        p_auto_rest_auth      => FALSE -- Set to TRUE if you want auto-rest tables
    );
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Successfully updated URL mapping for schema: ' || v_schema_name);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END;
/
