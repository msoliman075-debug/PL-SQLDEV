/*
================================================================================
  Dynamic Authorization Scheme - APEX Usage Guide
  Oracle APEX Security Framework
  
  This file contains examples of how to use the authorization package
  within Oracle APEX applications.
  
================================================================================
*/

/*
================================================================================
  PART 1: CREATING AUTHORIZATION SCHEMES IN APEX
================================================================================

To create authorization schemes in Oracle APEX:

1. Go to: Shared Components > Authorization Schemes
2. Click "Create"
3. Select "From Scratch" and choose "PL/SQL Function Returning Boolean"
4. Create the following authorization schemes:

--------------------------------------------------------------------------------
AUTHORIZATION SCHEME 1: Page-Level Authorization
--------------------------------------------------------------------------------
Name: DYNAMIC_PAGE_AUTH
Scheme Type: PL/SQL Function Returning Boolean
PL/SQL Function Body:
*/

-- For Page Authorization (copy this to APEX):
/*
RETURN apex_auth_pkg.can_access_page(
    p_page_id        => :APP_PAGE_ID,
    p_application_id => :APP_ID,
    p_username       => :APP_USER
);
*/

/*
--------------------------------------------------------------------------------
AUTHORIZATION SCHEME 2: Region Authorization (Generic)
--------------------------------------------------------------------------------
Name: DYNAMIC_REGION_AUTH
Scheme Type: PL/SQL Function Returning Boolean
PL/SQL Function Body:
(Use with Region Static ID)
*/

-- For Region Authorization (copy this to APEX):
-- Set on each region, passing the region's static ID
/*
RETURN apex_auth_pkg.can_view_region(
    p_region_static_id => 'REGION_SALARY',  -- Replace with actual Static ID
    p_page_id          => :APP_PAGE_ID,
    p_application_id   => :APP_ID,
    p_username         => :APP_USER
);
*/

/*
--------------------------------------------------------------------------------
AUTHORIZATION SCHEME 3: Button Authorization (Generic)
--------------------------------------------------------------------------------
Name: DYNAMIC_BUTTON_AUTH
Scheme Type: PL/SQL Function Returning Boolean
PL/SQL Function Body:
*/

-- For Button Authorization (copy this to APEX):
/*
RETURN apex_auth_pkg.can_use_button(
    p_button_static_id => 'BTN_SAVE',  -- Replace with actual Static ID
    p_page_id          => :APP_PAGE_ID,
    p_application_id   => :APP_ID,
    p_username         => :APP_USER
);
*/

/*
--------------------------------------------------------------------------------
AUTHORIZATION SCHEME 4: Navigation Menu Entry Authorization
--------------------------------------------------------------------------------
Name: DYNAMIC_MENU_AUTH
Scheme Type: PL/SQL Function Returning Boolean
PL/SQL Function Body:
*/

-- For Menu Entry Authorization (copy this to APEX):
/*
RETURN apex_auth_pkg.can_view_menu_entry(
    p_menu_entry_name => 'MENU_ADMIN',  -- Replace with actual menu entry name
    p_application_id  => :APP_ID,
    p_username        => :APP_USER
);
*/

/*
--------------------------------------------------------------------------------
AUTHORIZATION SCHEME 5: Role-Based Authorization
--------------------------------------------------------------------------------
Name: IS_ADMIN
Scheme Type: PL/SQL Function Returning Boolean
PL/SQL Function Body:
*/

-- Check if user has ADMIN role:
/*
RETURN apex_auth_pkg.has_role(
    p_role_code => 'ADMIN',
    p_username  => :APP_USER
);
*/

/*
--------------------------------------------------------------------------------
AUTHORIZATION SCHEME 6: Multiple Roles Check
--------------------------------------------------------------------------------
Name: IS_MANAGER_OR_ADMIN
Scheme Type: PL/SQL Function Returning Boolean
PL/SQL Function Body:
*/

-- Check if user has ADMIN or MANAGER role:
/*
RETURN apex_auth_pkg.has_any_role(
    p_role_codes => apex_auth_pkg.t_role_list('ADMIN', 'MANAGER'),
    p_username   => :APP_USER
);
*/

