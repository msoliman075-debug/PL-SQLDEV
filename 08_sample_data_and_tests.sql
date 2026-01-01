-- ============================================================================
-- Sample Data and Test Scripts
-- Description: Sample data for testing the profile management system
-- ============================================================================

-- ============================================================================
-- PART 1: INSERT SAMPLE PROFILE OPTIONS
-- ============================================================================

-- Sample Profile Option 1: Default Date Format
INSERT INTO fnd_profile_options (
    profile_option_id,
    profile_option_name,
    application_id,
    user_profile_option_name,
    description,
    enabled_flag,
    start_date_active,
    user_changeable_flag,
    user_visible_flag,
    read_only_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_options_s.NEXTVAL,
    'DEFAULT_DATE_FORMAT',
    0,
    'Default Date Format',
    'Default date format for the application (DD-MON-YYYY, MM/DD/YYYY, etc.)',
    'Y',
    SYSDATE,
    'Y',
    'Y',
    'N',
    SYSDATE,
    0,
    SYSDATE,
    0
);

-- Sample Profile Option 2: Rows Per Page
INSERT INTO fnd_profile_options (
    profile_option_id,
    profile_option_name,
    application_id,
    user_profile_option_name,
    description,
    enabled_flag,
    start_date_active,
    user_changeable_flag,
    user_visible_flag,
    read_only_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_options_s.NEXTVAL,
    'ROWS_PER_PAGE',
    0,
    'Rows Per Page',
    'Number of rows to display per page in list views',
    'Y',
    SYSDATE,
    'Y',
    'Y',
    'N',
    SYSDATE,
    0,
    SYSDATE,
    0
);

-- Sample Profile Option 3: Default Language
INSERT INTO fnd_profile_options (
    profile_option_id,
    profile_option_name,
    application_id,
    user_profile_option_name,
    description,
    enabled_flag,
    start_date_active,
    user_changeable_flag,
    user_visible_flag,
    read_only_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_options_s.NEXTVAL,
    'DEFAULT_LANGUAGE',
    0,
    'Default Language',
    'Default language for the user interface',
    'Y',
    SYSDATE,
    'Y',
    'Y',
    'N',
    SYSDATE,
    0,
    SYSDATE,
    0
);

-- Sample Profile Option 4: Session Timeout
INSERT INTO fnd_profile_options (
    profile_option_id,
    profile_option_name,
    application_id,
    user_profile_option_name,
    description,
    enabled_flag,
    start_date_active,
    user_changeable_flag,
    user_visible_flag,
    read_only_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_options_s.NEXTVAL,
    'SESSION_TIMEOUT',
    0,
    'Session Timeout (Minutes)',
    'Number of minutes before an inactive session times out',
    'Y',
    SYSDATE,
    'N',
    'Y',
    'N',
    SYSDATE,
    0,
    SYSDATE,
    0
);

-- Sample Profile Option 5: Debug Mode (System Only)
INSERT INTO fnd_profile_options (
    profile_option_id,
    profile_option_name,
    application_id,
    user_profile_option_name,
    description,
    enabled_flag,
    start_date_active,
    user_changeable_flag,
    user_visible_flag,
    read_only_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_options_s.NEXTVAL,
    'DEBUG_MODE',
    0,
    'Debug Mode',
    'Enable debug logging (Y/N) - System administrators only',
    'Y',
    SYSDATE,
    'N',
    'N',
    'N',
    SYSDATE,
    0,
    SYSDATE,
    0
);

-- Sample Profile Option 6: Default Currency
INSERT INTO fnd_profile_options (
    profile_option_id,
    profile_option_name,
    application_id,
    user_profile_option_name,
    description,
    enabled_flag,
    start_date_active,
    user_changeable_flag,
    user_visible_flag,
    read_only_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_options_s.NEXTVAL,
    'DEFAULT_CURRENCY',
    0,
    'Default Currency',
    'Default currency code (USD, EUR, GBP, etc.)',
    'Y',
    SYSDATE,
    'Y',
    'Y',
    'N',
    SYSDATE,
    0,
    SYSDATE,
    0
);

COMMIT;

-- ============================================================================
-- PART 2: INSERT SAMPLE PROFILE VALUES AT DIFFERENT LEVELS
-- ============================================================================

-- Site Level Values (Apply to everyone by default)
INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    profile_option_value,
    enabled_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_option_values_s.NEXTVAL,
    (SELECT profile_option_id FROM fnd_profile_options 
     WHERE profile_option_name = 'DEFAULT_DATE_FORMAT'),
    10001,  -- Site level
    'DD-MON-YYYY',
    'Y',
    SYSDATE,
    0,
    SYSDATE,
    0
);

INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    profile_option_value,
    enabled_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_option_values_s.NEXTVAL,
    (SELECT profile_option_id FROM fnd_profile_options 
     WHERE profile_option_name = 'ROWS_PER_PAGE'),
    10001,  -- Site level
    '25',
    'Y',
    SYSDATE,
    0,
    SYSDATE,
    0
);

INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    profile_option_value,
    enabled_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_option_values_s.NEXTVAL,
    (SELECT profile_option_id FROM fnd_profile_options 
     WHERE profile_option_name = 'DEFAULT_LANGUAGE'),
    10001,  -- Site level
    'ENGLISH',
    'Y',
    SYSDATE,
    0,
    SYSDATE,
    0
);

INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    profile_option_value,
    enabled_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_option_values_s.NEXTVAL,
    (SELECT profile_option_id FROM fnd_profile_options 
     WHERE profile_option_name = 'SESSION_TIMEOUT'),
    10001,  -- Site level
    '30',
    'Y',
    SYSDATE,
    0,
    SYSDATE,
    0
);

INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    profile_option_value,
    enabled_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_option_values_s.NEXTVAL,
    (SELECT profile_option_id FROM fnd_profile_options 
     WHERE profile_option_name = 'DEBUG_MODE'),
    10001,  -- Site level
    'N',
    'Y',
    SYSDATE,
    0,
    SYSDATE,
    0
);

INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    profile_option_value,
    enabled_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_option_values_s.NEXTVAL,
    (SELECT profile_option_id FROM fnd_profile_options 
     WHERE profile_option_name = 'DEFAULT_CURRENCY'),
    10001,  -- Site level
    'USD',
    'Y',
    SYSDATE,
    0,
    SYSDATE,
    0
);

-- Application Level Values (Override site defaults for specific application)
INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    level_value,
    profile_option_value,
    enabled_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_option_values_s.NEXTVAL,
    (SELECT profile_option_id FROM fnd_profile_options 
     WHERE profile_option_name = 'ROWS_PER_PAGE'),
    10002,  -- Application level
    101,    -- Application ID 101
    '50',
    'Y',
    SYSDATE,
    0,
    SYSDATE,
    0
);

-- User Level Values (Highest priority - user preferences)
INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    level_value,
    profile_option_value,
    enabled_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_option_values_s.NEXTVAL,
    (SELECT profile_option_id FROM fnd_profile_options 
     WHERE profile_option_name = 'DEFAULT_DATE_FORMAT'),
    10004,  -- User level
    1001,   -- User ID 1001
    'MM/DD/YYYY',
    'Y',
    SYSDATE,
    1001,
    SYSDATE,
    1001
);

INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    level_value,
    profile_option_value,
    enabled_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_option_values_s.NEXTVAL,
    (SELECT profile_option_id FROM fnd_profile_options 
     WHERE profile_option_name = 'ROWS_PER_PAGE'),
    10004,  -- User level
    1001,   -- User ID 1001
    '100',
    'Y',
    SYSDATE,
    1001,
    SYSDATE,
    1001
);

INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    level_value,
    profile_option_value,
    enabled_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_option_values_s.NEXTVAL,
    (SELECT profile_option_id FROM fnd_profile_options 
     WHERE profile_option_name = 'DEFAULT_CURRENCY'),
    10004,  -- User level
    1002,   -- User ID 1002
    'EUR',
    'Y',
    SYSDATE,
    1002,
    SYSDATE,
    1002
);

COMMIT;

-- ============================================================================
-- PART 3: TEST QUERIES
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT TEST 1: View all profile options
PROMPT ============================================================================
SELECT profile_option_name,
       user_profile_option_name,
       status,
       user_changeable_flag,
       user_visible_flag
FROM   fnd_profile_options_vl
ORDER BY profile_option_name;

PROMPT
PROMPT ============================================================================
PROMPT TEST 2: View all profile values with hierarchy
PROMPT ============================================================================
SELECT profile_option_name,
       level_name,
       priority,
       level_value,
       profile_option_value,
       status
FROM   fnd_profile_hierarchy_v
ORDER BY profile_option_name, priority;

PROMPT
PROMPT ============================================================================
PROMPT TEST 3: View profile summary statistics
PROMPT ============================================================================
SELECT profile_option_name,
       total_values,
       site_values,
       application_values,
       user_values
FROM   fnd_profile_summary_v
ORDER BY profile_option_name;

PROMPT
PROMPT ============================================================================
PROMPT TEST 4: Test FND_PROFILE.VALUE function for User 1001
PROMPT ============================================================================
DECLARE
    l_date_format   VARCHAR2(2000);
    l_rows_per_page VARCHAR2(2000);
    l_currency      VARCHAR2(2000);
    l_timeout       VARCHAR2(2000);
BEGIN
    -- User 1001 should get user-level overrides
    l_date_format := fnd_profile.value(
        p_profile_name => 'DEFAULT_DATE_FORMAT',
        p_user_id => 1001
    );
    
    l_rows_per_page := fnd_profile.value(
        p_profile_name => 'ROWS_PER_PAGE',
        p_user_id => 1001
    );
    
    l_currency := fnd_profile.value(
        p_profile_name => 'DEFAULT_CURRENCY',
        p_user_id => 1001
    );
    
    l_timeout := fnd_profile.value(
        p_profile_name => 'SESSION_TIMEOUT',
        p_user_id => 1001
    );
    
    DBMS_OUTPUT.PUT_LINE('User 1001 Profile Values:');
    DBMS_OUTPUT.PUT_LINE('  DEFAULT_DATE_FORMAT: ' || l_date_format || ' (Expected: MM/DD/YYYY from user level)');
    DBMS_OUTPUT.PUT_LINE('  ROWS_PER_PAGE: ' || l_rows_per_page || ' (Expected: 100 from user level)');
    DBMS_OUTPUT.PUT_LINE('  DEFAULT_CURRENCY: ' || l_currency || ' (Expected: USD from site level)');
    DBMS_OUTPUT.PUT_LINE('  SESSION_TIMEOUT: ' || l_timeout || ' (Expected: 30 from site level)');
