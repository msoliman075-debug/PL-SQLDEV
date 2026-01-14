/*
================================================================================
  Fix ORDS Handler - Examples for Common Syntax Errors
================================================================================
  Purpose: Examples of how to fix PL/SQL syntax errors in ORDS handlers
  
  Error: PLS-00103: Encountered the symbol "APPLICATION"
  
  This script shows how to update handlers with corrected syntax.
================================================================================
*/

SET SERVEROUTPUT ON

/*
================================================================================
  Example 1: Fix V() function usage (APEX substitution)
================================================================================
  The APEX V() function requires the substitution name in QUOTES
  
  WRONG: V(APPLICATION_ID) or V(APPLICATION ID)
  RIGHT: V('APP_ID')
================================================================================
*/

-- Example: Update a handler with correct V() syntax
BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'surety.v1',           -- Your module name
        p_pattern        => 'your_endpoint/',       -- Your URI template
        p_method         => 'GET',
        p_source_type    => 'json/collection',
        p_source         => q'[
            SELECT employee_id, first_name, last_name
            FROM employees
            WHERE application_id = V('APP_ID')  -- Correct: quotes around APP_ID
        ]'
    );
    COMMIT;
END;
/

/*
================================================================================
  Example 2: Fix string literal without quotes
================================================================================
  String values must be enclosed in single quotes
  
  WRONG: WHERE status = APPLICATION
  RIGHT: WHERE status = 'APPLICATION'
================================================================================
*/

BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'surety.v1',
        p_pattern        => 'your_endpoint/',
        p_method         => 'GET',
        p_source_type    => 'json/collection',
        p_source         => q'[
            SELECT id, name, status
            FROM some_table
            WHERE status = 'APPLICATION'  -- Correct: string in quotes
        ]'
    );
    COMMIT;
END;
/

/*
================================================================================
  Example 3: Fix bind variable with space
================================================================================
  Bind variables cannot contain spaces
  
  WRONG: :APPLICATION ID or :application id
  RIGHT: :application_id (use underscore)
================================================================================
*/

BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'surety.v1',
        p_pattern        => 'items/:application_id',  -- Correct: underscore
        p_method         => 'GET',
        p_source_type    => 'json/collection',
        p_source         => q'[
            SELECT id, name
            FROM items
            WHERE application_id = :application_id  -- Correct: underscore
        ]'
    );
    COMMIT;
END;
/

/*
================================================================================
  Example 4: Fix NVL/COALESCE with APEX functions
================================================================================
  When mixing APEX V() with NVL, ensure proper quoting
  
  WRONG: NVL(V(APP_ID), 0)
  RIGHT: NVL(V('APP_ID'), 0)
================================================================================
*/

BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'surety.v1',
        p_pattern        => 'data/',
        p_method         => 'GET',
        p_source_type    => 'json/collection',
        p_source         => q'[
            SELECT id, name
            FROM my_table
            WHERE app_id = NVL(V('APP_ID'), :default_app_id)
        ]'
    );
    COMMIT;
END;
/

/*
================================================================================
  How to identify and fix your specific handler
================================================================================
  
  Step 1: Find the problematic endpoint
  
  Look at the URL you were calling when you got the error.
  For example: /ords/surety/surety/some_endpoint
  
  The URI pattern would be: some_endpoint or some_endpoint/
  
  Step 2: Get the current source (run as SYS or with grants)
*/

-- Query to find handlers containing "APPLICATION"
SELECT 
    m.name AS module_name,
    t.uri_template,
    h.method,
    h.source
FROM ords_metadata.ords_handlers h
JOIN ords_metadata.ords_templates t ON h.template_id = t.id
JOIN ords_metadata.ords_modules m ON t.module_id = m.id
JOIN ords_metadata.ords_schemas s ON m.schema_id = s.id
WHERE s.parsing_schema = 'SURETY'
AND (
    UPPER(h.source) LIKE '%APPLICATION%'
    OR UPPER(h.source) LIKE '%V(APP%'
);

/*
  Step 3: Fix the handler
  
  Once you identify the problematic source, use ORDS.DEFINE_HANDLER
  to update it with the corrected SQL/PL/SQL.
*/

/*
================================================================================
  Delete a handler if needed
================================================================================
*/

-- To delete a specific handler:
-- BEGIN
--     ORDS.DELETE_HANDLER(
--         p_module_name => 'surety.v1',
--         p_pattern     => 'problematic_endpoint/',
--         p_method      => 'GET'
--     );
--     COMMIT;
-- END;
-- /

/*
================================================================================
  Test your fix
================================================================================
  
  After updating the handler, test it:
  
  curl -X GET "http://your-server/ords/surety/surety/your_endpoint"
  
  Or in browser: http://your-server/ords/surety/surety/your_endpoint
================================================================================
*/
