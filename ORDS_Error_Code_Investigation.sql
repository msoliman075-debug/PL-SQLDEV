--------------------------------------------------------------------------------
-- ORDS Error Code Investigation & Resolution
-- Issue: ORDS returns 404 with empty "Error Code:" field
-- Endpoint: /ords/surety_api/surety/upload_policy/
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- PART 1: DIAGNOSTIC QUERIES
-- Run these to identify why the endpoint returns 404
-- NOTE: Your setup - Schema: SURETY, URL Pattern: SURETY_API
--------------------------------------------------------------------------------

-- 1.1 Check if schema is REST-enabled (correct column names)
-- Option A: Using USER_ORDS_SCHEMAS (check all columns first)
DESC user_ords_schemas;

SELECT * FROM user_ords_schemas;

-- Option B: Using ORDS_SCHEMAS view (if available)
SELECT * FROM ords_schemas WHERE parsing_schema = 'SURETY';

-- Option C: Query ORDS metadata directly (works on most ORDS versions)
SELECT ur.parsing_schema, 
       ur.url_mapping_pattern,
       ur.status,
       ur.auto_rest_auth
FROM user_ords_enabled_schemas ur;

-- Option D: Check via DBA view (requires privileges)
SELECT schema_name, url_mapping_pattern, status
FROM dba_ords_schemas
WHERE schema_name = 'SURETY';

-- 1.2 Check all REST modules in the schema
-- First, check what columns exist
DESC user_ords_modules;

SELECT * FROM user_ords_modules ORDER BY name;

-- 1.3 Check REST templates (endpoints)
SELECT m.name AS module_name, 
       t.uri_template,
       t.priority
FROM user_ords_modules m
JOIN user_ords_templates t ON m.id = t.module_id
ORDER BY m.name, t.uri_template;

-- 1.4 Check REST handlers (methods like GET, POST)
SELECT m.name AS module_name,
       t.uri_template,
       h.source_type,
       h.method
FROM user_ords_modules m
JOIN user_ords_templates t ON m.id = t.module_id
JOIN user_ords_handlers h ON t.id = h.template_id
ORDER BY m.name, t.uri_template, h.method;

-- 1.5 Quick check - List ALL ORDS-related views available
SELECT view_name 
FROM all_views 
WHERE view_name LIKE '%ORDS%'
ORDER BY view_name;

--------------------------------------------------------------------------------
-- PART 2: WHY ERROR CODE IS EMPTY
--------------------------------------------------------------------------------
/*
The "Error Code:" field in ORDS error responses is ONLY populated when:

1. Your PL/SQL handler explicitly raises an exception with a custom error code
2. You use ORDS_UTIL.HTTP_ERROR procedure with an error code
3. You define custom error handlers in the REST module

For standard HTTP errors (404, 401, 403, 500), ORDS does NOT generate 
custom error codes automatically.

Your 404 error means ONE of these:
- The REST module/template doesn't exist
- The HTTP method (GET vs POST) doesn't match
- The URL path is incorrect
- The schema isn't REST-enabled
*/

--------------------------------------------------------------------------------
-- PART 3: ENABLE ORDS FOR SCHEMA (if not already enabled)
-- Your setup: Schema = SURETY, URL Pattern = SURETY_API
--------------------------------------------------------------------------------

-- Run as ADMIN or DBA user, OR connected as SURETY schema
BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'SURETY',           -- Your actual DB schema name
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'surety_api',       -- URL path (lowercase recommended)
        p_auto_rest_auth      => FALSE               -- Set TRUE if you want authentication
    );
    COMMIT;
END;
/

-- If running from SURETY schema itself (without p_schema parameter):
BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'surety_api',
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
END;
/

--------------------------------------------------------------------------------
-- PART 4: CREATE/VERIFY THE REST MODULE
--------------------------------------------------------------------------------

