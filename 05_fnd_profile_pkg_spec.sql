-- ============================================================================
-- FND_PROFILE Package Specification
-- Description: Profile management package similar to Oracle EBS FND_PROFILE
-- ============================================================================

CREATE OR REPLACE PACKAGE fnd_profile AS
    
    -- ========================================================================
    -- Constants for Profile Hierarchy Levels
    -- ========================================================================
    g_level_site            CONSTANT NUMBER := 10001;  -- Site level
    g_level_application     CONSTANT NUMBER := 10002;  -- Application level
    g_level_responsibility  CONSTANT NUMBER := 10003;  -- Responsibility level
    g_level_user            CONSTANT NUMBER := 10004;  -- User level
    g_level_server          CONSTANT NUMBER := 10005;  -- Server level
    g_level_org             CONSTANT NUMBER := 10006;  -- Organization level
    
    -- ========================================================================
    -- Exception Definitions
    -- ========================================================================
    e_profile_not_found     EXCEPTION;
    e_invalid_level         EXCEPTION;
    e_invalid_value         EXCEPTION;
    e_read_only_profile     EXCEPTION;
    
    PRAGMA EXCEPTION_INIT(e_profile_not_found, -20001);
    PRAGMA EXCEPTION_INIT(e_invalid_level, -20002);
    PRAGMA EXCEPTION_INIT(e_invalid_value, -20003);
    PRAGMA EXCEPTION_INIT(e_read_only_profile, -20004);
    
    -- ========================================================================
    -- Public Function: VALUE
    -- Description: Retrieves profile option value for current context
    -- Parameters:
    --   p_profile_name    : Internal name of the profile option
    --   p_user_id         : User ID (optional, uses current user if NULL)
    --   p_responsibility_id: Responsibility ID (optional)
    --   p_application_id  : Application ID (optional)
    --   p_org_id          : Organization ID (optional)
    --   p_server_id       : Server ID (optional)
    -- Returns: Profile option value (VARCHAR2) or NULL if not found
    -- Execution Impact: Single hierarchical query with index usage
    -- ========================================================================
    FUNCTION value(
        p_profile_name      IN VARCHAR2,
        p_user_id           IN NUMBER DEFAULT NULL,
        p_responsibility_id IN NUMBER DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL,
        p_org_id            IN NUMBER DEFAULT NULL,
        p_server_id         IN NUMBER DEFAULT NULL
    ) RETURN VARCHAR2;
    
    -- ========================================================================
    -- Public Function: VALUE_SPECIFIC
    -- Description: Retrieves profile value at a specific level
    -- Parameters:
    --   p_profile_name : Internal name of the profile option
    --   p_level_id     : Level ID (use g_level_* constants)
    --   p_level_value  : ID at that level
    --   p_level_value_app_id: Application ID for responsibility level
    -- Returns: Profile option value (VARCHAR2) or NULL if not found
    -- Execution Impact: Single direct lookup with composite index
    -- ========================================================================
    FUNCTION value_specific(
        p_profile_name       IN VARCHAR2,
        p_level_id           IN NUMBER,
        p_level_value        IN NUMBER DEFAULT NULL,
        p_level_value_app_id IN NUMBER DEFAULT NULL
    ) RETURN VARCHAR2;
    
    -- ========================================================================
    -- Public Function: DEFINED
    -- Description: Checks if a profile option is defined
    -- Parameters:
    --   p_profile_name : Internal name of the profile option
    -- Returns: TRUE if profile exists and is enabled, FALSE otherwise
    -- Execution Impact: Single index lookup on profile_option_name
    -- ========================================================================
    FUNCTION defined(
        p_profile_name IN VARCHAR2
    ) RETURN BOOLEAN;
    
    -- ========================================================================
    -- Public Procedure: GET
    -- Description: Retrieves profile option value (procedure version)
    -- Parameters:
    --   p_profile_name : Internal name of the profile option
    --   p_value        : OUT parameter for the profile value
    --   p_user_id      : User ID (optional)
    --   p_responsibility_id: Responsibility ID (optional)
    --   p_application_id: Application ID (optional)
    -- Execution Impact: Calls VALUE function
    -- ========================================================================
    PROCEDURE get(
        p_profile_name      IN  VARCHAR2,
        p_value             OUT VARCHAR2,
        p_user_id           IN  NUMBER DEFAULT NULL,
        p_responsibility_id IN  NUMBER DEFAULT NULL,
        p_application_id    IN  NUMBER DEFAULT NULL
    );
    
    -- ========================================================================
    -- Public Procedure: PUT
    -- Description: Sets profile option value in current session
    -- Note: This is in-memory only, does not persist to database
    -- Parameters:
    --   p_profile_name : Internal name of the profile option
    --   p_value        : Value to set
    -- Execution Impact: Updates package global collection (no DML)
    -- ========================================================================
    PROCEDURE put(
        p_profile_name IN VARCHAR2,
        p_value        IN VARCHAR2
    );
    
    -- ========================================================================
    -- Public Procedure: SAVE
    -- Description: Saves profile option value to database
    -- Parameters:
    --   p_profile_name : Internal name of the profile option
    --   p_value        : Value to save
    --   p_level_id     : Level ID (use g_level_* constants)
    --   p_level_value  : ID at that level
    --   p_level_value_app_id: Application ID for responsibility level
    --   p_user_id      : User performing the operation
    -- Execution Impact: INSERT or UPDATE on FND_PROFILE_OPTION_VALUES
    -- ========================================================================
    PROCEDURE save(
        p_profile_name       IN VARCHAR2,
        p_value              IN VARCHAR2,
        p_level_id           IN NUMBER,
        p_level_value        IN NUMBER DEFAULT NULL,
        p_level_value_app_id IN NUMBER DEFAULT NULL,
        p_user_id            IN NUMBER DEFAULT 0
    );
    
    -- ========================================================================
    -- Public Procedure: INITIALIZE
    -- Description: Initializes profile cache for current session
    -- Parameters:
    --   p_user_id      : User ID
    --   p_responsibility_id: Responsibility ID (optional)
    --   p_application_id: Application ID (optional)
    -- Execution Impact: Bulk query to populate session cache
    -- ========================================================================
    PROCEDURE initialize(
        p_user_id           IN NUMBER,
        p_responsibility_id IN NUMBER DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL
    );
    
    -- ========================================================================
    -- Public Procedure: GET_ALL
    -- Description: Returns all profile values for the current context
    -- Parameters:
    --   p_user_id      : User ID
    --   p_responsibility_id: Responsibility ID (optional)
    --   p_application_id: Application ID (optional)
    -- Returns: Cursor of profile names and values
    -- Execution Impact: Hierarchical query across all profile values
    -- ========================================================================
    PROCEDURE get_all(
        p_user_id           IN  NUMBER,
        p_responsibility_id IN  NUMBER DEFAULT NULL,
        p_application_id    IN  NUMBER DEFAULT NULL,
        p_cursor            OUT SYS_REFCURSOR
    );
    
END fnd_profile;
/
