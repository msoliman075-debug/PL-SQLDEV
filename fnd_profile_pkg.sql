CREATE OR REPLACE PACKAGE fnd_profile_pkg AS
    -- Constants for Profile Levels
    SITE_LEVEL CONSTANT NUMBER := 10001;
    APP_LEVEL  CONSTANT NUMBER := 10002;
    RESP_LEVEL CONSTANT NUMBER := 10003;
    USER_LEVEL CONSTANT NUMBER := 10004;

    -- -------------------------------------------------------------------------
    -- Function: VALUE
    -- Description: Retrieves the value of a profile option based on the current context.
    --              For this standalone version, context must be passed or mocked.
    --              Since we don't have FND_GLOBAL, we will accept context IDs as optional params,
    --              defaulting to NULL (which acts like Site level usually if others are missing).
    -- -------------------------------------------------------------------------
    FUNCTION value(
        p_profile_name IN VARCHAR2,
        p_user_id      IN NUMBER DEFAULT NULL,
        p_resp_id      IN NUMBER DEFAULT NULL,
        p_app_id       IN NUMBER DEFAULT NULL
    ) RETURN VARCHAR2;

    -- -------------------------------------------------------------------------
    -- Procedure: SAVE
    -- Description: Sets the value of a profile option at a specific level.
    -- -------------------------------------------------------------------------
    PROCEDURE save(
        p_profile_name IN VARCHAR2,
        p_value        IN VARCHAR2,
        p_level_id     IN NUMBER,
        p_level_value  IN NUMBER,
        p_level_value_app_id IN NUMBER DEFAULT NULL
    );
    
    -- -------------------------------------------------------------------------
    -- Procedure: DELETE_VALUE
    -- Description: Removes a specific profile option value.
    -- -------------------------------------------------------------------------
    PROCEDURE delete_value(
        p_profile_name IN VARCHAR2,
        p_level_id     IN NUMBER,
        p_level_value  IN NUMBER,
        p_level_value_app_id IN NUMBER DEFAULT NULL
    );

END fnd_profile_pkg;
/

