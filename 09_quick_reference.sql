-- ============================================================================
-- QUICK REFERENCE GUIDE
-- Common queries and operations for FND_PROFILE system
-- ============================================================================

-- ============================================================================
-- SECTION 1: QUERYING PROFILE OPTIONS
-- ============================================================================

-- List all active profile options
SELECT profile_option_name,
       user_profile_option_name,
       user_changeable_flag,
       user_visible_flag,
       read_only_flag
FROM   fnd_profile_options_vl
WHERE  status = 'Active'
ORDER BY user_profile_option_name;

-- Find profile options by name pattern
SELECT profile_option_name,
       user_profile_option_name,
       description
FROM   fnd_profile_options_vl
WHERE  UPPER(profile_option_name) LIKE '%DATE%'
   OR  UPPER(user_profile_option_name) LIKE '%DATE%'
ORDER BY profile_option_name;

-- Check if a profile option exists
SELECT CASE 
           WHEN fnd_profile.defined('DEFAULT_DATE_FORMAT') THEN 'YES'
           ELSE 'NO'
       END AS is_defined
FROM   dual;

-- ============================================================================
-- SECTION 2: QUERYING PROFILE VALUES
-- ============================================================================

-- Get all values for a specific profile (all levels)
SELECT level_name,
       priority,
       level_value,
       profile_option_value,
       status
FROM   fnd_profile_hierarchy_v
WHERE  profile_option_name = 'DEFAULT_DATE_FORMAT'
ORDER BY priority;

-- Get profile value for a specific user
SELECT fnd_profile.value(
    p_profile_name => 'DEFAULT_DATE_FORMAT',
    p_user_id => 1001
) AS profile_value
FROM dual;

-- Get profile value at a specific level only
SELECT fnd_profile.value_specific(
    p_profile_name => 'DEFAULT_DATE_FORMAT',
    p_level_id => 10004,  -- User level
    p_level_value => 1001  -- User ID
) AS profile_value
FROM dual;

-- Find all users with a specific profile value
SELECT pov.level_value AS user_id,
       pov.profile_option_value
FROM   fnd_profile_option_values pov,
       fnd_profile_options po
WHERE  pov.profile_option_id = po.profile_option_id
AND    po.profile_option_name = 'DEFAULT_DATE_FORMAT'
AND    pov.level_id = 10004  -- User level
AND    pov.enabled_flag = 'Y'
ORDER BY pov.level_value;

-- ============================================================================
-- SECTION 3: SETTING PROFILE VALUES
-- ============================================================================

-- Set site-level default (applies to everyone)
BEGIN
    fnd_profile.save(
        p_profile_name => 'DEFAULT_DATE_FORMAT',
        p_value => 'DD-MON-YYYY',
        p_level_id => fnd_profile.g_level_site,
        p_user_id => 0
    );
END;
/

-- Set application-level override
BEGIN
    fnd_profile.save(
        p_profile_name => 'ROWS_PER_PAGE',
        p_value => '50',
        p_level_id => fnd_profile.g_level_application,
        p_level_value => 101,  -- Application ID
        p_user_id => 0
    );
END;
/

-- Set user preference
BEGIN
    fnd_profile.save(
        p_profile_name => 'DEFAULT_DATE_FORMAT',
        p_value => 'MM/DD/YYYY',
        p_level_id => fnd_profile.g_level_user,
        p_level_value => 1001,  -- User ID
        p_user_id => 1001
    );
END;
/

-- Set multiple values at once
BEGIN
    fnd_profile.save('DEFAULT_DATE_FORMAT', 'DD-MON-YYYY', 
                    fnd_profile.g_level_user, 1001, NULL, 1001);
    fnd_profile.save('ROWS_PER_PAGE', '100', 
                    fnd_profile.g_level_user, 1001, NULL, 1001);
    fnd_profile.save('DEFAULT_LANGUAGE', 'ENGLISH', 
                    fnd_profile.g_level_user, 1001, NULL, 1001);
END;
/

-- ============================================================================
-- SECTION 4: SESSION CACHE OPERATIONS
-- ============================================================================

-- Initialize session cache for a user
BEGIN
    fnd_profile.initialize(
        p_user_id => 1001,
        p_responsibility_id => NULL,
        p_application_id => NULL
    );
END;
/

-- Set value in session (temporary, does not persist)
BEGIN
    fnd_profile.put('ROWS_PER_PAGE', '50');
    fnd_profile.put('DEFAULT_DATE_FORMAT', 'MM/DD/YYYY');
