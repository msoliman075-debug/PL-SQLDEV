-- ============================================================================
-- FND_PROFILE Package Body
-- Description: Implementation of profile management package
-- ============================================================================

CREATE OR REPLACE PACKAGE BODY fnd_profile AS
    
    -- ========================================================================
    -- Private Types and Variables
    -- ========================================================================
    
    -- Type for profile cache
    TYPE profile_cache_rec IS RECORD (
        profile_name  VARCHAR2(240),
        profile_value VARCHAR2(2000)
    );
    
    TYPE profile_cache_tab IS TABLE OF profile_cache_rec
        INDEX BY VARCHAR2(240);
    
    -- Package-level cache for session profiles
    g_profile_cache profile_cache_tab;
    g_cache_initialized BOOLEAN := FALSE;
    
    -- ========================================================================
    -- Private Function: get_profile_option_id
    -- Description: Internal function to get profile option ID
    -- ========================================================================
    FUNCTION get_profile_option_id(
        p_profile_name IN VARCHAR2
    ) RETURN NUMBER IS
        l_profile_id NUMBER;
    BEGIN
        SELECT profile_option_id
        INTO   l_profile_id
        FROM   fnd_profile_options
        WHERE  profile_option_name = UPPER(p_profile_name)
        AND    enabled_flag = 'Y'
        AND    SYSDATE BETWEEN start_date_active 
                           AND NVL(end_date_active, SYSDATE + 1);
        
        RETURN l_profile_id;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
        WHEN OTHERS THEN
            RAISE;
    END get_profile_option_id;
    
    -- ========================================================================
    -- Private Function: validate_level
    -- Description: Validates that level_id is valid
    -- ========================================================================
    FUNCTION validate_level(
        p_level_id IN NUMBER
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN p_level_id IN (
            g_level_site,
            g_level_application,
            g_level_responsibility,
            g_level_user,
            g_level_server,
            g_level_org
        );
    END validate_level;
    
    -- ========================================================================
    -- Public Function: VALUE
    -- Description: Retrieves profile option value using hierarchy
    -- Execution Impact: Single query with CONNECT BY or hierarchical logic
    -- ========================================================================
    FUNCTION value(
        p_profile_name      IN VARCHAR2,
        p_user_id           IN NUMBER DEFAULT NULL,
        p_responsibility_id IN NUMBER DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_org_id            IN NUMBER DEFAULT NULL,
        p_server_id         IN NUMBER DEFAULT NULL
    ) RETURN VARCHAR2 IS
        l_profile_id         NUMBER;
        l_profile_value      VARCHAR2(2000);
        l_current_date       DATE := SYSDATE;
    BEGIN
        -- Check session cache first
        IF g_profile_cache.EXISTS(UPPER(p_profile_name)) THEN
            RETURN g_profile_cache(UPPER(p_profile_name)).profile_value;
        END IF;
        
        -- Get profile option ID
        l_profile_id := get_profile_option_id(p_profile_name);
        
        IF l_profile_id IS NULL THEN
            RETURN NULL;
        END IF;
        
        -- Retrieve value using hierarchy (User > Responsibility > Application > Site)
        -- Priority: User level (highest) -> Responsibility -> Application -> Org -> Server -> Site (lowest)
        
        BEGIN
            SELECT profile_option_value
            INTO   l_profile_value
            FROM   (
                SELECT pov.profile_option_value,
                       CASE pov.level_id
                           WHEN g_level_user THEN 1
                           WHEN g_level_responsibility THEN 2
                           WHEN g_level_application THEN 3
                           WHEN g_level_org THEN 4
                           WHEN g_level_server THEN 5
                           WHEN g_level_site THEN 6
                       END AS priority
                FROM   fnd_profile_option_values pov
                WHERE  pov.profile_option_id = l_profile_id
                AND    pov.enabled_flag = 'Y'
                AND    l_current_date BETWEEN pov.start_date_active 
                                          AND NVL(pov.end_date_active, l_current_date + 1)
                AND    (
                    -- User level
                    (pov.level_id = g_level_user AND pov.level_value = p_user_id)
                    OR
                    -- Responsibility level
                    (pov.level_id = g_level_responsibility 
                     AND pov.level_value = p_responsibility_id
                     AND NVL(pov.level_value_application_id, p_application_id) = p_application_id)
                    OR
                    -- Application level
                    (pov.level_id = g_level_application AND pov.level_value = p_application_id)
                    OR
                    -- Organization level
                    (pov.level_id = g_level_org AND pov.level_value = p_org_id)
                    OR
                    -- Server level
                    (pov.level_id = g_level_server AND pov.level_value = p_server_id)
                    OR
                    -- Site level (always applies)
                    (pov.level_id = g_level_site)
                )
                ORDER BY priority ASC
            )
            WHERE ROWNUM = 1;
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_profile_value := NULL;
        END;
        
        RETURN l_profile_value;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Log error but return NULL to maintain compatibility
            RETURN NULL;
    END value;
    
    -- ========================================================================
    -- Public Function: VALUE_SPECIFIC
    -- Description: Retrieves profile value at specific level
    -- Execution Impact: Direct index lookup on composite key
    -- ========================================================================
    FUNCTION value_specific(
        p_profile_name       IN VARCHAR2,
        p_level_id           IN NUMBER,
        p_level_value        IN NUMBER DEFAULT NULL,
        p_level_value_app_id IN NUMBER DEFAULT NULL
    ) RETURN VARCHAR2 IS
        l_profile_id    NUMBER;
        l_profile_value VARCHAR2(2000);
        l_current_date  DATE := SYSDATE;
    BEGIN
        -- Validate level
        IF NOT validate_level(p_level_id) THEN
            RAISE_APPLICATION_ERROR(-20002, 
                'Invalid level_id: ' || p_level_id);
        END IF;
        
        -- Get profile option ID
        l_profile_id := get_profile_option_id(p_profile_name);
        
        IF l_profile_id IS NULL THEN
            RETURN NULL;
        END IF;
        
        -- Retrieve value at specific level
        BEGIN
            SELECT profile_option_value
            INTO   l_profile_value
            FROM   fnd_profile_option_values
            WHERE  profile_option_id = l_profile_id
            AND    level_id = p_level_id
            AND    NVL(level_value, -1) = NVL(p_level_value, -1)
            AND    NVL(level_value_application_id, -1) = NVL(p_level_value_app_id, -1)
            AND    enabled_flag = 'Y'
            AND    l_current_date BETWEEN start_date_active 
                                      AND NVL(end_date_active, l_current_date + 1);
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_profile_value := NULL;
        END;
        
        RETURN l_profile_value;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END value_specific;
    
    -- ========================================================================
    -- Public Function: DEFINED
    -- Description: Checks if profile option is defined
    -- Execution Impact: Single index lookup
    -- ========================================================================
    FUNCTION defined(
        p_profile_name IN VARCHAR2
    ) RETURN BOOLEAN IS
        l_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO   l_count
        FROM   fnd_profile_options
        WHERE  profile_option_name = UPPER(p_profile_name)
        AND    enabled_flag = 'Y'
        AND    SYSDATE BETWEEN start_date_active 
                           AND NVL(end_date_active, SYSDATE + 1);
        
        RETURN (l_count > 0);
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END defined;
    
    -- ========================================================================
    -- Public Procedure: GET
    -- Description: Procedure wrapper for VALUE function
    -- Execution Impact: Calls VALUE function
    -- ========================================================================
    PROCEDURE get(
        p_profile_name      IN  VARCHAR2,
        p_value             OUT VARCHAR2,
        p_user_id           IN  NUMBER DEFAULT NULL,
        p_responsibility_id IN  NUMBER DEFAULT NULL,
        p_application_id    IN  NUMBER DEFAULT NULL
    ) IS
    BEGIN
        p_value := value(
            p_profile_name      => p_profile_name,
            p_user_id           => p_user_id,
            p_responsibility_id => p_responsibility_id,
            p_application_id    => p_application_id
        );
    END get;
    
    -- ========================================================================
    -- Public Procedure: PUT
    -- Description: Sets profile in session cache (in-memory)
    -- Execution Impact: Memory operation only, no DML
    -- ========================================================================
    PROCEDURE put(
        p_profile_name IN VARCHAR2,
        p_value        IN VARCHAR2
    ) IS
        l_profile_rec profile_cache_rec;
    BEGIN
        l_profile_rec.profile_name := UPPER(p_profile_name);
        l_profile_rec.profile_value := p_value;
        
        g_profile_cache(UPPER(p_profile_name)) := l_profile_rec;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END put;
    
    -- ========================================================================
    -- Public Procedure: SAVE
    -- Description: Saves profile value to database
    -- Execution Impact: MERGE statement (INSERT or UPDATE)
    -- ========================================================================
    PROCEDURE save(
        p_profile_name       IN VARCHAR2,
        p_value              IN VARCHAR2,
        p_level_id           IN NUMBER,
        p_level_value        IN NUMBER DEFAULT NULL,
        p_level_value_app_id IN NUMBER DEFAULT NULL,
        p_user_id            IN NUMBER DEFAULT 0
    ) IS
        l_profile_id     NUMBER;
        l_read_only_flag VARCHAR2(1);
        l_existing_count NUMBER;
    BEGIN
        -- Validate level
        IF NOT validate_level(p_level_id) THEN
            RAISE_APPLICATION_ERROR(-20002, 
                'Invalid level_id: ' || p_level_id);
        END IF;
        
        -- Get profile option ID and check if read-only
        BEGIN
            SELECT profile_option_id, read_only_flag
            INTO   l_profile_id, l_read_only_flag
            FROM   fnd_profile_options
            WHERE  profile_option_name = UPPER(p_profile_name)
            AND    enabled_flag = 'Y'
            AND    SYSDATE BETWEEN start_date_active 
                               AND NVL(end_date_active, SYSDATE + 1);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 
                    'Profile option not found or not enabled: ' || p_profile_name);
        END;
        
        -- Check if read-only
        IF l_read_only_flag = 'Y' THEN
            RAISE_APPLICATION_ERROR(-20004, 
                'Profile option is read-only: ' || p_profile_name);
        END IF;
        
        -- Use MERGE to insert or update
        MERGE INTO fnd_profile_option_values tgt
        USING (
            SELECT l_profile_id AS profile_option_id,
                   p_level_id AS level_id,
                   p_level_value AS level_value,
                   p_level_value_app_id AS level_value_application_id,
                   NULL AS application_id
            FROM   dual
        ) src
        ON (
            tgt.profile_option_id = src.profile_option_id
            AND tgt.level_id = src.level_id
            AND NVL(tgt.level_value, -1) = NVL(src.level_value, -1)
            AND NVL(tgt.level_value_application_id, -1) = NVL(src.level_value_application_id, -1)
            AND NVL(tgt.application_id, -1) = NVL(src.application_id, -1)
        )
        WHEN MATCHED THEN
            UPDATE SET
                tgt.profile_option_value = p_value,
                tgt.last_update_date = SYSDATE,
                tgt.last_updated_by = p_user_id,
                tgt.last_update_login = p_user_id
        WHEN NOT MATCHED THEN
            INSERT (
                profile_option_value_id,
                profile_option_id,
                application_id,
                level_id,
                level_value,
                level_value_application_id,
                profile_option_value,
                enabled_flag,
                start_date_active,
                creation_date,
                created_by,
                last_update_date,
                last_updated_by,
                last_update_login
            ) VALUES (
                fnd_profile_option_values_s.NEXTVAL,
                src.profile_option_id,
                src.application_id,
                src.level_id,
                src.level_value,
                src.level_value_application_id,
                p_value,
                'Y',
                SYSDATE,
                SYSDATE,
                p_user_id,
                SYSDATE,
                p_user_id,
                p_user_id
            );
        
        COMMIT;
        
        -- Update session cache if exists
        IF g_profile_cache.EXISTS(UPPER(p_profile_name)) THEN
            put(p_profile_name, p_value);
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END save;
    
    -- ========================================================================
    -- Public Procedure: INITIALIZE
    -- Description: Loads profile values into session cache
    -- Execution Impact: Bulk query to populate cache
    -- ========================================================================
    PROCEDURE initialize(
        p_user_id           IN NUMBER,
        p_responsibility_id IN NUMBER DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL
    ) IS
        CURSOR c_profiles IS
            SELECT po.profile_option_name,
                   pov.profile_option_value,
                   CASE pov.level_id
                       WHEN g_level_user THEN 1
                       WHEN g_level_responsibility THEN 2
                       WHEN g_level_application THEN 3
                       WHEN g_level_site THEN 4
                   END AS priority
            FROM   fnd_profile_options po,
                   fnd_profile_option_values pov
            WHERE  po.profile_option_id = pov.profile_option_id
            AND    po.enabled_flag = 'Y'
            AND    pov.enabled_flag = 'Y'
            AND    SYSDATE BETWEEN po.start_date_active 
                               AND NVL(po.end_date_active, SYSDATE + 1)
            AND    SYSDATE BETWEEN pov.start_date_active 
                               AND NVL(pov.end_date_active, SYSDATE + 1)
            AND    (
                (pov.level_id = g_level_user AND pov.level_value = p_user_id)
                OR
                (pov.level_id = g_level_responsibility 
                 AND pov.level_value = p_responsibility_id)
                OR
                (pov.level_id = g_level_application 
                 AND pov.level_value = p_application_id)
                OR
                (pov.level_id = g_level_site)
            )
            ORDER BY po.profile_option_name, priority;
        
        l_current_profile VARCHAR2(240) := NULL;
        l_profile_rec     profile_cache_rec;
    BEGIN
        -- Clear existing cache
        g_profile_cache.DELETE;
        
        -- Load profiles into cache (only highest priority value per profile)
        FOR rec IN c_profiles LOOP
            IF l_current_profile IS NULL OR l_current_profile != rec.profile_option_name THEN
                l_profile_rec.profile_name := rec.profile_option_name;
                l_profile_rec.profile_value := rec.profile_option_value;
                g_profile_cache(rec.profile_option_name) := l_profile_rec;
                l_current_profile := rec.profile_option_name;
            END IF;
        END LOOP;
        
        g_cache_initialized := TRUE;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END initialize;
    
    -- ========================================================================
    -- Public Procedure: GET_ALL
    -- Description: Returns all profile values for context
    -- Execution Impact: Hierarchical query with cursor return
    -- ========================================================================
    PROCEDURE get_all(
        p_user_id           IN  NUMBER,
        p_responsibility_id IN  NUMBER DEFAULT NULL,
        p_application_id    IN  NUMBER DEFAULT NULL,
        p_cursor            OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT po.profile_option_name,
                   po.user_profile_option_name,
                   po.description,
                   pov.profile_option_value,
                   CASE pov.level_id
                       WHEN g_level_site THEN 'Site'
                       WHEN g_level_application THEN 'Application'
                       WHEN g_level_responsibility THEN 'Responsibility'
                       WHEN g_level_user THEN 'User'
                       WHEN g_level_server THEN 'Server'
                       WHEN g_level_org THEN 'Organization'
                   END AS level_name,
                   pov.level_value
            FROM   (
                SELECT po.profile_option_name,
                       po.user_profile_option_name,
                       po.description,
                       pov.profile_option_value,
                       pov.level_id,
                       pov.level_value,
                       ROW_NUMBER() OVER (
                           PARTITION BY po.profile_option_id
                           ORDER BY CASE pov.level_id
                                       WHEN g_level_user THEN 1
                                       WHEN g_level_responsibility THEN 2
                                       WHEN g_level_application THEN 3
                                       WHEN g_level_site THEN 4
                                   END
                       ) AS rn
                FROM   fnd_profile_options po,
                       fnd_profile_option_values pov
                WHERE  po.profile_option_id = pov.profile_option_id
                AND    po.enabled_flag = 'Y'
                AND    pov.enabled_flag = 'Y'
                AND    po.user_visible_flag = 'Y'
                AND    SYSDATE BETWEEN po.start_date_active 
                                   AND NVL(po.end_date_active, SYSDATE + 1)
                AND    SYSDATE BETWEEN pov.start_date_active 
                                   AND NVL(pov.end_date_active, SYSDATE + 1)
                AND    (
                    (pov.level_id = g_level_user AND pov.level_value = p_user_id)
                    OR
                    (pov.level_id = g_level_responsibility 
                     AND pov.level_value = p_responsibility_id)
                    OR
                    (pov.level_id = g_level_application 
                     AND pov.level_value = p_application_id)
                    OR
                    (pov.level_id = g_level_site)
                )
            ) pov
            WHERE pov.rn = 1
            ORDER BY pov.profile_option_name;
            
    EXCEPTION
        WHEN OTHERS THEN
            IF p_cursor%ISOPEN THEN
                CLOSE p_cursor;
            END IF;
            RAISE;
    END get_all;
    
END fnd_profile;
/