END;
/

PROMPT
PROMPT ============================================================================
PROMPT TEST 5: Test FND_PROFILE.VALUE function for User 1002
PROMPT ============================================================================
DECLARE
    l_date_format   VARCHAR2(2000);
    l_rows_per_page VARCHAR2(2000);
    l_currency      VARCHAR2(2000);
BEGIN
    -- User 1002 should get some site defaults and one user override
    l_date_format := fnd_profile.value(
        p_profile_name => 'DEFAULT_DATE_FORMAT',
        p_user_id => 1002
    );
    
    l_rows_per_page := fnd_profile.value(
        p_profile_name => 'ROWS_PER_PAGE',
        p_user_id => 1002
    );
    
    l_currency := fnd_profile.value(
        p_profile_name => 'DEFAULT_CURRENCY',
        p_user_id => 1002
    );
    
    DBMS_OUTPUT.PUT_LINE('User 1002 Profile Values:');
    DBMS_OUTPUT.PUT_LINE('  DEFAULT_DATE_FORMAT: ' || l_date_format || ' (Expected: DD-MON-YYYY from site level)');
    DBMS_OUTPUT.PUT_LINE('  ROWS_PER_PAGE: ' || l_rows_per_page || ' (Expected: 25 from site level)');
    DBMS_OUTPUT.PUT_LINE('  DEFAULT_CURRENCY: ' || l_currency || ' (Expected: EUR from user level)');
END;
/

PROMPT
PROMPT ============================================================================
PROMPT TEST 6: Test FND_PROFILE.SAVE procedure
PROMPT ============================================================================
DECLARE
    l_new_value VARCHAR2(2000);
BEGIN
    -- Save a new user-level preference for User 1003
    fnd_profile.save(
        p_profile_name => 'DEFAULT_LANGUAGE',
        p_value => 'SPANISH',
        p_level_id => fnd_profile.g_level_user,
        p_level_value => 1003,
        p_user_id => 1003
    );
    
    DBMS_OUTPUT.PUT_LINE('Saved DEFAULT_LANGUAGE = SPANISH for User 1003');
    
    -- Retrieve the saved value
    l_new_value := fnd_profile.value(
        p_profile_name => 'DEFAULT_LANGUAGE',
        p_user_id => 1003
    );
    
    DBMS_OUTPUT.PUT_LINE('Retrieved value: ' || l_new_value);
    
    IF l_new_value = 'SPANISH' THEN
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Value saved and retrieved correctly');
    ELSE
        DBMS_OUTPUT.PUT_LINE('ERROR: Value mismatch');
    END IF;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT TEST 7: Test FND_PROFILE.PUT (session cache)
PROMPT ============================================================================
DECLARE
    l_value VARCHAR2(2000);
BEGIN
    -- Put value in session cache
    fnd_profile.put(
        p_profile_name => 'SESSION_TIMEOUT',
        p_value => '60'
    );
    
    DBMS_OUTPUT.PUT_LINE('Put SESSION_TIMEOUT = 60 in session cache');
    
    -- Retrieve from cache
    l_value := fnd_profile.value(
        p_profile_name => 'SESSION_TIMEOUT'
    );
    
    DBMS_OUTPUT.PUT_LINE('Retrieved from cache: ' || l_value);
    
    IF l_value = '60' THEN
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Session cache working correctly');
    ELSE
        DBMS_OUTPUT.PUT_LINE('ERROR: Session cache value mismatch');
    END IF;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT TEST 8: Test FND_PROFILE.GET_ALL procedure
PROMPT ============================================================================
DECLARE
    l_cursor SYS_REFCURSOR;
    l_profile_name VARCHAR2(240);
    l_user_profile_name VARCHAR2(240);
    l_description VARCHAR2(2000);
    l_value VARCHAR2(2000);
    l_level VARCHAR2(100);
    l_level_value NUMBER;
BEGIN
    fnd_profile.get_all(
        p_user_id => 1001,
        p_cursor => l_cursor
    );
    
    DBMS_OUTPUT.PUT_LINE('All profiles for User 1001:');
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    LOOP
        FETCH l_cursor INTO l_profile_name, l_user_profile_name, 
                           l_description, l_value, l_level, l_level_value;
        EXIT WHEN l_cursor%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE(
            l_profile_name || ' = ' || l_value || 
            ' (' || l_level || ' level)'
        );
    END LOOP;
    
    CLOSE l_cursor;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT All tests completed successfully!
PROMPT ============================================================================
