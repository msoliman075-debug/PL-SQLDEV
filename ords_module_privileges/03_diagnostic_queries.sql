/*
================================================================================
  ORDS Diagnostic Queries
================================================================================
  Purpose: Diagnose ORDS configuration and privilege issues
  
  Section A: Run as Regular User (e.g., SURETY)
  Section B: Run as SYS/DBA
  
  NOTE: Column names vary between ORDS versions. Uses SELECT * where possible.
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

SELECT * FROM user_ords_modules;

PROMPT
PROMPT --- A3: Check current schema ORDS enablement ---
PROMPT

SELECT * FROM user_ords_schemas;

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

SELECT * FROM ords_metadata.ords_schemas
ORDER BY 1;

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
PROMPT --- B6: Verify ORDS_METADATA objects (tables and views) ---
PROMPT

SELECT 
    object_name,
    object_type
FROM dba_objects
WHERE owner = 'ORDS_METADATA'
AND object_type IN ('TABLE', 'VIEW')
ORDER BY object_type, object_name;

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
PROMPT --- B8: Check SURETY modules with templates and handlers ---
PROMPT

SELECT 
    s.parsing_schema,
    m.name AS module_name,
    m.uri_prefix,
    m.status
FROM ords_metadata.ords_modules m
JOIN ords_metadata.ords_schemas s ON m.schema_id = s.id
WHERE s.parsing_schema = 'SURETY'
ORDER BY m.name;

PROMPT
PROMPT --- B9: List all ORDS_METADATA tables (for grant reference) ---
PROMPT

SELECT table_name 
FROM dba_tables 
WHERE owner = 'ORDS_METADATA'
ORDER BY table_name;

PROMPT
PROMPT --- B10: Check column names in key ORDS_METADATA tables ---
PROMPT

SELECT table_name, column_name, data_type
FROM dba_tab_columns
WHERE owner = 'ORDS_METADATA'
AND table_name IN ('ORDS_MODULES', 'ORDS_SCHEMAS', 'ORDS_TEMPLATES', 'ORDS_HANDLERS')
ORDER BY table_name, column_id;

PROMPT
PROMPT ============================================================
PROMPT  Diagnostic queries completed
PROMPT ============================================================
