/*
================================================================================
  FND_PROFILE Package Body
  Similar to Oracle EBS FND_PROFILE API Implementation
  
  Author: Database Team
  Version: 1.0
  Target: Oracle 19c+
================================================================================
*/

CREATE OR REPLACE PACKAGE BODY fnd_profile AS

    -- ========================================================================
    -- Private Types and Variables
    -- ========================================================================
    
    -- Cache for profile values
    TYPE profile_cache_rec IS RECORD (
        profile_name  VARCHAR2(80),
        profile_value VARCHAR2(240),
        cached_time   DATE
    );
    
    TYPE profile_cache_tbl IS TABLE OF profile_cache_rec INDEX BY VARCHAR2(80);
    
    g_profile_cache profile_cache_tbl;
    
    -- Exception definitions
    e_profile_not_found EXCEPTION;
    e_invalid_level     EXCEPTION;
    e_update_not_allowed EXCEPTION;
    
    -- ========================================================================
    -- Private Helper Functions and Procedures
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Function: get_level_id
    Purpose: Convert level name to level ID
    --------------------------------------------------------------------------
    */
    FUNCTION get_level_id(p_level_name IN VARCHAR2) RETURN NUMBER IS
        v_level_id NUMBER;
    BEGIN
        SELECT level_id
        INTO   v_level_id
        FROM   fnd_profile_levels
        WHERE  level_name = UPPER(p_level_name)
        AND    enabled_flag = 'Y';
        
        RETURN v_level_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_level_id;
    
    /*
    --------------------------------------------------------------------------
    Function: get_profile_option_id
    Purpose: Get profile option ID from name
    --------------------------------------------------------------------------
    */
    FUNCTION get_profile_option_id(p_name IN VARCHAR2) RETURN NUMBER IS
        v_profile_option_id NUMBER;
    BEGIN
        SELECT profile_option_id
        INTO   v_profile_option_id
        FROM   fnd_profile_options
        WHERE  profile_option_name = UPPER(p_name)
        AND    SYSDATE BETWEEN start_date_active AND NVL(end_date_active, SYSDATE + 1);
        
        RETURN v_profile_option_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_profile_option_id;
    
    /*
    --------------------------------------------------------------------------
    Function: get_value_at_level
    Purpose: Get profile value at specific level from database
    --------------------------------------------------------------------------
    */
    FUNCTION get_value_at_level(
        p_profile_option_id   IN NUMBER,
        p_level_id            IN NUMBER,
        p_level_value         IN NUMBER,
        p_level_value_appl_id IN NUMBER DEFAULT NULL
    ) RETURN VARCHAR2 IS
        v_value VARCHAR2(240);
    BEGIN
        SELECT pov.profile_option_value
        INTO   v_value
        FROM   fnd_profile_option_values pov
        WHERE  pov.profile_option_id = p_profile_option_id
        AND    pov.level_id = p_level_id
        AND    pov.level_value = NVL(p_level_value, 0)
        AND    NVL(pov.level_value_application_id, 0) = NVL(p_level_value_appl_id, 0);
        
        RETURN v_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_value_at_level;
    
    /*
    --------------------------------------------------------------------------
    Procedure: log_change_history
    Purpose: Record profile value changes for auditing
    --------------------------------------------------------------------------
    */
    PROCEDURE log_change_history(
        p_profile_option_value_id IN NUMBER,
        p_profile_option_id       IN NUMBER,
        p_level_id                IN NUMBER,
        p_level_value             IN NUMBER,
        p_level_value_appl_id     IN NUMBER,
        p_old_value               IN VARCHAR2,
        p_new_value               IN VARCHAR2,
        p_change_type             IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO fnd_profile_option_values_h (
            history_id,
            profile_option_value_id,
            profile_option_id,
            level_id,
            level_value,
            level_value_application_id,
            old_profile_option_value,
            new_profile_option_value,
            change_type,
            changed_by,
            change_date
        ) VALUES (
            fnd_profile_option_values_h_s.NEXTVAL,
            p_profile_option_value_id,
            p_profile_option_id,
            p_level_id,
            p_level_value,
            p_level_value_appl_id,
            p_old_value,
            p_new_value,
            p_change_type,
            NVL(g_user_id, -1),
            SYSDATE
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
    END log_change_history;
    
    -- ========================================================================
    -- Public Procedure Implementations
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Procedure: INITIALIZE
    --------------------------------------------------------------------------
    */
    PROCEDURE initialize(
        p_user_id        IN NUMBER,
        p_resp_id        IN NUMBER DEFAULT NULL,
        p_resp_appl_id   IN NUMBER DEFAULT NULL,
        p_application_id IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        g_user_id := p_user_id;
        g_resp_id := p_resp_id;
        g_resp_appl_id := p_resp_appl_id;
        g_application_id := p_application_id;
        
        -- Get user name
        BEGIN
            SELECT user_name
            INTO   g_user_name
            FROM   fnd_user
            WHERE  user_id = p_user_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                g_user_name := NULL;
        END;
        
        -- Clear cache on re-initialization
        clear_cache;
        
    END initialize;
    
    /*
    --------------------------------------------------------------------------
    Procedure: GET
    --------------------------------------------------------------------------
    */
    PROCEDURE get(
        p_name  IN  VARCHAR2,
        p_value OUT VARCHAR2
    ) IS
        v_profile_option_id NUMBER;
        v_value             VARCHAR2(240);
    BEGIN
        -- First check cache
        IF g_profile_cache.EXISTS(UPPER(p_name)) THEN
            p_value := g_profile_cache(UPPER(p_name)).profile_value;
            RETURN;
        END IF;
        
        -- Get profile option ID
        v_profile_option_id := get_profile_option_id(p_name);
        
        IF v_profile_option_id IS NULL THEN
            p_value := NULL;
            RETURN;
        END IF;
        
        -- Search hierarchy: User -> Responsibility -> Application -> Site
        
        -- 1. User level
        IF g_user_id IS NOT NULL THEN
            v_value := get_value_at_level(v_profile_option_id, USER_LEVEL, g_user_id);
            IF v_value IS NOT NULL THEN
                p_value := v_value;
                RETURN;
            END IF;
        END IF;
        
        -- 2. Responsibility level
        IF g_resp_id IS NOT NULL THEN
            v_value := get_value_at_level(v_profile_option_id, RESP_LEVEL, g_resp_id, g_resp_appl_id);
            IF v_value IS NOT NULL THEN
                p_value := v_value;
                RETURN;
            END IF;
        END IF;
        
        -- 3. Application level
        IF g_application_id IS NOT NULL THEN
            v_value := get_value_at_level(v_profile_option_id, APPL_LEVEL, g_application_id);
            IF v_value IS NOT NULL THEN
                p_value := v_value;
                RETURN;
            END IF;
        END IF;
        
        -- 4. Site level
        v_value := get_value_at_level(v_profile_option_id, SITE_LEVEL, 0);
        p_value := v_value;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_value := NULL;
    END get;
    
    /*
    --------------------------------------------------------------------------
    Function: VALUE
    --------------------------------------------------------------------------
    */
    FUNCTION value(
        p_name IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_value VARCHAR2(240);
    BEGIN
        get(p_name, v_value);
        RETURN v_value;
    END value;
    
    /*
    --------------------------------------------------------------------------
    Function: VALUE_SPECIFIC
    --------------------------------------------------------------------------
    */
    FUNCTION value_specific(
        p_name           IN VARCHAR2,
        p_user_id        IN NUMBER   DEFAULT NULL,
        p_resp_id        IN NUMBER   DEFAULT NULL,
        p_resp_appl_id   IN NUMBER   DEFAULT NULL,
        p_application_id IN NUMBER   DEFAULT NULL
    ) RETURN VARCHAR2 IS
        v_profile_option_id NUMBER;
        v_value             VARCHAR2(240);
    BEGIN
        v_profile_option_id := get_profile_option_id(p_name);
        
        IF v_profile_option_id IS NULL THEN
            RETURN NULL;
        END IF;
        
        -- Search hierarchy with provided context
        
        -- User level
        IF p_user_id IS NOT NULL THEN
            v_value := get_value_at_level(v_profile_option_id, USER_LEVEL, p_user_id);
            IF v_value IS NOT NULL THEN
                RETURN v_value;
            END IF;
        END IF;
        
        -- Responsibility level
        IF p_resp_id IS NOT NULL THEN
            v_value := get_value_at_level(v_profile_option_id, RESP_LEVEL, p_resp_id, p_resp_appl_id);
            IF v_value IS NOT NULL THEN
                RETURN v_value;
            END IF;
        END IF;
        
        -- Application level
        IF p_application_id IS NOT NULL THEN
            v_value := get_value_at_level(v_profile_option_id, APPL_LEVEL, p_application_id);
            IF v_value IS NOT NULL THEN
                RETURN v_value;
            END IF;
        END IF;
        
        -- Site level
        v_value := get_value_at_level(v_profile_option_id, SITE_LEVEL, 0);
        RETURN v_value;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END value_specific;
    
    /*
    --------------------------------------------------------------------------
    Function: GET_SPECIFIC
    --------------------------------------------------------------------------
    */
    FUNCTION get_specific(
        p_name                IN VARCHAR2,
        p_level_id            IN NUMBER,
        p_level_value         IN NUMBER DEFAULT 0,
        p_level_value_appl_id IN NUMBER DEFAULT NULL
    ) RETURN VARCHAR2 IS
        v_profile_option_id NUMBER;
    BEGIN
        v_profile_option_id := get_profile_option_id(p_name);
        
        IF v_profile_option_id IS NULL THEN
            RETURN NULL;
        END IF;
        
        RETURN get_value_at_level(
            v_profile_option_id,
            p_level_id,
            p_level_value,
            p_level_value_appl_id
        );
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END get_specific;
    
    /*
    --------------------------------------------------------------------------
    Procedure: PUT
    --------------------------------------------------------------------------
    */
    PROCEDURE put(
        p_name  IN VARCHAR2,
        p_value IN VARCHAR2
    ) IS
        v_cache_rec profile_cache_rec;
    BEGIN
        v_cache_rec.profile_name := UPPER(p_name);
        v_cache_rec.profile_value := p_value;
        v_cache_rec.cached_time := SYSDATE;
        
        g_profile_cache(UPPER(p_name)) := v_cache_rec;
    END put;
    
    /*
    --------------------------------------------------------------------------
    Function: SAVE
    --------------------------------------------------------------------------
    */
    FUNCTION save(
        p_name                IN VARCHAR2,
        p_value               IN VARCHAR2,
        p_level_name          IN VARCHAR2,
        p_level_value         IN VARCHAR2 DEFAULT NULL,
        p_level_value_appl_id IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
        v_profile_option_id NUMBER;
        v_level_id          NUMBER;
        v_level_value       NUMBER;
        v_level_appl_id     NUMBER;
        v_existing_value_id NUMBER;
        v_old_value         VARCHAR2(240);
        v_enabled_flag      VARCHAR2(1);
        v_update_flag       VARCHAR2(1);
    BEGIN
        -- Get profile option ID
        v_profile_option_id := get_profile_option_id(p_name);
        
        IF v_profile_option_id IS NULL THEN
            RETURN FALSE;
        END IF;
        
        -- Get level ID
        v_level_id := get_level_id(p_level_name);
        
        IF v_level_id IS NULL THEN
            RETURN FALSE;
        END IF;
        
        -- Determine level value
        v_level_value := NVL(TO_NUMBER(p_level_value), 0);
        v_level_appl_id := NVL(TO_NUMBER(p_level_value_appl_id), 0);
        
        -- Check if level is enabled and update is allowed
        SELECT CASE UPPER(p_level_name)
                 WHEN 'SITE' THEN site_enabled_flag
                 WHEN 'APPLICATION' THEN app_enabled_flag
                 WHEN 'RESPONSIBILITY' THEN resp_enabled_flag
                 WHEN 'USER' THEN user_enabled_flag
               END,
               CASE UPPER(p_level_name)
                 WHEN 'SITE' THEN site_update_allowed_flag
                 WHEN 'APPLICATION' THEN app_update_allowed_flag
                 WHEN 'RESPONSIBILITY' THEN resp_update_allowed_flag
                 WHEN 'USER' THEN user_update_allowed_flag
               END
        INTO   v_enabled_flag, v_update_flag
        FROM   fnd_profile_options
        WHERE  profile_option_id = v_profile_option_id;
        
        IF v_enabled_flag = 'N' THEN
            RETURN FALSE;
        END IF;
        
        IF v_update_flag = 'N' THEN
            RETURN FALSE;
        END IF;
        
        -- Check if value already exists
        BEGIN
            SELECT profile_option_value_id, profile_option_value
            INTO   v_existing_value_id, v_old_value
            FROM   fnd_profile_option_values
            WHERE  profile_option_id = v_profile_option_id
            AND    level_id = v_level_id
            AND    level_value = v_level_value
            AND    NVL(level_value_application_id, 0) = v_level_appl_id;
            
            -- Update existing value
            UPDATE fnd_profile_option_values
            SET    profile_option_value = p_value,
                   last_updated_by = NVL(g_user_id, -1),
                   last_update_date = SYSDATE,
                   last_update_login = g_user_id
            WHERE  profile_option_value_id = v_existing_value_id;
            
            -- Log history
            log_change_history(
                v_existing_value_id,
                v_profile_option_id,
                v_level_id,
                v_level_value,
                v_level_appl_id,
                v_old_value,
                p_value,
                'UPDATE'
            );
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Insert new value
                v_existing_value_id := fnd_profile_option_values_s.NEXTVAL;
                
                INSERT INTO fnd_profile_option_values (
                    profile_option_value_id,
                    profile_option_id,
                    level_id,
                    level_value,
                    level_value_application_id,
                    profile_option_value,
                    created_by,
                    creation_date,
                    last_updated_by,
                    last_update_date,
                    last_update_login
                ) VALUES (
                    v_existing_value_id,
                    v_profile_option_id,
                    v_level_id,
                    v_level_value,
                    v_level_appl_id,
                    p_value,
                    NVL(g_user_id, -1),
                    SYSDATE,
                    NVL(g_user_id, -1),
                    SYSDATE,
                    g_user_id
                );
                
                -- Log history
                log_change_history(
                    v_existing_value_id,
                    v_profile_option_id,
                    v_level_id,
                    v_level_value,
                    v_level_appl_id,
                    NULL,
                    p_value,
                    'INSERT'
                );
        END;
        
        -- Update cache
        put(p_name, p_value);
        
        RETURN TRUE;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END save;
    
    /*
    --------------------------------------------------------------------------
    Procedure: SAVE (Procedure version)
    --------------------------------------------------------------------------
    */
    PROCEDURE save(
        p_name                IN VARCHAR2,
        p_value               IN VARCHAR2,
        p_level_name          IN VARCHAR2,
        p_level_value         IN VARCHAR2 DEFAULT NULL,
        p_level_value_appl_id IN VARCHAR2 DEFAULT NULL,
        x_return_status       OUT VARCHAR2,
        x_return_message      OUT VARCHAR2
    ) IS
        v_result BOOLEAN;
    BEGIN
        v_result := save(
            p_name,
            p_value,
            p_level_name,
            p_level_value,
            p_level_value_appl_id
        );
        
        IF v_result THEN
            x_return_status := 'S';
            x_return_message := 'Profile saved successfully';
        ELSE
            x_return_status := 'E';
            x_return_message := 'Failed to save profile';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            x_return_status := 'E';
            x_return_message := 'Error: ' || SQLERRM;
    END save;
    
    /*
    --------------------------------------------------------------------------
    Function: DELETE_VALUE
    --------------------------------------------------------------------------
    */
    FUNCTION delete_value(
        p_name                IN VARCHAR2,
        p_level_name          IN VARCHAR2,
        p_level_value         IN VARCHAR2 DEFAULT NULL,
        p_level_value_appl_id IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
        v_profile_option_id NUMBER;
        v_level_id          NUMBER;
        v_level_value       NUMBER;
        v_level_appl_id     NUMBER;
        v_value_id          NUMBER;
        v_old_value         VARCHAR2(240);
    BEGIN
        v_profile_option_id := get_profile_option_id(p_name);
        v_level_id := get_level_id(p_level_name);
        
        IF v_profile_option_id IS NULL OR v_level_id IS NULL THEN
            RETURN FALSE;
        END IF;
        
        v_level_value := NVL(TO_NUMBER(p_level_value), 0);
        v_level_appl_id := NVL(TO_NUMBER(p_level_value_appl_id), 0);
        
        -- Get existing value for history
        BEGIN
            SELECT profile_option_value_id, profile_option_value
            INTO   v_value_id, v_old_value
            FROM   fnd_profile_option_values
            WHERE  profile_option_id = v_profile_option_id
            AND    level_id = v_level_id
            AND    level_value = v_level_value
            AND    NVL(level_value_application_id, 0) = v_level_appl_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN FALSE;
        END;
        
        -- Delete the value
        DELETE FROM fnd_profile_option_values
        WHERE  profile_option_value_id = v_value_id;
        
        -- Log history
        log_change_history(
            v_value_id,
            v_profile_option_id,
            v_level_id,
            v_level_value,
            v_level_appl_id,
            v_old_value,
            NULL,
            'DELETE'
        );
        
        -- Remove from cache
        IF g_profile_cache.EXISTS(UPPER(p_name)) THEN
            g_profile_cache.DELETE(UPPER(p_name));
        END IF;
        
        RETURN TRUE;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END delete_value;
    
    /*
    --------------------------------------------------------------------------
    Function: DEFINED
    --------------------------------------------------------------------------
    */
    FUNCTION defined(
        p_name IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_value VARCHAR2(240);
    BEGIN
        get(p_name, v_value);
        RETURN (v_value IS NOT NULL);
    END defined;
    
    /*
    --------------------------------------------------------------------------
    Procedure: GET_ALL_VALUES
    --------------------------------------------------------------------------
    */
    PROCEDURE get_all_values(
        p_name   IN  VARCHAR2,
        x_values OUT profile_value_tbl,
        x_count  OUT NUMBER
    ) IS
        v_profile_option_id NUMBER;
        v_index             PLS_INTEGER := 0;
        
        CURSOR c_values IS
            SELECT pl.level_name,
                   pov.level_id,
                   pov.level_value,
                   pov.level_value_application_id,
                   pov.profile_option_value,
                   CASE pl.level_name
                       WHEN 'SITE' THEN 'Site'
                       WHEN 'APPLICATION' THEN (SELECT application_name FROM fnd_application WHERE application_id = pov.level_value)
                       WHEN 'RESPONSIBILITY' THEN (SELECT responsibility_name FROM fnd_responsibility WHERE responsibility_id = pov.level_value)
                       WHEN 'USER' THEN (SELECT user_name FROM fnd_user WHERE user_id = pov.level_value)
                   END AS level_display_value
            FROM   fnd_profile_option_values pov
            JOIN   fnd_profile_levels pl ON pov.level_id = pl.level_id
            WHERE  pov.profile_option_id = v_profile_option_id
            ORDER BY pl.hierarchy_order DESC;
    BEGIN
        v_profile_option_id := get_profile_option_id(p_name);
        
        IF v_profile_option_id IS NULL THEN
            x_count := 0;
            RETURN;
        END IF;
        
        FOR rec IN c_values LOOP
            v_index := v_index + 1;
            x_values(v_index).level_name := rec.level_name;
            x_values(v_index).level_id := rec.level_id;
            x_values(v_index).level_value := rec.level_value;
            x_values(v_index).level_value_appl_id := rec.level_value_application_id;
            x_values(v_index).profile_option_value := rec.profile_option_value;
            x_values(v_index).level_display_value := rec.level_display_value;
        END LOOP;
        
        x_count := v_index;
        
    EXCEPTION
        WHEN OTHERS THEN
            x_count := 0;
    END get_all_values;
    
    /*
    --------------------------------------------------------------------------
    Procedure: CLEAR_CACHE
    --------------------------------------------------------------------------
    */
    PROCEDURE clear_cache IS
    BEGIN
        g_profile_cache.DELETE;
    END clear_cache;
    
    /*
    --------------------------------------------------------------------------
    Function: GET_CACHE_VALUE
    --------------------------------------------------------------------------
    */
    FUNCTION get_cache_value(
        p_name IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        IF g_profile_cache.EXISTS(UPPER(p_name)) THEN
            RETURN g_profile_cache(UPPER(p_name)).profile_value;
        ELSE
            RETURN NULL;
        END IF;
    END get_cache_value;
    
    /*
    --------------------------------------------------------------------------
    Function: IS_ENABLED
    --------------------------------------------------------------------------
    */
    FUNCTION is_enabled(
        p_name       IN VARCHAR2,
        p_level_name IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_enabled VARCHAR2(1);
    BEGIN
        SELECT CASE UPPER(p_level_name)
                 WHEN 'SITE' THEN site_enabled_flag
                 WHEN 'APPLICATION' THEN app_enabled_flag
                 WHEN 'RESPONSIBILITY' THEN resp_enabled_flag
                 WHEN 'USER' THEN user_enabled_flag
               END
        INTO   v_enabled
        FROM   fnd_profile_options
        WHERE  profile_option_name = UPPER(p_name)
        AND    SYSDATE BETWEEN start_date_active AND NVL(end_date_active, SYSDATE + 1);
        
        RETURN (v_enabled = 'Y');
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END is_enabled;
    
    /*
    --------------------------------------------------------------------------
    Function: IS_UPDATE_ALLOWED
    --------------------------------------------------------------------------
    */
    FUNCTION is_update_allowed(
        p_name       IN VARCHAR2,
        p_level_name IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_allowed VARCHAR2(1);
    BEGIN
        SELECT CASE UPPER(p_level_name)
                 WHEN 'SITE' THEN site_update_allowed_flag
                 WHEN 'APPLICATION' THEN app_update_allowed_flag
                 WHEN 'RESPONSIBILITY' THEN resp_update_allowed_flag
                 WHEN 'USER' THEN user_update_allowed_flag
               END
        INTO   v_allowed
        FROM   fnd_profile_options
        WHERE  profile_option_name = UPPER(p_name)
        AND    SYSDATE BETWEEN start_date_active AND NVL(end_date_active, SYSDATE + 1);
        
        RETURN (v_allowed = 'Y');
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END is_update_allowed;

END fnd_profile;
/

SHOW ERRORS PACKAGE BODY fnd_profile;

/*
================================================================================
  End of Package Body
================================================================================
*/
