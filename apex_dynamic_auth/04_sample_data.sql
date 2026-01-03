/*
================================================================================
  Dynamic Authorization Scheme - Sample Data & Usage Examples
  Oracle APEX Security Framework
  
  Purpose: Demonstrate how to set up and use the authorization framework
  
  Target: Oracle 19c+ / Oracle APEX 21.1+
  
================================================================================
*/

SET SERVEROUTPUT ON;

PROMPT ========================================
PROMPT Creating Sample Roles
PROMPT ========================================

-- Create sample roles
DECLARE
    l_role_id NUMBER;
BEGIN
    -- Administrator role - full access
    apex_auth_pkg.create_role(
        p_role_code        => 'ADMIN',
        p_role_name        => 'Administrator',
        p_role_description => 'Full system access with all permissions',
        p_display_sequence => 10,
        p_role_id          => l_role_id
    );
    DBMS_OUTPUT.PUT_LINE('Created ADMIN role, ID: ' || l_role_id);
    
    -- Manager role - elevated access
    apex_auth_pkg.create_role(
        p_role_code        => 'MANAGER',
        p_role_name        => 'Manager',
        p_role_description => 'Department manager with edit/delete permissions',
        p_display_sequence => 20,
        p_role_id          => l_role_id
    );
    DBMS_OUTPUT.PUT_LINE('Created MANAGER role, ID: ' || l_role_id);
    
    -- User role - standard access
    apex_auth_pkg.create_role(
        p_role_code        => 'USER',
        p_role_name        => 'Standard User',
        p_role_description => 'Standard user with view access',
        p_display_sequence => 30,
        p_role_id          => l_role_id
    );
    DBMS_OUTPUT.PUT_LINE('Created USER role, ID: ' || l_role_id);
    
    -- Read-only role
    apex_auth_pkg.create_role(
        p_role_code        => 'READONLY',
        p_role_name        => 'Read Only',
        p_role_description => 'View-only access to selected areas',
        p_display_sequence => 40,
        p_role_id          => l_role_id
    );
    DBMS_OUTPUT.PUT_LINE('Created READONLY role, ID: ' || l_role_id);
    
    -- Finance role
    apex_auth_pkg.create_role(
        p_role_code        => 'FINANCE',
        p_role_name        => 'Finance Team',
        p_role_description => 'Access to financial reports and data',
        p_display_sequence => 50,
        p_role_id          => l_role_id
    );
    DBMS_OUTPUT.PUT_LINE('Created FINANCE role, ID: ' || l_role_id);
    
    -- HR role
    apex_auth_pkg.create_role(
        p_role_code        => 'HR',
        p_role_name        => 'Human Resources',
        p_role_description => 'Access to HR modules and employee data',
        p_display_sequence => 60,
        p_role_id          => l_role_id
    );
    DBMS_OUTPUT.PUT_LINE('Created HR role, ID: ' || l_role_id);
    
    COMMIT;
END;
/

PROMPT ========================================
PROMPT Assigning Roles to Sample Users
PROMPT ========================================

