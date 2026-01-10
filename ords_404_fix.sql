/*
================================================================================
ORDS 404 Error - FIX SCRIPT
================================================================================
Endpoint: http://80.238.234.247:8080/ords/surety_ws/ic.policy/policy_upload

RUN THIS SCRIPT AS THE SCHEMA OWNER OR A USER WITH ORDS PRIVILEGES
================================================================================
*/

SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ============================================================
PROMPT STEP 1: ENABLE SCHEMA FOR REST (if not already enabled)
PROMPT ============================================================

BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'SURETY_WS',        -- Change to your actual schema name
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'surety_ws',        -- This is the alias in the URL
        p_auto_rest_auth      => FALSE               -- Set TRUE if authentication required
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Schema REST-enabled successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error enabling schema: ' || SQLERRM);
END;
/

PROMPT
PROMPT ============================================================
PROMPT STEP 2: DELETE EXISTING MODULE (if exists, to recreate cleanly)
PROMPT ============================================================

BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'ic.policy');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Existing module deleted.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Module did not exist or error: ' || SQLERRM);
END;
/

PROMPT
PROMPT ============================================================
PROMPT STEP 3: CREATE MODULE
PROMPT ============================================================

BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'ic.policy',
        p_base_path      => '/ic.policy/',           -- Note: include leading and trailing slash
        p_items_per_page => 25,
        p_status         => 'PUBLISHED',             -- MUST be PUBLISHED to be accessible
        p_comments       => 'Insurance Policy Upload Module'
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Module created successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error creating module: ' || SQLERRM);
        RAISE;
END;
/

PROMPT
PROMPT ============================================================
PROMPT STEP 4: CREATE TEMPLATE
PROMPT ============================================================

BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'ic.policy',
        p_pattern     => 'policy_upload',            -- Template pattern (no leading slash)
        p_comments    => 'Policy upload endpoint'
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Template created successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error creating template: ' || SQLERRM);
        RAISE;
END;
/

PROMPT
PROMPT ============================================================
PROMPT STEP 5: CREATE HANDLER (POST method for upload)
PROMPT ============================================================

BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'ic.policy',
        p_pattern        => 'policy_upload',
        p_method         => 'POST',                  -- Use POST for uploads
        p_source_type    => 'plsql/block',
        p_mimes_allowed  => 'application/json',      -- Adjust based on your content type
        p_source         => q'[
BEGIN
    -- Replace this with your actual procedure call
    -- Example: ic_policy_pkg.upload_policy(:body);
    
    -- For testing, just return success
    :status_code := 200;
    
    HTP.P('{"status": "success", "message": "Policy upload endpoint is working"}');
    
EXCEPTION
    WHEN OTHERS THEN
        :status_code := 500;
        HTP.P('{"status": "error", "message": "' || SQLERRM || '"}');
END;
]',
        p_comments       => 'Handler for policy upload'
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Handler created successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error creating handler: ' || SQLERRM);
        RAISE;
END;
/

PROMPT
PROMPT ============================================================
PROMPT STEP 6: VERIFY THE SETUP
PROMPT ============================================================

SELECT m.name AS module_name,
       m.uri_prefix AS base_path,
       m.status AS module_status,
       t.uri_template AS template,
       h.method,
       h.source_type
FROM user_ords_modules m
JOIN user_ords_templates t ON m.id = t.module_id
JOIN user_ords_handlers h ON t.id = h.template_id
WHERE m.name = 'ic.policy';

PROMPT
PROMPT ============================================================
PROMPT STEP 7: CONSTRUCT FULL URL
PROMPT ============================================================

DECLARE
    v_schema_alias VARCHAR2(100);
BEGIN
    SELECT url_mapping_pattern INTO v_schema_alias
    FROM user_ords_schemas
    WHERE ROWNUM = 1;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Your endpoint should now be accessible at:');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  POST http://80.238.234.247:8080/ords/' || v_schema_alias || '/ic.policy/policy_upload');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test with curl:');
    DBMS_OUTPUT.PUT_LINE('  curl -X POST http://80.238.234.247:8080/ords/' || v_schema_alias || '/ic.policy/policy_upload');
    DBMS_OUTPUT.PUT_LINE('');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: Could not find schema alias. Check ORDS.ENABLE_SCHEMA.');
END;
/

PROMPT
PROMPT ============================================================
PROMPT COMPLETE! Test the endpoint in Postman now.
PROMPT ============================================================
