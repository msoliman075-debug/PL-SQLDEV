--------------------------------------------------------------------------------
-- ORDS Module Visibility Check
-- ORDS Log shows: "Could not find any dispatcher to handle request"
-- This means ORDS can't see the module - let's find out why
--------------------------------------------------------------------------------

-- 1. Check which user created the module
SELECT 
    name,
    uri_prefix,
    status,
    created_by,
    created_on,
    schema_id
FROM user_ords_modules
WHERE name = 'surety.v1';

-- 2. Check all schemas registered in ORDS
SELECT 
    id,
    parsing_schema,
    pattern,
    status
FROM user_ords_schemas;

-- 3. Verify the module is linked to the correct schema
SELECT 
    m.name AS module_name,
    m.uri_prefix,
    m.status AS module_status,
    m.schema_id,
    s.id AS schema_id_check,
    s.parsing_schema,
    s.pattern AS schema_url_pattern,
    CASE WHEN m.schema_id = s.id THEN 'LINKED OK' ELSE 'NOT LINKED!' END AS linkage
FROM user_ords_modules m, user_ords_schemas s
WHERE m.name = 'surety.v1';

-- 4. Check if maybe the module exists in ORDS_METADATA schema instead
-- (Run this as DBA if possible)
SELECT owner, object_name, object_type 
FROM all_objects 
WHERE object_name LIKE '%ORDS%MODULE%'
AND owner NOT IN ('SYS','SYSTEM')
ORDER BY owner;

-- 5. Full path verification - what URL should work?
SELECT 
    'http://ai.suretysa.com:8080/ords/' || 
    LOWER(s.pattern) || 
    m.uri_prefix || 
    t.uri_template AS expected_url,
    h.method
FROM user_ords_schemas s
JOIN user_ords_modules m ON s.id = m.schema_id
JOIN user_ords_templates t ON m.id = t.module_id  
JOIN user_ords_handlers h ON t.id = h.template_id
WHERE m.name = 'surety.v1';

--------------------------------------------------------------------------------
-- POTENTIAL FIX: The module might need to be created by ORDS_PUBLIC_USER
-- or the REST-enabled schema needs to be properly configured
--------------------------------------------------------------------------------

/*
ISSUE: ORDS connects to the database as a specific user (often ORDS_PUBLIC_USER 
or a proxy user). If the module was created by SURETY user but ORDS connects 
as a different user, ORDS might not see the module.

SOLUTION 1: Check ORDS connection user
--------------------------------------
On the Linux server, run:
  cd /opt/ords
  ./ords config get db.username

SOLUTION 2: Grant access to the modules (if using proxy)
--------------------------------------
If ORDS connects as ORDS_PUBLIC_USER with proxy to SURETY:
*/

-- Check if ORDS_PUBLIC_USER can see the modules
-- Run as DBA:
SELECT grantee, owner, table_name, privilege
FROM dba_tab_privs
WHERE table_name LIKE '%ORDS%'
AND grantee IN ('ORDS_PUBLIC_USER', 'PUBLIC', 'SURETY');

/*
SOLUTION 3: Re-enable ORDS for schema with correct settings
--------------------------------------
*/
-- Connect as SURETY schema and run:
BEGIN
    -- First disable
    ORDS.ENABLE_SCHEMA(
        p_enabled             => FALSE,
        p_schema              => 'SURETY',
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'surety_api',
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
    
    -- Then re-enable
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'SURETY',
        p_url_mapping_type    => 'BASE_PATH', 
        p_url_mapping_pattern => 'surety_api',
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
END;
/

/*
SOLUTION 4: Delete and recreate module ensuring it's in correct schema
--------------------------------------
*/
-- Make absolutely sure you're connected as SURETY
SELECT USER FROM DUAL;

-- Delete existing
BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'surety.v1');
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- Recreate
BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'surety.v1',
        p_base_path      => '/surety/',
        p_items_per_page => 25,
        p_status         => 'PUBLISHED'
    );
    
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'surety.v1',
        p_pattern     => 'upload_policy/'
    );
    
    ORDS.DEFINE_HANDLER(
        p_module_name => 'surety.v1',
        p_pattern     => 'upload_policy/',
        p_method      => 'GET',
        p_source_type => 'plsql/block',
        p_source      => 'BEGIN HTP.P(''{"status":"ok","method":"GET"}''); END;'
    );
    
    ORDS.DEFINE_HANDLER(
        p_module_name  => 'surety.v1',
        p_pattern      => 'upload_policy/',
        p_method       => 'POST',
        p_source_type  => 'plsql/block',
        p_mimes_allowed => 'application/json',
        p_source       => 'BEGIN HTP.P(''{"status":"ok","method":"POST"}''); END;'
    );
    
    COMMIT;
END;
/

-- Verify creation
SELECT name, uri_prefix, status, created_by 
FROM user_ords_modules 
WHERE name = 'surety.v1';
