create or replace PACKAGE pkg_auth AS
    /**
     * Package: PKG_AUTH
     * Purpose: Manages Dynamic Authorization for APEX Application
     * Author: AI Assistant
     * Date: 2026-01-03
     */

    -- Exception for invalid inputs
    e_invalid_input EXCEPTION;

    /**
     * Checks if the current user (APP_USER) has a specific permission.
     * Use this in APEX Authorization Schemes -> PL/SQL Function Returning Boolean.
     *
     * @param p_permission_code The unique code of the permission (e.g. 'PAGE:1:VIEW')
     * @param p_app_user        Optional: Override user to check (defaults to V('APP_USER'))
     * @return BOOLEAN          TRUE if authorized, FALSE otherwise
     */
    FUNCTION has_permission (
        p_permission_code IN VARCHAR2,
        p_app_user        IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN;

    /**
     * Checks if the current user has a specific Role Key.
     * Useful for broad checks like 'IS_ADMIN'.
     *
     * @param p_role_key   The unique key of the role (e.g. 'ADMIN')
     * @param p_app_user   Optional: Override user to check
     * @return BOOLEAN
     */
    FUNCTION has_role (
        p_role_key   IN VARCHAR2,
        p_app_user   IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN;

    /**
     * Utility to add a role to a user.
     */
    PROCEDURE add_user_role (
        p_user_name  IN VARCHAR2,
        p_role_key   IN VARCHAR2
    );

    /**
     * Utility to remove a role from a user.
     */
    PROCEDURE remove_user_role (
        p_user_name  IN VARCHAR2,
        p_role_key   IN VARCHAR2
    );

    /**
     * Clears the package-level cache.
     * Call this if permissions change mid-session (rare) or for debugging.
     */
    PROCEDURE clear_cache;

END pkg_auth;
/

create or replace PACKAGE BODY pkg_auth AS

    -- Types for caching
    TYPE t_perm_cache IS TABLE OF BOOLEAN INDEX BY VARCHAR2(100);
    TYPE t_role_cache IS TABLE OF BOOLEAN INDEX BY VARCHAR2(50);
    
    -- Package state variables (Persist for the duration of the DB Session / APEX Request)
    g_perm_cache    t_perm_cache;
    g_role_cache    t_role_cache;
    g_cached_user   VARCHAR2(255);

    -- Helper to get current user securely
    FUNCTION get_current_user RETURN VARCHAR2 IS
    BEGIN
        RETURN COALESCE(SYS_CONTEXT('APEX$SESSION', 'APP_USER'), USER);
    END get_current_user;

    -------------------------------------------------------------------------
    -- PROCEDURE: clear_cache
    -------------------------------------------------------------------------
    PROCEDURE clear_cache IS
    BEGIN
        g_perm_cache.DELETE;
        g_role_cache.DELETE;
        g_cached_user := NULL;
    END clear_cache;

    -------------------------------------------------------------------------
    -- FUNCTION: has_permission
    -------------------------------------------------------------------------
    FUNCTION has_permission (
        p_permission_code IN VARCHAR2,
        p_app_user        IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
        l_user          VARCHAR2(255);
        l_count         NUMBER;
        l_perm_code     app_permissions.permission_code%TYPE;
    BEGIN
        -- Determine user
        l_user := COALESCE(p_app_user, get_current_user());
        
        -- Normalize input
        l_perm_code := UPPER(TRIM(p_permission_code));
        
        -- If user changed (or first call), clear cache
        IF g_cached_user IS NULL OR g_cached_user != l_user THEN
            clear_cache;
            g_cached_user := l_user;
        END IF;

        -- Check cache first
        IF g_perm_cache.EXISTS(l_perm_code) THEN
            RETURN g_perm_cache(l_perm_code);
        END IF;

        -- Query Database:
        -- Join User -> User Roles -> Role Permissions -> Permissions
        SELECT COUNT(1)
          INTO l_count
          FROM app_user_roles ur
          JOIN app_roles r ON ur.role_id = r.role_id
          JOIN app_role_permissions rp ON r.role_id = rp.role_id
          JOIN app_permissions p ON rp.permission_id = p.permission_id
         WHERE UPPER(ur.user_name) = UPPER(l_user)
           AND UPPER(p.permission_code) = l_perm_code
           AND r.is_active = 'Y';

        -- Update Cache
        g_perm_cache(l_perm_code) := (l_count > 0);
        
        RETURN g_perm_cache(l_perm_code);

    EXCEPTION
        WHEN OTHERS THEN
            -- Log error in a real app (e.g., APEX_DEBUG.ERROR)
            -- For now, return FALSE on error to be safe (Fail Secure)
            RETURN FALSE;
    END has_permission;

    -------------------------------------------------------------------------
    -- FUNCTION: has_role
    -------------------------------------------------------------------------
    FUNCTION has_role (
        p_role_key   IN VARCHAR2,
        p_app_user   IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
        l_user      VARCHAR2(255);
        l_count     NUMBER;
        l_role_key  app_roles.role_key%TYPE;
    BEGIN
        l_user := COALESCE(p_app_user, get_current_user());
        l_role_key := UPPER(TRIM(p_role_key));

        -- Cache check logic for roles could be added here similar to permissions
        -- For brevity, direct query:
        
        SELECT COUNT(1)
          INTO l_count
          FROM app_user_roles ur
          JOIN app_roles r ON ur.role_id = r.role_id
         WHERE UPPER(ur.user_name) = UPPER(l_user)
           AND UPPER(r.role_key) = l_role_key
           AND r.is_active = 'Y';
           
        RETURN (l_count > 0);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END has_role;

    -------------------------------------------------------------------------
    -- PROCEDURE: add_user_role
    -------------------------------------------------------------------------
    PROCEDURE add_user_role (
        p_user_name  IN VARCHAR2,
        p_role_key   IN VARCHAR2
    ) IS
        l_role_id NUMBER;
    BEGIN
        -- Get Role ID
        SELECT role_id INTO l_role_id
          FROM app_roles
         WHERE UPPER(role_key) = UPPER(p_role_key);
         
        -- Insert if not exists
        MERGE INTO app_user_roles dest
        USING (SELECT p_user_name AS uname, l_role_id AS rid FROM DUAL) src
        ON (UPPER(dest.user_name) = UPPER(src.uname) AND dest.role_id = src.rid)
        WHEN NOT MATCHED THEN
            INSERT (user_name, role_id)
            VALUES (src.uname, src.rid);
            
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Role not found: ' || p_role_key);
    END add_user_role;

    -------------------------------------------------------------------------
    -- PROCEDURE: remove_user_role
    -------------------------------------------------------------------------
    PROCEDURE remove_user_role (
        p_user_name  IN VARCHAR2,
        p_role_key   IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM app_user_roles
         WHERE UPPER(user_name) = UPPER(p_user_name)
           AND role_id = (SELECT role_id FROM app_roles WHERE UPPER(role_key) = UPPER(p_role_key));
           
        COMMIT;
    END remove_user_role;

END pkg_auth;
/