-- Example: Define the REST module for surety API
BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'surety.v1',
        p_base_path      => '/surety/',
        p_items_per_page => 25,
        p_status         => 'PUBLISHED',
        p_comments       => 'Surety API Module'
    );
    COMMIT;
END;
/

--------------------------------------------------------------------------------
-- PART 5: CREATE THE UPLOAD_POLICY TEMPLATE AND HANDLER
--------------------------------------------------------------------------------

-- Define the template (URL pattern)
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'surety.v1',
        p_pattern        => 'upload_policy/',
        p_priority       => 0,
        p_etag_type      => 'HASH',
        p_etag_query     => NULL,
        p_comments       => 'Upload Policy Endpoint'
    );
    COMMIT;
END;
/

-- Define GET handler (if you want GET method)
BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'surety.v1',
        p_pattern        => 'upload_policy/',
        p_method         => 'GET',
        p_source_type    => 'plsql/block',
        p_mimes_allowed  => NULL,
        p_comments       => 'Get upload policy info',
        p_source         => q'[
BEGIN
    -- Your PL/SQL logic here
    -- To return custom error codes, use:
    -- APEX_JSON.OPEN_OBJECT;
    -- APEX_JSON.WRITE('status', 'success');
    -- APEX_JSON.WRITE('error_code', NULL);
    -- APEX_JSON.CLOSE_OBJECT;
    
    HTP.P('{"status": "success", "message": "Upload policy endpoint"}');
EXCEPTION
    WHEN OTHERS THEN
        -- Return custom error code
        OWA_UTIL.STATUS_LINE(500, 'Internal Server Error', FALSE);
        HTP.P('{"error_code": "UPLOAD_ERR_001", "message": "' || SQLERRM || '"}');
END;
]'
    );
    COMMIT;
END;
/

-- Define POST handler (if you want POST method)
BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'surety.v1',
        p_pattern        => 'upload_policy/',
        p_method         => 'POST',
        p_source_type    => 'plsql/block',
        p_mimes_allowed  => 'application/json',
        p_comments       => 'Upload policy data',
        p_source         => q'[
DECLARE
    l_body     CLOB := :body;
    l_result   VARCHAR2(4000);
BEGIN
    -- Your upload logic here
    -- Process l_body JSON
    
    HTP.P('{"status": "success", "error_code": null, "message": "Policy uploaded"}');
EXCEPTION
    WHEN OTHERS THEN
        OWA_UTIL.STATUS_LINE(400, 'Bad Request', FALSE);
        HTP.P('{"error_code": "UPLOAD_ERR_002", "message": "' || SQLERRM || '"}');
END;
]'
    );
    COMMIT;
END;
/

--------------------------------------------------------------------------------
-- PART 6: HOW TO RETURN CUSTOM ERROR CODES IN ORDS
--------------------------------------------------------------------------------