END;
/

-- Get value (checks session cache first, then database)
SELECT fnd_profile.value('ROWS_PER_PAGE') FROM dual;

-- ============================================================================
-- SECTION 5: REPORTING QUERIES
-- ============================================================================

-- Summary of all profiles with value counts
SELECT profile_option_name,
       user_profile_option_name,
       total_values,
       site_values,
       application_values,
       user_values
FROM   fnd_profile_summary_v
ORDER BY total_values DESC;

-- Profiles modified in last 7 days
SELECT profile_option_name,
       user_profile_option_name,
       level_name,
       profile_option_value,
       last_update_date,
       last_updated_by
FROM   fnd_profile_option_values_vl
WHERE  last_update_date >= SYSDATE - 7
ORDER BY last_update_date DESC;

-- User-specific profile values
SELECT profile_option_name,
       user_profile_option_name,
       profile_option_value
FROM   fnd_profile_user_values_v
WHERE  user_id = 1001
ORDER BY profile_option_name;

-- Audit trail of changes
SELECT profile_option_name,
       level_name,
       level_value,
       profile_option_value,
       change_type,
       created_by,
       creation_date,
       last_updated_by,
       last_update_date
FROM   fnd_profile_audit_v
WHERE  last_update_date >= SYSDATE - 30
ORDER BY last_update_date DESC;

-- Profiles with no values set
SELECT po.profile_option_name,
       po.user_profile_option_name
FROM   fnd_profile_options po
WHERE  po.enabled_flag = 'Y'
AND    NOT EXISTS (
    SELECT 1
    FROM   fnd_profile_option_values pov
    WHERE  pov.profile_option_id = po.profile_option_id
    AND    pov.enabled_flag = 'Y'
)
ORDER BY po.profile_option_name;

-- ============================================================================
-- SECTION 6: ADMINISTRATIVE QUERIES
-- ============================================================================

-- Find duplicate profile values at same level
SELECT profile_option_id,
       level_id,
       level_value,
       COUNT(*) AS duplicate_count
FROM   fnd_profile_option_values
WHERE  enabled_flag = 'Y'
GROUP BY profile_option_id, level_id, level_value
HAVING COUNT(*) > 1;

-- Find profiles with invalid date ranges
SELECT profile_option_name,
       user_profile_option_name,
       start_date_active,
       end_date_active
FROM   fnd_profile_options
WHERE  end_date_active IS NOT NULL
AND    end_date_active < start_date_active;

-- Find expired but still enabled profiles
SELECT profile_option_name,
       user_profile_option_name,
       end_date_active
FROM   fnd_profile_options
WHERE  enabled_flag = 'Y'
AND    end_date_active IS NOT NULL
AND    end_date_active < SYSDATE;

-- Count values by level
SELECT CASE pov.level_id
           WHEN 10001 THEN 'Site'
           WHEN 10002 THEN 'Application'
           WHEN 10003 THEN 'Responsibility'
           WHEN 10004 THEN 'User'
           WHEN 10005 THEN 'Server'
           WHEN 10006 THEN 'Organization'
       END AS level_name,
       COUNT(*) AS value_count,
       COUNT(DISTINCT pov.profile_option_id) AS profile_count
FROM   fnd_profile_option_values pov
WHERE  pov.enabled_flag = 'Y'
GROUP BY pov.level_id
ORDER BY pov.level_id;

-- ============================================================================
-- SECTION 7: MAINTENANCE OPERATIONS
-- ============================================================================

-- Disable a profile option
UPDATE fnd_profile_options
SET    enabled_flag = 'N',
       last_update_date = SYSDATE,
       last_updated_by = 0
WHERE  profile_option_name = 'PROFILE_NAME_HERE';

-- End-date a profile option
UPDATE fnd_profile_options
SET    end_date_active = SYSDATE,
       last_update_date = SYSDATE,
       last_updated_by = 0
WHERE  profile_option_name = 'PROFILE_NAME_HERE';

-- Delete all values for a user
DELETE FROM fnd_profile_option_values
WHERE  level_id = 10004
AND    level_value = 1001;  -- User ID

-- Delete a specific profile value
DELETE FROM fnd_profile_option_values
WHERE  profile_option_id = (
    SELECT profile_option_id 
    FROM fnd_profile_options 
    WHERE profile_option_name = 'PROFILE_NAME_HERE'
)
AND    level_id = 10004
AND    level_value = 1001;

