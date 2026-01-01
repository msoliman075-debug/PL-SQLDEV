/*
================================================================================
  FND_PROFILE Uninstallation Script
  
  Description: Removes all FND_PROFILE database objects
  
  Usage: 
    SQL> @uninstall.sql
  
  WARNING: This will DROP all FND_PROFILE tables and data!
  
  Author: Database Team
  Version: 1.0
================================================================================
*/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET VERIFY OFF
SET FEEDBACK OFF

PROMPT
PROMPT ================================================================
PROMPT   FND_PROFILE Uninstallation
PROMPT   WARNING: This will remove ALL FND_PROFILE objects and data!
PROMPT ================================================================
PROMPT

-- ============================================================================
-- Drop Package
-- ============================================================================
PROMPT Dropping package...
BEGIN
    EXECUTE IMMEDIATE 'DROP PACKAGE fnd_profile';
    DBMS_OUTPUT.PUT_LINE('Package FND_PROFILE dropped.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Package FND_PROFILE not found or already dropped.');
END;
/

-- ============================================================================
-- Drop Views
-- ============================================================================
PROMPT Dropping views...

BEGIN EXECUTE IMMEDIATE 'DROP VIEW fnd_profile_options_vl'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP VIEW fnd_profile_option_values_v'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP VIEW fnd_profile_values_by_user_v'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP VIEW fnd_profile_site_values_v'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP VIEW fnd_profile_user_values_v'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP VIEW fnd_profile_change_history_v'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP VIEW fnd_profile_summary_v'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

PROMPT Views dropped.

-- ============================================================================
-- Drop Triggers
-- ============================================================================
PROMPT Dropping triggers...

BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER fnd_profile_options_biu'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER fnd_profile_opt_values_biu'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER fnd_application_biu'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER fnd_responsibility_biu'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER fnd_user_biu'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER fnd_user_resp_groups_biu'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

PROMPT Triggers dropped.

-- ============================================================================
-- Drop Tables (in dependency order)
-- ============================================================================
PROMPT Dropping tables...

BEGIN EXECUTE IMMEDIATE 'DROP TABLE fnd_profile_option_values_h CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE fnd_profile_option_values CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE fnd_profile_options CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE fnd_profile_levels CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE fnd_user_resp_groups CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE fnd_responsibility CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE fnd_user CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE fnd_application CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

PROMPT Tables dropped.

-- ============================================================================
-- Drop Sequences
-- ============================================================================
PROMPT Dropping sequences...

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE fnd_profile_options_s'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE fnd_profile_option_values_s'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE fnd_profile_option_values_h_s'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

PROMPT Sequences dropped.

-- ============================================================================
-- Verify Uninstallation
-- ============================================================================
PROMPT
PROMPT ================================================================
PROMPT   Uninstallation Verification
PROMPT ================================================================
PROMPT

PROMPT Remaining FND_% objects (should be none):
SELECT object_type, object_name
FROM user_objects
WHERE object_name LIKE 'FND_%'
ORDER BY object_type, object_name;

PROMPT
PROMPT ================================================================
PROMPT   Uninstallation Complete
PROMPT ================================================================
PROMPT

SET FEEDBACK ON