/*
Method 1: Using APEX_JSON for structured error responses
*/
CREATE OR REPLACE PROCEDURE return_ords_error (
    p_http_status   IN NUMBER,
    p_error_code    IN VARCHAR2,
    p_error_message IN VARCHAR2
) AS
BEGIN
    -- Set HTTP status code
    OWA_UTIL.STATUS_LINE(p_http_status, p_error_message, FALSE);
    
    -- Return JSON error response with custom error code
    APEX_JSON.OPEN_OBJECT;
    APEX_JSON.WRITE('http_status', p_http_status);
    APEX_JSON.WRITE('error_code', p_error_code);
    APEX_JSON.WRITE('error_message', p_error_message);
    APEX_JSON.WRITE('timestamp', TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"'));
    APEX_JSON.CLOSE_OBJECT;
END return_ords_error;
/

/*
Method 2: Using the ORDS-specific error handling (ORDS 22.1+)
*/
-- In your handler, raise application errors that ORDS will capture
-- Example handler source:
/*
BEGIN
    IF :id IS NULL THEN
        raise_application_error(-20001, 'POLICY_ID_REQUIRED: Policy ID cannot be null');
    END IF;
    
    -- Your logic here
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        raise_application_error(-20002, 'POLICY_NOT_FOUND: No policy exists with the given ID');
    WHEN OTHERS THEN
        raise_application_error(-20999, 'UNEXPECTED_ERROR: ' || SQLERRM);
END;
*/

--------------------------------------------------------------------------------
-- PART 7: QUICK VERIFICATION COMMANDS
--------------------------------------------------------------------------------

-- First: Check available ORDS views and their columns
SELECT view_name FROM user_views WHERE view_name LIKE 'USER_ORDS%';

-- After creating the module, verify it exists:
SELECT * FROM user_ords_modules WHERE name = 'surety.v1';

-- Verify the template:
SELECT * FROM user_ords_templates WHERE uri_template = 'upload_policy/';

-- Verify handlers:
SELECT h.method, h.source_type, t.uri_template
FROM user_ords_handlers h
JOIN user_ords_templates t ON h.template_id = t.id
JOIN user_ords_modules m ON t.module_id = m.id
WHERE m.name = 'surety.v1';

-- COMPREHENSIVE CHECK: See ALL your ORDS REST services
SELECT 
    m.name AS module_name,
    m.uri_prefix AS module_base_path,
    t.uri_template,
    h.method,
    h.source_type,
    m.status AS module_status
FROM user_ords_modules m
LEFT JOIN user_ords_templates t ON m.id = t.module_id
LEFT JOIN user_ords_handlers h ON t.id = h.template_id
ORDER BY m.name, t.uri_template, h.method;

--------------------------------------------------------------------------------
-- PART 8: COMMON 404 CAUSES AND FIXES
-- Your URL: http://ai.suretysa.com:8080/ords/surety_api/surety/upload_policy/
--------------------------------------------------------------------------------
/*
YOUR URL BREAKDOWN:
- Server: http://ai.suretysa.com:8080
- ORDS context: /ords
- Schema pattern: /surety_api  <-- Must match ORDS.ENABLE_SCHEMA url_mapping_pattern
- Module base: /surety         <-- Must match module uri_prefix
- Template: /upload_policy/    <-- Must match template uri_template

CAUSE 1: URL Path Mismatch
- Schema 'SURETY' must have url_mapping_pattern = 'surety_api'
- Module must have uri_prefix = '/surety/' or 'surety/'
- Template must have uri_template = 'upload_policy/' or 'upload_policy'

CAUSE 2: Method Mismatch
- You're calling GET but only POST handler exists
- Solution: Add handler for the method you're using
- Check: SELECT method FROM user_ords_handlers;

CAUSE 3: Schema Not REST-Enabled
- Run: SELECT * FROM user_ords_schemas;
- If empty, enable the schema with ORDS.ENABLE_SCHEMA

CAUSE 4: Module Not Published
- Check: SELECT name, status FROM user_ords_modules;
- Should be 'PUBLISHED', not 'NOT_PUBLISHED'

CAUSE 5: Case Sensitivity
- ORDS URLs are case-sensitive by default!
- URL has 'surety_api' (lowercase) - ensure schema pattern matches
- Ensure template definition matches exact case

CAUSE 6: Trailing Slash Mismatch
- URL has trailing slash: upload_policy/
- Template might be defined as 'upload_policy' (no slash)
- Try both: /upload_policy/ and /upload_policy
*/

--------------------------------------------------------------------------------
-- PART 9: ORDS METADATA REFRESH
--------------------------------------------------------------------------------

-- Sometimes ORDS cache needs refresh. Restart ORDS or run:
-- From command line: ords --config /path/to/config serve --apex-images /path/to/images

-- Or use SQL to republish:
BEGIN
    ORDS.PUBLISH_MODULE(
        p_module_name => 'surety.v1'
    );
    COMMIT;
END;
/
