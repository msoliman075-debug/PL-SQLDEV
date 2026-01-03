/*******************************************************************************
 * Oracle APEX Dynamic Authorization Scheme
 * Quick Start Installation Script
 * 
 * Purpose: Execute all installation steps in one script
 * 
 * Instructions:
 * 1. Review and update Application ID (search for "100" and replace)
 * 2. Update sample usernames if needed
 * 3. Execute this script in SQL*Plus or SQL Developer
 * 4. Review output for any errors
 * 
 * Author: Generated for Oracle APEX 19c+
 * Date: January 2026
 ******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF
SET FEEDBACK ON

PROMPT
PROMPT ============================================================================
PROMPT Oracle APEX Dynamic Authorization Scheme - Quick Start Installation
PROMPT ============================================================================
PROMPT
PROMPT This script will:
PROMPT   1. Create all authorization tables
PROMPT   2. Create the authorization package (spec and body)
PROMPT   3. Initialize default roles and permissions
PROMPT   4. Create sample users (optional - comment out if not needed)
PROMPT   5. Validate installation
PROMPT
PROMPT Press Ctrl+C to cancel, or press Enter to continue...
PAUSE

-- Variables for configuration
DEFINE v_app_id = 100

PROMPT
PROMPT ============================================================================
PROMPT STEP 1: Creating Authorization Tables
PROMPT ============================================================================

-- Execute DDL from file or inline
@@01_DDL_Authorization_Tables.sql

PROMPT ✓ Authorization tables created

PROMPT
PROMPT ============================================================================
PROMPT STEP 2: Creating Package Specification
PROMPT ============================================================================

@@02_PKG_SPEC_Authorization.sql

PROMPT ✓ Package specification created

PROMPT
PROMPT ============================================================================
PROMPT STEP 3: Creating Package Body
PROMPT ============================================================================

@@03_PKG_BODY_Authorization.sql

PROMPT ✓ Package body created

PROMPT
PROMPT ============================================================================
PROMPT STEP 4: Validating Installation
PROMPT ============================================================================

SET HEADING ON
SET FEEDBACK OFF

SELECT 
    object_name,
    object_type,
    status,
    CASE 
        WHEN status = 'VALID' THEN '✓'
        ELSE '✗ ERROR - See user_errors'
    END AS validation
FROM user_objects
WHERE object_name LIKE 'APEX_AUTH%'
ORDER BY object_type, object_name;

PROMPT
PROMPT Checking for compilation errors...

DECLARE
    l_error_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO l_error_count
    FROM user_errors
    WHERE name LIKE 'APEX_AUTH%';
    
    IF l_error_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('✗ WARNING: ' || l_error_count || ' compilation errors found!');
        DBMS_OUTPUT.PUT_LINE('  Run: SELECT * FROM user_errors WHERE name LIKE ''APEX_AUTH%'';');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ No compilation errors');
    END IF;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT STEP 5: Initializing Default Roles and Permissions
PROMPT ============================================================================

BEGIN
    apex_authorization_pkg.initialize_default_permissions;
    DBMS_OUTPUT.PUT_LINE('✓ Default roles created: SUPERADMIN, ADMIN, MANAGER, USER, GUEST');
    DBMS_OUTPUT.PUT_LINE('✓ Default permissions created: VIEW, EDIT, DELETE, EXECUTE, ADMIN');
END;
/

PROMPT
PROMPT ============================================================================
PROMPT STEP 6: Creating Sample Users (OPTIONAL - comment out if not needed)
PROMPT ============================================================================

BEGIN
    -- Create sample admin user
    BEGIN
        apex_authorization_pkg.create_user(
            p_username => 'APEX_ADMIN',
            p_email => 'admin@yourcompany.com',
            p_full_name => 'APEX Administrator',
            p_is_active => 'Y'
        );
        
        apex_authorization_pkg.assign_role_to_user(
            p_username => 'APEX_ADMIN',
            p_role_code => 'SUPERADMIN'
        );
        
        DBMS_OUTPUT.PUT_LINE('✓ Sample user APEX_ADMIN created with SUPERADMIN role');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  Note: User APEX_ADMIN may already exist');
    END;
    
    -- Create sample regular user
    BEGIN
        apex_authorization_pkg.create_user(
            p_username => 'DEMO_USER',
            p_email => 'demo@yourcompany.com',
            p_full_name => 'Demo User',
            p_is_active => 'Y'
        );
        
        apex_authorization_pkg.assign_role_to_user(
            p_username => 'DEMO_USER',
            p_role_code => 'USER'
        );
        
        DBMS_OUTPUT.PUT_LINE('✓ Sample user DEMO_USER created with USER role');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  Note: User DEMO_USER may already exist');
    END;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT STEP 7: Registering Sample APEX Objects for Application &v_app_id
PROMPT ============================================================================
PROMPT
PROMPT NOTE: Update Application ID if different from 100
PROMPT       Edit this script and change DEFINE v_app_id at the top
PROMPT

BEGIN
    -- Register home page
    apex_authorization_pkg.register_object(
        p_application_id => &v_app_id,
        p_object_type => 'PAGE',
        p_object_code => 'PAGE_1',
        p_object_name => 'Home Page',
        p_page_id => 1,
        p_object_desc => 'Application home page - accessible to all'
    );
    
    -- Grant access to all roles
    apex_authorization_pkg.grant_permission(
        p_role_code => 'USER',
        p_application_id => &v_app_id,
        p_object_code => 'PAGE_1',
        p_permission_code => 'VIEW'
    );
    
    DBMS_OUTPUT.PUT_LINE('✓ Sample page registered (PAGE_1) with VIEW permission for USER role');
    
    -- Register admin page
    apex_authorization_pkg.register_object(
        p_application_id => &v_app_id,
        p_object_type => 'PAGE',
        p_object_code => 'PAGE_9999',
        p_object_name => 'Administration',
        p_page_id => 9999,
        p_object_desc => 'Admin only page'
    );
    
    -- Grant only to ADMIN role
    apex_authorization_pkg.grant_permission(
        p_role_code => 'ADMIN',
        p_application_id => &v_app_id,
        p_object_code => 'PAGE_9999',
        p_permission_code => 'VIEW'
    );
    
    DBMS_OUTPUT.PUT_LINE('✓ Admin page registered (PAGE_9999) with VIEW permission for ADMIN role');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error registering objects: ' || SQLERRM);
END;
/

PROMPT
PROMPT ============================================================================
PROMPT STEP 8: Running Quick Tests
PROMPT ============================================================================

DECLARE
    l_result    BOOLEAN;
    l_username  VARCHAR2(100) := 'APEX_ADMIN';
BEGIN
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Testing authorization functions...');
    
    -- Test 1: Check if user has role
    l_result := apex_authorization_pkg.has_role(l_username, 'SUPERADMIN');
    DBMS_OUTPUT.PUT_LINE('  Test 1 - has_role(APEX_ADMIN, SUPERADMIN): ' || 
        CASE WHEN l_result THEN 'PASS ✓' ELSE 'FAIL ✗' END);
    
    -- Test 2: Check page authorization
    l_result := apex_authorization_pkg.is_page_authorized(
        p_page_id => 1,
        p_application_id => &v_app_id,
        p_username => l_username
    );
    DBMS_OUTPUT.PUT_LINE('  Test 2 - is_page_authorized(PAGE_1, APEX_ADMIN): ' || 
        CASE WHEN l_result THEN 'PASS ✓' ELSE 'FAIL ✗' END);
    
    -- Test 3: Check if demo user has USER role
    l_result := apex_authorization_pkg.has_role('DEMO_USER', 'USER');
    DBMS_OUTPUT.PUT_LINE('  Test 3 - has_role(DEMO_USER, USER): ' || 
        CASE WHEN l_result THEN 'PASS ✓' ELSE 'FAIL ✗' END);
    
    -- Test 4: Check demo user cannot access admin page
    l_result := apex_authorization_pkg.is_page_authorized(
        p_page_id => 9999,
        p_application_id => &v_app_id,
        p_username => 'DEMO_USER'
    );
    DBMS_OUTPUT.PUT_LINE('  Test 4 - is_page_authorized(PAGE_9999, DEMO_USER): ' || 
        CASE WHEN NOT l_result THEN 'PASS ✓ (correctly denied)' ELSE 'FAIL ✗' END);
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('  Test error: ' || SQLERRM);
END;
/

PROMPT
PROMPT ============================================================================
PROMPT Installation Summary
PROMPT ============================================================================

SELECT 
    'Database Objects' AS category,
    COUNT(*) AS count
FROM user_objects
WHERE object_name LIKE 'APEX_AUTH%'
UNION ALL
SELECT 
    'Roles Created',
    COUNT(*)
FROM apex_auth_roles
UNION ALL
SELECT 
    'Permissions Created',
    COUNT(*)
FROM apex_auth_permissions
UNION ALL
SELECT 
    'Users Created',
    COUNT(*)
FROM apex_auth_users
UNION ALL
SELECT 
    'Objects Registered',
    COUNT(*)
FROM apex_auth_objects
UNION ALL
SELECT 
    'Configuration Items',
    COUNT(*)
FROM apex_auth_config;

PROMPT
PROMPT ============================================================================
PROMPT Next Steps
PROMPT ============================================================================
PROMPT
PROMPT 1. Update Application ID in this script if not using App 100
PROMPT    Current Application ID: &v_app_id
PROMPT
PROMPT 2. Create Authorization Schemes in APEX:
PROMPT    - Shared Components > Security > Authorization Schemes
PROMPT    - Use the functions from apex_authorization_pkg
PROMPT
PROMPT 3. Register your actual APEX objects:
PROMPT    - Pages: Call register_object with object_type = 'PAGE'
PROMPT    - Regions: Call register_object with object_type = 'REGION'
PROMPT    - Buttons: Call register_object with object_type = 'BUTTON'
PROMPT    - Menus: Call register_object with object_type = 'MENU'
PROMPT
PROMPT 4. Grant permissions to roles:
PROMPT    - Use grant_permission() procedure
PROMPT
PROMPT 5. Create users and assign roles:
PROMPT    - Use create_user() and assign_role_to_user()
PROMPT
PROMPT 6. Review the Implementation Guide:
PROMPT    - See 05_Implementation_Guide.txt for detailed instructions
PROMPT
PROMPT 7. Test thoroughly in development before deploying to production
PROMPT
PROMPT ============================================================================
PROMPT Configuration Settings
PROMPT ============================================================================

SELECT 
    config_key,
    config_value,
    config_description
FROM apex_auth_config
ORDER BY config_key;

PROMPT
PROMPT ============================================================================
PROMPT Quick Reference - Common Functions
PROMPT ============================================================================
PROMPT
PROMPT Check if user has role:
PROMPT   apex_authorization_pkg.has_role('USERNAME', 'ROLE_CODE')
PROMPT
PROMPT Check page authorization:
PROMPT   apex_authorization_pkg.is_page_authorized(p_page_id, p_application_id, p_username)
PROMPT
PROMPT Create user:
PROMPT   apex_authorization_pkg.create_user('USERNAME', 'email@domain.com', 'Full Name')
PROMPT
PROMPT Assign role:
PROMPT   apex_authorization_pkg.assign_role_to_user('USERNAME', 'ROLE_CODE')
PROMPT
PROMPT Register object:
PROMPT   apex_authorization_pkg.register_object(app_id, 'PAGE', 'PAGE_10', 'Page Name', 10)
PROMPT
PROMPT Grant permission:
PROMPT   apex_authorization_pkg.grant_permission('ROLE_CODE', app_id, 'PAGE_10', 'VIEW')
PROMPT
PROMPT Clear cache after changes:
PROMPT   apex_authorization_pkg.clear_cache;
PROMPT
PROMPT ============================================================================
PROMPT Installation Complete!
PROMPT ============================================================================
PROMPT
PROMPT Check for any errors above. If all tests passed, you're ready to configure
PROMPT your APEX application to use the dynamic authorization scheme.
PROMPT
PROMPT For detailed instructions, see:
PROMPT   - README.md
PROMPT   - 05_Implementation_Guide.txt
PROMPT
PROMPT ============================================================================

SET FEEDBACK ON
SET VERIFY ON
