/*
================================================================================
  ORDS Quick Reference - Common Operations
================================================================================
  Purpose: Quick reference for ORDS PL/SQL API operations
  Execute As: Schema user (e.g., SURETY)
================================================================================
*/

SET SERVEROUTPUT ON

PROMPT ============================================================
PROMPT  Quick Reference: ORDS PL/SQL API
PROMPT ============================================================

/*
================================================================================
  1. ENABLE SCHEMA FOR ORDS
================================================================================
*/

-- Enable current schema for ORDS REST access
BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'SURETY',  -- Optional, defaults to current
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'surety',
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
END;
/

/*
================================================================================
  2. CREATE A MODULE
================================================================================
*/

BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'example.api',
        p_base_path      => '/api/v1/',
        p_items_per_page => 25,
        p_status         => 'PUBLISHED',
        p_comments       => 'Example API Module'
    );
    COMMIT;
END;
/

/*
================================================================================
  3. CREATE A TEMPLATE (URI Pattern)
================================================================================
*/

BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'example.api',
        p_pattern        => 'employees/',
        p_priority       => 0,
        p_etag_type      => 'HASH',
        p_comments       => 'Employees endpoint'
    );
    COMMIT;
END;
/

/*
================================================================================
  4. CREATE A HANDLER (HTTP Method)
================================================================================
*/

-- GET Handler (Query)
BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'example.api',
        p_pattern        => 'employees/',
        p_method         => 'GET',
        p_source_type    => 'json/collection',
        p_source         => 'SELECT employee_id, first_name, last_name, email FROM employees',
        p_items_per_page => 25
    );
    COMMIT;
END;
/

-- POST Handler (Insert)
BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'example.api',
        p_pattern        => 'employees/',
        p_method         => 'POST',
        p_source_type    => 'plsql/block',
        p_source         => '
            BEGIN
                INSERT INTO employees (first_name, last_name, email)
                VALUES (:first_name, :last_name, :email);
                :status := 201;
            END;'
    );
    COMMIT;
END;
/

/*
================================================================================
  5. DELETE MODULE (and all its templates/handlers)
================================================================================
*/

BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'example.api');
    COMMIT;
END;
/

/*
================================================================================
  6. QUERY YOUR MODULES (Using USER_ORDS views)
================================================================================
*/

-- List all modules
SELECT name, uri_prefix, status FROM user_ords_modules;

-- List templates
SELECT module_name, uri_template FROM user_ords_templates;

-- List handlers
SELECT module_name, uri_template, method, source_type FROM user_ords_handlers;

/*
================================================================================
  7. ENABLE AutoREST on a TABLE
================================================================================
*/

BEGIN
    ORDS.ENABLE_OBJECT(
        p_enabled        => TRUE,
        p_schema         => 'SURETY',
        p_object         => 'EMPLOYEES',
        p_object_type    => 'TABLE',
        p_object_alias   => 'employees',
        p_auto_rest_auth => FALSE
    );
    COMMIT;
END;
/

-- Query AutoREST enabled objects
SELECT object_name, object_alias, status FROM user_ords_services;

/*
================================================================================
  8. DISABLE AutoREST on a TABLE
================================================================================
*/

BEGIN
    ORDS.ENABLE_OBJECT(
        p_enabled     => FALSE,
        p_schema      => 'SURETY',
        p_object      => 'EMPLOYEES',
        p_object_type => 'TABLE'
    );
    COMMIT;
END;
/

/*
================================================================================
  IMPORTANT: Why use USER_ORDS views instead of ORDS_METADATA tables?
================================================================================

  1. USER_ORDS views are automatically available to all schema users
  2. No special privileges required
  3. Data is automatically filtered to current schema only
  4. Views are stable across ORDS versions
  5. Internal ORDS_METADATA structure may change between versions

  Available USER_ORDS views:
  - USER_ORDS_MODULES      : Your REST modules
  - USER_ORDS_TEMPLATES    : URI templates in your modules
  - USER_ORDS_HANDLERS     : HTTP handlers (GET, POST, etc.)
  - USER_ORDS_PARAMETERS   : Handler parameters
  - USER_ORDS_PRIVILEGES   : ORDS privileges
  - USER_ORDS_ROLES        : ORDS roles
  - USER_ORDS_SCHEMAS      : Your schema ORDS settings
  - USER_ORDS_SERVICES     : AutoREST enabled objects
  - USER_ORDS_URL_MAPPINGS : URL mapping patterns
================================================================================
*/