BEGIN
    -- Admin users get full access
    apex_auth_pkg.assign_role_to_user('ADMIN_USER', 'ADMIN');
    apex_auth_pkg.assign_role_to_user('SYSTEM_ADMIN', 'ADMIN');
    
    -- Managers get manager role
    apex_auth_pkg.assign_role_to_user('JOHN.SMITH', 'MANAGER');
    apex_auth_pkg.assign_role_to_user('JANE.DOE', 'MANAGER');
    
    -- Standard users
    apex_auth_pkg.assign_role_to_user('BOB.WILSON', 'USER');
    apex_auth_pkg.assign_role_to_user('ALICE.JOHNSON', 'USER');
    
    -- Finance team
    apex_auth_pkg.assign_role_to_user('FINANCE_USER1', 'FINANCE');
    apex_auth_pkg.assign_role_to_user('FINANCE_USER1', 'USER');  -- Also has user role
    
    -- HR team
    apex_auth_pkg.assign_role_to_user('HR_USER1', 'HR');
    apex_auth_pkg.assign_role_to_user('HR_USER1', 'USER');  -- Also has user role
    
    -- Temporary role assignment (expires in 30 days)
    apex_auth_pkg.assign_role_to_user(
        p_username       => 'TEMP_CONTRACTOR',
        p_role_code      => 'USER',
        p_effective_from => TRUNC(SYSDATE),
        p_effective_to   => TRUNC(SYSDATE) + 30
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('User role assignments completed');
END;
/

PROMPT ========================================
PROMPT Registering APEX Components (Example App ID: 100)
PROMPT ========================================

DECLARE
    l_app_id CONSTANT NUMBER := 100;  -- Change to your actual app ID
    l_comp_id NUMBER;
BEGIN
    -- =====================
    -- Register Pages
    -- =====================
    apex_auth_pkg.register_page(l_app_id, 1, 'Home Page', 'Main dashboard and landing page');
    apex_auth_pkg.register_page(l_app_id, 2, 'Employee List', 'List of all employees');
    apex_auth_pkg.register_page(l_app_id, 3, 'Employee Details', 'Employee detail form');
    apex_auth_pkg.register_page(l_app_id, 10, 'Reports', 'Reporting dashboard');
    apex_auth_pkg.register_page(l_app_id, 20, 'Finance Dashboard', 'Financial overview');
    apex_auth_pkg.register_page(l_app_id, 30, 'HR Dashboard', 'HR management');
    apex_auth_pkg.register_page(l_app_id, 100, 'Administration', 'System administration');
    apex_auth_pkg.register_page(l_app_id, 101, 'User Management', 'Manage users and roles');
    apex_auth_pkg.register_page(l_app_id, 102, 'System Settings', 'Configure system settings');
    
    -- =====================
    -- Register Regions
    -- =====================
    -- Home page regions
    apex_auth_pkg.register_region(l_app_id, 1, 'REGION_SUMMARY', 'Summary Statistics');
    apex_auth_pkg.register_region(l_app_id, 1, 'REGION_RECENT', 'Recent Activity');
    apex_auth_pkg.register_region(l_app_id, 1, 'REGION_ALERTS', 'System Alerts');
    
    -- Employee page regions
    apex_auth_pkg.register_region(l_app_id, 3, 'REGION_EMP_INFO', 'Employee Information');
    apex_auth_pkg.register_region(l_app_id, 3, 'REGION_SALARY', 'Salary Information');
    apex_auth_pkg.register_region(l_app_id, 3, 'REGION_PERFORMANCE', 'Performance Reviews');
    
    -- Finance regions
    apex_auth_pkg.register_region(l_app_id, 20, 'REGION_REVENUE', 'Revenue Charts');
    apex_auth_pkg.register_region(l_app_id, 20, 'REGION_EXPENSES', 'Expense Reports');
    apex_auth_pkg.register_region(l_app_id, 20, 'REGION_BUDGET', 'Budget Overview');
    
    -- =====================
    -- Register Buttons
    -- =====================
    -- Employee form buttons
    apex_auth_pkg.register_button(l_app_id, 3, 'BTN_SAVE', 'Save Employee');
    apex_auth_pkg.register_button(l_app_id, 3, 'BTN_DELETE', 'Delete Employee');
    apex_auth_pkg.register_button(l_app_id, 3, 'BTN_PROMOTE', 'Promote Employee');
    apex_auth_pkg.register_button(l_app_id, 3, 'BTN_TERMINATE', 'Terminate Employee');
    
    -- Admin buttons
    apex_auth_pkg.register_button(l_app_id, 101, 'BTN_CREATE_USER', 'Create User');
    apex_auth_pkg.register_button(l_app_id, 101, 'BTN_RESET_PASSWORD', 'Reset Password');
    apex_auth_pkg.register_button(l_app_id, 102, 'BTN_EXPORT_CONFIG', 'Export Configuration');
    apex_auth_pkg.register_button(l_app_id, 102, 'BTN_IMPORT_CONFIG', 'Import Configuration');
    
    -- =====================
    -- Register Menu Entries
    -- =====================
    apex_auth_pkg.register_menu_entry(l_app_id, 'MENU_HOME', 'Home');
    apex_auth_pkg.register_menu_entry(l_app_id, 'MENU_EMPLOYEES', 'Employees');
    apex_auth_pkg.register_menu_entry(l_app_id, 'MENU_REPORTS', 'Reports');
    apex_auth_pkg.register_menu_entry(l_app_id, 'MENU_FINANCE', 'Finance');
    apex_auth_pkg.register_menu_entry(l_app_id, 'MENU_HR', 'Human Resources');
    apex_auth_pkg.register_menu_entry(l_app_id, 'MENU_ADMIN', 'Administration');
    apex_auth_pkg.register_menu_entry(l_app_id, 'MENU_SETTINGS', 'Settings');
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Components registered successfully');
END;
/

PROMPT ========================================
PROMPT Granting Permissions to Roles
PROMPT ========================================

DECLARE
    l_app_id CONSTANT NUMBER := 100;  -- Change to your actual app ID
BEGIN
    -- =====================================================
    -- ADMIN Role - Full access to everything
    -- =====================================================
    -- Pages
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'PAGE', '1', 1, 'Y', 'Y', 'Y', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'PAGE', '2', 2, 'Y', 'Y', 'Y', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'PAGE', '3', 3, 'Y', 'Y', 'Y', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'PAGE', '10', 10, 'Y', 'Y', 'Y', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'PAGE', '20', 20, 'Y', 'Y', 'Y', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'PAGE', '30', 30, 'Y', 'Y', 'Y', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'PAGE', '100', 100, 'Y', 'Y', 'Y', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'PAGE', '101', 101, 'Y', 'Y', 'Y', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'PAGE', '102', 102, 'Y', 'Y', 'Y', 'Y');
    
    -- All menu entries for admin
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'MENU', 'MENU_HOME', NULL, 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'MENU', 'MENU_EMPLOYEES', NULL, 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'MENU', 'MENU_REPORTS', NULL, 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'MENU', 'MENU_FINANCE', NULL, 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'MENU', 'MENU_HR', NULL, 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'MENU', 'MENU_ADMIN', NULL, 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'MENU', 'MENU_SETTINGS', NULL, 'Y');
    
    -- All buttons for admin
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'BUTTON', 'BTN_SAVE', 3, 'Y', 'N', 'N', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'BUTTON', 'BTN_DELETE', 3, 'Y', 'N', 'N', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'BUTTON', 'BTN_PROMOTE', 3, 'Y', 'N', 'N', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'BUTTON', 'BTN_TERMINATE', 3, 'Y', 'N', 'N', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'BUTTON', 'BTN_CREATE_USER', 101, 'Y', 'N', 'N', 'Y');
    apex_auth_pkg.grant_permission_by_name('ADMIN', l_app_id, 'BUTTON', 'BTN_RESET_PASSWORD', 101, 'Y', 'N', 'N', 'Y');
    
    -- =====================================================
    -- MANAGER Role - Most areas except admin
    -- =====================================================
    apex_auth_pkg.grant_permission_by_name('MANAGER', l_app_id, 'PAGE', '1', 1, 'Y', 'Y', 'N', 'Y');
    apex_auth_pkg.grant_permission_by_name('MANAGER', l_app_id, 'PAGE', '2', 2, 'Y', 'Y', 'N', 'Y');
    apex_auth_pkg.grant_permission_by_name('MANAGER', l_app_id, 'PAGE', '3', 3, 'Y', 'Y', 'Y', 'Y');
    apex_auth_pkg.grant_permission_by_name('MANAGER', l_app_id, 'PAGE', '10', 10, 'Y', 'Y', 'N', 'Y');
    
    -- Manager menu entries
    apex_auth_pkg.grant_permission_by_name('MANAGER', l_app_id, 'MENU', 'MENU_HOME', NULL, 'Y');
    apex_auth_pkg.grant_permission_by_name('MANAGER', l_app_id, 'MENU', 'MENU_EMPLOYEES', NULL, 'Y');
    apex_auth_pkg.grant_permission_by_name('MANAGER', l_app_id, 'MENU', 'MENU_REPORTS', NULL, 'Y');
    
    -- Manager buttons
    apex_auth_pkg.grant_permission_by_name('MANAGER', l_app_id, 'BUTTON', 'BTN_SAVE', 3, 'Y', 'N', 'N', 'Y');
    apex_auth_pkg.grant_permission_by_name('MANAGER', l_app_id, 'BUTTON', 'BTN_DELETE', 3, 'Y', 'N', 'N', 'Y');
    
    -- Manager regions (can see salary info)
    apex_auth_pkg.grant_permission_by_name('MANAGER', l_app_id, 'REGION', 'REGION_EMP_INFO', 3, 'Y');
    apex_auth_pkg.grant_permission_by_name('MANAGER', l_app_id, 'REGION', 'REGION_SALARY', 3, 'Y');
    apex_auth_pkg.grant_permission_by_name('MANAGER', l_app_id, 'REGION', 'REGION_PERFORMANCE', 3, 'Y');
    
    -- =====================================================
    -- USER Role - Basic access
    -- =====================================================
    apex_auth_pkg.grant_permission_by_name('USER', l_app_id, 'PAGE', '1', 1, 'Y', 'N', 'N', 'N');
    apex_auth_pkg.grant_permission_by_name('USER', l_app_id, 'PAGE', '2', 2, 'Y', 'N', 'N', 'N');
    apex_auth_pkg.grant_permission_by_name('USER', l_app_id, 'PAGE', '3', 3, 'Y', 'N', 'N', 'N');
    
    -- User menu entries
    apex_auth_pkg.grant_permission_by_name('USER', l_app_id, 'MENU', 'MENU_HOME', NULL, 'Y');
    apex_auth_pkg.grant_permission_by_name('USER', l_app_id, 'MENU', 'MENU_EMPLOYEES', NULL, 'Y');
    
    -- User regions (cannot see salary)
    apex_auth_pkg.grant_permission_by_name('USER', l_app_id, 'REGION', 'REGION_EMP_INFO', 3, 'Y');
    -- Note: REGION_SALARY not granted to USER role
    
    -- =====================================================
    -- FINANCE Role - Finance areas only
    -- =====================================================
    apex_auth_pkg.grant_permission_by_name('FINANCE', l_app_id, 'PAGE', '1', 1, 'Y', 'N', 'N', 'N');
    apex_auth_pkg.grant_permission_by_name('FINANCE', l_app_id, 'PAGE', '20', 20, 'Y', 'Y', 'N', 'Y');
    
    apex_auth_pkg.grant_permission_by_name('FINANCE', l_app_id, 'MENU', 'MENU_HOME', NULL, 'Y');
    apex_auth_pkg.grant_permission_by_name('FINANCE', l_app_id, 'MENU', 'MENU_FINANCE', NULL, 'Y');
    
    apex_auth_pkg.grant_permission_by_name('FINANCE', l_app_id, 'REGION', 'REGION_REVENUE', 20, 'Y');
    apex_auth_pkg.grant_permission_by_name('FINANCE', l_app_id, 'REGION', 'REGION_EXPENSES', 20, 'Y');
    apex_auth_pkg.grant_permission_by_name('FINANCE', l_app_id, 'REGION', 'REGION_BUDGET', 20, 'Y');
    
    -- =====================================================
    -- HR Role - HR areas only
    -- =====================================================
    apex_auth_pkg.grant_permission_by_name('HR', l_app_id, 'PAGE', '1', 1, 'Y', 'N', 'N', 'N');
    apex_auth_pkg.grant_permission_by_name('HR', l_app_id, 'PAGE', '2', 2, 'Y', 'Y', 'N', 'Y');
    apex_auth_pkg.grant_permission_by_name('HR', l_app_id, 'PAGE', '3', 3, 'Y', 'Y', 'Y', 'Y');
    apex_auth_pkg.grant_permission_by_name('HR', l_app_id, 'PAGE', '30', 30, 'Y', 'Y', 'Y', 'Y');
    
    apex_auth_pkg.grant_permission_by_name('HR', l_app_id, 'MENU', 'MENU_HOME', NULL, 'Y');
    apex_auth_pkg.grant_permission_by_name('HR', l_app_id, 'MENU', 'MENU_EMPLOYEES', NULL, 'Y');
    apex_auth_pkg.grant_permission_by_name('HR', l_app_id, 'MENU', 'MENU_HR', NULL, 'Y');
    
    -- HR can see all employee regions including salary
    apex_auth_pkg.grant_permission_by_name('HR', l_app_id, 'REGION', 'REGION_EMP_INFO', 3, 'Y');
    apex_auth_pkg.grant_permission_by_name('HR', l_app_id, 'REGION', 'REGION_SALARY', 3, 'Y');
    apex_auth_pkg.grant_permission_by_name('HR', l_app_id, 'REGION', 'REGION_PERFORMANCE', 3, 'Y');
    
    -- HR can terminate employees
    apex_auth_pkg.grant_permission_by_name('HR', l_app_id, 'BUTTON', 'BTN_SAVE', 3, 'Y', 'N', 'N', 'Y');
    apex_auth_pkg.grant_permission_by_name('HR', l_app_id, 'BUTTON', 'BTN_TERMINATE', 3, 'Y', 'N', 'N', 'Y');
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Permissions granted successfully');
END;
/

PROMPT ========================================
PROMPT Sample Data Setup Complete
PROMPT ========================================
