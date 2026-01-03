/*******************************************************************************
 * Oracle APEX Dynamic Authorization Scheme
 * Sample Data and Usage Examples
 * 
 * Purpose: Demonstrate how to use the authorization system
 * 
 * Author: Generated for Oracle APEX 19c+
 * Date: January 2026
 ******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ============================================================================
PROMPT STEP 1: Initialize Default Permissions and Roles
PROMPT ============================================================================

BEGIN
    apex_authorization_pkg.initialize_default_permissions;
    DBMS_OUTPUT.PUT_LINE('✓ Default roles and permissions created');
END;
/

PROMPT ============================================================================
PROMPT STEP 2: Create Sample Users
PROMPT ============================================================================

BEGIN
    -- Create sample users
    apex_authorization_pkg.create_user(
        p_username => 'JOHN.DOE',
        p_email => 'john.doe@company.com',
        p_full_name => 'John Doe',
        p_is_active => 'Y'
    );
    DBMS_OUTPUT.PUT_LINE('✓ User JOHN.DOE created');
    
    apex_authorization_pkg.create_user(
        p_username => 'JANE.SMITH',
        p_email => 'jane.smith@company.com',
        p_full_name => 'Jane Smith',
        p_is_active => 'Y'
    );
    DBMS_OUTPUT.PUT_LINE('✓ User JANE.SMITH created');
    
    apex_authorization_pkg.create_user(
        p_username => 'BOB.MANAGER',
        p_email => 'bob.manager@company.com',
        p_full_name => 'Bob Manager',
        p_is_active => 'Y'
    );
    DBMS_OUTPUT.PUT_LINE('✓ User BOB.MANAGER created');
    
    apex_authorization_pkg.create_user(
        p_username => 'ALICE.ADMIN',
        p_email => 'alice.admin@company.com',
        p_full_name => 'Alice Administrator',
        p_is_active => 'Y'
    );
    DBMS_OUTPUT.PUT_LINE('✓ User ALICE.ADMIN created');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Note: Some users may already exist');
END;
/

PROMPT ============================================================================
PROMPT STEP 3: Assign Roles to Users
PROMPT ============================================================================

BEGIN
    -- Assign roles to users
    apex_authorization_pkg.assign_role_to_user('ALICE.ADMIN', 'SUPERADMIN');
    DBMS_OUTPUT.PUT_LINE('✓ ALICE.ADMIN assigned SUPERADMIN role');
    
    apex_authorization_pkg.assign_role_to_user('BOB.MANAGER', 'MANAGER');
    DBMS_OUTPUT.PUT_LINE('✓ BOB.MANAGER assigned MANAGER role');
    
    apex_authorization_pkg.assign_role_to_user('JOHN.DOE', 'USER');
    DBMS_OUTPUT.PUT_LINE('✓ JOHN.DOE assigned USER role');
    
    apex_authorization_pkg.assign_role_to_user('JANE.SMITH', 'USER');
    DBMS_OUTPUT.PUT_LINE('✓ JANE.SMITH assigned USER role');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

PROMPT ============================================================================
PROMPT STEP 4: Register Sample APEX Application Objects
PROMPT Assuming Application ID = 100 (replace with your actual app ID)
PROMPT ============================================================================

DECLARE
    l_app_id    NUMBER := 100;
BEGIN
    -- Register Pages
    apex_authorization_pkg.register_object(
        p_application_id => l_app_id,
        p_object_type => 'PAGE',
        p_object_code => 'PAGE_1',
        p_object_name => 'Home Page',
        p_page_id => 1,
        p_object_desc => 'Application home page'
    );
    
    apex_authorization_pkg.register_object(
        p_application_id => l_app_id,
        p_object_type => 'PAGE',
        p_object_code => 'PAGE_10',
        p_object_name => 'Dashboard',
        p_page_id => 10,
        p_object_desc => 'Main dashboard'
    );
    
    apex_authorization_pkg.register_object(
        p_application_id => l_app_id,
        p_object_type => 'PAGE',
        p_object_code => 'PAGE_20',
        p_object_name => 'Reports',
        p_page_id => 20,
        p_object_desc => 'Reports page'
    );
    
    apex_authorization_pkg.register_object(
        p_application_id => l_app_id,
        p_object_type => 'PAGE',
        p_object_code => 'PAGE_100',
        p_object_name => 'Administration',
        p_page_id => 100,
        p_object_desc => 'Admin settings page'
    );
    
    -- Register Regions
    apex_authorization_pkg.register_object(
        p_application_id => l_app_id,
        p_object_type => 'REGION',
        p_object_code => 'SALES_REPORT',
        p_object_name => 'Sales Report Region',
        p_page_id => 20,
        p_object_desc => 'Displays sales data'
    );
    
    apex_authorization_pkg.register_object(
        p_application_id => l_app_id,
        p_object_type => 'REGION',
        p_object_code => 'FINANCIAL_DATA',
        p_object_name => 'Financial Data Region',
        p_page_id => 20,
        p_object_desc => 'Sensitive financial information'
    );
    
    -- Register Buttons
    apex_authorization_pkg.register_object(
        p_application_id => l_app_id,
        p_object_type => 'BUTTON',
        p_object_code => 'BTN_CREATE',
        p_object_name => 'Create Button',
        p_page_id => 10,
        p_object_desc => 'Create new record'
    );
    
    apex_authorization_pkg.register_object(
        p_application_id => l_app_id,
        p_object_type => 'BUTTON',
        p_object_code => 'BTN_DELETE',
        p_object_name => 'Delete Button',
        p_page_id => 10,
        p_object_desc => 'Delete records'
    );
    
    apex_authorization_pkg.register_object(
        p_application_id => l_app_id,
        p_object_type => 'BUTTON',
        p_object_code => 'BTN_APPROVE',
        p_object_name => 'Approve Button',
        p_page_id => 20,
        p_object_desc => 'Approve transactions'
    );
    
    -- Register Menu Items
    apex_authorization_pkg.register_object(
        p_application_id => l_app_id,
        p_object_type => 'MENU',
        p_object_code => 'MENU_DASHBOARD',
        p_object_name => 'Dashboard Menu',
        p_object_desc => 'Navigation to dashboard'
    );
    
    apex_authorization_pkg.register_object(
        p_application_id => l_app_id,
        p_object_type => 'MENU',
        p_object_code => 'MENU_REPORTS',
        p_object_name => 'Reports Menu',
        p_object_desc => 'Navigation to reports'
    );
    
    apex_authorization_pkg.register_object(
        p_application_id => l_app_id,
        p_object_type => 'MENU',
        p_object_code => 'MENU_ADMIN',
        p_object_name => 'Administration Menu',
        p_object_desc => 'Navigation to admin section'
    );
    
    DBMS_OUTPUT.PUT_LINE('✓ Application objects registered successfully');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

PROMPT ============================================================================
PROMPT STEP 5: Grant Permissions to Roles
PROMPT ============================================================================

DECLARE
    l_app_id    NUMBER := 100;
BEGIN
    -- USER role permissions - Basic access
    apex_authorization_pkg.grant_permission('USER', l_app_id, 'PAGE_1', 'VIEW');
    apex_authorization_pkg.grant_permission('USER', l_app_id, 'PAGE_10', 'VIEW');
    apex_authorization_pkg.grant_permission('USER', l_app_id, 'MENU_DASHBOARD', 'VIEW');
    apex_authorization_pkg.grant_permission('USER', l_app_id, 'SALES_REPORT', 'VIEW');
    apex_authorization_pkg.grant_permission('USER', l_app_id, 'BTN_CREATE', 'EXECUTE');
    
    DBMS_OUTPUT.PUT_LINE('✓ USER role permissions granted');
    
    -- MANAGER role permissions - Extended access
    apex_authorization_pkg.grant_permission('MANAGER', l_app_id, 'PAGE_1', 'VIEW');
    apex_authorization_pkg.grant_permission('MANAGER', l_app_id, 'PAGE_10', 'VIEW');
    apex_authorization_pkg.grant_permission('MANAGER', l_app_id, 'PAGE_20', 'VIEW');
    apex_authorization_pkg.grant_permission('MANAGER', l_app_id, 'MENU_DASHBOARD', 'VIEW');
    apex_authorization_pkg.grant_permission('MANAGER', l_app_id, 'MENU_REPORTS', 'VIEW');
    apex_authorization_pkg.grant_permission('MANAGER', l_app_id, 'SALES_REPORT', 'VIEW');
    apex_authorization_pkg.grant_permission('MANAGER', l_app_id, 'FINANCIAL_DATA', 'VIEW');
    apex_authorization_pkg.grant_permission('MANAGER', l_app_id, 'BTN_CREATE', 'EXECUTE');
    apex_authorization_pkg.grant_permission('MANAGER', l_app_id, 'BTN_DELETE', 'EXECUTE');
    apex_authorization_pkg.grant_permission('MANAGER', l_app_id, 'BTN_APPROVE', 'EXECUTE');
    
    DBMS_OUTPUT.PUT_LINE('✓ MANAGER role permissions granted');
    
    -- ADMIN role permissions - Full access
    apex_authorization_pkg.grant_permission('ADMIN', l_app_id, 'PAGE_1', 'VIEW');
    apex_authorization_pkg.grant_permission('ADMIN', l_app_id, 'PAGE_10', 'VIEW');
    apex_authorization_pkg.grant_permission('ADMIN', l_app_id, 'PAGE_20', 'VIEW');
    apex_authorization_pkg.grant_permission('ADMIN', l_app_id, 'PAGE_100', 'ADMIN');
    apex_authorization_pkg.grant_permission('ADMIN', l_app_id, 'MENU_ADMIN', 'VIEW');
    
    DBMS_OUTPUT.PUT_LINE('✓ ADMIN role permissions granted');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

PROMPT ============================================================================
PROMPT STEP 6: Grant User-Specific Override (Example)
PROMPT ============================================================================

DECLARE
    l_app_id    NUMBER := 100;
BEGIN
    -- Give JANE.SMITH special access to financial data
    apex_authorization_pkg.grant_user_permission(
        p_username => 'JANE.SMITH',
        p_application_id => l_app_id,
        p_object_code => 'FINANCIAL_DATA',
        p_permission_code => 'VIEW',
        p_is_granted => 'Y',
        p_override_roles => 'Y'
    );
    
    DBMS_OUTPUT.PUT_LINE('✓ User-specific permission granted to JANE.SMITH');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

PROMPT ============================================================================
PROMPT STEP 7: Test Authorization Functions
PROMPT ============================================================================

DECLARE
    l_app_id    NUMBER := 100;
    l_result    BOOLEAN;
BEGIN
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Testing Page Authorization ---');
    
    -- Test JOHN.DOE (USER role)
    l_result := apex_authorization_pkg.is_page_authorized(
        p_page_id => 10,
        p_application_id => l_app_id,
        p_username => 'JOHN.DOE'
    );
    DBMS_OUTPUT.PUT_LINE('JOHN.DOE access to Page 10: ' || 
        CASE WHEN l_result THEN 'GRANTED ✓' ELSE 'DENIED ✗' END);
    
    l_result := apex_authorization_pkg.is_page_authorized(
        p_page_id => 100,
        p_application_id => l_app_id,
        p_username => 'JOHN.DOE'
    );
    DBMS_OUTPUT.PUT_LINE('JOHN.DOE access to Page 100 (Admin): ' || 
        CASE WHEN l_result THEN 'GRANTED ✓' ELSE 'DENIED ✗' END);
    
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Testing Button Authorization ---');
    
    -- Test button access
    l_result := apex_authorization_pkg.is_button_authorized(
        p_button_code => 'BTN_CREATE',
        p_application_id => l_app_id,
        p_username => 'JOHN.DOE'
    );
    DBMS_OUTPUT.PUT_LINE('JOHN.DOE access to CREATE button: ' || 
        CASE WHEN l_result THEN 'GRANTED ✓' ELSE 'DENIED ✗' END);
    
    l_result := apex_authorization_pkg.is_button_authorized(
        p_button_code => 'BTN_DELETE',
        p_application_id => l_app_id,
        p_username => 'JOHN.DOE'
    );
    DBMS_OUTPUT.PUT_LINE('JOHN.DOE access to DELETE button: ' || 
        CASE WHEN l_result THEN 'GRANTED ✓' ELSE 'DENIED ✗' END);
    
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Testing Region Authorization ---');
    
    -- Test region access for JANE.SMITH (has user override)
    l_result := apex_authorization_pkg.is_region_authorized(
        p_region_code => 'FINANCIAL_DATA',
        p_application_id => l_app_id,
        p_username => 'JANE.SMITH'
    );
    DBMS_OUTPUT.PUT_LINE('JANE.SMITH access to FINANCIAL_DATA region: ' || 
        CASE WHEN l_result THEN 'GRANTED ✓ (via user override)' ELSE 'DENIED ✗' END);
    
    -- Test same region for JOHN.DOE (no special permission)
    l_result := apex_authorization_pkg.is_region_authorized(
        p_region_code => 'FINANCIAL_DATA',
        p_application_id => l_app_id,
        p_username => 'JOHN.DOE'
    );
    DBMS_OUTPUT.PUT_LINE('JOHN.DOE access to FINANCIAL_DATA region: ' || 
        CASE WHEN l_result THEN 'GRANTED ✓' ELSE 'DENIED ✗' END);
    
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Testing Role Checks ---');
    
    -- Test role membership
    l_result := apex_authorization_pkg.has_role('BOB.MANAGER', 'MANAGER');
    DBMS_OUTPUT.PUT_LINE('BOB.MANAGER has MANAGER role: ' || 
        CASE WHEN l_result THEN 'YES ✓' ELSE 'NO ✗' END);
    
    l_result := apex_authorization_pkg.has_role('ALICE.ADMIN', 'SUPERADMIN');
    DBMS_OUTPUT.PUT_LINE('ALICE.ADMIN has SUPERADMIN role: ' || 
        CASE WHEN l_result THEN 'YES ✓' ELSE 'NO ✗' END);
    
    -- Test multiple role check
    l_result := apex_authorization_pkg.has_any_role('BOB.MANAGER', 'ADMIN,MANAGER,USER');
    DBMS_OUTPUT.PUT_LINE('BOB.MANAGER has any of (ADMIN,MANAGER,USER): ' || 
        CASE WHEN l_result THEN 'YES ✓' ELSE 'NO ✗' END);
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error during testing: ' || SQLERRM);
END;
/

PROMPT ============================================================================
PROMPT STEP 8: View Authorization Summary
PROMPT ============================================================================

-- User-Role Summary
PROMPT
PROMPT === User-Role Assignments ===
SELECT 
    u.username,
    u.full_name,
    r.role_code,
    r.role_name,
    CASE WHEN ur.is_active = 'Y' THEN 'Active' ELSE 'Inactive' END AS status
FROM apex_auth_users u
INNER JOIN apex_auth_user_roles ur ON u.user_id = ur.user_id
INNER JOIN apex_auth_roles r ON ur.role_id = r.role_id
WHERE SYSDATE BETWEEN ur.effective_from AND NVL(ur.effective_to, SYSDATE + 1)
ORDER BY u.username, r.role_code;

-- Permission Summary
PROMPT
PROMPT === Role-Permission Summary (Application 100) ===
SELECT 
    r.role_code,
    o.object_type,
    o.object_name,
    p.permission_type,
    CASE WHEN rp.is_granted = 'Y' THEN 'Granted' ELSE 'Denied' END AS access
FROM apex_auth_roles r
INNER JOIN apex_auth_role_permissions rp ON r.role_id = rp.role_id
INNER JOIN apex_auth_objects o ON rp.object_id = o.object_id
INNER JOIN apex_auth_permissions p ON rp.permission_id = p.permission_id
WHERE o.application_id = 100
AND SYSDATE BETWEEN rp.effective_from AND NVL(rp.effective_to, SYSDATE + 1)
ORDER BY r.role_code, o.object_type, o.object_name;

PROMPT
PROMPT ============================================================================
PROMPT Sample Data Installation Complete!
PROMPT ============================================================================
PROMPT
PROMPT Next Steps:
PROMPT 1. Review the sample data above
PROMPT 2. Modify Application ID (currently set to 100) to match your APEX app
PROMPT 3. Register your actual APEX objects (pages, regions, buttons)
PROMPT 4. Create authorization schemes in APEX using the package functions
PROMPT 5. Test authorization in your APEX application
PROMPT
PROMPT ============================================================================
