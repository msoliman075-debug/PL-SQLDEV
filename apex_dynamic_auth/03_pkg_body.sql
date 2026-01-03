/*
================================================================================
  Dynamic Authorization Scheme - Package Body
  Oracle APEX Security Framework
  
  Purpose: Implementation of dynamic authorization functions and procedures
  
  Target: Oracle 19c+ / Oracle APEX 21.1+
  Author: APEX Security Framework
  
================================================================================
*/

CREATE OR REPLACE PACKAGE BODY apex_auth_pkg AS

    -- ========================================================================
    -- Private Constants and Variables
    -- ========================================================================
    gc_scope_prefix CONSTANT VARCHAR2(50) := 'apex_auth_pkg.';
    
    -- ========================================================================
    -- Private Helper Functions
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Private Function: get_component_type_id
    Purpose: Get component type ID from code
    --------------------------------------------------------------------------
    */
    FUNCTION get_component_type_id(
        p_component_type_code IN VARCHAR2
    ) RETURN NUMBER IS
        l_component_type_id NUMBER;
    BEGIN
        SELECT component_type_id
        INTO   l_component_type_id
        FROM   apex_auth_component_types
        WHERE  component_type_code = UPPER(p_component_type_code)
        AND    is_active = 'Y';
        
        RETURN l_component_type_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_component_type_id;
    
    /*
    --------------------------------------------------------------------------
    Private Function: is_role_assignment_active
    Purpose: Check if user role assignment is currently active
    --------------------------------------------------------------------------
    */
    FUNCTION is_role_assignment_active(
        p_username  IN VARCHAR2,
        p_role_id   IN NUMBER
    ) RETURN BOOLEAN IS
        l_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO   l_count
        FROM   apex_auth_user_roles
        WHERE  UPPER(username) = UPPER(p_username)
        AND    role_id = p_role_id
        AND    is_active = 'Y'
        AND    TRUNC(SYSDATE) BETWEEN effective_from 
                                  AND NVL(effective_to, TRUNC(SYSDATE));
        
        RETURN (l_count > 0);
    END is_role_assignment_active;
    
    /*
    --------------------------------------------------------------------------
    Private Function: get_current_user
    Purpose: Get current APEX user with fallback
    --------------------------------------------------------------------------
    */
    FUNCTION get_current_user RETURN VARCHAR2 IS
        l_username VARCHAR2(255);
    BEGIN
        l_username := V('APP_USER');
        
        IF l_username IS NULL THEN
            l_username := SYS_CONTEXT('USERENV', 'SESSION_USER');
        END IF;
        
        RETURN l_username;
    END get_current_user;
    
    -- ========================================================================
    -- Authorization Check Functions Implementation
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Function: is_authorized
    --------------------------------------------------------------------------
    */
    FUNCTION is_authorized(
        p_component_type    IN VARCHAR2,
        p_component_name    IN VARCHAR2,
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_page_id           IN NUMBER   DEFAULT NV('APP_PAGE_ID'),
        p_permission_type   IN VARCHAR2 DEFAULT gc_perm_view,
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN IS
        l_scope         VARCHAR2(100) := gc_scope_prefix || 'is_authorized';
        l_authorized    BOOLEAN := FALSE;
        l_permission    VARCHAR2(1);
        l_username      VARCHAR2(255);
        l_app_id        NUMBER;
        l_page_id       NUMBER;
        
        CURSOR c_check_auth IS
            SELECT 
                CASE UPPER(p_permission_type)
                    WHEN 'VIEW'    THEN p.can_view
                    WHEN 'EDIT'    THEN p.can_edit
                    WHEN 'DELETE'  THEN p.can_delete
                    WHEN 'EXECUTE' THEN p.can_execute
                    ELSE p.can_view
                END AS permission_value
            FROM   apex_auth_permissions p
            JOIN   apex_auth_roles r 
                   ON r.role_id = p.role_id
            JOIN   apex_auth_user_roles ur 
                   ON ur.role_id = r.role_id
            JOIN   apex_auth_components c 
                   ON c.component_id = p.component_id
            JOIN   apex_auth_component_types ct 
                   ON ct.component_type_id = c.component_type_id
            WHERE  UPPER(ur.username) = UPPER(l_username)
            AND    ur.is_active = 'Y'
            AND    TRUNC(SYSDATE) BETWEEN ur.effective_from 
                                      AND NVL(ur.effective_to, TRUNC(SYSDATE))
            AND    r.is_active = 'Y'
            AND    p.is_active = 'Y'
            AND    TRUNC(SYSDATE) BETWEEN p.effective_from 
                                      AND NVL(p.effective_to, TRUNC(SYSDATE))
            AND    c.is_active = 'Y'
            AND    c.application_id = l_app_id
            AND    NVL(c.page_id, -1) = NVL(l_page_id, NVL(c.page_id, -1))
            AND    ct.component_type_code = UPPER(p_component_type)
            AND    (c.component_name = p_component_name 
                    OR c.component_static_id = p_component_name)
            ORDER BY 
                -- Prioritize exact page match over NULL page
                CASE WHEN c.page_id = l_page_id THEN 1 ELSE 2 END;
    BEGIN
        -- Get effective values with defaults
        l_username := NVL(p_username, get_current_user);
        l_app_id   := NVL(p_application_id, NV('APP_ID'));
        l_page_id  := p_page_id;  -- Allow NULL for app-level components
        
        -- Check authorization
        OPEN c_check_auth;
        FETCH c_check_auth INTO l_permission;
        
        IF c_check_auth%FOUND AND l_permission = 'Y' THEN
            l_authorized := TRUE;
        END IF;
        
        CLOSE c_check_auth;
        
        -- Log the authorization check (only if auditing is enabled)
        BEGIN
            log_audit(
                p_audit_type     => gc_audit_auth_check,
                p_username       => l_username,
                p_application_id => l_app_id,
                p_page_id        => l_page_id,
                p_component_type => p_component_type,
                p_component_name => p_component_name,
                p_action_taken   => p_permission_type,
                p_auth_result    => CASE WHEN l_authorized THEN 'GRANTED' ELSE 'DENIED' END
            );
        EXCEPTION
            WHEN OTHERS THEN
                -- Don't fail authorization check due to audit logging error
                NULL;
        END;
        
        RETURN l_authorized;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Log error but return FALSE for security
            BEGIN
                log_audit(
                    p_audit_type => gc_audit_error,
                    p_username   => l_username,
                    p_details    => 'Error in is_authorized: ' || SQLERRM
                );
            EXCEPTION
                WHEN OTHERS THEN NULL;
            END;
            RETURN FALSE;
    END is_authorized;
    
    /*
    --------------------------------------------------------------------------
    Function: is_authorized_yn
    --------------------------------------------------------------------------
    */
    FUNCTION is_authorized_yn(
        p_component_type    IN VARCHAR2,
        p_component_name    IN VARCHAR2,
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_page_id           IN NUMBER   DEFAULT NV('APP_PAGE_ID'),
        p_permission_type   IN VARCHAR2 DEFAULT gc_perm_view,
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN VARCHAR2 IS
    BEGIN
        IF is_authorized(
            p_component_type  => p_component_type,
            p_component_name  => p_component_name,
            p_application_id  => p_application_id,
            p_page_id         => p_page_id,
            p_permission_type => p_permission_type,
            p_username        => p_username
        ) THEN
            RETURN 'Y';
        ELSE
            RETURN 'N';
        END IF;
    END is_authorized_yn;
    
    /*
    --------------------------------------------------------------------------
    Function: can_access_page
    --------------------------------------------------------------------------
    */
    FUNCTION can_access_page(
        p_page_id           IN NUMBER,
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN is_authorized(
            p_component_type  => gc_comp_page,
            p_component_name  => TO_CHAR(p_page_id),
            p_application_id  => p_application_id,
            p_page_id         => p_page_id,
            p_permission_type => gc_perm_view,
            p_username        => p_username
        );
    END can_access_page;
    
    /*
    --------------------------------------------------------------------------
    Function: can_view_region
    --------------------------------------------------------------------------
    */
    FUNCTION can_view_region(
        p_region_static_id  IN VARCHAR2,
        p_page_id           IN NUMBER   DEFAULT NV('APP_PAGE_ID'),
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN is_authorized(
            p_component_type  => gc_comp_region,
            p_component_name  => p_region_static_id,
            p_application_id  => p_application_id,
            p_page_id         => p_page_id,
            p_permission_type => gc_perm_view,
            p_username        => p_username
        );
    END can_view_region;
    
    /*
    --------------------------------------------------------------------------
    Function: can_use_button
    --------------------------------------------------------------------------
    */
    FUNCTION can_use_button(
        p_button_static_id  IN VARCHAR2,
        p_page_id           IN NUMBER   DEFAULT NV('APP_PAGE_ID'),
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN is_authorized(
            p_component_type  => gc_comp_button,
            p_component_name  => p_button_static_id,
            p_application_id  => p_application_id,
            p_page_id         => p_page_id,
            p_permission_type => gc_perm_execute,
            p_username        => p_username
        );
    END can_use_button;
    
    /*
    --------------------------------------------------------------------------
    Function: can_view_menu_entry
    --------------------------------------------------------------------------
    */
    FUNCTION can_view_menu_entry(
        p_menu_entry_name   IN VARCHAR2,
        p_application_id    IN NUMBER   DEFAULT NV('APP_ID'),
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN is_authorized(
            p_component_type  => gc_comp_menu,
            p_component_name  => p_menu_entry_name,
            p_application_id  => p_application_id,
            p_page_id         => NULL,  -- Menus are app-level
            p_permission_type => gc_perm_view,
            p_username        => p_username
        );
    END can_view_menu_entry;
    
    /*
    --------------------------------------------------------------------------
    Function: has_role
    --------------------------------------------------------------------------
    */
    FUNCTION has_role(
        p_role_code         IN VARCHAR2,
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN IS
        l_count    NUMBER;
        l_username VARCHAR2(255);
    BEGIN
        l_username := NVL(p_username, get_current_user);
        
        SELECT COUNT(*)
        INTO   l_count
        FROM   apex_auth_user_roles ur
        JOIN   apex_auth_roles r ON r.role_id = ur.role_id
        WHERE  UPPER(ur.username) = UPPER(l_username)
        AND    r.role_code = UPPER(p_role_code)
        AND    ur.is_active = 'Y'
        AND    r.is_active = 'Y'
        AND    TRUNC(SYSDATE) BETWEEN ur.effective_from 
                                  AND NVL(ur.effective_to, TRUNC(SYSDATE));
        
        RETURN (l_count > 0);
    END has_role;
    
    /*
    --------------------------------------------------------------------------
    Function: has_any_role
    --------------------------------------------------------------------------
    */
    FUNCTION has_any_role(
        p_role_codes        IN t_role_list,
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN IS
    BEGIN
        IF p_role_codes IS NULL OR p_role_codes.COUNT = 0 THEN
            RETURN FALSE;
        END IF;
        
        FOR i IN 1..p_role_codes.COUNT LOOP
            IF has_role(p_role_codes(i), p_username) THEN
                RETURN TRUE;
            END IF;
        END LOOP;
        
        RETURN FALSE;
    END has_any_role;
    
    /*
    --------------------------------------------------------------------------
    Function: has_all_roles
    --------------------------------------------------------------------------
    */
    FUNCTION has_all_roles(
        p_role_codes        IN t_role_list,
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN BOOLEAN IS
    BEGIN
        IF p_role_codes IS NULL OR p_role_codes.COUNT = 0 THEN
            RETURN FALSE;
        END IF;
        
        FOR i IN 1..p_role_codes.COUNT LOOP
            IF NOT has_role(p_role_codes(i), p_username) THEN
                RETURN FALSE;
            END IF;
        END LOOP;
        
        RETURN TRUE;
    END has_all_roles;
    
    /*
    --------------------------------------------------------------------------
    Function: get_user_roles
    --------------------------------------------------------------------------
    */
    FUNCTION get_user_roles(
        p_username          IN VARCHAR2 DEFAULT V('APP_USER')
    ) RETURN VARCHAR2 IS
        l_roles    VARCHAR2(4000);
        l_username VARCHAR2(255);
    BEGIN
        l_username := NVL(p_username, get_current_user);
        
        SELECT LISTAGG(r.role_code, ',') WITHIN GROUP (ORDER BY r.display_sequence, r.role_code)
        INTO   l_roles
        FROM   apex_auth_user_roles ur
        JOIN   apex_auth_roles r ON r.role_id = ur.role_id
        WHERE  UPPER(ur.username) = UPPER(l_username)
        AND    ur.is_active = 'Y'
        AND    r.is_active = 'Y'
        AND    TRUNC(SYSDATE) BETWEEN ur.effective_from 
                                  AND NVL(ur.effective_to, TRUNC(SYSDATE));
        
        RETURN l_roles;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END get_user_roles;
    
    -- ========================================================================
    -- Role Management Procedures Implementation
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Procedure: create_role
    --------------------------------------------------------------------------
    */
    PROCEDURE create_role(
        p_role_code         IN VARCHAR2,
        p_role_name         IN VARCHAR2,
        p_role_description  IN VARCHAR2 DEFAULT NULL,
        p_display_sequence  IN NUMBER   DEFAULT 0,
        p_role_id           OUT NUMBER
    ) IS
        l_scope VARCHAR2(100) := gc_scope_prefix || 'create_role';
    BEGIN
        -- Validate input
        IF p_role_code IS NULL THEN
            RAISE_APPLICATION_ERROR(-20003, 'Role code cannot be NULL');
        END IF;
        
        IF p_role_name IS NULL THEN
            RAISE_APPLICATION_ERROR(-20003, 'Role name cannot be NULL');
        END IF;
        
        INSERT INTO apex_auth_roles (
            role_code,
            role_name,
            role_description,
            display_sequence,
            created_by,
            created_date
        ) VALUES (
            UPPER(p_role_code),
            p_role_name,
            p_role_description,
            NVL(p_display_sequence, 0),
            get_current_user,
            SYSTIMESTAMP
        )
        RETURNING role_id INTO p_role_id;
        
        -- Audit log
        log_audit(
            p_audit_type   => gc_audit_role_chg,
            p_action_taken => 'CREATE_ROLE',
            p_details      => 'Created role: ' || p_role_code
        );
        
    END create_role;
    
    /*
    --------------------------------------------------------------------------
    Procedure: update_role
    --------------------------------------------------------------------------
    */
    PROCEDURE update_role(
        p_role_id           IN NUMBER,
        p_role_name         IN VARCHAR2 DEFAULT NULL,
        p_role_description  IN VARCHAR2 DEFAULT NULL,
        p_is_active         IN VARCHAR2 DEFAULT NULL,
        p_display_sequence  IN NUMBER   DEFAULT NULL
    ) IS
    BEGIN
        UPDATE apex_auth_roles
        SET    role_name        = NVL(p_role_name, role_name),
               role_description = NVL(p_role_description, role_description),
               is_active        = NVL(p_is_active, is_active),
               display_sequence = NVL(p_display_sequence, display_sequence),
               updated_by       = get_current_user,
               updated_date     = SYSTIMESTAMP
        WHERE  role_id = p_role_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Role not found: ' || p_role_id);
        END IF;
        
        log_audit(
            p_audit_type   => gc_audit_role_chg,
            p_action_taken => 'UPDATE_ROLE',
            p_details      => 'Updated role ID: ' || p_role_id
        );
    END update_role;
    
    /*
    --------------------------------------------------------------------------
    Procedure: delete_role
    --------------------------------------------------------------------------
    */
    PROCEDURE delete_role(
        p_role_id           IN NUMBER
    ) IS
        l_role_code VARCHAR2(50);
    BEGIN
        -- Get role code for audit
        SELECT role_code INTO l_role_code
        FROM   apex_auth_roles
        WHERE  role_id = p_role_id;
        
        DELETE FROM apex_auth_roles
        WHERE  role_id = p_role_id;
        
        log_audit(
            p_audit_type   => gc_audit_role_chg,
            p_action_taken => 'DELETE_ROLE',
            p_details      => 'Deleted role: ' || l_role_code
        );
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Role not found: ' || p_role_id);
    END delete_role;
    
    /*
    --------------------------------------------------------------------------
    Procedure: assign_role_to_user
    --------------------------------------------------------------------------
    */
    PROCEDURE assign_role_to_user(
        p_username          IN VARCHAR2,
        p_role_code         IN VARCHAR2,
        p_effective_from    IN DATE     DEFAULT TRUNC(SYSDATE),
        p_effective_to      IN DATE     DEFAULT NULL
    ) IS
        l_role_id NUMBER;
    BEGIN
        -- Get role ID
        l_role_id := get_role_id(p_role_code);
        
        IF l_role_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Role not found: ' || p_role_code);
        END IF;
        
        -- Insert or update (merge)
        MERGE INTO apex_auth_user_roles tgt
        USING (
            SELECT l_role_id AS role_id, 
                   UPPER(p_username) AS username 
            FROM DUAL
        ) src
        ON (tgt.role_id = src.role_id AND UPPER(tgt.username) = src.username)
        WHEN MATCHED THEN
            UPDATE SET 
                is_active      = 'Y',
                effective_from = NVL(p_effective_from, TRUNC(SYSDATE)),
                effective_to   = p_effective_to,
                updated_by     = get_current_user,
                updated_date   = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (username, role_id, is_active, effective_from, effective_to, created_by)
            VALUES (UPPER(p_username), l_role_id, 'Y', 
                    NVL(p_effective_from, TRUNC(SYSDATE)), p_effective_to, get_current_user);
        
        log_audit(
            p_audit_type   => gc_audit_role_chg,
            p_username     => p_username,
            p_action_taken => 'ASSIGN_ROLE',
            p_details      => 'Assigned role ' || p_role_code || ' to user ' || p_username
        );
    END assign_role_to_user;
    
    /*
    --------------------------------------------------------------------------
    Procedure: remove_role_from_user
    --------------------------------------------------------------------------
    */
    PROCEDURE remove_role_from_user(
        p_username          IN VARCHAR2,
        p_role_code         IN VARCHAR2
    ) IS
        l_role_id NUMBER;
    BEGIN
        l_role_id := get_role_id(p_role_code);
        
        IF l_role_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Role not found: ' || p_role_code);
        END IF;
        
        UPDATE apex_auth_user_roles
        SET    is_active    = 'N',
               updated_by   = get_current_user,
               updated_date = SYSTIMESTAMP
        WHERE  UPPER(username) = UPPER(p_username)
        AND    role_id = l_role_id;
        
        log_audit(
            p_audit_type   => gc_audit_role_chg,
            p_username     => p_username,
            p_action_taken => 'REMOVE_ROLE',
            p_details      => 'Removed role ' || p_role_code || ' from user ' || p_username
        );
    END remove_role_from_user;
    
    /*
    --------------------------------------------------------------------------
    Procedure: sync_user_roles
    --------------------------------------------------------------------------
    */
    PROCEDURE sync_user_roles(
        p_username          IN VARCHAR2,
        p_role_codes        IN t_role_list
    ) IS
    BEGIN
        -- Deactivate all current roles
        UPDATE apex_auth_user_roles
        SET    is_active    = 'N',
               updated_by   = get_current_user,
               updated_date = SYSTIMESTAMP
        WHERE  UPPER(username) = UPPER(p_username);
        
        -- Assign new roles
        IF p_role_codes IS NOT NULL AND p_role_codes.COUNT > 0 THEN
            FOR i IN 1..p_role_codes.COUNT LOOP
                assign_role_to_user(p_username, p_role_codes(i));
            END LOOP;
        END IF;
        
        log_audit(
            p_audit_type   => gc_audit_role_chg,
            p_username     => p_username,
            p_action_taken => 'SYNC_ROLES',
            p_details      => 'Synchronized roles for user ' || p_username
        );
    END sync_user_roles;
    
    -- ========================================================================
    -- Component Management Procedures Implementation
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Procedure: register_component
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
    ) IS
        l_component_type_id NUMBER;
    BEGIN
        -- Get component type ID
        l_component_type_id := get_component_type_id(p_component_type_code);
        
        IF l_component_type_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20003, 'Invalid component type: ' || p_component_type_code);
        END IF;
        
        -- Insert or update (merge)
        MERGE INTO apex_auth_components tgt
        USING (
            SELECT p_application_id AS app_id,
                   l_component_type_id AS comp_type_id,
                   NVL(p_page_id, -1) AS pg_id,
                   p_component_name AS comp_name
            FROM DUAL
        ) src
        ON (tgt.application_id = src.app_id 
            AND tgt.component_type_id = src.comp_type_id
            AND NVL(tgt.page_id, -1) = src.pg_id
            AND tgt.component_name = src.comp_name)
        WHEN MATCHED THEN
            UPDATE SET
                component_static_id = NVL(p_component_static_id, component_static_id),
                display_name        = NVL(p_display_name, display_name),
                description         = NVL(p_description, description),
                parent_component_id = NVL(p_parent_component_id, parent_component_id),
                is_active           = 'Y',
                updated_by          = get_current_user,
                updated_date        = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (application_id, component_type_id, page_id, component_name,
                    component_static_id, display_name, description, 
                    parent_component_id, created_by)
            VALUES (p_application_id, l_component_type_id, 
                    CASE WHEN p_page_id = -1 THEN NULL ELSE p_page_id END,
                    p_component_name, p_component_static_id, p_display_name,
                    p_description, p_parent_component_id, get_current_user);
        
        -- Get the component ID
        SELECT component_id INTO p_component_id
        FROM   apex_auth_components
        WHERE  application_id = p_application_id
        AND    component_type_id = l_component_type_id
        AND    NVL(page_id, -1) = NVL(p_page_id, -1)
        AND    component_name = p_component_name;
        
        log_audit(
            p_audit_type     => gc_audit_comp_chg,
            p_application_id => p_application_id,
            p_page_id        => p_page_id,
            p_component_type => p_component_type_code,
            p_component_name => p_component_name,
            p_action_taken   => 'REGISTER_COMPONENT'
        );
    END register_component;
    
    /*
    --------------------------------------------------------------------------
    Procedure: register_page
    --------------------------------------------------------------------------
    */
    PROCEDURE register_page(
        p_application_id    IN NUMBER,
        p_page_id           IN NUMBER,
        p_display_name      IN VARCHAR2 DEFAULT NULL,
        p_description       IN VARCHAR2 DEFAULT NULL
    ) IS
        l_component_id NUMBER;
    BEGIN
        register_component(
            p_application_id      => p_application_id,
            p_component_type_code => gc_comp_page,
            p_component_name      => TO_CHAR(p_page_id),
            p_page_id             => p_page_id,
            p_display_name        => p_display_name,
            p_description         => p_description,
            p_component_id        => l_component_id
        );
    END register_page;
    
    /*
    --------------------------------------------------------------------------
    Procedure: register_region
    --------------------------------------------------------------------------
    */
    PROCEDURE register_region(
        p_application_id    IN NUMBER,
        p_page_id           IN NUMBER,
        p_region_static_id  IN VARCHAR2,
        p_display_name      IN VARCHAR2 DEFAULT NULL,
        p_description       IN VARCHAR2 DEFAULT NULL
    ) IS
        l_component_id NUMBER;
    BEGIN
        register_component(
            p_application_id      => p_application_id,
            p_component_type_code => gc_comp_region,
            p_component_name      => p_region_static_id,
            p_page_id             => p_page_id,
            p_component_static_id => p_region_static_id,
            p_display_name        => p_display_name,
            p_description         => p_description,
            p_component_id        => l_component_id
        );
    END register_region;
    
    /*
    --------------------------------------------------------------------------
    Procedure: register_button
    --------------------------------------------------------------------------
    */
    PROCEDURE register_button(
        p_application_id    IN NUMBER,
        p_page_id           IN NUMBER,
        p_button_static_id  IN VARCHAR2,
        p_display_name      IN VARCHAR2 DEFAULT NULL,
        p_description       IN VARCHAR2 DEFAULT NULL
    ) IS
        l_component_id NUMBER;
    BEGIN
        register_component(
            p_application_id      => p_application_id,
            p_component_type_code => gc_comp_button,
            p_component_name      => p_button_static_id,
            p_page_id             => p_page_id,
            p_component_static_id => p_button_static_id,
            p_display_name        => p_display_name,
            p_description         => p_description,
            p_component_id        => l_component_id
        );
    END register_button;
    
    /*
    --------------------------------------------------------------------------
    Procedure: register_menu_entry
    --------------------------------------------------------------------------
    */
    PROCEDURE register_menu_entry(
        p_application_id    IN NUMBER,
        p_menu_entry_name   IN VARCHAR2,
        p_display_name      IN VARCHAR2 DEFAULT NULL,
        p_description       IN VARCHAR2 DEFAULT NULL
    ) IS
        l_component_id NUMBER;
    BEGIN
        register_component(
            p_application_id      => p_application_id,
            p_component_type_code => gc_comp_menu,
            p_component_name      => p_menu_entry_name,
            p_page_id             => NULL,  -- Menus are application-level
            p_display_name        => p_display_name,
            p_description         => p_description,
            p_component_id        => l_component_id
        );
    END register_menu_entry;
    
    /*
    --------------------------------------------------------------------------
    Procedure: deactivate_component
    --------------------------------------------------------------------------
    */
    PROCEDURE deactivate_component(
        p_component_id      IN NUMBER
    ) IS
    BEGIN
        UPDATE apex_auth_components
        SET    is_active    = 'N',
               updated_by   = get_current_user,
               updated_date = SYSTIMESTAMP
        WHERE  component_id = p_component_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Component not found: ' || p_component_id);
        END IF;
        
        log_audit(
            p_audit_type   => gc_audit_comp_chg,
            p_action_taken => 'DEACTIVATE_COMPONENT',
            p_details      => 'Deactivated component ID: ' || p_component_id
        );
    END deactivate_component;
    
    /*
    --------------------------------------------------------------------------
    Procedure: delete_component
    --------------------------------------------------------------------------
    */
    PROCEDURE delete_component(
        p_component_id      IN NUMBER
    ) IS
    BEGIN
        DELETE FROM apex_auth_components
        WHERE  component_id = p_component_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Component not found: ' || p_component_id);
        END IF;
        
        log_audit(
            p_audit_type   => gc_audit_comp_chg,
            p_action_taken => 'DELETE_COMPONENT',
            p_details      => 'Deleted component ID: ' || p_component_id
        );
    END delete_component;
    
    -- ========================================================================
    -- Permission Management Procedures Implementation
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Procedure: grant_permission
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
    ) IS
        l_role_id NUMBER;
    BEGIN
        l_role_id := get_role_id(p_role_code);
        
        IF l_role_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Role not found: ' || p_role_code);
        END IF;
        
        -- Merge permission
        MERGE INTO apex_auth_permissions tgt
        USING (
            SELECT l_role_id AS role_id, p_component_id AS component_id FROM DUAL
        ) src
        ON (tgt.role_id = src.role_id AND tgt.component_id = src.component_id)
        WHEN MATCHED THEN
            UPDATE SET
                can_view       = NVL(p_can_view, can_view),
                can_edit       = NVL(p_can_edit, can_edit),
                can_delete     = NVL(p_can_delete, can_delete),
                can_execute    = NVL(p_can_execute, can_execute),
                is_active      = 'Y',
                effective_from = NVL(p_effective_from, effective_from),
                effective_to   = p_effective_to,
                updated_by     = get_current_user,
                updated_date   = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (role_id, component_id, can_view, can_edit, can_delete, 
                    can_execute, effective_from, effective_to, created_by)
            VALUES (l_role_id, p_component_id, 
                    NVL(p_can_view, 'Y'), NVL(p_can_edit, 'N'), 
                    NVL(p_can_delete, 'N'), NVL(p_can_execute, 'N'),
                    NVL(p_effective_from, TRUNC(SYSDATE)), p_effective_to,
                    get_current_user);
        
        log_audit(
            p_audit_type   => gc_audit_perm_chg,
            p_action_taken => 'GRANT_PERMISSION',
            p_details      => 'Granted permission on component ' || p_component_id || 
                             ' to role ' || p_role_code
        );
    END grant_permission;
    
    /*
    --------------------------------------------------------------------------
    Procedure: grant_permission_by_name
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
    ) IS
        l_component_id NUMBER;
    BEGIN
        l_component_id := get_component_id(
            p_application_id      => p_application_id,
            p_component_type_code => p_component_type_code,
            p_component_name      => p_component_name,
            p_page_id             => p_page_id
        );
        
        IF l_component_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 
                'Component not found: ' || p_component_type_code || '/' || p_component_name);
        END IF;
        
        grant_permission(
            p_role_code    => p_role_code,
            p_component_id => l_component_id,
            p_can_view     => p_can_view,
            p_can_edit     => p_can_edit,
            p_can_delete   => p_can_delete,
            p_can_execute  => p_can_execute
        );
    END grant_permission_by_name;
    
    /*
    --------------------------------------------------------------------------
    Procedure: revoke_permission
    --------------------------------------------------------------------------
    */
    PROCEDURE revoke_permission(
        p_role_code         IN VARCHAR2,
        p_component_id      IN NUMBER
    ) IS
        l_role_id NUMBER;
    BEGIN
        l_role_id := get_role_id(p_role_code);
        
        IF l_role_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Role not found: ' || p_role_code);
        END IF;
        
        UPDATE apex_auth_permissions
        SET    is_active    = 'N',
               updated_by   = get_current_user,
               updated_date = SYSTIMESTAMP
        WHERE  role_id = l_role_id
        AND    component_id = p_component_id;
        
        log_audit(
            p_audit_type   => gc_audit_perm_chg,
            p_action_taken => 'REVOKE_PERMISSION',
            p_details      => 'Revoked permission on component ' || p_component_id || 
                             ' from role ' || p_role_code
        );
    END revoke_permission;
    
    /*
    --------------------------------------------------------------------------
    Procedure: update_permission
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
    ) IS
    BEGIN
        UPDATE apex_auth_permissions
        SET    can_view       = NVL(p_can_view, can_view),
               can_edit       = NVL(p_can_edit, can_edit),
               can_delete     = NVL(p_can_delete, can_delete),
               can_execute    = NVL(p_can_execute, can_execute),
               is_active      = NVL(p_is_active, is_active),
               effective_from = NVL(p_effective_from, effective_from),
               effective_to   = NVL(p_effective_to, effective_to),
               updated_by     = get_current_user,
               updated_date   = SYSTIMESTAMP
        WHERE  permission_id = p_permission_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Permission not found: ' || p_permission_id);
        END IF;
        
        log_audit(
            p_audit_type   => gc_audit_perm_chg,
            p_action_taken => 'UPDATE_PERMISSION',
            p_details      => 'Updated permission ID: ' || p_permission_id
        );
    END update_permission;
    
    -- ========================================================================
    -- Bulk Operations Implementation
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Procedure: grant_role_to_all_pages
    --------------------------------------------------------------------------
    */
    PROCEDURE grant_role_to_all_pages(
        p_role_code         IN VARCHAR2,
        p_application_id    IN NUMBER
    ) IS
    BEGIN
        FOR rec IN (
            SELECT component_id
            FROM   apex_auth_components c
            JOIN   apex_auth_component_types ct 
                   ON ct.component_type_id = c.component_type_id
            WHERE  c.application_id = p_application_id
            AND    ct.component_type_code = gc_comp_page
            AND    c.is_active = 'Y'
        ) LOOP
            grant_permission(
                p_role_code    => p_role_code,
                p_component_id => rec.component_id,
                p_can_view     => 'Y'
            );
        END LOOP;
        
        log_audit(
            p_audit_type     => gc_audit_perm_chg,
            p_application_id => p_application_id,
            p_action_taken   => 'GRANT_ALL_PAGES',
            p_details        => 'Granted all pages to role ' || p_role_code
        );
    END grant_role_to_all_pages;
    
    /*
    --------------------------------------------------------------------------
    Procedure: copy_role_permissions
    --------------------------------------------------------------------------
    */
    PROCEDURE copy_role_permissions(
        p_source_role_code  IN VARCHAR2,
        p_target_role_code  IN VARCHAR2
    ) IS
        l_source_role_id NUMBER;
        l_target_role_id NUMBER;
    BEGIN
        l_source_role_id := get_role_id(p_source_role_code);
        l_target_role_id := get_role_id(p_target_role_code);
        
        IF l_source_role_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Source role not found: ' || p_source_role_code);
        END IF;
        
        IF l_target_role_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Target role not found: ' || p_target_role_code);
        END IF;
        
        -- Copy all permissions from source to target
        MERGE INTO apex_auth_permissions tgt
        USING (
            SELECT l_target_role_id AS role_id, 
                   component_id, can_view, can_edit, can_delete, can_execute,
                   effective_from, effective_to
            FROM   apex_auth_permissions
            WHERE  role_id = l_source_role_id
            AND    is_active = 'Y'
        ) src
        ON (tgt.role_id = src.role_id AND tgt.component_id = src.component_id)
        WHEN MATCHED THEN
            UPDATE SET
                can_view       = src.can_view,
                can_edit       = src.can_edit,
                can_delete     = src.can_delete,
                can_execute    = src.can_execute,
                is_active      = 'Y',
                effective_from = src.effective_from,
                effective_to   = src.effective_to,
                updated_by     = get_current_user,
                updated_date   = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (role_id, component_id, can_view, can_edit, can_delete, 
                    can_execute, effective_from, effective_to, created_by)
            VALUES (src.role_id, src.component_id, src.can_view, src.can_edit,
                    src.can_delete, src.can_execute, src.effective_from, 
                    src.effective_to, get_current_user);
        
        log_audit(
            p_audit_type   => gc_audit_perm_chg,
            p_action_taken => 'COPY_PERMISSIONS',
            p_details      => 'Copied permissions from ' || p_source_role_code || 
                             ' to ' || p_target_role_code
        );
    END copy_role_permissions;
    
    -- ========================================================================
    -- Utility Functions Implementation
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Function: get_version
    --------------------------------------------------------------------------
    */
    FUNCTION get_version RETURN VARCHAR2 IS
    BEGIN
        RETURN gc_version;
    END get_version;
    
    /*
    --------------------------------------------------------------------------
    Function: get_component_id
    --------------------------------------------------------------------------
    */
    FUNCTION get_component_id(
        p_application_id      IN NUMBER,
        p_component_type_code IN VARCHAR2,
        p_component_name      IN VARCHAR2,
        p_page_id             IN NUMBER DEFAULT NULL
    ) RETURN NUMBER IS
        l_component_id NUMBER;
    BEGIN
        SELECT c.component_id
        INTO   l_component_id
        FROM   apex_auth_components c
        JOIN   apex_auth_component_types ct 
               ON ct.component_type_id = c.component_type_id
        WHERE  c.application_id = p_application_id
        AND    ct.component_type_code = UPPER(p_component_type_code)
        AND    NVL(c.page_id, -1) = NVL(p_page_id, -1)
        AND    (c.component_name = p_component_name 
                OR c.component_static_id = p_component_name)
        AND    ROWNUM = 1;
        
        RETURN l_component_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_component_id;
    
    /*
    --------------------------------------------------------------------------
    Function: get_role_id
    --------------------------------------------------------------------------
    */
    FUNCTION get_role_id(
        p_role_code         IN VARCHAR2
    ) RETURN NUMBER IS
        l_role_id NUMBER;
    BEGIN
        SELECT role_id
        INTO   l_role_id
        FROM   apex_auth_roles
        WHERE  role_code = UPPER(p_role_code)
        AND    is_active = 'Y';
        
        RETURN l_role_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_role_id;
    
    -- ========================================================================
    -- Audit Procedures Implementation
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Procedure: log_audit
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
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_ip_address  VARCHAR2(100);
        l_session_id  VARCHAR2(100);
    BEGIN
        -- Get session info if available
        BEGIN
            l_ip_address := OWA_UTIL.GET_CGI_ENV('REMOTE_ADDR');
            l_session_id := V('APP_SESSION');
        EXCEPTION
            WHEN OTHERS THEN
                l_ip_address := SYS_CONTEXT('USERENV', 'IP_ADDRESS');
                l_session_id := SYS_CONTEXT('USERENV', 'SESSIONID');
        END;
        
        INSERT INTO apex_auth_audit_log (
            audit_type,
            username,
            application_id,
            page_id,
            component_type,
            component_name,
            action_taken,
            auth_result,
            ip_address,
            session_id,
            details
        ) VALUES (
            p_audit_type,
            NVL(p_username, get_current_user),
            p_application_id,
            p_page_id,
            p_component_type,
            p_component_name,
            p_action_taken,
            p_auth_result,
            l_ip_address,
            l_session_id,
            p_details
        );
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            -- Silently fail - don't break main operations due to audit failure
    END log_audit;
    
    /*
    --------------------------------------------------------------------------
    Procedure: purge_audit_log
    --------------------------------------------------------------------------
    */
    PROCEDURE purge_audit_log(
        p_days_to_keep      IN NUMBER DEFAULT 90
    ) IS
        l_count NUMBER;
    BEGIN
        DELETE FROM apex_auth_audit_log
        WHERE  audit_date < SYSTIMESTAMP - NUMTODSINTERVAL(p_days_to_keep, 'DAY');
        
        l_count := SQL%ROWCOUNT;
        
        log_audit(
            p_audit_type   => gc_audit_comp_chg,
            p_action_taken => 'PURGE_AUDIT_LOG',
            p_details      => 'Purged ' || l_count || ' audit records older than ' || 
                             p_days_to_keep || ' days'
        );
        
        COMMIT;
    END purge_audit_log;

END apex_auth_pkg;
/

SHOW ERRORS PACKAGE BODY apex_auth_pkg;

PROMPT ========================================
PROMPT Package Body Created: APEX_AUTH_PKG
PROMPT ========================================
