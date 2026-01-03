/*******************************************************************************
 * Oracle APEX Dynamic Authorization Scheme
 * Package Specification
 * 
 * Package: APEX_AUTHORIZATION_PKG
 * Purpose: Provides comprehensive authorization functions for APEX applications
 *          to control access to Menus, Pages, Regions, and Buttons
 * 
 * Author: Generated for Oracle APEX 19c+
 * Date: January 2026
 ******************************************************************************/

CREATE OR REPLACE PACKAGE apex_authorization_pkg AS

    /***************************************************************************
     * CONSTANTS
     ***************************************************************************/
    
    -- Authorization results
    c_auth_granted      CONSTANT VARCHAR2(10) := 'GRANTED';
    c_auth_denied       CONSTANT VARCHAR2(10) := 'DENIED';
    
    -- Object types
    c_obj_menu          CONSTANT VARCHAR2(20) := 'MENU';
    c_obj_page          CONSTANT VARCHAR2(20) := 'PAGE';
    c_obj_region        CONSTANT VARCHAR2(20) := 'REGION';
    c_obj_button        CONSTANT VARCHAR2(20) := 'BUTTON';
    c_obj_item          CONSTANT VARCHAR2(20) := 'ITEM';
    
    -- Permission types
    c_perm_view         CONSTANT VARCHAR2(20) := 'VIEW';
    c_perm_edit         CONSTANT VARCHAR2(20) := 'EDIT';
    c_perm_delete       CONSTANT VARCHAR2(20) := 'DELETE';
    c_perm_execute      CONSTANT VARCHAR2(20) := 'EXECUTE';
    c_perm_admin        CONSTANT VARCHAR2(20) := 'ADMIN';

    /***************************************************************************
     * EXCEPTIONS
     ***************************************************************************/
    
    e_user_not_found            EXCEPTION;
    e_role_not_found            EXCEPTION;
    e_object_not_found          EXCEPTION;
    e_permission_not_found      EXCEPTION;
    e_invalid_object_type       EXCEPTION;
    e_duplicate_assignment      EXCEPTION;
    e_user_account_locked       EXCEPTION;
    
    -- Exception codes
    ec_user_not_found           CONSTANT NUMBER := -20001;
    ec_role_not_found           CONSTANT NUMBER := -20002;
    ec_object_not_found         CONSTANT NUMBER := -20003;
    ec_permission_not_found     CONSTANT NUMBER := -20004;
    ec_invalid_object_type      CONSTANT NUMBER := -20005;
    ec_duplicate_assignment     CONSTANT NUMBER := -20006;
    ec_user_account_locked      CONSTANT NUMBER := -20007;
    
    PRAGMA EXCEPTION_INIT(e_user_not_found, -20001);
    PRAGMA EXCEPTION_INIT(e_role_not_found, -20002);
    PRAGMA EXCEPTION_INIT(e_object_not_found, -20003);
    PRAGMA EXCEPTION_INIT(e_permission_not_found, -20004);
    PRAGMA EXCEPTION_INIT(e_invalid_object_type, -20005);
    PRAGMA EXCEPTION_INIT(e_duplicate_assignment, -20006);
    PRAGMA EXCEPTION_INIT(e_user_account_locked, -20007);

    /***************************************************************************
     * TYPE DEFINITIONS
     ***************************************************************************/
    
    TYPE t_role_list IS TABLE OF VARCHAR2(100);
    TYPE t_permission_list IS TABLE OF VARCHAR2(100);
    
    TYPE t_auth_result IS RECORD (
        is_authorized       BOOLEAN,
        result_code         VARCHAR2(10),
        reason              VARCHAR2(4000)
    );

    /***************************************************************************
     * CORE AUTHORIZATION FUNCTIONS
     * These are the main functions called by APEX authorization schemes
     ***************************************************************************/

    /**
     * Main authorization function for APEX Authorization Schemes
     * Returns TRUE if user has access, FALSE otherwise
     * 
     * @param p_username         Username (defaults to current APEX user)
     * @param p_application_id   APEX Application ID
     * @param p_object_code      Object identifier (static ID)
     * @param p_object_type      Type: MENU, PAGE, REGION, BUTTON, ITEM
     * @param p_permission_type  Permission: VIEW, EDIT, DELETE, EXECUTE, ADMIN
     * @param p_enable_audit     Enable audit logging (default Y)
     * @return BOOLEAN           TRUE if authorized, FALSE otherwise
     */
    FUNCTION is_authorized(
        p_username          IN VARCHAR2 DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_object_code       IN VARCHAR2,
        p_object_type       IN VARCHAR2 DEFAULT c_obj_page,
        p_permission_type   IN VARCHAR2 DEFAULT c_perm_view,
        p_enable_audit      IN VARCHAR2 DEFAULT 'Y'
    ) RETURN BOOLEAN;

    /**
     * Authorization function specifically for APEX Pages
     * Optimized for page-level authorization schemes
     * 
     * @param p_page_id          APEX Page ID
     * @param p_application_id   APEX Application ID
     * @param p_username         Username (defaults to current APEX user)
     * @return BOOLEAN           TRUE if authorized, FALSE otherwise
     */
    FUNCTION is_page_authorized(
        p_page_id           IN NUMBER,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_username          IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN;

    /**
     * Authorization function for APEX Regions
     * Use in Region Authorization Scheme or Server-side Condition
     * 
     * @param p_region_code      Region Static ID
     * @param p_page_id          APEX Page ID
     * @param p_application_id   APEX Application ID
     * @param p_username         Username (defaults to current APEX user)
     * @return BOOLEAN           TRUE if authorized, FALSE otherwise
     */
    FUNCTION is_region_authorized(
        p_region_code       IN VARCHAR2,
        p_page_id           IN NUMBER DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_username          IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN;

    /**
     * Authorization function for APEX Buttons
     * Use in Button Server-side Condition or Authorization Scheme
     * 
     * @param p_button_code      Button Static ID
     * @param p_page_id          APEX Page ID
     * @param p_application_id   APEX Application ID
     * @param p_username         Username (defaults to current APEX user)
     * @return BOOLEAN           TRUE if authorized, FALSE otherwise
     */
    FUNCTION is_button_authorized(
        p_button_code       IN VARCHAR2,
        p_page_id           IN NUMBER DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_username          IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN;

    /**
     * Authorization function for Navigation Menu Items
     * Use in Navigation Menu Authorization
     * 
     * @param p_menu_code        Menu Static ID
     * @param p_application_id   APEX Application ID
     * @param p_username         Username (defaults to current APEX user)
     * @return BOOLEAN           TRUE if authorized, FALSE otherwise
     */
    FUNCTION is_menu_authorized(
        p_menu_code         IN VARCHAR2,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_username          IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN;

    /**
     * Check if user has a specific role
     * 
     * @param p_username         Username (defaults to current APEX user)
     * @param p_role_code        Role code to check
     * @return BOOLEAN           TRUE if user has role, FALSE otherwise
     */
    FUNCTION has_role(
        p_username          IN VARCHAR2 DEFAULT NULL,
        p_role_code         IN VARCHAR2
    ) RETURN BOOLEAN;

    /**
     * Check if user has ANY of the specified roles
     * 
     * @param p_username         Username (defaults to current APEX user)
     * @param p_role_codes       Comma-separated list of role codes
     * @return BOOLEAN           TRUE if user has any role, FALSE otherwise
     */
    FUNCTION has_any_role(
        p_username          IN VARCHAR2 DEFAULT NULL,
        p_role_codes        IN VARCHAR2
    ) RETURN BOOLEAN;

    /**
     * Check if user has ALL of the specified roles
     * 
     * @param p_username         Username (defaults to current APEX user)
     * @param p_role_codes       Comma-separated list of role codes
     * @return BOOLEAN           TRUE if user has all roles, FALSE otherwise
     */
    FUNCTION has_all_roles(
        p_username          IN VARCHAR2 DEFAULT NULL,
        p_role_codes        IN VARCHAR2
    ) RETURN BOOLEAN;

    /**
     * Get detailed authorization result with reason
     * 
     * @param p_username         Username (defaults to current APEX user)
     * @param p_application_id   APEX Application ID
     * @param p_object_code      Object identifier
     * @param p_object_type      Object type
     * @param p_permission_type  Permission type
     * @return t_auth_result     Authorization result with details
     */
    FUNCTION get_authorization_detail(
        p_username          IN VARCHAR2 DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_object_code       IN VARCHAR2,
        p_object_type       IN VARCHAR2 DEFAULT c_obj_page,
        p_permission_type   IN VARCHAR2 DEFAULT c_perm_view
    ) RETURN t_auth_result;

    /***************************************************************************
     * USER MANAGEMENT FUNCTIONS
     ***************************************************************************/

    /**
     * Get list of roles for a user
     * 
     * @param p_username         Username
     * @return t_role_list       Collection of role codes
     */
    FUNCTION get_user_roles(
        p_username          IN VARCHAR2
    ) RETURN t_role_list;

    /**
     * Check if user account is active and not locked
     * 
     * @param p_username         Username
     * @return BOOLEAN           TRUE if account is active, FALSE otherwise
     */
    FUNCTION is_user_active(
        p_username          IN VARCHAR2
    ) RETURN BOOLEAN;

    /**
     * Get current APEX username with fallback
     * 
     * @return VARCHAR2          Current username
     */
    FUNCTION get_current_username RETURN VARCHAR2;

    /**
     * Get current APEX application ID with fallback
     * 
     * @return NUMBER            Current application ID
     */
    FUNCTION get_current_app_id RETURN NUMBER;

    /***************************************************************************
     * ROLE MANAGEMENT PROCEDURES
     ***************************************************************************/

    /**
     * Create a new role
     * 
     * @param p_role_code        Unique role code
     * @param p_role_name        Display name
     * @param p_role_description Description
     * @param p_is_active        Active flag (default Y)
     */
    PROCEDURE create_role(
        p_role_code         IN VARCHAR2,
        p_role_name         IN VARCHAR2,
        p_role_description  IN VARCHAR2 DEFAULT NULL,
        p_is_active         IN VARCHAR2 DEFAULT 'Y'
    );

    /**
     * Update existing role
     * 
     * @param p_role_code        Role code to update
     * @param p_role_name        New display name
     * @param p_role_description New description
     * @param p_is_active        New active flag
     */
    PROCEDURE update_role(
        p_role_code         IN VARCHAR2,
        p_role_name         IN VARCHAR2 DEFAULT NULL,
        p_role_description  IN VARCHAR2 DEFAULT NULL,
        p_is_active         IN VARCHAR2 DEFAULT NULL
    );

    /**
     * Delete role and all assignments
     * 
     * @param p_role_code        Role code to delete
     */
    PROCEDURE delete_role(
        p_role_code         IN VARCHAR2
    );

    /***************************************************************************
     * USER MANAGEMENT PROCEDURES
     ***************************************************************************/

    /**
     * Register a new user
     * 
     * @param p_username         Username
     * @param p_email            Email address
     * @param p_full_name        Full name
     * @param p_is_active        Active flag (default Y)
     * @param p_effective_from   Effective start date
     * @param p_effective_to     Effective end date
     */
    PROCEDURE create_user(
        p_username          IN VARCHAR2,
        p_email             IN VARCHAR2 DEFAULT NULL,
        p_full_name         IN VARCHAR2 DEFAULT NULL,
        p_is_active         IN VARCHAR2 DEFAULT 'Y',
        p_effective_from    IN DATE DEFAULT SYSDATE,
        p_effective_to      IN DATE DEFAULT NULL
    );

    /**
     * Update existing user
     * 
     * @param p_username         Username
     * @param p_email            New email
     * @param p_full_name        New full name
     * @param p_is_active        New active flag
     * @param p_is_locked        Lock/unlock account
     */
    PROCEDURE update_user(
        p_username          IN VARCHAR2,
        p_email             IN VARCHAR2 DEFAULT NULL,
        p_full_name         IN VARCHAR2 DEFAULT NULL,
        p_is_active         IN VARCHAR2 DEFAULT NULL,
        p_is_locked         IN VARCHAR2 DEFAULT NULL
    );

    /**
     * Assign role to user
     * 
     * @param p_username         Username
     * @param p_role_code        Role code
     * @param p_effective_from   Effective start date
     * @param p_effective_to     Effective end date
     */
    PROCEDURE assign_role_to_user(
        p_username          IN VARCHAR2,
        p_role_code         IN VARCHAR2,
        p_effective_from    IN DATE DEFAULT SYSDATE,
        p_effective_to      IN DATE DEFAULT NULL
    );

    /**
     * Remove role from user
     * 
     * @param p_username         Username
     * @param p_role_code        Role code
     */
    PROCEDURE remove_role_from_user(
        p_username          IN VARCHAR2,
        p_role_code         IN VARCHAR2
    );

    /***************************************************************************
     * OBJECT MANAGEMENT PROCEDURES
     ***************************************************************************/

    /**
     * Register a secureable object (Page, Region, Button, Menu)
     * 
     * @param p_application_id   APEX Application ID
     * @param p_object_type      Object type
     * @param p_object_code      Object identifier (static ID)
     * @param p_object_name      Display name
     * @param p_page_id          Page ID (for regions/buttons)
     * @param p_parent_object_id Parent object ID
     * @param p_object_desc      Description
     */
    PROCEDURE register_object(
        p_application_id    IN NUMBER,
        p_object_type       IN VARCHAR2,
        p_object_code       IN VARCHAR2,
        p_object_name       IN VARCHAR2,
        p_page_id           IN NUMBER DEFAULT NULL,
        p_parent_object_id  IN NUMBER DEFAULT NULL,
        p_object_desc       IN VARCHAR2 DEFAULT NULL
    );

    /**
     * Grant permission to role for an object
     * 
     * @param p_role_code        Role code
     * @param p_application_id   Application ID
     * @param p_object_code      Object code
     * @param p_permission_code  Permission code
     * @param p_is_granted       Grant or deny (default Y)
     * @param p_effective_from   Effective start date
     * @param p_effective_to     Effective end date
     */
    PROCEDURE grant_permission(
        p_role_code         IN VARCHAR2,
        p_application_id    IN NUMBER,
        p_object_code       IN VARCHAR2,
        p_permission_code   IN VARCHAR2 DEFAULT 'VIEW',
        p_is_granted        IN VARCHAR2 DEFAULT 'Y',
        p_effective_from    IN DATE DEFAULT SYSDATE,
        p_effective_to      IN DATE DEFAULT NULL
    );

    /**
     * Revoke permission from role for an object
     * 
     * @param p_role_code        Role code
     * @param p_application_id   Application ID
     * @param p_object_code      Object code
     * @param p_permission_code  Permission code
     */
    PROCEDURE revoke_permission(
        p_role_code         IN VARCHAR2,
        p_application_id    IN NUMBER,
        p_object_code       IN VARCHAR2,
        p_permission_code   IN VARCHAR2 DEFAULT 'VIEW'
    );

    /**
     * Grant user-specific permission override
     * 
     * @param p_username         Username
     * @param p_application_id   Application ID
     * @param p_object_code      Object code
     * @param p_permission_code  Permission code
     * @param p_is_granted       Grant or deny
     * @param p_override_roles   Override role permissions
     * @param p_effective_from   Effective start date
     * @param p_effective_to     Effective end date
     */
    PROCEDURE grant_user_permission(
        p_username          IN VARCHAR2,
        p_application_id    IN NUMBER,
        p_object_code       IN VARCHAR2,
        p_permission_code   IN VARCHAR2 DEFAULT 'VIEW',
        p_is_granted        IN VARCHAR2 DEFAULT 'Y',
        p_override_roles    IN VARCHAR2 DEFAULT 'Y',
        p_effective_from    IN DATE DEFAULT SYSDATE,
        p_effective_to      IN DATE DEFAULT NULL
    );

    /***************************************************************************
     * UTILITY PROCEDURES
     ***************************************************************************/

    /**
     * Clear authorization cache (if caching is implemented)
     * 
     * @param p_username         Username (NULL = clear all)
     */
    PROCEDURE clear_cache(
        p_username          IN VARCHAR2 DEFAULT NULL
    );

    /**
     * Get configuration value
     * 
     * @param p_config_key       Configuration key
     * @return VARCHAR2          Configuration value
     */
    FUNCTION get_config(
        p_config_key        IN VARCHAR2
    ) RETURN VARCHAR2;

    /**
     * Set configuration value
     * 
     * @param p_config_key       Configuration key
     * @param p_config_value     Configuration value
     */
    PROCEDURE set_config(
        p_config_key        IN VARCHAR2,
        p_config_value      IN VARCHAR2
    );

    /**
     * Initialize default permissions for common roles
     * Useful for initial setup
     */
    PROCEDURE initialize_default_permissions;

END apex_authorization_pkg;
/
