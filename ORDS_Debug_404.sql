--------------------------------------------------------------------------------
-- ORDS 404 Debug Script
-- Configuration looks correct but still getting 404
--------------------------------------------------------------------------------

-- 1. Verify complete URL mapping
-- Expected URL: http://server:8080/ords/surety_api/surety/upload_policy/
SELECT 
    'Schema Pattern' AS component,
    s.pattern AS value,
    s.status AS status,
    'Must be: surety_api' AS expected
FROM user_ords_schemas s
WHERE s.parsing_schema = 'SURETY'
UNION ALL
SELECT 
    'Module URI Prefix',
    m.uri_prefix,
    m.status,
    'Must be: /surety/'
FROM user_ords_modules m
WHERE m.name = 'surety.v1'
UNION ALL
SELECT 
    'Template Pattern',
    t.uri_template,
    'N/A',
    'Must be: upload_policy/'
FROM user_ords_templates t
JOIN user_ords_modules m ON t.module_id = m.id
WHERE m.name = 'surety.v1';

-- 2. Check if handlers have valid source code
SELECT 
    h.method,
    h.source_type,
    SUBSTR(h.source, 1, 200) AS source_preview,
    h.mimes_allowed
FROM user_ords_handlers h
JOIN user_ords_templates t ON h.template_id = t.id
JOIN user_ords_modules m ON t.module_id = m.id
WHERE m.name = 'surety.v1'
AND t.uri_template = 'upload_policy/';

-- 3. Check for multiple schemas with same pattern (conflict)
SELECT parsing_schema, pattern, status
FROM user_ords_schemas
WHERE LOWER(pattern) = 'surety_api';

-- 4. Check if module is linked to correct schema
SELECT 
    m.name AS module_name,
    m.schema_id AS module_schema_id,
    s.id AS schema_id,
    s.parsing_schema,
    CASE WHEN m.schema_id = s.id THEN 'OK - MATCHED' ELSE 'ERROR - MISMATCH!' END AS status
FROM user_ords_modules m
CROSS JOIN user_ords_schemas s
WHERE m.name = 'surety.v1'
AND s.parsing_schema = 'SURETY';

-- 5. List ALL endpoints in your schema (what URLs should work)
SELECT 
    '/' || LOWER(s.pattern) || m.uri_prefix || t.uri_template AS full_url_path,
    h.method,
    m.status AS module_status
FROM user_ords_schemas s
JOIN user_ords_modules m ON s.id = m.schema_id
JOIN user_ords_templates t ON m.id = t.module_id
JOIN user_ords_handlers h ON t.id = h.template_id
WHERE s.parsing_schema = 'SURETY'
ORDER BY full_url_path, h.method;

-- 6. Alternative: Check ORDS Services view
SELECT * FROM user_ords_services;

--------------------------------------------------------------------------------
-- SOLUTIONS TO TRY
--------------------------------------------------------------------------------

/*
SOLUTION 1: Restart ORDS (most likely fix)
------------------------------------------
ORDS caches metadata. Changes may not take effect until restart.

On Linux server:
  ps aux | grep ords
  kill <PID>
  cd /opt/ords && ./ords serve &

Or if using systemd:
  sudo systemctl restart ords


SOLUTION 2: Try URL without trailing slash
------------------------------------------
http://ai.suretysa.com:8080/ords/surety_api/surety/upload_policy


SOLUTION 3: Republish the module
------------------------------------------
*/
BEGIN
    ORDS.PUBLISH_MODULE(p_module_name => 'surety.v1');
    COMMIT;
END;
/

/*
SOLUTION 4: Check ORDS version and context path
------------------------------------------
The ORDS context root might not be '/ords/'
Try: http://ai.suretysa.com:8080/surety_api/surety/upload_policy/
*/

-- Check ORDS version
SELECT * FROM ords_version;

/*
SOLUTION 5: Delete and recreate with explicit schema
------------------------------------------
*/
-- First delete
BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'surety.v1');
    COMMIT;
END;
/

-- Then recreate with explicit connection to schema
BEGIN
    -- Make sure we're in SURETY schema context
    ORDS.DEFINE_MODULE(
        p_module_name    => 'surety.v1',
        p_base_path      => 'surety/',  -- Try without leading slash
        p_items_per_page => 25,
        p_status         => 'PUBLISHED',
        p_comments       => 'Surety API Module'
    );
    
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'surety.v1',
        p_pattern        => 'upload_policy/',
        p_priority       => 0,
        p_etag_type      => 'HASH',
        p_comments       => 'Upload Policy Endpoint'
    );
    
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'surety.v1',
        p_pattern        => 'upload_policy/',
        p_method         => 'GET',
        p_source_type    => 'plsql/block',
        p_source         => 'BEGIN HTP.P(''{"status":"success","message":"GET upload_policy"}''); END;'
    );
    
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'surety.v1',
        p_pattern        => 'upload_policy/',
        p_method         => 'POST',
        p_source_type    => 'plsql/block',
        p_mimes_allowed  => 'application/json',
        p_source         => 'BEGIN HTP.P(''{"status":"success","message":"POST upload_policy"}''); END;'
    );
    
    COMMIT;
END;
/

/*
SOLUTION 6: Check if ORDS URL mapping is using a different context
------------------------------------------
Run this from command line to see ORDS configuration:
  ords config list

Check these settings:
  - standalone.context.path (default: /ords)
  - restEnabledSql.active
*/

/*
SOLUTION 7: Enable debug logging in ORDS
------------------------------------------
In ORDS configuration (standalone settings or defaults.xml):

<entry key="debug.printDebugToScreen">true</entry>
<entry key="log.procedure">true</entry>

Or via command line:
  ords config set debug.printDebugToScreen true
  ords config set log.procedure true
*/

--------------------------------------------------------------------------------
-- VERIFICATION AFTER FIX
--------------------------------------------------------------------------------

-- Run this after trying fixes to confirm configuration
SELECT 
    'Configuration Summary' AS info,
    COUNT(DISTINCT m.name) || ' modules' AS modules,
    COUNT(DISTINCT t.uri_template) || ' templates' AS templates,
    COUNT(h.id) || ' handlers' AS handlers
FROM user_ords_modules m
LEFT JOIN user_ords_templates t ON m.id = t.module_id
LEFT JOIN user_ords_handlers h ON t.id = h.template_id
WHERE m.name = 'surety.v1';
