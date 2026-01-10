/*
================================================================================
ORDS 404 Error Diagnostic Script
================================================================================
Endpoint: http://80.238.234.247:8080/ords/surety_ws/ic.policy/policy_upload
ORDS Version: 24.3
WebServer: Apache Tomcat 9.0.113

Run this script as the schema owner (SURETY_WS) or as DBA
================================================================================
*/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100

PROMPT ============================================================
PROMPT 1. CHECK IF CURRENT SCHEMA IS REST-ENABLED
PROMPT ============================================================

SELECT schema, 
       url_mapping_type, 
       url_mapping_pattern AS schema_alias,
       status
FROM user_ords_schemas;

PROMPT
PROMPT ============================================================
PROMPT 2. CHECK ALL SCHEMA ALIASES (Run as DBA)
PROMPT ============================================================

-- Uncomment if running as DBA:
-- SELECT parsing_schema, uri_prefix, status
-- FROM dba_ords_schema_aliases
-- WHERE UPPER(uri_prefix) LIKE '%SURETY%'
--    OR UPPER(parsing_schema) LIKE '%SURETY%';

PROMPT
PROMPT ============================================================
PROMPT 3. LIST ALL ORDS MODULES IN THIS SCHEMA
PROMPT ============================================================

SELECT id,
       name AS module_name, 
       uri_prefix AS base_path, 
       status,
       items_per_page
FROM user_ords_modules
ORDER BY name;

PROMPT
PROMPT ============================================================
PROMPT 4. SEARCH FOR MODULES CONTAINING 'POLICY' OR 'IC'
PROMPT ============================================================

SELECT id,
       name AS module_name, 
       uri_prefix AS base_path, 
       status
FROM user_ords_modules
WHERE UPPER(name) LIKE '%POLICY%'
   OR UPPER(name) LIKE '%IC%'
   OR UPPER(uri_prefix) LIKE '%POLICY%'
   OR UPPER(uri_prefix) LIKE '%IC%';

PROMPT
PROMPT ============================================================
PROMPT 5. LIST ALL TEMPLATES AND HANDLERS
PROMPT ============================================================

SELECT m.name AS module_name,
       m.uri_prefix AS module_base_path,
       m.status AS module_status,
       t.uri_template AS template_pattern,
       h.method AS http_method,
       h.source_type
FROM user_ords_modules m
LEFT JOIN user_ords_templates t ON m.id = t.module_id
LEFT JOIN user_ords_handlers h ON t.id = h.template_id
ORDER BY m.name, t.uri_template;

PROMPT
PROMPT ============================================================
PROMPT 6. CHECK SPECIFIC MODULE: ic.policy
PROMPT ============================================================

SELECT m.name AS module_name,
       m.uri_prefix AS base_path,
       m.status AS module_status,
       t.uri_template,
       h.method,
       h.source_type,
       h.source
FROM user_ords_modules m
LEFT JOIN user_ords_templates t ON m.id = t.module_id
LEFT JOIN user_ords_handlers h ON t.id = h.template_id
WHERE m.name = 'ic.policy'
   OR m.uri_prefix = 'ic.policy'
   OR m.uri_prefix = '/ic.policy/'
   OR m.uri_prefix = 'ic.policy/';

PROMPT
PROMPT ============================================================
PROMPT 7. VERIFY ORDS INSTALLATION
PROMPT ============================================================

SELECT owner, object_name, object_type, status
FROM all_objects
WHERE object_name = 'ORDS'
  AND object_type IN ('PACKAGE', 'PACKAGE BODY');

PROMPT
PROMPT ============================================================
PROMPT 8. CHECK ORDS PRIVILEGES
PROMPT ============================================================

SELECT grantee, privilege, table_name
FROM user_tab_privs
WHERE table_name LIKE 'ORDS%'
   OR grantor = 'ORDS_METADATA';

PROMPT
PROMPT ============================================================
PROMPT 9. FULL URL PATH CONSTRUCTION CHECK
PROMPT ============================================================

