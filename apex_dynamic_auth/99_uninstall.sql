/*
================================================================================
  Dynamic Authorization Scheme - Uninstall Script
  Oracle APEX Security Framework
  
  Purpose: Remove all objects created by the authorization framework
  
  WARNING: This will permanently delete all authorization data!
  
================================================================================
*/

SET SERVEROUTPUT ON
SET DEFINE OFF

PROMPT ========================================
PROMPT  Dynamic Authorization Scheme Uninstaller
PROMPT ========================================
PROMPT
PROMPT WARNING: This will permanently delete all authorization data!
PROMPT

-- Drop views first
PROMPT Dropping views...
BEGIN
    FOR rec IN (
        SELECT view_name 
        FROM user_views 
        WHERE view_name LIKE 'V_APEX_AUTH%'
    ) LOOP
        EXECUTE IMMEDIATE 'DROP VIEW ' || rec.view_name;
        DBMS_OUTPUT.PUT_LINE('Dropped view: ' || rec.view_name);
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error dropping views: ' || SQLERRM);
END;
/

-- Drop package
PROMPT Dropping package...
BEGIN
    EXECUTE IMMEDIATE 'DROP PACKAGE apex_auth_pkg';
    DBMS_OUTPUT.PUT_LINE('Dropped package: APEX_AUTH_PKG');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Package not found or error: ' || SQLERRM);
END;
/

-- Drop tables (in dependency order)
PROMPT Dropping tables...
BEGIN
    FOR rec IN (
        SELECT table_name 
        FROM user_tables 
        WHERE table_name IN (
            'APEX_AUTH_AUDIT_LOG',
            'APEX_AUTH_PERMISSIONS',
            'APEX_AUTH_COMPONENTS',
            'APEX_AUTH_USER_ROLES',
            'APEX_AUTH_ROLES',
            'APEX_AUTH_COMPONENT_TYPES'
        )
        ORDER BY 
            CASE table_name
                WHEN 'APEX_AUTH_AUDIT_LOG' THEN 1
                WHEN 'APEX_AUTH_PERMISSIONS' THEN 2
                WHEN 'APEX_AUTH_COMPONENTS' THEN 3
                WHEN 'APEX_AUTH_USER_ROLES' THEN 4
                WHEN 'APEX_AUTH_ROLES' THEN 5
                WHEN 'APEX_AUTH_COMPONENT_TYPES' THEN 6
            END
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || rec.table_name || ' CASCADE CONSTRAINTS';
            DBMS_OUTPUT.PUT_LINE('Dropped table: ' || rec.table_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error dropping ' || rec.table_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- Drop sequence
PROMPT Dropping sequence...
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE apex_auth_seq';
    DBMS_OUTPUT.PUT_LINE('Dropped sequence: APEX_AUTH_SEQ');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Sequence not found or error: ' || SQLERRM);
END;
/

PROMPT
PROMPT ========================================
PROMPT  Uninstallation Complete
PROMPT ========================================
PROMPT
PROMPT All Dynamic Authorization objects have been removed.
PROMPT
