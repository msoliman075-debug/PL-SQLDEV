/*
================================================================================
  FND_PROFILE Installation Script
  
  Description: Master installation script for FND_PROFILE database structure
  
  Usage: 
    SQL> @install.sql
  
  Prerequisites:
    - Oracle 19c or higher
    - User with CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE VIEW, 
      CREATE TRIGGER privileges
  
  Author: Database Team
  Version: 1.0
================================================================================
*/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET VERIFY OFF
SET FEEDBACK OFF
SET TIMING ON

PROMPT
PROMPT ================================================================
PROMPT   FND_PROFILE Installation
PROMPT   Oracle Profile Options Management System
PROMPT ================================================================
PROMPT

-- ============================================================================
-- Step 1: Create Tables and Base Data
-- ============================================================================
PROMPT
PROMPT Step 1 of 6: Creating tables and sequences...
@@01_tables.sql
PROMPT Tables created successfully.

-- ============================================================================
-- Step 2: Create Package Specification
-- ============================================================================
PROMPT
PROMPT Step 2 of 6: Creating package specification...
@@02_package_spec.sql
PROMPT Package specification created successfully.

-- ============================================================================
-- Step 3: Create Package Body
-- ============================================================================
PROMPT
PROMPT Step 3 of 6: Creating package body...
@@03_package_body.sql
PROMPT Package body created successfully.

-- ============================================================================
-- Step 4: Create Views
-- ============================================================================
PROMPT
PROMPT Step 4 of 6: Creating views...
@@04_views.sql
PROMPT Views created successfully.

-- ============================================================================
-- Step 5: Create Triggers
-- ============================================================================
PROMPT
PROMPT Step 5 of 6: Creating triggers...
@@05_triggers.sql
PROMPT Triggers created successfully.

-- ============================================================================
-- Step 6: Load Sample Data (Optional)
-- ============================================================================
PROMPT
PROMPT Step 6 of 6: Loading sample data...
@@06_sample_data.sql
PROMPT Sample data loaded successfully.

-- ============================================================================
-- Verify Installation
-- ============================================================================
PROMPT
PROMPT ================================================================
PROMPT   Installation Verification
PROMPT ================================================================
PROMPT

COLUMN object_name FORMAT A35
COLUMN object_type FORMAT A20
COLUMN status FORMAT A10

PROMPT
PROMPT Objects Created:
SELECT object_type, object_name, status
FROM user_objects
WHERE object_name LIKE 'FND_%'
ORDER BY object_type, object_name;

PROMPT
PROMPT Invalid Objects (should be none):
SELECT object_type, object_name, status
FROM user_objects
WHERE object_name LIKE 'FND_%'
AND status = 'INVALID';

PROMPT
PROMPT ================================================================
PROMPT   Installation Complete
PROMPT ================================================================
PROMPT
PROMPT To test the installation, run:
PROMPT   @07_examples.sql
PROMPT
PROMPT For documentation, see README.md
PROMPT ================================================================
PROMPT

SET FEEDBACK ON
SET TIMING OFF
