/*
================================================================================
  Dynamic Authorization Scheme - Package Specification
  Oracle APEX Security Framework
  
  Purpose: PL/SQL Package to manage dynamic authorization for APEX components
  
  Target: Oracle 19c+ / Oracle APEX 21.1+
  Author: APEX Security Framework
  
================================================================================
*/

CREATE OR REPLACE PACKAGE apex_auth_pkg AS
    /*
    ==========================================================================
    Package: APEX_AUTH_PKG
    Purpose: Provides authorization checking and management functions for
             Oracle APEX dynamic security framework
    
    Main Features:
      - Check user authorization for pages, regions, buttons, menus
      - Manage roles and user assignments
      - Register and manage components
      - Audit logging for security events
    ==========================================================================
    */
    
    -- ========================================================================
    -- Global Constants
    -- ========================================================================
    gc_version          CONSTANT VARCHAR2(10) := '1.0.0';
    
    -- Component Type Codes
    gc_comp_page        CONSTANT VARCHAR2(30) := 'PAGE';
    gc_comp_region      CONSTANT VARCHAR2(30) := 'REGION';
    gc_comp_button      CONSTANT VARCHAR2(30) := 'BUTTON';
    gc_comp_menu        CONSTANT VARCHAR2(30) := 'MENU';
    gc_comp_list_entry  CONSTANT VARCHAR2(30) := 'LIST_ENTRY';
    gc_comp_tab         CONSTANT VARCHAR2(30) := 'TAB';
    gc_comp_item        CONSTANT VARCHAR2(30) := 'ITEM';
    gc_comp_report_col  CONSTANT VARCHAR2(30) := 'REPORT_COL';
    gc_comp_process     CONSTANT VARCHAR2(30) := 'PROCESS';
    gc_comp_computation CONSTANT VARCHAR2(30) := 'COMPUTATION';
    
    -- Permission Types
    gc_perm_view        CONSTANT VARCHAR2(10) := 'VIEW';
    gc_perm_edit        CONSTANT VARCHAR2(10) := 'EDIT';
    gc_perm_delete      CONSTANT VARCHAR2(10) := 'DELETE';
    gc_perm_execute     CONSTANT VARCHAR2(10) := 'EXECUTE';
    
    -- Audit Types
    gc_audit_auth_check CONSTANT VARCHAR2(50) := 'AUTH_CHECK';
    gc_audit_role_chg   CONSTANT VARCHAR2(50) := 'ROLE_CHANGE';
    gc_audit_perm_chg   CONSTANT VARCHAR2(50) := 'PERMISSION_CHANGE';
    gc_audit_comp_chg   CONSTANT VARCHAR2(50) := 'COMPONENT_CHANGE';
    gc_audit_error      CONSTANT VARCHAR2(50) := 'ERROR';
    
    -- ========================================================================
    -- Exception Declarations
    -- ========================================================================
    e_role_not_found      EXCEPTION;
    e_component_not_found EXCEPTION;
    e_invalid_parameter   EXCEPTION;
    e_permission_denied   EXCEPTION;
    
    PRAGMA EXCEPTION_INIT(e_role_not_found, -20001);
    PRAGMA EXCEPTION_INIT(e_component_not_found, -20002);
    PRAGMA EXCEPTION_INIT(e_invalid_parameter, -20003);
    PRAGMA EXCEPTION_INIT(e_permission_denied, -20004);
    
    -- ========================================================================
    -- Type Declarations
    -- ========================================================================
    TYPE t_role_list IS TABLE OF apex_auth_roles.role_code%TYPE;
    TYPE t_varchar2_list IS TABLE OF VARCHAR2(4000);
    
    -- ========================================================================
    -- Authorization Check Functions (Use in APEX Authorization Schemes)
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Function: is_authorized
    Purpose:  Main authorization check - use this in APEX Authorization Schemes
    
    Parameters:
      p_component_type  - Type of component (PAGE, REGION, BUTTON, MENU, etc.)
      p_component_name  - Name/identifier of the component
      p_application_id  - APEX Application ID (default: current app)
      p_page_id         - APEX Page ID (default: current page)
      p_permission_type - Permission to check: VIEW, EDIT, DELETE, EXECUTE
      p_username        - Username to check (default: current APEX user)
    
    Returns: TRUE if authorized, FALSE otherwise
    
    Usage in APEX Authorization Scheme (PL/SQL Function Body):
      RETURN apex_auth_pkg.is_authorized(
          p_component_type => 'BUTTON',
          p_component_name => 'BTN_SAVE'
      );
    --------------------------------------------------------------------------
    */
    FUNCTION is_authorized(
        p_component_type    IN VARCHAR2,
        p_component_name    IN VARCHAR2,
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_page_id           IN NUMBER   DEFAULT NV('APP_PAGE_ID'),
        p_permission_type   IN VARCHAR2 DEFAULT gc_perm_view,
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN;
    
    /*
    --------------------------------------------------------------------------
    Function: is_authorized_yn
    Purpose:  Same as is_authorized but returns Y/N (for SQL queries)
    --------------------------------------------------------------------------
    */
    FUNCTION is_authorized_yn(
        p_component_type    IN VARCHAR2,
        p_component_name    IN VARCHAR2,
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_page_id           IN NUMBER   DEFAULT NV('APP_PAGE_ID'),
        p_permission_type   IN VARCHAR2 DEFAULT gc_perm_view,
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN VARCHAR2;
    
    /*
    --------------------------------------------------------------------------
    Function: can_access_page
    Purpose:  Check if user can access a specific page
    --------------------------------------------------------------------------
    */
    FUNCTION can_access_page(
        p_page_id           IN NUMBER,
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN;
    
    /*
    --------------------------------------------------------------------------
    Function: can_view_region
    Purpose:  Check if user can view a specific region
    --------------------------------------------------------------------------
    */
    FUNCTION can_view_region(
        p_region_static_id  IN VARCHAR2,
        p_page_id           IN NUMBER   DEFAULT NV('APP_PAGE_ID'),
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN;
    
    /*
    --------------------------------------------------------------------------
    Function: can_use_button
    Purpose:  Check if user can see/use a specific button
    --------------------------------------------------------------------------
    */
    FUNCTION can_use_button(
        p_button_static_id  IN VARCHAR2,
        p_page_id           IN NUMBER   DEFAULT NV('APP_PAGE_ID'),
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN;
    
    /*
    --------------------------------------------------------------------------
    Function: can_view_menu_entry
    Purpose:  Check if user can see a navigation menu entry
    --------------------------------------------------------------------------
    */
    FUNCTION can_view_menu_entry(
        p_menu_entry_name   IN VARCHAR2,
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN;
    
    /*
    --------------------------------------------------------------------------
    Function: has_role
    Purpose:  Check if user has a specific role
    --------------------------------------------------------------------------
    */
    FUNCTION has_role(
        p_role_code         IN VARCHAR2,
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN;
    
    /*
    --------------------------------------------------------------------------
    Function: has_any_role
    Purpose:  Check if user has any of the specified roles
    --------------------------------------------------------------------------
    */
    FUNCTION has_any_role(
        p_role_codes        IN t_role_list,
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN;
    
    /*
    --------------------------------------------------------------------------
    Function: has_all_roles
    Purpose:  Check if user has all of the specified roles
    --------------------------------------------------------------------------
    */
    FUNCTION has_all_roles(
        p_role_codes        IN t_role_list,
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN;
    
    /*
    --------------------------------------------------------------------------
    Function: get_user_roles
    Purpose:  Get comma-separated list of user's active roles
    --------------------------------------------------------------------------
    */
    FUNCTION get_user_roles(
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN VARCHAR2;
    
    -- ========================================================================
    -- Role Management Procedures
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Procedure: create_role
    Purpose:   Create a new authorization role
    --------------------------------------------------------------------------
    */
    PROCEDURE create_role(
        p_role_code         IN VARCHAR2,
        p_role_name         IN VARCHAR2,
        p_role_description  IN VARCHAR2 DEFAULT NULL,
        p_display_sequence  IN NUMBER   DEFAULT 0,
        p_role_id           OUT NUMBER
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: update_role
    Purpose:   Update an existing role
    --------------------------------------------------------------------------
    */
    PROCEDURE update_role(
        p_role_id           IN NUMBER,
        p_role_name         IN VARCHAR2 DEFAULT NULL,
        p_role_description  IN VARCHAR2 DEFAULT NULL,
        p_is_active         IN VARCHAR2 DEFAULT NULL,
        p_display_sequence  IN NUMBER   DEFAULT NULL
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: delete_role
    Purpose:   Delete a role (cascades to user assignments and permissions)
    --------------------------------------------------------------------------
    */
    PROCEDURE delete_role(
        p_role_id           IN NUMBER
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: assign_role_to_user
    Purpose:   Assign a role to a user
    --------------------------------------------------------------------------
    */
    PROCEDURE assign_role_to_user(
        p_username          IN VARCHAR2,
        p_role_code         IN VARCHAR2,
        p_effective_from    IN DATE     DEFAULT TRUNC(SYSDATE),
        p_effective_to      IN DATE     DEFAULT NULL
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: remove_role_from_user
    Purpose:   Remove a role from a user
    --------------------------------------------------------------------------
    */
    PROCEDURE remove_role_from_user(
        p_username          IN VARCHAR2,
        p_role_code         IN VARCHAR2
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: sync_user_roles
    Purpose:   Synchronize user roles (remove all, add new list)
    --------------------------------------------------------------------------
    */
    PROCEDURE sync_user_roles(
        p_username          IN VARCHAR2,
        p_role_codes        IN t_role_list
    );
    
    -- ========================================================================
    -- Component Management Procedures
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Procedure: register_component
    Purpose:   Register an APEX component for authorization
    --------------------------------------------------------------------------
    */
    PROCEDURE register_component(
        p_application_id      IN NUMBER,
        p_component_type_code IN VARCHAR2,
        p_component_name      IN VARCHAR2,
        p_page_id             IN NUMBER   DEFAULT NULL,
        p_component_static_id IN VARCHAR2 DEFAULT NULL,
        p_display_name        IN VARCHAR2 DEFAULT NULL,
        p_description         IN VARCHAR2 DEFAULT NULL,
        p_parent_component_id IN NUMBER   DEFAULT NULL,
        p_component_id        OUT NUMBER
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: register_page
    Purpose:   Register a page component (convenience wrapper)
    --------------------------------------------------------------------------
    */
    PROCEDURE register_page(
        p_application_id    IN NUMBER,
        p_page_id           IN NUMBER,
        p_display_name      IN VARCHAR2 DEFAULT NULL,
        p_description       IN VARCHAR2 DEFAULT NULL
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: register_region
    Purpose:   Register a region component (convenience wrapper)
    --------------------------------------------------------------------------
    */
    PROCEDURE register_region(
        p_application_id    IN NUMBER,
        p_page_id           IN NUMBER,
        p_region_static_id  IN VARCHAR2,
        p_display_name      IN VARCHAR2 DEFAULT NULL,
        p_description       IN VARCHAR2 DEFAULT NULL
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: register_button
    Purpose:   Register a button component (convenience wrapper)
    --------------------------------------------------------------------------
    */
    PROCEDURE register_button(
        p_application_id    IN NUMBER,
        p_page_id           IN NUMBER,
        p_button_static_id  IN VARCHAR2,
        p_display_name      IN VARCHAR2 DEFAULT NULL,
        p_description       IN VARCHAR2 DEFAULT NULL
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: register_menu_entry
    Purpose:   Register a navigation menu entry (convenience wrapper)
    --------------------------------------------------------------------------
    */
    PROCEDURE register_menu_entry(
        p_application_id    IN NUMBER,
        p_menu_entry_name   IN VARCHAR2,
        p_display_name      IN VARCHAR2 DEFAULT NULL,
        p_description       IN VARCHAR2 DEFAULT NULL
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: deactivate_component
    Purpose:   Deactivate a component (soft delete)
    --------------------------------------------------------------------------
    */
    PROCEDURE deactivate_component(
        p_component_id      IN NUMBER
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: delete_component
    Purpose:   Permanently delete a component
    --------------------------------------------------------------------------
    */
    PROCEDURE delete_component(
        p_component_id      IN NUMBER
    );
    
    -- ========================================================================
    -- Permission Management Procedures
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Procedure: grant_permission
    Purpose:   Grant permission on a component to a role
    --------------------------------------------------------------------------
    */
    PROCEDURE grant_permission(
        p_role_code         IN VARCHAR2,
        p_component_id      IN NUMBER,
        p_can_view          IN VARCHAR2 DEFAULT 'Y',
        p_can_edit          IN VARCHAR2 DEFAULT 'N',
        p_can_delete        IN VARCHAR2 DEFAULT 'N',
        p_can_execute       IN VARCHAR2 DEFAULT 'N',
        p_effective_from    IN DATE     DEFAULT TRUNC(SYSDATE),
        p_effective_to      IN DATE     DEFAULT NULL
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: grant_permission_by_name
    Purpose:   Grant permission using component name instead of ID
    --------------------------------------------------------------------------
    */
    PROCEDURE grant_permission_by_name(
        p_role_code           IN VARCHAR2,
        p_application_id      IN NUMBER,
        p_component_type_code IN VARCHAR2,
        p_component_name      IN VARCHAR2,
        p_page_id             IN NUMBER   DEFAULT NULL,
        p_can_view            IN VARCHAR2 DEFAULT 'Y',
        p_can_edit            IN VARCHAR2 DEFAULT 'N',
        p_can_delete          IN VARCHAR2 DEFAULT 'N',
        p_can_execute         IN VARCHAR2 DEFAULT 'N'
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: revoke_permission
    Purpose:   Revoke permission on a component from a role
    --------------------------------------------------------------------------
    */
    PROCEDURE revoke_permission(
        p_role_code         IN VARCHAR2,
        p_component_id      IN NUMBER
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: update_permission
    Purpose:   Update existing permission settings
    --------------------------------------------------------------------------
    */
    PROCEDURE update_permission(
        p_permission_id     IN NUMBER,
        p_can_view          IN VARCHAR2 DEFAULT NULL,
        p_can_edit          IN VARCHAR2 DEFAULT NULL,
        p_can_delete        IN VARCHAR2 DEFAULT NULL,
        p_can_execute       IN VARCHAR2 DEFAULT NULL,
        p_is_active         IN VARCHAR2 DEFAULT NULL,
        p_effective_from    IN DATE     DEFAULT NULL,
        p_effective_to      IN DATE     DEFAULT NULL
    );
    
    -- ========================================================================
    -- Bulk Operations
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Procedure: grant_role_to_all_pages
    Purpose:   Grant view permission to a role for all pages in an app
    --------------------------------------------------------------------------
    */
    PROCEDURE grant_role_to_all_pages(
        p_role_code         IN VARCHAR2,
        p_application_id    IN NUMBER
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: copy_role_permissions
    Purpose:   Copy all permissions from one role to another
    --------------------------------------------------------------------------
    */
    PROCEDURE copy_role_permissions(
        p_source_role_code  IN VARCHAR2,
        p_target_role_code  IN VARCHAR2
    );
    
    -- ========================================================================
    -- Utility Functions
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Function: get_version
    Purpose:  Return package version
    --------------------------------------------------------------------------
    */
    FUNCTION get_version RETURN VARCHAR2;
    
    /*
    --------------------------------------------------------------------------
    Function: get_component_id
    Purpose:  Get component ID by name and type
    --------------------------------------------------------------------------
    */
    FUNCTION get_component_id(
        p_application_id      IN NUMBER,
        p_component_type_code IN VARCHAR2,
        p_component_name      IN VARCHAR2,
        p_page_id             IN NUMBER DEFAULT NULL
    ) RETURN NUMBER;
    
    /*
    --------------------------------------------------------------------------
    Function: get_role_id
    Purpose:  Get role ID by code
    --------------------------------------------------------------------------
    */
    FUNCTION get_role_id(
        p_role_code         IN VARCHAR2
    ) RETURN NUMBER;
    
    -- ========================================================================
    -- Audit Procedures
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Procedure: log_audit
    Purpose:   Write an audit log entry
    --------------------------------------------------------------------------
    */
    PROCEDURE log_audit(
        p_audit_type        IN VARCHAR2,
        p_username          IN VARCHAR2 DEFAULT V('APP_USER'),
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_page_id           IN NUMBER   DEFAULT NULL,
        p_component_type    IN VARCHAR2 DEFAULT NULL,
        p_component_name    IN VARCHAR2 DEFAULT NULL,
        p_action_taken      IN VARCHAR2 DEFAULT NULL,
        p_auth_result       IN VARCHAR2 DEFAULT NULL,
        p_details           IN CLOB     DEFAULT NULL
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: purge_audit_log
    Purpose:   Remove audit log entries older than specified days
    --------------------------------------------------------------------------
    */
    PROCEDURE purge_audit_log(
        p_days_to_keep      IN NUMBER DEFAULT 90
    );

END apex_auth_pkg;
/

SHOW ERRORS PACKAGE apex_auth_pkg;

PROMPT ========================================
PROMPT Package Specification Created: APEX_AUTH_PKG
PROMPT ========================================