DECLARE
    v_schema_alias   VARCHAR2(200);
    v_module_base    VARCHAR2(200);
    v_template       VARCHAR2(200);
    v_full_url       VARCHAR2(500);
    v_module_exists  NUMBER := 0;
    v_schema_enabled NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Expected URL: /ords/surety_ws/ic.policy/policy_upload');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Check schema
    BEGIN
        SELECT COUNT(*) INTO v_schema_enabled
        FROM user_ords_schemas
        WHERE status = 'ENABLED';
    EXCEPTION
        WHEN OTHERS THEN
            v_schema_enabled := 0;
    END;
    
    IF v_schema_enabled > 0 THEN
        DBMS_OUTPUT.PUT_LINE('✓ Schema is REST-enabled');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ ERROR: Schema is NOT REST-enabled!');
        DBMS_OUTPUT.PUT_LINE('  FIX: Run ORDS.ENABLE_SCHEMA procedure');
    END IF;
    
    -- Check module
    BEGIN
        SELECT COUNT(*) INTO v_module_exists
        FROM user_ords_modules
        WHERE name = 'ic.policy'
           OR uri_prefix LIKE '%ic.policy%';
    EXCEPTION
        WHEN OTHERS THEN
            v_module_exists := 0;
    END;
    
    IF v_module_exists > 0 THEN
        DBMS_OUTPUT.PUT_LINE('✓ Module ic.policy exists');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ ERROR: Module ic.policy does NOT exist!');
        DBMS_OUTPUT.PUT_LINE('  FIX: Create the module using ORDS.DEFINE_MODULE');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Available Modules ---');
    FOR r IN (SELECT name, uri_prefix, status FROM user_ords_modules) LOOP
        DBMS_OUTPUT.PUT_LINE('  Module: ' || r.name || ' | Base: ' || r.uri_prefix || ' | Status: ' || r.status);
    END LOOP;
    
END;
/

PROMPT
PROMPT ============================================================
PROMPT 10. POTENTIAL FIXES
PROMPT ============================================================
PROMPT
PROMPT If module does not exist, create it with:
PROMPT
PROMPT BEGIN
PROMPT     -- Enable schema for REST
PROMPT     ORDS.ENABLE_SCHEMA(
PROMPT         p_enabled             => TRUE,
PROMPT         p_schema              => 'SURETY_WS',
PROMPT         p_url_mapping_type    => 'BASE_PATH',
PROMPT         p_url_mapping_pattern => 'surety_ws',
PROMPT         p_auto_rest_auth      => FALSE
PROMPT     );
PROMPT     
PROMPT     -- Define the module
PROMPT     ORDS.DEFINE_MODULE(
PROMPT         p_module_name    => 'ic.policy',
PROMPT         p_base_path      => '/ic.policy/',
PROMPT         p_items_per_page => 25,
PROMPT         p_status         => 'PUBLISHED',
PROMPT         p_comments       => 'Policy Upload API'
PROMPT     );
PROMPT     
PROMPT     -- Define the template
PROMPT     ORDS.DEFINE_TEMPLATE(
PROMPT         p_module_name => 'ic.policy',
PROMPT         p_pattern     => 'policy_upload'
PROMPT     );
PROMPT     
PROMPT     -- Define the handler (adjust method and source as needed)
PROMPT     ORDS.DEFINE_HANDLER(
PROMPT         p_module_name => 'ic.policy',
PROMPT         p_pattern     => 'policy_upload',
PROMPT         p_method      => 'POST',
PROMPT         p_source_type => 'plsql/block',
PROMPT         p_source      => 'BEGIN your_upload_procedure(:body); END;'
PROMPT     );
PROMPT     
PROMPT     COMMIT;
PROMPT END;
PROMPT /
PROMPT
PROMPT ============================================================
PROMPT END OF DIAGNOSTIC
PROMPT ============================================================