-- Archive old profile values
CREATE TABLE fnd_profile_option_values_archive
AS SELECT * FROM fnd_profile_option_values WHERE 1=0;

INSERT INTO fnd_profile_option_values_archive
SELECT * 
FROM   fnd_profile_option_values
WHERE  end_date_active IS NOT NULL
AND    end_date_active < ADD_MONTHS(SYSDATE, -12);

DELETE FROM fnd_profile_option_values
WHERE  end_date_active IS NOT NULL
AND    end_date_active < ADD_MONTHS(SYSDATE, -12);

COMMIT;

-- ============================================================================
-- SECTION 8: USEFUL PL/SQL BLOCKS
-- ============================================================================

-- Get all profiles for a user (formatted output)
SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
    l_cursor SYS_REFCURSOR;
    l_name VARCHAR2(240);
    l_display_name VARCHAR2(240);
    l_desc VARCHAR2(2000);
    l_value VARCHAR2(2000);
    l_level VARCHAR2(100);
    l_level_val NUMBER;
BEGIN
    fnd_profile.get_all(
        p_user_id => 1001,
        p_cursor => l_cursor
    );
    
    DBMS_OUTPUT.PUT_LINE('Profile Values for User 1001');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 80, '='));
    DBMS_OUTPUT.PUT_LINE(
        RPAD('Profile', 30) || 
        RPAD('Value', 30) || 
        RPAD('Level', 20)
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
    
    LOOP
        FETCH l_cursor INTO l_name, l_display_name, l_desc, 
                           l_value, l_level, l_level_val;
        EXIT WHEN l_cursor%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE(
            RPAD(SUBSTR(l_name, 1, 29), 30) || 
            RPAD(SUBSTR(l_value, 1, 29), 30) || 
            RPAD(l_level, 20)
        );
    END LOOP;
    
    CLOSE l_cursor;
END;
/

-- Copy profile values from one user to another
DECLARE
    l_cursor SYS_REFCURSOR;
    l_name VARCHAR2(240);
    l_value VARCHAR2(2000);
    
    l_source_user_id NUMBER := 1001;
    l_target_user_id NUMBER := 1005;
BEGIN
    -- Get all user-level profiles for source user
    FOR rec IN (
        SELECT po.profile_option_name,
               pov.profile_option_value
        FROM   fnd_profile_options po,
               fnd_profile_option_values pov
        WHERE  po.profile_option_id = pov.profile_option_id
        AND    pov.level_id = fnd_profile.g_level_user
        AND    pov.level_value = l_source_user_id
        AND    po.enabled_flag = 'Y'
        AND    pov.enabled_flag = 'Y'
    ) LOOP
        -- Save to target user
        fnd_profile.save(
            p_profile_name => rec.profile_option_name,
            p_value => rec.profile_option_value,
            p_level_id => fnd_profile.g_level_user,
            p_level_value => l_target_user_id,
            p_user_id => l_target_user_id
        );
        
        DBMS_OUTPUT.PUT_LINE(
            'Copied: ' || rec.profile_option_name || 
            ' = ' || rec.profile_option_value
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('Profile copy completed.');
END;
/

-- Validate all profile values against SQL validation
DECLARE
    l_valid BOOLEAN;
    l_result NUMBER;
BEGIN
    FOR rec IN (
        SELECT po.profile_option_name,
               po.sql_validation,
               pov.profile_option_value
        FROM   fnd_profile_options po,
               fnd_profile_option_values pov
        WHERE  po.profile_option_id = pov.profile_option_id
        AND    po.sql_validation IS NOT NULL
        AND    po.enabled_flag = 'Y'
        AND    pov.enabled_flag = 'Y'
    ) LOOP
        BEGIN
            -- Execute validation SQL
            EXECUTE IMMEDIATE rec.sql_validation 
                INTO l_result
                USING rec.profile_option_value;
            
            IF l_result > 0 THEN
                DBMS_OUTPUT.PUT_LINE(
                    'VALID: ' || rec.profile_option_name || 
                    ' = ' || rec.profile_option_value
                );
            ELSE
                DBMS_OUTPUT.PUT_LINE(
                    'INVALID: ' || rec.profile_option_name || 
                    ' = ' || rec.profile_option_value
                );
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(
                    'ERROR validating ' || rec.profile_option_name || 
                    ': ' || SQLERRM
                );
        END;
    END LOOP;
END;
/

-- ============================================================================
-- END OF QUICK REFERENCE GUIDE
-- ============================================================================
