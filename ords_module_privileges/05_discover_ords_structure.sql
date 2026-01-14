/*
================================================================================
  ORDS Structure Discovery Script
================================================================================
  Purpose: Discover actual column names in USER_ORDS views
           Column names vary between ORDS versions
  Execute As: Schema user (e.g., SURETY)
================================================================================
*/

SET LINESIZE 200
SET PAGESIZE 100
COLUMN table_name FORMAT A30
COLUMN column_name FORMAT A30
COLUMN data_type FORMAT A20

PROMPT ============================================================
PROMPT  Discovering USER_ORDS View Structures
PROMPT ============================================================

PROMPT
PROMPT --- USER_ORDS_MODULES columns ---
SELECT column_name, data_type, column_id
FROM all_tab_columns
WHERE table_name = 'USER_ORDS_MODULES'
AND owner = 'ORDS_METADATA'
ORDER BY column_id;

PROMPT
PROMPT --- USER_ORDS_TEMPLATES columns ---
SELECT column_name, data_type, column_id
FROM all_tab_columns
WHERE table_name = 'USER_ORDS_TEMPLATES'
AND owner = 'ORDS_METADATA'
ORDER BY column_id;

PROMPT
PROMPT --- USER_ORDS_HANDLERS columns ---
SELECT column_name, data_type, column_id
FROM all_tab_columns
WHERE table_name = 'USER_ORDS_HANDLERS'
AND owner = 'ORDS_METADATA'
ORDER BY column_id;

PROMPT
PROMPT --- USER_ORDS_PARAMETERS columns ---
SELECT column_name, data_type, column_id
FROM all_tab_columns
WHERE table_name = 'USER_ORDS_PARAMETERS'
AND owner = 'ORDS_METADATA'
ORDER BY column_id;

PROMPT
PROMPT --- USER_ORDS_SCHEMAS columns ---
SELECT column_name, data_type, column_id
FROM all_tab_columns
WHERE table_name = 'USER_ORDS_SCHEMAS'
AND owner = 'ORDS_METADATA'
ORDER BY column_id;

PROMPT
PROMPT --- USER_ORDS_SERVICES columns ---
SELECT column_name, data_type, column_id
FROM all_tab_columns
WHERE table_name = 'USER_ORDS_SERVICES'
AND owner = 'ORDS_METADATA'
ORDER BY column_id;

PROMPT
PROMPT --- USER_ORDS_PRIVILEGES columns ---
SELECT column_name, data_type, column_id
FROM all_tab_columns
WHERE table_name = 'USER_ORDS_PRIVILEGES'
AND owner = 'ORDS_METADATA'
ORDER BY column_id;

PROMPT
PROMPT --- USER_ORDS_ROLES columns ---
SELECT column_name, data_type, column_id
FROM all_tab_columns
WHERE table_name = 'USER_ORDS_ROLES'
AND owner = 'ORDS_METADATA'
ORDER BY column_id;

PROMPT
PROMPT ============================================================
PROMPT  List all available USER_ORDS views
PROMPT ============================================================

SELECT DISTINCT table_name
FROM all_tab_columns
WHERE owner = 'ORDS_METADATA'
AND table_name LIKE 'USER_ORDS%'
ORDER BY table_name;

PROMPT
PROMPT ============================================================
PROMPT  DBA: List all tables in ORDS_METADATA schema
PROMPT  (Run as SYS if the above doesn't work)
PROMPT ============================================================

-- SELECT object_name, object_type
-- FROM dba_objects
-- WHERE owner = 'ORDS_METADATA'
-- AND object_type IN ('TABLE', 'VIEW')
-- ORDER BY object_type, object_name;