CREATE OR REPLACE PACKAGE BODY fnd_profile_pkg AS

    -- -------------------------------------------------------------------------
    -- Private Function: get_id_by_name
    -- -------------------------------------------------------------------------
    FUNCTION get_id_by_name(p_profile_name IN VARCHAR2) RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT profile_option_id
        INTO v_id
        FROM fnd_profile_options
        WHERE profile_option_name = p_profile_name;
        
        RETURN v_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_id_by_name;

    -- -------------------------------------------------------------------------
    -- Function: VALUE
    -- -------------------------------------------------------------------------
    FUNCTION value(
        p_profile_name IN VARCHAR2,
        p_user_id      IN NUMBER DEFAULT NULL,
        p_resp_id      IN NUMBER DEFAULT NULL,
        p_app_id       IN NUMBER DEFAULT NULL
    ) RETURN VARCHAR2 IS
        v_profile_id NUMBER;
        v_value      VARCHAR2(240);
    BEGIN
        v_profile_id := get_id_by_name(p_profile_name);
        
        IF v_profile_id IS NULL THEN
            RETURN NULL;
        END IF;

        -- Hierarchy Check:
        -- 1. User
        -- 2. Responsibility
        -- 3. Application
        -- 4. Site

        -- 1. Check User Level
        IF p_user_id IS NOT NULL THEN
            BEGIN
                SELECT profile_option_value
                INTO v_value
                FROM fnd_profile_option_values
                WHERE profile_option_id = v_profile_id
                  AND level_id = USER_LEVEL
                  AND level_value = p_user_id;
                
                RETURN v_value;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL; -- Continue to next level
            END;
        END IF;

        -- 2. Check Responsibility Level
        IF p_resp_id IS NOT NULL THEN
            BEGIN
                SELECT profile_option_value
                INTO v_value
                FROM fnd_profile_option_values
                WHERE profile_option_id = v_profile_id
                  AND level_id = RESP_LEVEL
                  AND level_value = p_resp_id
                  AND (level_value_application_id IS NULL OR level_value_application_id = p_app_id); 
                  -- Note: EBS usually links Resp to App, but strictly profile table stores app_id for Resp level sometimes.
                  -- Simplified here: assuming unique Resp ID or passed App ID helps.
                
                RETURN v_value;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL; -- Continue to next level
            END;
        END IF;

        -- 3. Check Application Level
        IF p_app_id IS NOT NULL THEN
            BEGIN
                SELECT profile_option_value
                INTO v_value
                FROM fnd_profile_option_values
                WHERE profile_option_id = v_profile_id
                  AND level_id = APP_LEVEL
                  AND level_value = p_app_id;
                
                RETURN v_value;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL; -- Continue to next level
            END;
        END IF;

        -- 4. Check Site Level (Level Value is usually 0)
        BEGIN
            SELECT profile_option_value
            INTO v_value
            FROM fnd_profile_option_values
            WHERE profile_option_id = v_profile_id
              AND level_id = SITE_LEVEL
              AND level_value = 0;
            
            RETURN v_value;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN NULL; -- No value found at any level
        END;

    END value;

    -- -------------------------------------------------------------------------
    -- Procedure: SAVE
    -- -------------------------------------------------------------------------
    PROCEDURE save(
        p_profile_name IN VARCHAR2,
        p_value        IN VARCHAR2,
        p_level_id     IN NUMBER,
        p_level_value  IN NUMBER,
        p_level_value_app_id IN NUMBER DEFAULT NULL
    ) IS
        v_profile_id NUMBER;
    BEGIN
        v_profile_id := get_id_by_name(p_profile_name);
        
        IF v_profile_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Profile option ' || p_profile_name || ' does not exist.');
        END IF;

        MERGE INTO fnd_profile_option_values target
        USING (SELECT v_profile_id AS pid, 
                      p_level_id AS lid, 
                      p_level_value AS lval, 
                      p_level_value_app_id AS lapp,
                      p_value AS val 
               FROM dual) source
        ON (target.profile_option_id = source.pid 
            AND target.level_id = source.lid 
            AND target.level_value = source.lval
            AND (target.level_value_application_id IS NULL OR target.level_value_application_id = source.lapp))
        WHEN MATCHED THEN
            UPDATE SET target.profile_option_value = source.val,
                       target.last_update_date = SYSDATE,
                       target.last_updated_by = 0 -- System
        WHEN NOT MATCHED THEN
            INSERT (profile_option_value_id, profile_option_id, level_id, level_value, level_value_application_id, profile_option_value, creation_date, created_by, last_update_date, last_updated_by)
            VALUES (fnd_profile_option_values_s.NEXTVAL, source.pid, source.lid, source.lval, source.lapp, source.val, SYSDATE, 0, SYSDATE, 0);
            
        COMMIT;
    END save;

    -- -------------------------------------------------------------------------
    -- Procedure: DELETE_VALUE
    -- -------------------------------------------------------------------------
    PROCEDURE delete_value(
        p_profile_name IN VARCHAR2,
        p_level_id     IN NUMBER,
        p_level_value  IN NUMBER,
        p_level_value_app_id IN NUMBER DEFAULT NULL
    ) IS
        v_profile_id NUMBER;
    BEGIN
        v_profile_id := get_id_by_name(p_profile_name);
        
        IF v_profile_id IS NULL THEN
             RETURN; -- Nothing to delete
        END IF;

        DELETE FROM fnd_profile_option_values
        WHERE profile_option_id = v_profile_id
          AND level_id = p_level_id
          AND level_value = p_level_value
          AND (level_value_application_id IS NULL OR level_value_application_id = p_level_value_app_id);
          
        COMMIT;
    END delete_value;

END fnd_profile_pkg;
/
