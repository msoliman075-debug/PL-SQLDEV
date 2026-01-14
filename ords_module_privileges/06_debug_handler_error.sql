/*
================================================================================
  Debug ORDS Handler Error - ORDS-25001 / ORA-06550
================================================================================
  Purpose: Find and diagnose PL/SQL syntax errors in ORDS handlers
  
  Error: PLS-00103: Encountered the symbol "APPLICATION" when expecting...
  
  This error indicates a syntax problem in a handler's SQL/PL/SQL source.
  Common causes:
  1. Missing quotes around string literals
  2. Incorrect bind variable syntax (:param vs :param.)
  3. APEX substitutions used incorrectly (V('APP_ID') syntax)
  4. Reserved words used without quotes
================================================================================
*/

SET LINESIZE 300
SET PAGESIZE 200
SET LONG 10000
SET LONGCHUNKSIZE 10000
COLUMN source FORMAT A200 WORD_WRAPPED

PROMPT ============================================================
PROMPT  Step 1: List all handlers in SURETY schema
PROMPT ============================================================

SELECT * FROM user_ords_handlers;

PROMPT ============================================================
PROMPT  Step 2: View handler source code (DBA query)
PROMPT  Run as SYS to see the actual SQL/PL/SQL source
PROMPT ============================================================

-- Run this as SYS or with grants on ords_metadata tables
SELECT 
    s.parsing_schema,
    m.name AS module_name,
    m.uri_prefix,
    t.uri_template,
    h.method,
    h.source_type,
    h.source
FROM ords_metadata.ords_handlers h
JOIN ords_metadata.ords_templates t ON h.template_id = t.id
JOIN ords_metadata.ords_modules m ON t.module_id = m.id
JOIN ords_metadata.ords_schemas s ON m.schema_id = s.id
WHERE s.parsing_schema = 'SURETY'
ORDER BY m.name, t.uri_template, h.method;

PROMPT ============================================================
PROMPT  Step 3: Search for "APPLICATION" in handler source
PROMPT ============================================================

SELECT 
    s.parsing_schema,
    m.name AS module_name,
    t.uri_template,
    h.method,
    h.source
FROM ords_metadata.ords_handlers h
JOIN ords_metadata.ords_templates t ON h.template_id = t.id
JOIN ords_metadata.ords_modules m ON t.module_id = m.id
JOIN ords_metadata.ords_schemas s ON m.schema_id = s.id
WHERE s.parsing_schema = 'SURETY'
AND UPPER(h.source) LIKE '%APPLICATION%'
ORDER BY m.name;

PROMPT ============================================================
PROMPT  Step 4: Check handler parameters
PROMPT ============================================================

SELECT * FROM user_ords_parameters;

PROMPT ============================================================
PROMPT  Common Fixes for PLS-00103 with "APPLICATION"
PROMPT ============================================================
PROMPT
PROMPT  Issue 1: APEX V() function used incorrectly
PROMPT  -------------------------------------------------
PROMPT  WRONG:  WHERE app_id = V(APPLICATION ID)
PROMPT  RIGHT:  WHERE app_id = V('APP_ID')
PROMPT
PROMPT  Issue 2: Missing quotes around APPLICATION
PROMPT  -------------------------------------------------
PROMPT  WRONG:  WHERE status = APPLICATION
PROMPT  RIGHT:  WHERE status = 'APPLICATION'
PROMPT
PROMPT  Issue 3: Bind variable syntax error
PROMPT  -------------------------------------------------
PROMPT  WRONG:  WHERE app_id = :APPLICATION ID
PROMPT  RIGHT:  WHERE app_id = :application_id
PROMPT
PROMPT  Issue 4: Using reserved word as column alias
PROMPT  -------------------------------------------------
PROMPT  WRONG:  SELECT id AS APPLICATION FROM ...
PROMPT  RIGHT:  SELECT id AS "APPLICATION" FROM ...
PROMPT
PROMPT ============================================================
