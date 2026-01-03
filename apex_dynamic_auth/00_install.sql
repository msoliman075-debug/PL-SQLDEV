/*
================================================================================
  Dynamic Authorization Scheme - Installation Script
  Oracle APEX Security Framework
  
  Purpose: Master installation script for the authorization framework
  
  Target: Oracle 19c+ / Oracle APEX 21.1+
  
  Usage: 
    SQL> @00_install.sql
  
  Or run individual scripts in order:
    1. 01_ddl_tables.sql
    2. 02_pkg_spec.sql
    3. 03_pkg_body.sql
    4. 04_sample_data.sql (optional - for testing)
    5. 05_apex_usage_guide.sql (reference and views)
  
================================================================================
*/

SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET FEEDBACK ON
SET LINESIZE 200

PROMPT ========================================
PROMPT  Dynamic Authorization Scheme Installer
PROMPT  Oracle APEX Security Framework
PROMPT ========================================
PROMPT

PROMPT Installing DDL Tables...
@@01_ddl_tables.sql

PROMPT
PROMPT Installing Package Specification...
@@02_pkg_spec.sql

PROMPT
PROMPT Installing Package Body...
@@03_pkg_body.sql

PROMPT
PROMPT Creating Helper Views...
@@05_apex_usage_guide.sql

PROMPT
PROMPT ========================================
PROMPT  Installation Complete!
PROMPT ========================================
PROMPT
PROMPT Objects Created:
PROMPT   Tables:
PROMPT     - APEX_AUTH_ROLES
PROMPT     - APEX_AUTH_USER_ROLES
PROMPT     - APEX_AUTH_COMPONENT_TYPES
PROMPT     - APEX_AUTH_COMPONENTS
PROMPT     - APEX_AUTH_PERMISSIONS
PROMPT     - APEX_AUTH_AUDIT_LOG
PROMPT
PROMPT   Package:
PROMPT     - APEX_AUTH_PKG
PROMPT
PROMPT   Views:
PROMPT     - V_APEX_AUTH_USER_EFFECTIVE_PERMS
PROMPT     - V_APEX_AUTH_ROLE_PERMS
PROMPT
PROMPT ========================================
PROMPT  Next Steps:
PROMPT ========================================
PROMPT  1. Run 04_sample_data.sql to load test data
PROMPT  2. Create Authorization Schemes in APEX
PROMPT  3. Apply authorization to your components
PROMPT
PROMPT  See 05_apex_usage_guide.sql for examples
PROMPT ========================================

-- Verify installation
PROMPT
PROMPT Verification - Checking objects...

SELECT 'TABLE' AS object_type, table_name AS object_name, 'OK' AS status
FROM user_tables
WHERE table_name LIKE 'APEX_AUTH%'
UNION ALL
SELECT 'PACKAGE' AS object_type, object_name, 
       CASE status WHEN 'VALID' THEN 'OK' ELSE 'ERROR' END AS status
FROM user_objects
WHERE object_name = 'APEX_AUTH_PKG'
AND object_type IN ('PACKAGE', 'PACKAGE BODY')
UNION ALL
SELECT 'VIEW' AS object_type, view_name, 'OK' AS status
FROM user_views
WHERE view_name LIKE 'V_APEX_AUTH%'
ORDER BY 1, 2;

PROMPT
PROMPT Installation verification complete.
