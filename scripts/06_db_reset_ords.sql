/*
================================================================================
Script: 06_db_reset_ords.sql
Server: EC1 (Database Server - 80.238.214.217)
OS: Oracle Linux 8
OS User: oracle
Description: Reset ORDS database objects and users
================================================================================
WARNING: This will remove all ORDS-related database objects!
================================================================================
*/

-- Connect as SYSDBA
-- sqlplus / as sysdba

-- Ensure we're connected to PDB1
ALTER SESSION SET CONTAINER = PDB1;

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO ON
SET FEEDBACK ON

PROMPT ============================================================
PROMPT ORDS Database Reset Script
PROMPT ============================================================
PROMPT
PROMPT WARNING: This will remove ORDS database objects!
PROMPT Press Ctrl+C to cancel, or wait 10 seconds to continue...
PROMPT ============================================================

-- Give user time to cancel
EXEC DBMS_LOCK.SLEEP(10);

PROMPT ============================================================
PROMPT Step 1: Check Current ORDS Installation Status
PROMPT ============================================================

SELECT USERNAME, ACCOUNT_STATUS, CREATED
FROM DBA_USERS
WHERE USERNAME IN ('ORDS_PUBLIC_USER', 'ORDS_METADATA')
ORDER BY USERNAME;

PROMPT ============================================================
PROMPT Step 2: Drop ORDS_METADATA User (Schema Owner)
PROMPT ============================================================

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM DBA_USERS WHERE USERNAME = 'ORDS_METADATA';
    IF v_count > 0 THEN
        EXECUTE IMMEDIATE 'DROP USER ORDS_METADATA CASCADE';
        DBMS_OUTPUT.PUT_LINE('User ORDS_METADATA dropped successfully.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('User ORDS_METADATA does not exist.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error dropping ORDS_METADATA: ' || SQLERRM);
END;
/

PROMPT ============================================================
PROMPT Step 3: Drop ORDS_PUBLIC_USER (Runtime User)
PROMPT ============================================================

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM DBA_USERS WHERE USERNAME = 'ORDS_PUBLIC_USER';
    IF v_count > 0 THEN
        EXECUTE IMMEDIATE 'DROP USER ORDS_PUBLIC_USER CASCADE';
        DBMS_OUTPUT.PUT_LINE('User ORDS_PUBLIC_USER dropped successfully.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('User ORDS_PUBLIC_USER does not exist.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error dropping ORDS_PUBLIC_USER: ' || SQLERRM);
END;
/

PROMPT ============================================================
PROMPT Step 4: Lock APEX_PUBLIC_USER (Optional)
PROMPT ============================================================

-- Uncomment if you want to lock APEX_PUBLIC_USER
-- ALTER USER APEX_PUBLIC_USER ACCOUNT LOCK;
PROMPT APEX_PUBLIC_USER left unlocked (comment out to lock)

PROMPT ============================================================
PROMPT Step 5: Drop ORDS Tablespace (Optional)
PROMPT ============================================================

-- WARNING: This will delete all data in the tablespace!
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM DBA_TABLESPACES WHERE TABLESPACE_NAME = 'ORDS_TS';
    IF v_count > 0 THEN
        -- Uncomment the next line to actually drop the tablespace
        -- EXECUTE IMMEDIATE 'DROP TABLESPACE ORDS_TS INCLUDING CONTENTS AND DATAFILES';
        DBMS_OUTPUT.PUT_LINE('Tablespace ORDS_TS exists. Uncomment DROP command to remove.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Tablespace ORDS_TS does not exist.');
    END IF;
END;
/

PROMPT ============================================================
PROMPT Step 6: Verify Cleanup
PROMPT ============================================================

SELECT USERNAME, ACCOUNT_STATUS 
FROM DBA_USERS 
WHERE USERNAME IN ('ORDS_PUBLIC_USER', 'ORDS_METADATA', 'APEX_PUBLIC_USER')
ORDER BY USERNAME;

PROMPT ============================================================
PROMPT Step 7: Remove Network ACLs (Optional)
PROMPT ============================================================

-- This removes network ACLs for APEX schema
-- Uncomment if needed
/*
DECLARE
    v_apex_schema VARCHAR2(30);
BEGIN
    SELECT MAX(USERNAME) INTO v_apex_schema 
    FROM DBA_USERS 
    WHERE USERNAME LIKE 'APEX_%' 
    AND USERNAME NOT IN ('APEX_PUBLIC_USER', 'APEX_LISTENER', 'APEX_REST_PUBLIC_USER')
    AND REGEXP_LIKE(USERNAME, '^APEX_[0-9]+$');
    
    IF v_apex_schema IS NOT NULL THEN
        DBMS_NETWORK_ACL_ADMIN.REMOVE_HOST_ACE(
            host => '*',
            ace => xs$ace_type(
                privilege_list => xs$name_list('connect', 'resolve'),
                principal_name => v_apex_schema,
                principal_type => xs_acl.ptype_db
            )
        );
        DBMS_OUTPUT.PUT_LINE('Removed network ACL for ' || v_apex_schema);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ACL removal skipped: ' || SQLERRM);
END;
/
*/

COMMIT;

PROMPT ============================================================
PROMPT Database Reset Complete!
PROMPT ============================================================
PROMPT
PROMPT The following have been removed:
PROMPT   - ORDS_METADATA user and schema
PROMPT   - ORDS_PUBLIC_USER
PROMPT
PROMPT To reinstall ORDS:
PROMPT   1. Run 01_db_create_ords_user.sql to recreate users
PROMPT   2. On EC2, run ORDS install again
PROMPT ============================================================

EXIT;
