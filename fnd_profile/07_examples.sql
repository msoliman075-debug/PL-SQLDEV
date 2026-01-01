/*
================================================================================
  FND_PROFILE Usage Examples
  Demonstrates how to use the FND_PROFILE API
  
  Author: Database Team
  Version: 1.0
  Target: Oracle 19c+
================================================================================
*/

-- ============================================================================
-- Example 1: Initialize Session Context
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Example 1: Initialize Session
PROMPT ========================================

-- Initialize session for user JSMITH with GL Manager responsibility
BEGIN
    fnd_profile.initialize(
        p_user_id        => 100,   -- JSMITH
        p_resp_id        => 1002,  -- GL Manager
        p_resp_appl_id   => 200,   -- GL Application
        p_application_id => 200    -- GL Application
    );
    
    DBMS_OUTPUT.PUT_LINE('Session initialized for user: ' || fnd_profile.g_user_name);
END;
/

-- ============================================================================
-- Example 2: Get Profile Value (with hierarchy resolution)
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Example 2: GET Profile Value
PROMPT ========================================

DECLARE
    v_value VARCHAR2(240);
BEGIN
    -- Get using procedure
    fnd_profile.get('FND_ROWS_PER_PAGE', v_value);
    DBMS_OUTPUT.PUT_LINE('Rows per page (GET): ' || v_value);
    
    -- Get using function (can be used in SQL)
    v_value := fnd_profile.value('FND_DATE_FORMAT');
    DBMS_OUTPUT.PUT_LINE('Date format (VALUE): ' || v_value);
    
    -- Get using function in SQL
    SELECT fnd_profile.value('FND_LANGUAGE') INTO v_value FROM DUAL;
    DBMS_OUTPUT.PUT_LINE('Language (SQL): ' || v_value);
END;
/

-- ============================================================================
-- Example 3: Get Value at Specific Level
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Example 3: GET_SPECIFIC - Value at Level
PROMPT ========================================

DECLARE
    v_site_value VARCHAR2(240);
    v_user_value VARCHAR2(240);
BEGIN
    -- Get site level value directly
    v_site_value := fnd_profile.get_specific(
        p_name       => 'FND_ROWS_PER_PAGE',
        p_level_id   => fnd_profile.SITE_LEVEL,
        p_level_value => 0
    );
    DBMS_OUTPUT.PUT_LINE('Site level rows per page: ' || v_site_value);
    
    -- Get user level value for JSMITH
    v_user_value := fnd_profile.get_specific(
        p_name        => 'FND_ROWS_PER_PAGE',
        p_level_id    => fnd_profile.USER_LEVEL,
        p_level_value => 100  -- JSMITH user_id
    );
    DBMS_OUTPUT.PUT_LINE('User level rows per page: ' || v_user_value);
END;
/

-- ============================================================================
-- Example 4: Save Profile Value
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Example 4: SAVE Profile Value
PROMPT ========================================

DECLARE
    v_result BOOLEAN;
    v_status VARCHAR2(1);
    v_message VARCHAR2(2000);
BEGIN
    -- Save at site level using function
    v_result := fnd_profile.save(
        p_name       => 'FND_SESSION_TIMEOUT',
        p_value      => '45',
        p_level_name => 'SITE',
        p_level_value => NULL
    );
    
    IF v_result THEN
        DBMS_OUTPUT.PUT_LINE('Site level save: SUCCESS');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Site level save: FAILED');
    END IF;
    
    -- Save at user level using procedure
    fnd_profile.save(
        p_name          => 'FND_ROWS_PER_PAGE',
        p_value         => '100',
        p_level_name    => 'USER',
        p_level_value   => '100',  -- JSMITH
        x_return_status => v_status,
        x_return_message => v_message
    );
    
    DBMS_OUTPUT.PUT_LINE('User level save status: ' || v_status || ' - ' || v_message);
    
    COMMIT;
END;
/

-- ============================================================================
-- Example 5: Put Value in Cache Only
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Example 5: PUT (Cache Only)
PROMPT ========================================

DECLARE
    v_cached_value VARCHAR2(240);
BEGIN
    -- Put a temporary value in cache (not persisted)
    fnd_profile.put('MY_TEMP_SETTING', 'TEMP_VALUE_123');
    
    -- Retrieve from cache
    v_cached_value := fnd_profile.get_cache_value('MY_TEMP_SETTING');
    DBMS_OUTPUT.PUT_LINE('Cached value: ' || v_cached_value);
    
    -- Clear cache
    fnd_profile.clear_cache;
    
    -- Cache is now empty
    v_cached_value := fnd_profile.get_cache_value('MY_TEMP_SETTING');
    DBMS_OUTPUT.PUT_LINE('After clear (should be null): ' || NVL(v_cached_value, 'NULL'));
END;
/

-- ============================================================================
-- Example 6: Get All Values for a Profile
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Example 6: GET_ALL_VALUES
PROMPT ========================================

DECLARE
    v_values fnd_profile.profile_value_tbl;
    v_count  NUMBER;
BEGIN
    fnd_profile.get_all_values(
        p_name   => 'FND_ROWS_PER_PAGE',
        x_values => v_values,
        x_count  => v_count
    );
    
    DBMS_OUTPUT.PUT_LINE('Found ' || v_count || ' values for FND_ROWS_PER_PAGE:');
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    FOR i IN 1..v_count LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_values(i).level_name, 15) || ' | ' ||
            RPAD(NVL(v_values(i).level_display_value, '-'), 20) || ' | ' ||
            v_values(i).profile_option_value
        );
    END LOOP;
