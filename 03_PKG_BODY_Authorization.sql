/*******************************************************************************
 * Oracle APEX Dynamic Authorization Scheme
 * Package Body
 * 
 * Package: APEX_AUTHORIZATION_PKG
 * Purpose: Implementation of authorization functions for APEX applications
 * 
 * Author: Generated for Oracle APEX 19c+
 * Date: January 2026
 ******************************************************************************/

CREATE OR REPLACE PACKAGE BODY apex_authorization_pkg AS

    /***************************************************************************
     * PRIVATE VARIABLES
     ***************************************************************************/
    
    -- Cache for authorization results (session-based)
    TYPE t_auth_cache IS TABLE OF BOOLEAN INDEX BY VARCHAR2(500);
    g_auth_cache        t_auth_cache;
    g_cache_enabled     BOOLEAN := TRUE;
    g_cache_timestamp   TIMESTAMP := SYSTIMESTAMP;

    /***************************************************************************
     * PRIVATE HELPER FUNCTIONS
     ***************************************************************************/

    /**
     * Get cache key for authorization check
     */
    FUNCTION get_cache_key(
        p_username          IN VARCHAR2,
        p_application_id    IN NUMBER,
        p_object_code       IN VARCHAR2,
        p_object_type       IN VARCHAR2,
        p_permission_type   IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        RETURN p_username || '|' || 
               NVL(TO_CHAR(p_application_id), 'NULL') || '|' ||
               p_object_code || '|' || 
               p_object_type || '|' || 
               p_permission_type;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END get_cache_key;

    /**
     * Check if cache has expired based on configuration
     */
    FUNCTION is_cache_expired RETURN BOOLEAN IS
        l_timeout_seconds   NUMBER;
        l_age_seconds       NUMBER;
    BEGIN
        l_timeout_seconds := TO_NUMBER(get_config('CACHE_TIMEOUT_SECONDS'));
        l_age_seconds := EXTRACT(SECOND FROM (SYSTIMESTAMP - g_cache_timestamp));
        
        RETURN (l_age_seconds > l_timeout_seconds);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN TRUE;
    END is_cache_expired;

    /**
     * Log authorization check to audit table
     */
    PROCEDURE log_authorization(
        p_username              IN VARCHAR2,
        p_application_id        IN NUMBER,
        p_page_id               IN NUMBER,
        p_object_type           IN VARCHAR2,
        p_object_code           IN VARCHAR2,
        p_permission_type       IN VARCHAR2,
        p_authorization_result  IN VARCHAR2,
        p_reason                IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_enable_audit  VARCHAR2(1);
        l_session_id    NUMBER;
        l_ip_address    VARCHAR2(100);
    BEGIN
        l_enable_audit := get_config('ENABLE_AUDIT_LOG');
        
        IF NVL(l_enable_audit, 'N') = 'Y' THEN
            -- Get APEX session info if available
            BEGIN
                l_session_id := APEX_APPLICATION.G_INSTANCE;
                l_ip_address := APEX_APPLICATION.G_REMOTE_ADDR;
            EXCEPTION
                WHEN OTHERS THEN
                    l_session_id := NULL;
                    l_ip_address := SYS_CONTEXT('USERENV', 'IP_ADDRESS');
            END;
            
            INSERT INTO apex_auth_audit_log (
                username,
                application_id,
                page_id,
                object_type,
                object_code,
                permission_type,
                authorization_result,
                reason,
                session_id,
                ip_address
            ) VALUES (
                p_username,
                p_application_id,
                p_page_id,
                p_object_type,
                p_object_code,
                p_permission_type,
                p_authorization_result,
                p_reason,
                l_session_id,
                l_ip_address
            );
            
            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            -- Don't fail authorization due to audit logging error
            NULL;
    END log_authorization;

    /**
     * Check if user has super admin role
     */
    FUNCTION is_super_admin(
        p_username          IN VARCHAR2
    ) RETURN BOOLEAN IS
        l_superadmin_role   VARCHAR2(100);
        l_has_role          BOOLEAN := FALSE;
    BEGIN
        l_superadmin_role := get_config('SUPERADMIN_ROLE');
        
        IF l_superadmin_role IS NOT NULL THEN
            l_has_role := has_role(p_username, l_superadmin_role);
        END IF;
        
        RETURN l_has_role;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END is_super_admin;

    /***************************************************************************
     * PUBLIC UTILITY FUNCTIONS IMPLEMENTATION
     ***************************************************************************/

    FUNCTION get_current_username RETURN VARCHAR2 IS
        l_username  VARCHAR2(100);
    BEGIN
        -- Try to get APEX username first
        BEGIN
            l_username := APEX_APPLICATION.G_USER;
        EXCEPTION
            WHEN OTHERS THEN
                l_username := NULL;
        END;
        
        -- Fallback to database user
        IF l_username IS NULL THEN
            l_username := SYS_CONTEXT('USERENV', 'SESSION_USER');
        END IF;
        
        RETURN UPPER(l_username);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN USER;
    END get_current_username;

    FUNCTION get_current_app_id RETURN NUMBER IS
        l_app_id    NUMBER;
    BEGIN
        BEGIN
            l_app_id := APEX_APPLICATION.G_FLOW_ID;
        EXCEPTION
            WHEN OTHERS THEN
                l_app_id := NULL;
        END;
        
        RETURN l_app_id;
    END get_current_app_id;

    FUNCTION get_config(
        p_config_key        IN VARCHAR2
    ) RETURN VARCHAR2 IS
        l_config_value  VARCHAR2(4000);
    BEGIN
        SELECT config_value
        INTO l_config_value
        FROM apex_auth_config
        WHERE config_key = p_config_key
        AND is_active = 'Y';
        
        RETURN l_config_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
        WHEN OTHERS THEN
            RAISE;
    END get_config;

    PROCEDURE set_config(
        p_config_key        IN VARCHAR2,
        p_config_value      IN VARCHAR2
    ) IS
    BEGIN
        UPDATE apex_auth_config
        SET config_value = p_config_value,
            modified_by = get_current_username,
            modified_date = SYSDATE
        WHERE config_key = p_config_key;
        
        IF SQL%ROWCOUNT = 0 THEN
            INSERT INTO apex_auth_config (
                config_key,
                config_value
            ) VALUES (
                p_config_key,
                p_config_value
            );
        END IF;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END set_config;

    /***************************************************************************
     * USER VALIDATION FUNCTIONS
     ***************************************************************************/

    FUNCTION is_user_active(
        p_username          IN VARCHAR2
    ) RETURN BOOLEAN IS
        l_count         NUMBER;
        l_is_active     VARCHAR2(1);
        l_is_locked     VARCHAR2(1);
        l_eff_from      DATE;
        l_eff_to        DATE;
    BEGIN
        SELECT is_active, 
               is_locked,
               effective_from,
               effective_to
        INTO l_is_active,
             l_is_locked,
             l_eff_from,
             l_eff_to
        FROM apex_auth_users
        WHERE UPPER(username) = UPPER(p_username);
        
        -- Check if user is active
        IF l_is_active = 'N' THEN
            RETURN FALSE;
        END IF;
        
        -- Check if user is locked
        IF l_is_locked = 'Y' THEN
            RETURN FALSE;
        END IF;
        
        -- Check temporal validity
        IF SYSDATE < l_eff_from THEN
            RETURN FALSE;
        END IF;
        
        IF l_eff_to IS NOT NULL AND SYSDATE > l_eff_to THEN
            RETURN FALSE;
        END IF;
        
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
        WHEN OTHERS THEN
            RETURN FALSE;
    END is_user_active;

    /***************************************************************************
     * ROLE CHECKING FUNCTIONS
     ***************************************************************************/

    FUNCTION get_user_roles(
        p_username          IN VARCHAR2
    ) RETURN t_role_list IS
        l_roles     t_role_list;
    BEGIN
        SELECT r.role_code
        BULK COLLECT INTO l_roles
        FROM apex_auth_users u
        INNER JOIN apex_auth_user_roles ur 
            ON u.user_id = ur.user_id
        INNER JOIN apex_auth_roles r 
            ON ur.role_id = r.role_id
        WHERE UPPER(u.username) = UPPER(p_username)
        AND u.is_active = 'Y'
        AND u.is_locked = 'N'
        AND ur.is_active = 'Y'
        AND r.is_active = 'Y'
        AND SYSDATE BETWEEN ur.effective_from AND NVL(ur.effective_to, SYSDATE + 1);
        
        RETURN l_roles;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN t_role_list();
        WHEN OTHERS THEN
            RAISE;
    END get_user_roles;

    FUNCTION has_role(
        p_username          IN VARCHAR2 DEFAULT NULL,
        p_role_code         IN VARCHAR2
    ) RETURN BOOLEAN IS
        l_username      VARCHAR2(100);
        l_count         NUMBER;
    BEGIN
        l_username := NVL(p_username, get_current_username);
        
        SELECT COUNT(*)
        INTO l_count
        FROM apex_auth_users u
        INNER JOIN apex_auth_user_roles ur 
            ON u.user_id = ur.user_id
        INNER JOIN apex_auth_roles r 
            ON ur.role_id = r.role_id
        WHERE UPPER(u.username) = UPPER(l_username)
        AND UPPER(r.role_code) = UPPER(p_role_code)
        AND u.is_active = 'Y'
        AND u.is_locked = 'N'
        AND ur.is_active = 'Y'
        AND r.is_active = 'Y'
        AND SYSDATE BETWEEN ur.effective_from AND NVL(ur.effective_to, SYSDATE + 1)
        AND SYSDATE BETWEEN u.effective_from AND NVL(u.effective_to, SYSDATE + 1);
        
        RETURN (l_count > 0);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
        WHEN OTHERS THEN
            RETURN FALSE;
    END has_role;

    FUNCTION has_any_role(
        p_username          IN VARCHAR2 DEFAULT NULL,
        p_role_codes        IN VARCHAR2
    ) RETURN BOOLEAN IS
        l_username      VARCHAR2(100);
        l_count         NUMBER;
    BEGIN
        l_username := NVL(p_username, get_current_username);
        
        SELECT COUNT(*)
        INTO l_count
        FROM apex_auth_users u
        INNER JOIN apex_auth_user_roles ur 
            ON u.user_id = ur.user_id
        INNER JOIN apex_auth_roles r 
            ON ur.role_id = r.role_id
        WHERE UPPER(u.username) = UPPER(l_username)
        AND UPPER(r.role_code) IN (
            SELECT UPPER(TRIM(REGEXP_SUBSTR(p_role_codes, '[^,]+', 1, LEVEL)))
            FROM DUAL
            CONNECT BY LEVEL <= REGEXP_COUNT(p_role_codes, ',') + 1
        )
        AND u.is_active = 'Y'
        AND u.is_locked = 'N'
        AND ur.is_active = 'Y'
        AND r.is_active = 'Y'
        AND SYSDATE BETWEEN ur.effective_from AND NVL(ur.effective_to, SYSDATE + 1)
        AND SYSDATE BETWEEN u.effective_from AND NVL(u.effective_to, SYSDATE + 1);
        
        RETURN (l_count > 0);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
        WHEN OTHERS THEN
            RETURN FALSE;
    END has_any_role;

    FUNCTION has_all_roles(
        p_username          IN VARCHAR2 DEFAULT NULL,
        p_role_codes        IN VARCHAR2
    ) RETURN BOOLEAN IS
        l_username          VARCHAR2(100);
        l_required_count    NUMBER;
        l_actual_count      NUMBER;
    BEGIN
        l_username := NVL(p_username, get_current_username);
        
        -- Count required roles
        SELECT REGEXP_COUNT(p_role_codes, ',') + 1
        INTO l_required_count
        FROM DUAL;
        
        -- Count actual roles user has
        SELECT COUNT(*)
        INTO l_actual_count
        FROM apex_auth_users u
        INNER JOIN apex_auth_user_roles ur 
            ON u.user_id = ur.user_id
        INNER JOIN apex_auth_roles r 
            ON ur.role_id = r.role_id
        WHERE UPPER(u.username) = UPPER(l_username)
        AND UPPER(r.role_code) IN (
            SELECT UPPER(TRIM(REGEXP_SUBSTR(p_role_codes, '[^,]+', 1, LEVEL)))
            FROM DUAL
            CONNECT BY LEVEL <= REGEXP_COUNT(p_role_codes, ',') + 1
        )
        AND u.is_active = 'Y'
        AND u.is_locked = 'N'
        AND ur.is_active = 'Y'
        AND r.is_active = 'Y'
        AND SYSDATE BETWEEN ur.effective_from AND NVL(ur.effective_to, SYSDATE + 1)
        AND SYSDATE BETWEEN u.effective_from AND NVL(u.effective_to, SYSDATE + 1);
        
        RETURN (l_actual_count = l_required_count);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
        WHEN OTHERS THEN
            RETURN FALSE;
    END has_all_roles;

    /***************************************************************************
     * CORE AUTHORIZATION IMPLEMENTATION
     ***************************************************************************/

    FUNCTION get_authorization_detail(
        p_username          IN VARCHAR2 DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_object_code       IN VARCHAR2,
        p_object_type       IN VARCHAR2 DEFAULT c_obj_page,
        p_permission_type   IN VARCHAR2 DEFAULT c_perm_view
    ) RETURN t_auth_result IS
        l_result            t_auth_result;
        l_username          VARCHAR2(100);
        l_app_id            NUMBER;
        l_user_id           NUMBER;
        l_object_id         NUMBER;
        l_permission_id     NUMBER;
        l_has_permission    NUMBER := 0;
        l_user_override     VARCHAR2(1);
        l_default_perm      VARCHAR2(10);
    BEGIN
        -- Initialize result
        l_result.is_authorized := FALSE;
        l_result.result_code := c_auth_denied;
        l_result.reason := 'No matching authorization rule found';
        
        -- Get username and app ID
        l_username := NVL(p_username, get_current_username);
        l_app_id := NVL(p_application_id, get_current_app_id);
        
        -- Check if user account is active
        IF NOT is_user_active(l_username) THEN
            l_result.reason := 'User account is inactive or locked';
            RETURN l_result;
        END IF;
        
        -- Check for super admin
        IF is_super_admin(l_username) THEN
            l_result.is_authorized := TRUE;
            l_result.result_code := c_auth_granted;
            l_result.reason := 'User has super admin role';
            RETURN l_result;
        END IF;
        
        -- Get user ID
        BEGIN
            SELECT user_id
            INTO l_user_id
            FROM apex_auth_users
            WHERE UPPER(username) = UPPER(l_username)
            AND is_active = 'Y'
            AND is_locked = 'N';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_result.reason := 'User not found in authorization system';
                RETURN l_result;
        END;
        
        -- Get object ID
        BEGIN
            SELECT object_id
            INTO l_object_id
            FROM apex_auth_objects
            WHERE application_id = l_app_id
            AND UPPER(object_code) = UPPER(p_object_code)
            AND object_type = p_object_type
            AND is_active = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Object not registered - check default permission
                l_default_perm := get_config('DEFAULT_PERMISSION');
                IF NVL(l_default_perm, 'DENY') = 'ALLOW' THEN
                    l_result.is_authorized := TRUE;
                    l_result.result_code := c_auth_granted;
                    l_result.reason := 'Object not registered - default permission is ALLOW';
                ELSE
                    l_result.reason := 'Object not registered in authorization system';
                END IF;
                RETURN l_result;
        END;
        
        -- Get permission ID
        BEGIN
            SELECT permission_id
            INTO l_permission_id
            FROM apex_auth_permissions
            WHERE permission_type = p_permission_type
            AND is_active = 'Y'
            AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_result.reason := 'Permission type not found';
                RETURN l_result;
        END;
        
        -- Check for user-specific override
        BEGIN
            SELECT is_granted
            INTO l_user_override
            FROM apex_auth_user_permissions
            WHERE user_id = l_user_id
            AND object_id = l_object_id
            AND permission_id = l_permission_id
            AND override_roles = 'Y'
            AND SYSDATE BETWEEN effective_from AND NVL(effective_to, SYSDATE + 1)
            AND ROWNUM = 1;
            
            IF l_user_override = 'Y' THEN
                l_result.is_authorized := TRUE;
                l_result.result_code := c_auth_granted;
                l_result.reason := 'Granted by user-specific permission override';
            ELSE
                l_result.reason := 'Explicitly denied by user-specific permission override';
            END IF;
            RETURN l_result;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- No user override, check role permissions
                NULL;
        END;
        
        -- Check role-based permissions
        SELECT COUNT(*)
        INTO l_has_permission
        FROM apex_auth_user_roles ur
        INNER JOIN apex_auth_role_permissions rp 
            ON ur.role_id = rp.role_id
        WHERE ur.user_id = l_user_id
        AND rp.object_id = l_object_id
        AND rp.permission_id = l_permission_id
        AND ur.is_active = 'Y'
        AND rp.is_granted = 'Y'
        AND SYSDATE BETWEEN ur.effective_from AND NVL(ur.effective_to, SYSDATE + 1)
        AND SYSDATE BETWEEN rp.effective_from AND NVL(rp.effective_to, SYSDATE + 1);
        
        IF l_has_permission > 0 THEN
            l_result.is_authorized := TRUE;
            l_result.result_code := c_auth_granted;
            l_result.reason := 'Granted by role-based permission';
        ELSE
            -- Check default permission
            l_default_perm := get_config('DEFAULT_PERMISSION');
            IF NVL(l_default_perm, 'DENY') = 'ALLOW' THEN
                l_result.is_authorized := TRUE;
                l_result.result_code := c_auth_granted;
                l_result.reason := 'Granted by default permission policy';
            ELSE
                l_result.reason := 'No role grants this permission';
            END IF;
        END IF;
        
        RETURN l_result;
    EXCEPTION
        WHEN OTHERS THEN
            l_result.is_authorized := FALSE;
            l_result.result_code := c_auth_denied;
            l_result.reason := 'Authorization check failed: ' || SQLERRM;
            RETURN l_result;
    END get_authorization_detail;

    FUNCTION is_authorized(
        p_username          IN VARCHAR2 DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_object_code       IN VARCHAR2,
        p_object_type       IN VARCHAR2 DEFAULT c_obj_page,
        p_permission_type   IN VARCHAR2 DEFAULT c_perm_view,
        p_enable_audit      IN VARCHAR2 DEFAULT 'Y'
    ) RETURN BOOLEAN IS
        l_result            t_auth_result;
        l_cache_key         VARCHAR2(500);
        l_cached_result     BOOLEAN;
        l_username          VARCHAR2(100);
        l_app_id            NUMBER;
        l_page_id           NUMBER;
    BEGIN
        l_username := NVL(p_username, get_current_username);
        l_app_id := NVL(p_application_id, get_current_app_id);
        
        -- Check cache if enabled
        IF g_cache_enabled AND NOT is_cache_expired THEN
            l_cache_key := get_cache_key(l_username, l_app_id, p_object_code, p_object_type, p_permission_type);
            
            IF l_cache_key IS NOT NULL AND g_auth_cache.EXISTS(l_cache_key) THEN
                RETURN g_auth_cache(l_cache_key);
            END IF;
        END IF;
        
        -- Get authorization result
        l_result := get_authorization_detail(
            p_username => l_username,
            p_application_id => l_app_id,
            p_object_code => p_object_code,
            p_object_type => p_object_type,
            p_permission_type => p_permission_type
        );
        
        -- Cache result
        IF g_cache_enabled AND l_cache_key IS NOT NULL THEN
            g_auth_cache(l_cache_key) := l_result.is_authorized;
        END IF;
        
        -- Audit log if enabled
        IF p_enable_audit = 'Y' THEN
            BEGIN
                SELECT page_id
                INTO l_page_id
                FROM apex_auth_objects
                WHERE application_id = l_app_id
                AND UPPER(object_code) = UPPER(p_object_code)
                AND object_type = p_object_type
                AND ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    l_page_id := NULL;
            END;
            
            log_authorization(
                p_username => l_username,
                p_application_id => l_app_id,
                p_page_id => l_page_id,
                p_object_type => p_object_type,
                p_object_code => p_object_code,
                p_permission_type => p_permission_type,
                p_authorization_result => l_result.result_code,
                p_reason => l_result.reason
            );
        END IF;
        
        RETURN l_result.is_authorized;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END is_authorized;

    /***************************************************************************
     * SPECIALIZED AUTHORIZATION FUNCTIONS
     ***************************************************************************/

    FUNCTION is_page_authorized(
        p_page_id           IN NUMBER,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_username          IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
        l_object_code   VARCHAR2(200);
    BEGIN
        -- Use page ID as object code
        l_object_code := 'PAGE_' || TO_CHAR(p_page_id);
        
        RETURN is_authorized(
            p_username => p_username,
            p_application_id => p_application_id,
            p_object_code => l_object_code,
            p_object_type => c_obj_page,
            p_permission_type => c_perm_view
        );
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END is_page_authorized;

    FUNCTION is_region_authorized(
        p_region_code       IN VARCHAR2,
        p_page_id           IN NUMBER DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_username          IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN is_authorized(
            p_username => p_username,
            p_application_id => p_application_id,
            p_object_code => p_region_code,
            p_object_type => c_obj_region,
            p_permission_type => c_perm_view
        );
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END is_region_authorized;

    FUNCTION is_button_authorized(
        p_button_code       IN VARCHAR2,
        p_page_id           IN NUMBER DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_username          IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN is_authorized(
            p_username => p_username,
            p_application_id => p_application_id,
            p_object_code => p_button_code,
            p_object_type => c_obj_button,
            p_permission_type => c_perm_execute
        );
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END is_button_authorized;

    FUNCTION is_menu_authorized(
        p_menu_code         IN VARCHAR2,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_username          IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN is_authorized(
            p_username => p_username,
            p_application_id => p_application_id,
            p_object_code => p_menu_code,
            p_object_type => c_obj_menu,
            p_permission_type => c_perm_view
        );
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END is_menu_authorized;

    /***************************************************************************
     * ROLE MANAGEMENT PROCEDURES
     ***************************************************************************/

    PROCEDURE create_role(
        p_role_code         IN VARCHAR2,
        p_role_name         IN VARCHAR2,
        p_role_description  IN VARCHAR2 DEFAULT NULL,
        p_is_active         IN VARCHAR2 DEFAULT 'Y'
    ) IS
        l_count     NUMBER;
    BEGIN
        -- Check if role already exists
        SELECT COUNT(*)
        INTO l_count
        FROM apex_auth_roles
        WHERE UPPER(role_code) = UPPER(p_role_code);
        
        IF l_count > 0 THEN
            RAISE_APPLICATION_ERROR(ec_duplicate_assignment, 
                'Role ' || p_role_code || ' already exists');
        END IF;
        
        INSERT INTO apex_auth_roles (
            role_code,
            role_name,
            role_description,
            is_active,
            created_by
        ) VALUES (
            UPPER(p_role_code),
            p_role_name,
            p_role_description,
            p_is_active,
            get_current_username
        );
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END create_role;

    PROCEDURE update_role(
        p_role_code         IN VARCHAR2,
        p_role_name         IN VARCHAR2 DEFAULT NULL,
        p_role_description  IN VARCHAR2 DEFAULT NULL,
        p_is_active         IN VARCHAR2 DEFAULT NULL
    ) IS
        l_count     NUMBER;
    BEGIN
        UPDATE apex_auth_roles
        SET role_name = NVL(p_role_name, role_name),
            role_description = NVL(p_role_description, role_description),
            is_active = NVL(p_is_active, is_active),
            modified_by = get_current_username,
            modified_date = SYSDATE
        WHERE UPPER(role_code) = UPPER(p_role_code);
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(ec_role_not_found, 
                'Role ' || p_role_code || ' not found');
        END IF;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END update_role;

    PROCEDURE delete_role(
        p_role_code         IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM apex_auth_roles
        WHERE UPPER(role_code) = UPPER(p_role_code);
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(ec_role_not_found, 
                'Role ' || p_role_code || ' not found');
        END IF;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END delete_role;

    /***************************************************************************
     * USER MANAGEMENT PROCEDURES
     ***************************************************************************/

    PROCEDURE create_user(
        p_username          IN VARCHAR2,
        p_email             IN VARCHAR2 DEFAULT NULL,
        p_full_name         IN VARCHAR2 DEFAULT NULL,
        p_is_active         IN VARCHAR2 DEFAULT 'Y',
        p_effective_from    IN DATE DEFAULT SYSDATE,
        p_effective_to      IN DATE DEFAULT NULL
    ) IS
        l_count     NUMBER;
    BEGIN
        -- Check if user already exists
        SELECT COUNT(*)
        INTO l_count
        FROM apex_auth_users
        WHERE UPPER(username) = UPPER(p_username);
        
        IF l_count > 0 THEN
            RAISE_APPLICATION_ERROR(ec_duplicate_assignment, 
                'User ' || p_username || ' already exists');
        END IF;
        
        INSERT INTO apex_auth_users (
            username,
            email,
            full_name,
            is_active,
            effective_from,
            effective_to,
            created_by
        ) VALUES (
            UPPER(p_username),
            p_email,
            p_full_name,
            p_is_active,
            p_effective_from,
            p_effective_to,
            get_current_username
        );
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END create_user;

    PROCEDURE update_user(
        p_username          IN VARCHAR2,
        p_email             IN VARCHAR2 DEFAULT NULL,
        p_full_name         IN VARCHAR2 DEFAULT NULL,
        p_is_active         IN VARCHAR2 DEFAULT NULL,
        p_is_locked         IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        UPDATE apex_auth_users
        SET email = NVL(p_email, email),
            full_name = NVL(p_full_name, full_name),
            is_active = NVL(p_is_active, is_active),
            is_locked = NVL(p_is_locked, is_locked),
            modified_by = get_current_username,
            modified_date = SYSDATE
        WHERE UPPER(username) = UPPER(p_username);
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(ec_user_not_found, 
                'User ' || p_username || ' not found');
        END IF;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END update_user;

    PROCEDURE assign_role_to_user(
        p_username          IN VARCHAR2,
        p_role_code         IN VARCHAR2,
        p_effective_from    IN DATE DEFAULT SYSDATE,
        p_effective_to      IN DATE DEFAULT NULL
    ) IS
        l_user_id   NUMBER;
        l_role_id   NUMBER;
    BEGIN
        -- Get user ID
        SELECT user_id
        INTO l_user_id
        FROM apex_auth_users
        WHERE UPPER(username) = UPPER(p_username);
        
        -- Get role ID
        SELECT role_id
        INTO l_role_id
        FROM apex_auth_roles
        WHERE UPPER(role_code) = UPPER(p_role_code);
        
        -- Insert or update assignment
        BEGIN
            INSERT INTO apex_auth_user_roles (
                user_id,
                role_id,
                effective_from,
                effective_to,
                is_active,
                created_by
            ) VALUES (
                l_user_id,
                l_role_id,
                p_effective_from,
                p_effective_to,
                'Y',
                get_current_username
            );
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                UPDATE apex_auth_user_roles
                SET effective_from = p_effective_from,
                    effective_to = p_effective_to,
                    is_active = 'Y',
                    modified_by = get_current_username,
                    modified_date = SYSDATE
                WHERE user_id = l_user_id
                AND role_id = l_role_id;
        END;
        
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20100, 
                'User or role not found');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END assign_role_to_user;

    PROCEDURE remove_role_from_user(
        p_username          IN VARCHAR2,
        p_role_code         IN VARCHAR2
    ) IS
        l_user_id   NUMBER;
        l_role_id   NUMBER;
    BEGIN
        -- Get user ID
        SELECT user_id
        INTO l_user_id
        FROM apex_auth_users
        WHERE UPPER(username) = UPPER(p_username);
        
        -- Get role ID
        SELECT role_id
        INTO l_role_id
        FROM apex_auth_roles
        WHERE UPPER(role_code) = UPPER(p_role_code);
        
        DELETE FROM apex_auth_user_roles
        WHERE user_id = l_user_id
        AND role_id = l_role_id;
        
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20100, 
                'User or role not found');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END remove_role_from_user;

    /***************************************************************************
     * OBJECT AND PERMISSION MANAGEMENT
     ***************************************************************************/

    PROCEDURE register_object(
        p_application_id    IN NUMBER,
        p_object_type       IN VARCHAR2,
        p_object_code       IN VARCHAR2,
        p_object_name       IN VARCHAR2,
        p_page_id           IN NUMBER DEFAULT NULL,
        p_parent_object_id  IN NUMBER DEFAULT NULL,
        p_object_desc       IN VARCHAR2 DEFAULT NULL
    ) IS
        l_count     NUMBER;
    BEGIN
        -- Validate object type
        IF p_object_type NOT IN (c_obj_menu, c_obj_page, c_obj_region, c_obj_button, c_obj_item) THEN
            RAISE_APPLICATION_ERROR(ec_invalid_object_type, 
                'Invalid object type: ' || p_object_type);
        END IF;
        
        -- Check if object already exists
        SELECT COUNT(*)
        INTO l_count
        FROM apex_auth_objects
        WHERE application_id = p_application_id
        AND UPPER(object_code) = UPPER(p_object_code)
        AND object_type = p_object_type;
        
        IF l_count > 0 THEN
            -- Update existing
            UPDATE apex_auth_objects
            SET object_name = p_object_name,
                page_id = p_page_id,
                parent_object_id = p_parent_object_id,
                object_description = p_object_desc,
                modified_by = get_current_username,
                modified_date = SYSDATE
            WHERE application_id = p_application_id
            AND UPPER(object_code) = UPPER(p_object_code)
            AND object_type = p_object_type;
        ELSE
            -- Insert new
            INSERT INTO apex_auth_objects (
                application_id,
                object_type,
                object_code,
                object_name,
                page_id,
                parent_object_id,
                object_description,
                created_by
            ) VALUES (
                p_application_id,
                p_object_type,
                UPPER(p_object_code),
                p_object_name,
                p_page_id,
                p_parent_object_id,
                p_object_desc,
                get_current_username
            );
        END IF;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END register_object;

    PROCEDURE grant_permission(
        p_role_code         IN VARCHAR2,
        p_application_id    IN NUMBER,
        p_object_code       IN VARCHAR2,
        p_permission_code   IN VARCHAR2 DEFAULT 'VIEW',
        p_is_granted        IN VARCHAR2 DEFAULT 'Y',
        p_effective_from    IN DATE DEFAULT SYSDATE,
        p_effective_to      IN DATE DEFAULT NULL
    ) IS
        l_role_id       NUMBER;
        l_object_id     NUMBER;
        l_permission_id NUMBER;
    BEGIN
        -- Get role ID
        SELECT role_id
        INTO l_role_id
        FROM apex_auth_roles
        WHERE UPPER(role_code) = UPPER(p_role_code);
        
        -- Get object ID
        SELECT object_id
        INTO l_object_id
        FROM apex_auth_objects
        WHERE application_id = p_application_id
        AND UPPER(object_code) = UPPER(p_object_code);
        
        -- Get permission ID
        SELECT permission_id
        INTO l_permission_id
        FROM apex_auth_permissions
        WHERE UPPER(permission_code) = UPPER(p_permission_code)
        AND ROWNUM = 1;
        
        -- Insert or update permission
        BEGIN
            INSERT INTO apex_auth_role_permissions (
                role_id,
                object_id,
                permission_id,
                is_granted,
                effective_from,
                effective_to,
                created_by
            ) VALUES (
                l_role_id,
                l_object_id,
                l_permission_id,
                p_is_granted,
                p_effective_from,
                p_effective_to,
                get_current_username
            );
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                UPDATE apex_auth_role_permissions
                SET is_granted = p_is_granted,
                    effective_from = p_effective_from,
                    effective_to = p_effective_to,
                    modified_by = get_current_username,
                    modified_date = SYSDATE
                WHERE role_id = l_role_id
                AND object_id = l_object_id
                AND permission_id = l_permission_id;
        END;
        
        -- Clear cache
        clear_cache;
        
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20100, 
                'Role, object, or permission not found');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END grant_permission;

    PROCEDURE revoke_permission(
        p_role_code         IN VARCHAR2,
        p_application_id    IN NUMBER,
        p_object_code       IN VARCHAR2,
        p_permission_code   IN VARCHAR2 DEFAULT 'VIEW'
    ) IS
        l_role_id       NUMBER;
        l_object_id     NUMBER;
        l_permission_id NUMBER;
    BEGIN
        -- Get IDs
        SELECT r.role_id, o.object_id, p.permission_id
        INTO l_role_id, l_object_id, l_permission_id
        FROM apex_auth_roles r,
             apex_auth_objects o,
             apex_auth_permissions p
        WHERE UPPER(r.role_code) = UPPER(p_role_code)
        AND o.application_id = p_application_id
        AND UPPER(o.object_code) = UPPER(p_object_code)
        AND UPPER(p.permission_code) = UPPER(p_permission_code)
        AND ROWNUM = 1;
        
        DELETE FROM apex_auth_role_permissions
        WHERE role_id = l_role_id
        AND object_id = l_object_id
        AND permission_id = l_permission_id;
        
        -- Clear cache
        clear_cache;
        
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20100, 
                'Role, object, or permission not found');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END revoke_permission;

    PROCEDURE grant_user_permission(
        p_username          IN VARCHAR2,
        p_application_id    IN NUMBER,
        p_object_code       IN VARCHAR2,
        p_permission_code   IN VARCHAR2 DEFAULT 'VIEW',
        p_is_granted        IN VARCHAR2 DEFAULT 'Y',
        p_override_roles    IN VARCHAR2 DEFAULT 'Y',
        p_effective_from    IN DATE DEFAULT SYSDATE,
        p_effective_to      IN DATE DEFAULT NULL
    ) IS
        l_user_id       NUMBER;
        l_object_id     NUMBER;
        l_permission_id NUMBER;
    BEGIN
        -- Get user ID
        SELECT user_id
        INTO l_user_id
        FROM apex_auth_users
        WHERE UPPER(username) = UPPER(p_username);
        
        -- Get object ID
        SELECT object_id
        INTO l_object_id
        FROM apex_auth_objects
        WHERE application_id = p_application_id
        AND UPPER(object_code) = UPPER(p_object_code);
        
        -- Get permission ID
        SELECT permission_id
        INTO l_permission_id
        FROM apex_auth_permissions
        WHERE UPPER(permission_code) = UPPER(p_permission_code)
        AND ROWNUM = 1;
        
        -- Insert or update permission
        BEGIN
            INSERT INTO apex_auth_user_permissions (
                user_id,
                object_id,
                permission_id,
                is_granted,
                override_roles,
                effective_from,
                effective_to,
                created_by
            ) VALUES (
                l_user_id,
                l_object_id,
                l_permission_id,
                p_is_granted,
                p_override_roles,
                p_effective_from,
                p_effective_to,
                get_current_username
            );
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                UPDATE apex_auth_user_permissions
                SET is_granted = p_is_granted,
                    override_roles = p_override_roles,
                    effective_from = p_effective_from,
                    effective_to = p_effective_to,
                    modified_by = get_current_username,
                    modified_date = SYSDATE
                WHERE user_id = l_user_id
                AND object_id = l_object_id
                AND permission_id = l_permission_id;
        END;
        
        -- Clear cache
        clear_cache;
        
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20100, 
                'User, object, or permission not found');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END grant_user_permission;

    /***************************************************************************
     * UTILITY PROCEDURES
     ***************************************************************************/

    PROCEDURE clear_cache(
        p_username          IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        IF p_username IS NULL THEN
            -- Clear entire cache
            g_auth_cache.DELETE;
        ELSE
            -- Clear cache for specific user (requires iteration)
            -- For simplicity, clear entire cache
            g_auth_cache.DELETE;
        END IF;
        
        g_cache_timestamp := SYSTIMESTAMP;
    END clear_cache;

    PROCEDURE initialize_default_permissions IS
        l_app_id    NUMBER;
    BEGIN
        -- Create default roles
        BEGIN
            create_role('SUPERADMIN', 'Super Administrator', 
                'Full system access', 'Y');
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            create_role('ADMIN', 'Administrator', 
                'Application administrator', 'Y');
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            create_role('MANAGER', 'Manager', 
                'Manager role with limited admin access', 'Y');
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            create_role('USER', 'Standard User', 
                'Standard application user', 'Y');
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            create_role('GUEST', 'Guest User', 
                'Limited read-only access', 'Y');
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        
        -- Create default permissions
        BEGIN
            INSERT INTO apex_auth_permissions (permission_code, permission_name, permission_type)
            VALUES ('VIEW', 'View Access', 'VIEW');
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;
        
        BEGIN
            INSERT INTO apex_auth_permissions (permission_code, permission_name, permission_type)
            VALUES ('EDIT', 'Edit Access', 'EDIT');
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;
        
        BEGIN
            INSERT INTO apex_auth_permissions (permission_code, permission_name, permission_type)
            VALUES ('DELETE', 'Delete Access', 'DELETE');
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;
        
        BEGIN
            INSERT INTO apex_auth_permissions (permission_code, permission_name, permission_type)
            VALUES ('EXECUTE', 'Execute Access', 'EXECUTE');
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;
        
        BEGIN
            INSERT INTO apex_auth_permissions (permission_code, permission_name, permission_type)
            VALUES ('ADMIN', 'Admin Access', 'ADMIN');
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END initialize_default_permissions;

END apex_authorization_pkg;
/