/*
================================================================================
  PART 2: CREATING REUSABLE AUTHORIZATION SCHEMES WITH COMPONENT CONDITIONS
================================================================================

For a more elegant approach, create a single authorization scheme that reads
the component name from a Component Setting:

--------------------------------------------------------------------------------
UNIVERSAL AUTHORIZATION SCHEME
--------------------------------------------------------------------------------
Name: UNIVERSAL_DYNAMIC_AUTH
Scheme Type: PL/SQL Function Returning Boolean

Then when applying to components, you can use an Expression with substitution:

For example, in Page Designer, under Authorization:
- Authorization Scheme: (Create individual schemes OR use Server-Side Condition)
*/

/*
================================================================================
  PART 3: SQL QUERIES FOR ADMINISTRATION PAGES
================================================================================

Use these queries to build administration pages for managing authorization:
*/

-- Query: List all roles
SELECT 
    role_id,
    role_code,
    role_name,
    role_description,
    is_active,
    display_sequence,
    created_date,
    created_by
FROM apex_auth_roles
ORDER BY display_sequence, role_code;

-- Query: List users and their roles
SELECT 
    ur.user_role_id,
    ur.username,
    r.role_code,
    r.role_name,
    ur.is_active,
    ur.effective_from,
    ur.effective_to,
    CASE 
        WHEN ur.is_active = 'Y' 
             AND TRUNC(SYSDATE) BETWEEN ur.effective_from 
                                    AND NVL(ur.effective_to, TRUNC(SYSDATE))
        THEN 'Active'
        ELSE 'Inactive'
    END AS status
FROM apex_auth_user_roles ur
JOIN apex_auth_roles r ON r.role_id = ur.role_id
ORDER BY ur.username, r.display_sequence;

-- Query: List all components by application
SELECT 
    c.component_id,
    c.application_id,
    ct.component_type_name,
    c.page_id,
    c.component_name,
    c.component_static_id,
    c.display_name,
    c.is_active
FROM apex_auth_components c
JOIN apex_auth_component_types ct ON ct.component_type_id = c.component_type_id
WHERE c.application_id = :P_APP_ID  -- Bind variable for app ID
ORDER BY ct.display_sequence, c.page_id NULLS FIRST, c.display_sequence;

-- Query: List permissions matrix (Role x Component)
SELECT 
    r.role_code,
    r.role_name,
    ct.component_type_name,
    c.component_name,
    c.display_name,
    c.page_id,
    p.can_view,
    p.can_edit,
    p.can_delete,
    p.can_execute,
    p.is_active AS permission_active
FROM apex_auth_permissions p
JOIN apex_auth_roles r ON r.role_id = p.role_id
JOIN apex_auth_components c ON c.component_id = p.component_id
JOIN apex_auth_component_types ct ON ct.component_type_id = c.component_type_id
WHERE c.application_id = :P_APP_ID
ORDER BY r.display_sequence, ct.display_sequence, c.page_id, c.component_name;

-- Query: Get current user's permissions
SELECT 
    ct.component_type_name,
    c.component_name,
    c.display_name,
    c.page_id,
    MAX(p.can_view) AS can_view,
    MAX(p.can_edit) AS can_edit,
    MAX(p.can_delete) AS can_delete,
    MAX(p.can_execute) AS can_execute
FROM apex_auth_permissions p
JOIN apex_auth_roles r ON r.role_id = p.role_id
JOIN apex_auth_user_roles ur ON ur.role_id = r.role_id
JOIN apex_auth_components c ON c.component_id = p.component_id
JOIN apex_auth_component_types ct ON ct.component_type_id = c.component_type_id
WHERE UPPER(ur.username) = UPPER(:APP_USER)
AND ur.is_active = 'Y'
AND r.is_active = 'Y'
AND p.is_active = 'Y'
AND c.is_active = 'Y'
AND TRUNC(SYSDATE) BETWEEN ur.effective_from AND NVL(ur.effective_to, TRUNC(SYSDATE))
AND TRUNC(SYSDATE) BETWEEN p.effective_from AND NVL(p.effective_to, TRUNC(SYSDATE))
AND c.application_id = :APP_ID
GROUP BY ct.component_type_name, c.component_name, c.display_name, c.page_id
ORDER BY ct.component_type_name, c.page_id, c.component_name;

-- Query: Audit log for security monitoring
SELECT 
    audit_id,
    audit_date,
    audit_type,
    username,
    application_id,
    page_id,
    component_type,
    component_name,
    action_taken,
    auth_result,
    ip_address,
    session_id
FROM apex_auth_audit_log
WHERE audit_date >= SYSTIMESTAMP - INTERVAL '7' DAY
ORDER BY audit_date DESC;

/*
================================================================================
  PART 4: PL/SQL EXAMPLES FOR APPLICATION PROCESSES
================================================================================
*/

