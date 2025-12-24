/*
================================================================================
Script: 01_db_create_ords_user.sql
Server: EC1 (Database Server - 80.238.214.217)
OS: Oracle Linux 8
OS User: oracle
Description: Create ORDS database users and configure prerequisites
================================================================================
IMPORTANT: Replace <PASSWORD> placeholders with secure passwords before running
================================================================================
*/

-- Connect as SYSDBA
-- sqlplus / as sysdba

-- Ensure we're connected to PDB1
ALTER SESSION SET CONTAINER = PDB1;

PROMPT ============================================================
PROMPT Step 1: Verify APEX Installation
PROMPT ============================================================

SELECT 'APEX Version: ' || VERSION_NO || ' - Status: ' || STATUS AS APEX_STATUS 
FROM DBA_REGISTRY WHERE COMP_ID = 'APEX';

SELECT USERNAME, ACCOUNT_STATUS, CREATED 
FROM DBA_USERS 
WHERE USERNAME LIKE 'APEX%' 
ORDER BY USERNAME;

PROMPT ============================================================
PROMPT Step 2: Create ORDS Tablespace (Optional but Recommended)
PROMPT ============================================================

-- Check if tablespace already exists
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM DBA_TABLESPACES WHERE TABLESPACE_NAME = 'ORDS_TS';
    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE TABLESPACE ORDS_TS DATAFILE SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 2G';
        DBMS_OUTPUT.PUT_LINE('Tablespace ORDS_TS created successfully.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Tablespace ORDS_TS already exists.');
    END IF;
END;
/

PROMPT ============================================================
PROMPT Step 3: Create/Verify ORDS_PUBLIC_USER
PROMPT ============================================================

-- ORDS_PUBLIC_USER is the runtime user for ORDS connections
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM DBA_USERS WHERE USERNAME = 'ORDS_PUBLIC_USER';
    IF v_count = 0 THEN
        -- Create user - REPLACE PASSWORD BELOW
        EXECUTE IMMEDIATE 'CREATE USER ORDS_PUBLIC_USER IDENTIFIED BY "Change_Me_123!" 
                           DEFAULT TABLESPACE ORDS_TS 
                           TEMPORARY TABLESPACE TEMP 
                           QUOTA UNLIMITED ON ORDS_TS';
        DBMS_OUTPUT.PUT_LINE('User ORDS_PUBLIC_USER created.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('User ORDS_PUBLIC_USER already exists. Resetting password...');
        -- Reset password - REPLACE PASSWORD BELOW
        EXECUTE IMMEDIATE 'ALTER USER ORDS_PUBLIC_USER IDENTIFIED BY "Change_Me_123!" ACCOUNT UNLOCK';
    END IF;
END;
/

GRANT CONNECT TO ORDS_PUBLIC_USER;

PROMPT ============================================================
PROMPT Step 4: Create/Verify ORDS_METADATA User
PROMPT ============================================================

-- ORDS_METADATA stores ORDS configuration in the database
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM DBA_USERS WHERE USERNAME = 'ORDS_METADATA';
    IF v_count = 0 THEN
        -- Create user - REPLACE PASSWORD BELOW
        EXECUTE IMMEDIATE 'CREATE USER ORDS_METADATA IDENTIFIED BY "Change_Me_456!" 
                           DEFAULT TABLESPACE ORDS_TS 
                           TEMPORARY TABLESPACE TEMP 
                           QUOTA UNLIMITED ON ORDS_TS';
        DBMS_OUTPUT.PUT_LINE('User ORDS_METADATA created.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('User ORDS_METADATA already exists. Resetting password...');
        -- Reset password - REPLACE PASSWORD BELOW
        EXECUTE IMMEDIATE 'ALTER USER ORDS_METADATA IDENTIFIED BY "Change_Me_456!" ACCOUNT UNLOCK';
    END IF;
END;
/

GRANT CONNECT, RESOURCE TO ORDS_METADATA;

PROMPT ============================================================
PROMPT Step 5: Configure APEX_PUBLIC_USER
PROMPT ============================================================

-- APEX_PUBLIC_USER is required for APEX authentication
-- REPLACE PASSWORD BELOW
ALTER USER APEX_PUBLIC_USER IDENTIFIED BY "Change_Me_789!" ACCOUNT UNLOCK;
GRANT CONNECT TO APEX_PUBLIC_USER;

PROMPT ============================================================
PROMPT Step 6: Verify Users Created
PROMPT ============================================================

SELECT USERNAME, ACCOUNT_STATUS, DEFAULT_TABLESPACE, CREATED
FROM DBA_USERS
WHERE USERNAME IN ('ORDS_PUBLIC_USER', 'ORDS_METADATA', 'APEX_PUBLIC_USER')
ORDER BY USERNAME;

PROMPT ============================================================
PROMPT Step 7: Configure Network ACL for APEX
PROMPT ============================================================

-- Get the APEX schema name dynamically
DECLARE
    v_apex_schema VARCHAR2(30);
    v_count NUMBER;
BEGIN
    -- Find APEX schema
    SELECT MAX(USERNAME) INTO v_apex_schema 
    FROM DBA_USERS 
    WHERE USERNAME LIKE 'APEX_%' 
    AND USERNAME NOT IN ('APEX_PUBLIC_USER', 'APEX_LISTENER', 'APEX_REST_PUBLIC_USER')
    AND REGEXP_LIKE(USERNAME, '^APEX_[0-9]+$');
    
    IF v_apex_schema IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Could not find APEX schema');
        RETURN;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('Found APEX schema: ' || v_apex_schema);
    
    -- Check if ACE already exists
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
            host => '*',
            ace => xs$ace_type(
                privilege_list => xs$name_list('connect', 'resolve'),
                principal_name => v_apex_schema,
                principal_type => xs_acl.ptype_db
            )
        );
        DBMS_OUTPUT.PUT_LINE('Network ACL configured for ' || v_apex_schema);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -24244 THEN
                DBMS_OUTPUT.PUT_LINE('ACL already exists for ' || v_apex_schema);
            ELSE
                RAISE;
            END IF;
    END;
END;
/

COMMIT;

PROMPT ============================================================
PROMPT Step 8: Verify Listener Configuration
PROMPT ============================================================

-- Verify PDB1 service is registered
SELECT NAME, PDB FROM V$SERVICES WHERE PDB = 'PDB1';

PROMPT ============================================================
PROMPT Database Preparation Complete!
PROMPT ============================================================
PROMPT
PROMPT IMPORTANT: Make sure to:
PROMPT 1. Replace all default passwords with secure passwords
PROMPT 2. Note down the passwords for ORDS configuration:
PROMPT    - ORDS_PUBLIC_USER password
PROMPT    - APEX_PUBLIC_USER password
PROMPT    - SYS password (for ORDS installation)
PROMPT 3. Open firewall port 1521 on EC1
PROMPT
PROMPT Run this on EC1 as root:
PROMPT    sudo firewall-cmd --permanent --add-port=1521/tcp
PROMPT    sudo firewall-cmd --reload
PROMPT ============================================================

EXIT;
