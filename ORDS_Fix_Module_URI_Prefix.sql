--------------------------------------------------------------------------------
-- ORDS Fix: Module URI Prefix Mismatch
-- Issue: URL uses /surety/ but module has /surety_1/
--------------------------------------------------------------------------------

/*
PROBLEM IDENTIFIED:
- Your URL: /ords/surety_api/surety/upload_policy/
- Module surety.upload has URI_PREFIX: /surety_1/  <-- MISMATCH!
- This causes 404 Not Found

SOLUTION OPTIONS:
1. Change your URL to use /surety_1/ (quick fix)
2. Update the module URI_PREFIX to /surety/ (permanent fix)
3. Use the new surety.v1 module that was just created (already has /surety/)
*/

--------------------------------------------------------------------------------
-- OPTION 1: Quick Fix - Use the correct URL
--------------------------------------------------------------------------------
-- Try this URL instead:
-- http://ai.suretysa.com:8080/ords/surety_api/surety_1/upload_policy/
-- (Note: surety_1 instead of surety)

--------------------------------------------------------------------------------
-- OPTION 2: Update existing module URI_PREFIX from /surety_1/ to /surety/
--------------------------------------------------------------------------------

-- First, check current module details
SELECT id, name, uri_prefix, status 
FROM user_ords_modules 
WHERE name = 'surety.upload';

-- Delete the old module and recreate with correct prefix
-- WARNING: This will remove all templates and handlers - backup first!

-- Backup: View current handlers
SELECT m.name, t.uri_template, h.method, h.source_type, h.source
FROM user_ords_modules m
JOIN user_ords_templates t ON m.id = t.module_id
JOIN user_ords_handlers h ON t.id = h.template_id
WHERE m.name = 'surety.upload';

-- Update module URI prefix (ORDS 22.1+)
BEGIN
    ORDS.SET_MODULE(
        p_module_name => 'surety.upload',
        p_base_path   => '/surety/',       -- Changed from /surety_1/
        p_status      => 'PUBLISHED'
    );
    COMMIT;
END;
/

-- If SET_MODULE doesn't work, delete and recreate:
/*
BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'surety.upload');
    COMMIT;
END;
/

BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'surety.upload',
        p_base_path      => '/surety/',
        p_items_per_page => 25,
        p_status         => 'PUBLISHED',
        p_comments       => 'Surety Upload API'
    );
    COMMIT;
END;
/
-- Then recreate your templates and handlers
*/

--------------------------------------------------------------------------------
-- OPTION 3: Use the new surety.v1 module (RECOMMENDED)
--------------------------------------------------------------------------------
-- The script already created surety.v1 with correct /surety/ prefix
-- Your URL /ords/surety_api/surety/upload_policy/ should now work!

-- Verify it exists:
SELECT m.name, m.uri_prefix, m.status, t.uri_template, h.method
FROM user_ords_modules m
JOIN user_ords_templates t ON m.id = t.module_id
JOIN user_ords_handlers h ON t.id = h.template_id
WHERE m.name = 'surety.v1';

--------------------------------------------------------------------------------
-- CLEANUP: Remove duplicate module if you only need one
--------------------------------------------------------------------------------

-- If you want to keep only surety.v1 (with /surety/):
/*
BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'surety.upload');
    COMMIT;
END;
/
*/

-- If you want to keep only surety.upload (but fix its prefix):
/*
BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'surety.v1');
    COMMIT;
END;
/
*/

--------------------------------------------------------------------------------
-- VERIFICATION: Test your endpoints
--------------------------------------------------------------------------------

-- After fixing, your URLs should be:
-- GET:  http://ai.suretysa.com:8080/ords/surety_api/surety/upload_policy/
-- POST: http://ai.suretysa.com:8080/ords/surety_api/surety/upload_policy/

-- Complete URL structure:
-- http://[server]:[port]/ords/[schema_pattern]/[module_uri_prefix]/[template]/
-- http://ai.suretysa.com:8080/ords/surety_api/surety/upload_policy/
--                              └── surety_api = schema pattern
--                                              └── surety = module uri_prefix  
--                                                       └── upload_policy = template

--------------------------------------------------------------------------------
-- WHY ERROR CODE WAS EMPTY
--------------------------------------------------------------------------------
/*
The "Error Code:" field in ORDS error responses is ONLY populated when:
1. Your PL/SQL handler executes AND
2. The handler explicitly raises an error with a custom code

For 404 errors (resource not found):
- ORDS cannot find a matching route
- No PL/SQL handler is executed
- Therefore no custom error code is generated
- The Error Code field remains EMPTY

This is expected ORDS behavior - not a bug!
*/