-- Example: Application Process to set user roles in session state
-- (Run "On Load: Before Header" on page 0 or as an Application Process)
/*
DECLARE
    l_roles VARCHAR2(4000);
BEGIN
    -- Get user's roles and store in application item
    l_roles := apex_auth_pkg.get_user_roles(:APP_USER);
    
    -- Set application item (create G_USER_ROLES as Hidden application item)
    apex_util.set_session_state('G_USER_ROLES', l_roles);
END;
*/

-- Example: Check authorization in a Page Process
/*
BEGIN
    -- Verify user can execute this action
    IF NOT apex_auth_pkg.is_authorized(
        p_component_type  => 'BUTTON',
        p_component_name  => 'BTN_DELETE',
        p_permission_type => 'EXECUTE'
    ) THEN
        apex_error.add_error(
            p_message          => 'You do not have permission to delete records.',
            p_display_location => apex_error.c_inline_in_notification
        );
        RETURN;
    END IF;
    
    -- Proceed with delete operation
    DELETE FROM employees WHERE employee_id = :P3_EMPLOYEE_ID;
END;
*/

-- Example: Dynamic Actions - Server-side Condition
-- In a Dynamic Action, use this as a Server-side Condition (PL/SQL Expression):
/*
apex_auth_pkg.is_authorized(
    p_component_type  => 'BUTTON',
    p_component_name  => 'BTN_SPECIAL_ACTION',
    p_permission_type => 'EXECUTE'
)
*/

/*
================================================================================
  PART 5: NAVIGATION MENU SETUP
================================================================================

For Navigation Menu entries, you can set authorization on each entry:

1. Go to Shared Components > Navigation Menu
2. Edit each list entry
3. In the "Authorization" section, set:
   - Authorization Scheme: Create one for each menu entry, OR
   - Use Conditions with PL/SQL Expression

Example PL/SQL Expression for menu entry condition:
*/

-- Menu entry condition (Type: PL/SQL Expression):
/*
apex_auth_pkg.can_view_menu_entry('MENU_ADMIN')
*/

/*
================================================================================
  PART 6: VIEWS FOR EASIER QUERYING
================================================================================
*/

-- Create view for effective user permissions (current user, current date)
CREATE OR REPLACE VIEW v_apex_auth_user_effective_perms AS
SELECT 
    ur.username,
    r.role_code,
    r.role_name,
    c.application_id,
    ct.component_type_code,
    ct.component_type_name,
    c.page_id,
    c.component_name,
    c.component_static_id,
    c.display_name AS component_display_name,
    p.can_view,
    p.can_edit,
    p.can_delete,
    p.can_execute
FROM apex_auth_permissions p
JOIN apex_auth_roles r ON r.role_id = p.role_id
JOIN apex_auth_user_roles ur ON ur.role_id = r.role_id
JOIN apex_auth_components c ON c.component_id = p.component_id
JOIN apex_auth_component_types ct ON ct.component_type_id = c.component_type_id
WHERE ur.is_active = 'Y'
AND r.is_active = 'Y'
AND p.is_active = 'Y'
AND c.is_active = 'Y'
AND TRUNC(SYSDATE) BETWEEN ur.effective_from AND NVL(ur.effective_to, TRUNC(SYSDATE))
AND TRUNC(SYSDATE) BETWEEN p.effective_from AND NVL(p.effective_to, TRUNC(SYSDATE));

-- Create view for role permission summary
CREATE OR REPLACE VIEW v_apex_auth_role_perms AS
SELECT 
    r.role_code,
    r.role_name,
    c.application_id,
    ct.component_type_code,
    c.page_id,
    c.component_name,
    c.display_name,
    p.can_view,
    p.can_edit,
    p.can_delete,
    p.can_execute,
    p.is_active,
    p.effective_from,
    p.effective_to
FROM apex_auth_permissions p
JOIN apex_auth_roles r ON r.role_id = p.role_id
JOIN apex_auth_components c ON c.component_id = p.component_id
JOIN apex_auth_component_types ct ON ct.component_type_id = c.component_type_id
WHERE r.is_active = 'Y'
AND c.is_active = 'Y';

PROMPT ========================================
PROMPT APEX Usage Guide Complete
PROMPT Views created:
PROMPT   - V_APEX_AUTH_USER_EFFECTIVE_PERMS
PROMPT   - V_APEX_AUTH_ROLE_PERMS
PROMPT ========================================
