/*
================================================================================
  FND_PROFILE Package Specification
  Similar to Oracle EBS FND_PROFILE API
  
  Author: Database Team
  Version: 1.0
  Target: Oracle 19c+
  
  Description:
  Provides API for getting and setting profile option values at different
  hierarchy levels. Maintains runtime cache for performance optimization.
================================================================================
*/

CREATE OR REPLACE PACKAGE fnd_profile AS
    /*
    ==========================================================================
    Package: FND_PROFILE
    Purpose: Profile option management API
    
    Key Features:
    - GET: Retrieve profile values with hierarchy resolution
    - PUT: Set profile values in memory cache
    - SAVE: Persist profile values to database
    - VALUE: Function version of GET for SQL usage
    - Automatic hierarchy resolution (User > Resp > App > Site)
    ==========================================================================
    */
    
    -- ========================================================================
    -- Constants for Profile Hierarchy Levels
    -- ========================================================================
    SITE_LEVEL              CONSTANT NUMBER := 10001;
    APPL_LEVEL              CONSTANT NUMBER := 10002;
    RESP_LEVEL              CONSTANT NUMBER := 10003;
    USER_LEVEL              CONSTANT NUMBER := 10004;
    
    -- ========================================================================
    -- Context Variables (set during session initialization)
    -- ========================================================================
    -- Current session context
    g_user_id               NUMBER;
    g_resp_id               NUMBER;
    g_resp_appl_id          NUMBER;
    g_application_id        NUMBER;
    g_user_name             VARCHAR2(100);
    
    -- ========================================================================
    -- Public Procedures and Functions
    -- ========================================================================
    
    /*
    --------------------------------------------------------------------------
    Procedure: INITIALIZE
    Purpose: Initialize session context with user/responsibility information
    
    Parameters:
        p_user_id        - User ID for the session
        p_resp_id        - Responsibility ID
        p_resp_appl_id   - Responsibility Application ID
        p_application_id - Current Application ID
    --------------------------------------------------------------------------
    */
    PROCEDURE initialize(
        p_user_id        IN NUMBER,
        p_resp_id        IN NUMBER DEFAULT NULL,
        p_resp_appl_id   IN NUMBER DEFAULT NULL,
        p_application_id IN NUMBER DEFAULT NULL
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: GET
    Purpose: Retrieve profile option value based on current context
             Searches hierarchy: User -> Responsibility -> Application -> Site
    
    Parameters:
        p_name  - Profile option name (internal name)
        p_value - OUT: Retrieved value (NULL if not found)
    --------------------------------------------------------------------------
    */
    PROCEDURE get(
        p_name  IN  VARCHAR2,
        p_value OUT VARCHAR2
    );
    
    /*
    --------------------------------------------------------------------------
    Function: VALUE
    Purpose: Returns profile option value (for use in SQL statements)
    
    Parameters:
        p_name - Profile option name
    
    Returns: Profile option value or NULL if not found
    --------------------------------------------------------------------------
    */
    FUNCTION value(
        p_name IN VARCHAR2
    ) RETURN VARCHAR2;
    
    /*
    --------------------------------------------------------------------------
    Function: VALUE_SPECIFIC
    Purpose: Get profile value at a specific hierarchy level
    
    Parameters:
        p_name           - Profile option name
        p_user_id        - User ID (for USER level)
        p_resp_id        - Responsibility ID (for RESP level)
        p_resp_appl_id   - Responsibility App ID
        p_application_id - Application ID (for APP level)
    
    Returns: Profile option value at specified level
    --------------------------------------------------------------------------
    */
    FUNCTION value_specific(
        p_name           IN VARCHAR2,
        p_user_id        IN NUMBER   DEFAULT NULL,
        p_resp_id        IN NUMBER   DEFAULT NULL,
        p_resp_appl_id   IN NUMBER   DEFAULT NULL,
        p_application_id IN NUMBER   DEFAULT NULL
    ) RETURN VARCHAR2;
    
    /*
    --------------------------------------------------------------------------
    Function: GET_SPECIFIC
    Purpose: Get profile value at a specific hierarchy level
    
    Parameters:
        p_name           - Profile option name
        p_level_id       - Hierarchy level ID
        p_level_value    - Level value (user_id, resp_id, app_id, or 0 for site)
        p_level_value_appl_id - Application ID for responsibility level
    
    Returns: Profile option value at the exact level specified
    --------------------------------------------------------------------------
    */
    FUNCTION get_specific(
        p_name                IN VARCHAR2,
        p_level_id            IN NUMBER,
        p_level_value         IN NUMBER DEFAULT 0,
        p_level_value_appl_id IN NUMBER DEFAULT NULL
    ) RETURN VARCHAR2;
    
    /*
    --------------------------------------------------------------------------
    Procedure: PUT
    Purpose: Sets profile option value in memory cache only
             Does NOT persist to database (use SAVE for persistence)
    
    Parameters:
        p_name  - Profile option name
        p_value - Value to set
    
    Returns: TRUE if successful, FALSE otherwise
    --------------------------------------------------------------------------
    */
    PROCEDURE put(
        p_name  IN VARCHAR2,
        p_value IN VARCHAR2
    );
    
    /*
    --------------------------------------------------------------------------
    Function: SAVE
    Purpose: Saves profile option value to database at specified level
    
    Parameters:
        p_name                - Profile option name
        p_value               - Value to save
        p_level_name          - Level name: 'SITE', 'APPLICATION', 'RESPONSIBILITY', 'USER'
        p_level_value         - Level value (0 for site, app_id, resp_id, or user_id)
        p_level_value_appl_id - Application ID (for responsibility level)
    
    Returns: TRUE if successful, FALSE otherwise
    --------------------------------------------------------------------------
    */
    FUNCTION save(
        p_name                IN VARCHAR2,
        p_value               IN VARCHAR2,
        p_level_name          IN VARCHAR2,
        p_level_value         IN VARCHAR2 DEFAULT NULL,
        p_level_value_appl_id IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN;
    
    /*
    --------------------------------------------------------------------------
    Procedure: SAVE
    Purpose: Procedure version of SAVE function
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
    );
    
    /*
    --------------------------------------------------------------------------
    Function: DELETE_VALUE
    Purpose: Deletes profile option value at specified level
    
    Parameters:
        p_name                - Profile option name
        p_level_name          - Level name
        p_level_value         - Level value
        p_level_value_appl_id - Application ID (for responsibility level)
    
    Returns: TRUE if successful, FALSE otherwise
    --------------------------------------------------------------------------
    */
    FUNCTION delete_value(
        p_name                IN VARCHAR2,
        p_level_name          IN VARCHAR2,
        p_level_value         IN VARCHAR2 DEFAULT NULL,
        p_level_value_appl_id IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN;
    
    /*
    --------------------------------------------------------------------------
    Function: DEFINED
    Purpose: Check if a profile option is defined
    
    Parameters:
        p_name - Profile option name
    
    Returns: TRUE if profile exists and has a value, FALSE otherwise
    --------------------------------------------------------------------------
    */
    FUNCTION defined(
        p_name IN VARCHAR2
    ) RETURN BOOLEAN;
    
    /*
    --------------------------------------------------------------------------
    Procedure: GET_ALL_VALUES
    Purpose: Get all values for a profile at all hierarchy levels
    
    Parameters:
        p_name - Profile option name
    --------------------------------------------------------------------------
    */
    TYPE profile_value_rec IS RECORD (
        level_name              VARCHAR2(80),
        level_id                NUMBER,
        level_value             NUMBER,
        level_value_appl_id     NUMBER,
        profile_option_value    VARCHAR2(240),
        level_display_value     VARCHAR2(240)
    );
    
    TYPE profile_value_tbl IS TABLE OF profile_value_rec INDEX BY BINARY_INTEGER;
    
    PROCEDURE get_all_values(
        p_name   IN  VARCHAR2,
        x_values OUT profile_value_tbl,
        x_count  OUT NUMBER
    );
    
    /*
    --------------------------------------------------------------------------
    Procedure: CLEAR_CACHE
    Purpose: Clears the in-memory profile cache
    --------------------------------------------------------------------------
    */
    PROCEDURE clear_cache;
    
    /*
    --------------------------------------------------------------------------
    Function: GET_CACHE_VALUE
    Purpose: Returns value from cache (not database)
    
    Parameters:
        p_name - Profile option name
    
    Returns: Cached value or NULL if not in cache
    --------------------------------------------------------------------------
    */
    FUNCTION get_cache_value(
        p_name IN VARCHAR2
    ) RETURN VARCHAR2;
    
    /*
    --------------------------------------------------------------------------
    Function: IS_ENABLED
    Purpose: Check if a profile option is enabled at a specific level
    
    Parameters:
        p_name       - Profile option name
        p_level_name - Level name to check
    
    Returns: TRUE if enabled at level, FALSE otherwise
    --------------------------------------------------------------------------
    */
    FUNCTION is_enabled(
        p_name       IN VARCHAR2,
        p_level_name IN VARCHAR2
    ) RETURN BOOLEAN;
    
    /*
    --------------------------------------------------------------------------
    Function: IS_UPDATE_ALLOWED
    Purpose: Check if update is allowed at a specific level
    
    Parameters:
        p_name       - Profile option name
        p_level_name - Level name to check
    
    Returns: TRUE if update allowed, FALSE otherwise
    --------------------------------------------------------------------------
    */
    FUNCTION is_update_allowed(
        p_name       IN VARCHAR2,
        p_level_name IN VARCHAR2
    ) RETURN BOOLEAN;

END fnd_profile;
/

SHOW ERRORS PACKAGE fnd_profile;

/*
================================================================================
  End of Package Specification
================================================================================
*/
