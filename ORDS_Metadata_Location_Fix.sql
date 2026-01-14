--------------------------------------------------------------------------------
-- ORDS Metadata Location Investigation
-- Issue: Modules exist in DB but ORDS can't see them
-- Both hr/employees and surety/upload_policy return 404
--------------------------------------------------------------------------------

-- 1. Check where USER_ORDS_MODULES view points to
SELECT owner, synonym_name, table_owner, table_name
FROM all_synonyms 
WHERE synonym_name IN ('USER_ORDS_MODULES', 'USER_ORDS_SCHEMAS', 'USER_ORDS_TEMPLATES');

-- 2. Check ORDS-related users
SELECT username, created, account_status
FROM all_users 
WHERE username LIKE '%ORDS%'
ORDER BY username;

-- 3. Check ORDS metadata tables ownership
SELECT owner, table_name 
FROM all_tables 
WHERE table_name LIKE 'ORDS_%'
ORDER BY owner, table_name;

-- 4. Check if there's an ORDS_METADATA schema with modules
SELECT owner, COUNT(*) as module_count
FROM all_objects 
WHERE object_name LIKE '%ORDS%MODULE%'
GROUP BY owner;

-- 5. Check the actual source of module data
-- If modules are in ORDS_METADATA schema, query there:
SELECT * FROM ords_metadata.user_ords_modules;
-- (This might error if ORDS_METADATA doesn't exist or you don't have access)

--------------------------------------------------------------------------------
-- SOLUTION: RE-REGISTER SCHEMA WITH ORDS
-- The schema URL mapping might need to be refreshed
--------------------------------------------------------------------------------

-- Run as SYS or ADMIN with ORDS privileges:

-- First, check current ORDS schema registrations
SELECT parsing_schema, pattern, status 
FROM ords_metadata.ords_schemas
WHERE parsing_schema = 'SURETY';
-- (Adjust table name based on your ORDS version)

-- Option 1: Use ORDS_ADMIN package (if available)
BEGIN
    ORDS_ADMIN.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'SURETY',
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'surety_api',
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
END;
/

-- Option 2: Re-enable as SURETY user
-- Connect as SURETY and run:
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
-- ALTERNATIVE: CHECK IF ORDS IS USING A DIFFERENT METADATA REPOSITORY
--------------------------------------------------------------------------------

/*
ORDS can store metadata in two ways:

1. ORDS_METADATA schema (centralized) - ORDS 18.1+
   - All REST definitions stored in ORDS_METADATA schema
   - Schemas are registered in ORDS_METADATA.ORDS_SCHEMAS
   
2. Per-schema metadata (legacy)
   - Each schema has its own ORDS_* tables
   - USER_ORDS_* views query local tables

If your ORDS installation uses ORDS_METADATA but you're creating modules
in the local schema tables, ORDS won't see them!

To check:
*/

-- See if ORDS_METADATA schema exists and has your schema registered
SELECT * FROM all_users WHERE username = 'ORDS_METADATA';

-- If it exists, check registrations there (run as DBA):
-- SELECT * FROM ords_metadata.ords_schemas;
-- SELECT * FROM ords_metadata.ords_modules;

--------------------------------------------------------------------------------
-- FIX: If using ORDS_METADATA, register modules there
--------------------------------------------------------------------------------

/*
If ORDS uses centralized metadata (ORDS_METADATA schema), you need to:

1. Connect as a user with ORDS_ADMINISTRATOR_ROLE or as SYS
2. Use ORDS_ADMIN package instead of ORDS package
3. Or use SQL Developer's REST Data Services wizard

Example using ORDS_ADMIN (run as privileged user):
*/

BEGIN
    -- Enable schema in ORDS_METADATA
    ORDS_ADMIN.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'SURETY',
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'surety_api',
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
END;
/

-- Define module via ORDS_ADMIN
BEGIN
    ORDS_ADMIN.DEFINE_MODULE(
        p_schema         => 'SURETY',
        p_module_name    => 'surety.v1',
        p_base_path      => '/surety/',
        p_items_per_page => 25,
        p_status         => 'PUBLISHED'
    );
    COMMIT;
END;
/

BEGIN
    ORDS_ADMIN.DEFINE_TEMPLATE(
        p_schema      => 'SURETY',
        p_module_name => 'surety.v1',
        p_pattern     => 'upload_policy/'
    );
    COMMIT;
END;
/

BEGIN
    ORDS_ADMIN.DEFINE_HANDLER(
        p_schema      => 'SURETY',
        p_module_name => 'surety.v1',
        p_pattern     => 'upload_policy/',
        p_method      => 'GET',
        p_source_type => 'plsql/block',
        p_source      => 'BEGIN HTP.P(''{"status":"success"}''); END;'
    );
    COMMIT;
END;
/

--------------------------------------------------------------------------------
-- VERIFICATION AFTER FIX
--------------------------------------------------------------------------------

-- Check in ORDS_METADATA (if it exists):
SELECT m.name, m.uri_prefix, m.status
FROM ords_metadata.ords_modules m
JOIN ords_metadata.ords_schemas s ON m.schema_id = s.id
WHERE s.parsing_schema = 'SURETY';

-- Then restart Tomcat and test:
-- sudo systemctl restart tomcat
-- curl http://ai.suretysa.com:8080/ords/surety_api/surety/upload_policy/
