/*
================================================================================
  ORDS User Queries - Using USER_ORDS Views
================================================================================
  Purpose: Standard queries for schema users to view their own ORDS metadata
  Execute As: Schema user (e.g., SURETY)
  
  These views are accessible without additional privileges because they:
  1. Are exposed via PUBLIC synonyms
  2. Automatically filter to show only the current schema's data
================================================================================
*/

SET LINESIZE 200
SET PAGESIZE 100
COLUMN name FORMAT A30
COLUMN uri_prefix FORMAT A30
COLUMN uri_template FORMAT A40
COLUMN method FORMAT A8
COLUMN source_type FORMAT A20
COLUMN module_name FORMAT A30
COLUMN status FORMAT A12

PROMPT ============================================================
PROMPT  ORDS MODULES - Current Schema
PROMPT ============================================================

SELECT 
    name,
    uri_prefix,
    status,
    items_per_page,
    TO_CHAR(created_on, 'YYYY-MM-DD HH24:MI:SS') AS created_on,
    TO_CHAR(updated_on, 'YYYY-MM-DD HH24:MI:SS') AS updated_on
FROM user_ords_modules
ORDER BY name;

PROMPT ============================================================
PROMPT  ORDS TEMPLATES - URI Patterns
PROMPT ============================================================

SELECT 
    module_name,
    uri_template,
    priority,
    etag_type
FROM user_ords_templates
ORDER BY module_name, priority;

PROMPT ============================================================
PROMPT  ORDS HANDLERS - HTTP Methods
PROMPT ============================================================

SELECT 
    module_name,
    uri_template,
    method,
    source_type,
    items_per_page
FROM user_ords_handlers
ORDER BY module_name, uri_template, method;

PROMPT ============================================================
PROMPT  ORDS PARAMETERS - Handler Parameters
PROMPT ============================================================

SELECT 
    module_name,
    uri_template,
    method,
    name AS param_name,
    bind_variable_name,
    source_type AS param_source,
    param_type,
    access_method
FROM user_ords_parameters
ORDER BY module_name, uri_template, method, name;

PROMPT ============================================================
PROMPT  ORDS PRIVILEGES - Security Configuration
PROMPT ============================================================

SELECT 
    name AS privilege_name,
    label,
    description
FROM user_ords_privileges
ORDER BY name;

PROMPT ============================================================
PROMPT  ORDS ROLES - Defined Roles
PROMPT ============================================================

SELECT 
    name AS role_name
FROM user_ords_roles
ORDER BY name;

PROMPT ============================================================
PROMPT  ORDS SCHEMA STATUS
PROMPT ============================================================

-- Check if current schema is ORDS-enabled
SELECT 
    url_mapping_type,
    url_mapping_pattern,
    auto_rest_auth
FROM user_ords_schemas;

PROMPT ============================================================
PROMPT  AutoREST Enabled Objects
PROMPT ============================================================

SELECT 
    object_type,
    object_name,
    object_alias,
    status,
    auto_rest_auth
FROM user_ords_services
ORDER BY object_type, object_name;

PROMPT
PROMPT Query completed successfully using USER_ORDS views.
PROMPT These views only show data for the current schema.
PROMPT