END;
/

-- ============================================================================
-- Example 7: Check if Profile is Defined
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Example 7: DEFINED Check
PROMPT ========================================

BEGIN
    IF fnd_profile.defined('FND_LANGUAGE') THEN
        DBMS_OUTPUT.PUT_LINE('FND_LANGUAGE is defined');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FND_LANGUAGE is NOT defined');
    END IF;
    
    IF fnd_profile.defined('NON_EXISTENT_PROFILE') THEN
        DBMS_OUTPUT.PUT_LINE('NON_EXISTENT_PROFILE is defined');
    ELSE
        DBMS_OUTPUT.PUT_LINE('NON_EXISTENT_PROFILE is NOT defined');
    END IF;
END;
/

-- ============================================================================
-- Example 8: Check Level Permissions
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Example 8: Level Permissions
PROMPT ========================================

BEGIN
    -- Check if user level is enabled
    IF fnd_profile.is_enabled('FND_LANGUAGE', 'USER') THEN
        DBMS_OUTPUT.PUT_LINE('FND_LANGUAGE: User level ENABLED');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FND_LANGUAGE: User level DISABLED');
    END IF;
    
    -- Check if update is allowed at user level
    IF fnd_profile.is_update_allowed('FND_LANGUAGE', 'USER') THEN
        DBMS_OUTPUT.PUT_LINE('FND_LANGUAGE: User update ALLOWED');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FND_LANGUAGE: User update NOT ALLOWED');
    END IF;
    
    -- Check DEBUG_MODE (disabled at user level)
    IF fnd_profile.is_enabled('FND_DEBUG_MODE', 'USER') THEN
        DBMS_OUTPUT.PUT_LINE('FND_DEBUG_MODE: User level ENABLED');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FND_DEBUG_MODE: User level DISABLED');
    END IF;
END;
/

-- ============================================================================
-- Example 9: Delete Profile Value
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Example 9: DELETE_VALUE
PROMPT ========================================

DECLARE
    v_result BOOLEAN;
BEGIN
    -- First save a test value
    v_result := fnd_profile.save(
        p_name       => 'FND_EMAIL_NOTIFICATIONS',
        p_value      => 'N',
        p_level_name => 'USER',
        p_level_value => '103'  -- LBROWN
    );
    
    IF v_result THEN
        DBMS_OUTPUT.PUT_LINE('Test value saved for deletion');
    END IF;
    
    -- Now delete it
    v_result := fnd_profile.delete_value(
        p_name       => 'FND_EMAIL_NOTIFICATIONS',
        p_level_name => 'USER',
        p_level_value => '103'
    );
    
    IF v_result THEN
        DBMS_OUTPUT.PUT_LINE('Profile value deleted successfully');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Delete failed or value did not exist');
    END IF;
    
    COMMIT;
END;
/

-- ============================================================================
-- Example 10: Using VALUE_SPECIFIC for Different Contexts
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Example 10: VALUE_SPECIFIC
PROMPT ========================================

DECLARE
    v_value VARCHAR2(240);
BEGIN
    -- Get effective value for a specific user context
    v_value := fnd_profile.value_specific(
        p_name           => 'FND_DATE_FORMAT',
        p_user_id        => 100,  -- JSMITH
        p_resp_id        => 1002, -- GL Manager
        p_resp_appl_id   => 200,  -- GL App
        p_application_id => 200   -- GL App
    );
    DBMS_OUTPUT.PUT_LINE('Date format for JSMITH in GL: ' || v_value);
    
    -- Get effective value for different user
    v_value := fnd_profile.value_specific(
        p_name    => 'FND_LANGUAGE',
        p_user_id => 101  -- MJOHNSON (has user-level override)
    );
    DBMS_OUTPUT.PUT_LINE('Language for MJOHNSON: ' || v_value);
    
    -- Get value with no user context (site level only)
    v_value := fnd_profile.value_specific(
        p_name => 'FND_SESSION_TIMEOUT'
    );
    DBMS_OUTPUT.PUT_LINE('Session timeout (site): ' || v_value);
END;
/

-- ============================================================================
-- Example 11: Using Profile Value in SQL Queries
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Example 11: Profile in SQL Queries
PROMPT ========================================

-- Use profile value directly in SQL
SELECT 
    'Language: ' || fnd_profile.value('FND_LANGUAGE') AS language,
    'Date Format: ' || fnd_profile.value('FND_DATE_FORMAT') AS date_format,
    'Rows Per Page: ' || fnd_profile.value('FND_ROWS_PER_PAGE') AS rows_per_page
FROM DUAL;

-- Filter based on profile value
SELECT user_name, email_address
FROM fnd_user
WHERE ROWNUM <= TO_NUMBER(NVL(fnd_profile.value('FND_ROWS_PER_PAGE'), '10'));

-- ============================================================================
-- Example 12: View Profile Change History
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Example 12: Change History
PROMPT ========================================

SELECT 
    profile_option_name,
    level_name,
    level_value_display,
    old_profile_option_value AS old_value,
    new_profile_option_value AS new_value,
    change_type,
    changed_by_name,
    TO_CHAR(change_date, 'DD-MON-YYYY HH24:MI:SS') AS change_time
FROM fnd_profile_change_history_v
WHERE ROWNUM <= 10
ORDER BY change_date DESC;

/*
================================================================================
  End of Examples
================================================================================
*/
