/*
================================================================================
  ORDS Diagnostic Queries
================================================================================
  Purpose: Diagnose ORDS configuration and privilege issues
  
  Section A: Run as Regular User (e.g., SURETY)
  Section B: Run as SYS/DBA
================================================================================
*/

SET LINESIZE 200
SET PAGESIZE 100

PROMPT ============================================================
PROMPT  SECTION A: Queries for Regular Users
PROMPT  (Run as the schema user, e.g., SURETY)
PROMPT ============================================================

PROMPT
PROMPT --- A1: Check if current user can access USER_ORDS views ---
PROMPT

SELECT 
    synonym_name,
    table_owner,
    table_name
FROM all_synonyms
WHERE synonym_name LIKE 'USER_ORDS%'
AND owner = 'PUBLIC'
ORDER BY synonym_name;

PROMPT
PROMPT --- A2: Check current user's ORDS modules ---
PROMPT

SELECT name, uri_prefix, status 
FROM user_ords_modules;

PROMPT
PROMPT --- A3: Check current schema ORDS enablement ---
PROMPT

SELECT url_mapping_type, url_mapping_pattern, auto_rest_auth
FROM user_ords_schemas;

PROMPT
PROMPT --- A4: List available ORDS-related synonyms ---
PROMPT

SELECT synonym_name 
FROM all_synonyms 
WHERE synonym_name LIKE '%ORDS%' 
AND owner = 'PUBLIC'
ORDER BY synonym_name;

PROMPT
PROMPT ============================================================
PROMPT  SECTION B: DBA Diagnostic Queries
PROMPT  (Run as SYS or DBA user)
PROMPT ============================================================

PROMPT
PROMPT --- B1: Check ORDS_METADATA schema exists ---
PROMPT

SELECT username, account_status, created 
FROM dba_users 
WHERE username = 'ORDS_METADATA';

PROMPT
PROMPT --- B2: List all ORDS-enabled schemas ---
PROMPT

SELECT 
    s.parsing_schema,
    s.url_mapping_type,
    s.url_mapping_pattern,
    s.status
FROM ords_metadata.ords_schemas s
ORDER BY s.parsing_schema;

PROMPT
PROMPT --- B3: List all ORDS modules across all schemas ---
PROMPT

SELECT 
    s.parsing_schema,
    m.name AS module_name,
    m.uri_prefix,
    m.status,
    m.items_per_page
FROM ords_metadata.ords_modules m
JOIN ords_metadata.ords_schemas s ON m.schema_id = s.id
ORDER BY s.parsing_schema, m.name;

PROMPT
PROMPT --- B4: Check grants on ORDS_METADATA tables ---
PROMPT

SELECT 
    grantee,
    table_name,
    privilege,
    grantable
FROM dba_tab_privs
WHERE owner = 'ORDS_METADATA'
AND grantee NOT IN ('SYS', 'SYSTEM', 'ORDS_METADATA')
ORDER BY grantee, table_name;

PROMPT
PROMPT --- B5: Check ORDS_PUBLIC_USER status ---
PROMPT

SELECT 
    username,
    account_status,
    default_tablespace,
    created
FROM dba_users
WHERE username = 'ORDS_PUBLIC_USER';

PROMPT
PROMPT --- B6: Verify ORDS_METADATA objects ---
PROMPT

SELECT 
    object_type,
    COUNT(*) AS object_count
FROM dba_objects
WHERE owner = 'ORDS_METADATA'
GROUP BY object_type
ORDER BY object_type;

PROMPT
PROMPT --- B7: Check PUBLIC synonyms for USER_ORDS views ---
PROMPT

SELECT 
    synonym_name,
    table_owner,
    table_name
FROM dba_synonyms
WHERE owner = 'PUBLIC'
AND table_owner = 'ORDS_METADATA'
AND synonym_name LIKE 'USER_ORDS%'
ORDER BY synonym_name;

PROMPT
PROMPT --- B8: Check if SURETY schema is ORDS-enabled ---
PROMPT

SELECT 
    parsing_schema,
    url_mapping_type,
    url_mapping_pattern,
    status,
    auto_rest_auth
FROM ords_metadata.ords_schemas
WHERE parsing_schema = 'SURETY';

PROMPT
PROMPT --- B9: Full module details for SURETY ---
PROMPT

SELECT 
    s.parsing_schema,
    m.name AS module_name,
    m.uri_prefix,
    m.status,
    m.items_per_page,
    t.uri_template,
    h.method,
    h.source_type
FROM ords_metadata.ords_modules m
JOIN ords_metadata.ords_schemas s ON m.schema_id = s.id
LEFT JOIN ords_metadata.ords_templates t ON t.module_id = m.id
LEFT JOIN ords_metadata.ords_handlers h ON h.template_id = t.id
WHERE s.parsing_schema = 'SURETY'
ORDER BY m.name, t.uri_template, h.method;

PROMPT
PROMPT --- B10: Check role and privilege assignments ---
PROMPT

SELECT 
    r.name AS role_name,
    p.name AS privilege_name,
    pm.pattern AS url_pattern
FROM ords_metadata.ords_roles r
LEFT JOIN ords_metadata.ords_privilege_roles pr ON r.id = pr.role_id
LEFT JOIN ords_metadata.ords_privileges p ON p.id = pr.privilege_id
LEFT JOIN ords_metadata.ords_privilege_mappings pm ON p.id = pm.privilege_id
ORDER BY r.name, p.name;

PROMPT
PROMPT ============================================================
PROMPT  Diagnostic queries completed
PROMPT ============================================================
