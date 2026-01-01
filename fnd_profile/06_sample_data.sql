/*
================================================================================
  FND_PROFILE Sample Data
  Test data to demonstrate the profile options functionality
  
  Author: Database Team
  Version: 1.0
  Target: Oracle 19c+
================================================================================
*/

-- ============================================================================
-- Sample Applications
-- ============================================================================
INSERT INTO fnd_application (application_id, application_short_name, application_name, description)
VALUES (100, 'FND', 'Application Foundation', 'Oracle Application Foundation');

INSERT INTO fnd_application (application_id, application_short_name, application_name, description)
VALUES (200, 'GL', 'General Ledger', 'Oracle General Ledger');

INSERT INTO fnd_application (application_id, application_short_name, application_name, description)
VALUES (300, 'AP', 'Accounts Payable', 'Oracle Accounts Payable');

INSERT INTO fnd_application (application_id, application_short_name, application_name, description)
VALUES (400, 'AR', 'Accounts Receivable', 'Oracle Accounts Receivable');

INSERT INTO fnd_application (application_id, application_short_name, application_name, description)
VALUES (500, 'INV', 'Inventory', 'Oracle Inventory Management');

COMMIT;

-- ============================================================================
-- Sample Responsibilities
-- ============================================================================
INSERT INTO fnd_responsibility (responsibility_id, application_id, responsibility_key, responsibility_name, description)
VALUES (1001, 100, 'SYSTEM_ADMIN', 'System Administrator', 'System Administrator Responsibility');

INSERT INTO fnd_responsibility (responsibility_id, application_id, responsibility_key, responsibility_name, description)
VALUES (1002, 200, 'GL_MANAGER', 'General Ledger Manager', 'GL Manager Responsibility');

INSERT INTO fnd_responsibility (responsibility_id, application_id, responsibility_key, responsibility_name, description)
VALUES (1003, 200, 'GL_USER', 'General Ledger User', 'GL User Responsibility');

INSERT INTO fnd_responsibility (responsibility_id, application_id, responsibility_key, responsibility_name, description)
VALUES (1004, 300, 'AP_MANAGER', 'Accounts Payable Manager', 'AP Manager Responsibility');

INSERT INTO fnd_responsibility (responsibility_id, application_id, responsibility_key, responsibility_name, description)
VALUES (1005, 400, 'AR_MANAGER', 'Accounts Receivable Manager', 'AR Manager Responsibility');

COMMIT;

-- ============================================================================
-- Sample Users
-- ============================================================================
INSERT INTO fnd_user (user_id, user_name, email_address, description)
VALUES (1, 'SYSADMIN', 'sysadmin@company.com', 'System Administrator User');

INSERT INTO fnd_user (user_id, user_name, email_address, description)
VALUES (100, 'JSMITH', 'john.smith@company.com', 'John Smith - GL Manager');

INSERT INTO fnd_user (user_id, user_name, email_address, description)
VALUES (101, 'MJOHNSON', 'mary.johnson@company.com', 'Mary Johnson - AP Manager');

INSERT INTO fnd_user (user_id, user_name, email_address, description)
VALUES (102, 'RWILLIAMS', 'robert.williams@company.com', 'Robert Williams - AR Manager');

INSERT INTO fnd_user (user_id, user_name, email_address, description)
VALUES (103, 'LBROWN', 'lisa.brown@company.com', 'Lisa Brown - GL User');

COMMIT;

-- ============================================================================
-- Sample User-Responsibility Assignments
-- ============================================================================
INSERT INTO fnd_user_resp_groups (user_id, responsibility_id, responsibility_application_id, description)
VALUES (1, 1001, 100, 'Sysadmin to System Administrator');

INSERT INTO fnd_user_resp_groups (user_id, responsibility_id, responsibility_application_id, description)
VALUES (100, 1002, 200, 'John Smith to GL Manager');

INSERT INTO fnd_user_resp_groups (user_id, responsibility_id, responsibility_application_id, description)
VALUES (101, 1004, 300, 'Mary Johnson to AP Manager');

INSERT INTO fnd_user_resp_groups (user_id, responsibility_id, responsibility_application_id, description)
VALUES (102, 1005, 400, 'Robert Williams to AR Manager');

INSERT INTO fnd_user_resp_groups (user_id, responsibility_id, responsibility_application_id, description)
VALUES (103, 1003, 200, 'Lisa Brown to GL User');

COMMIT;

-- ============================================================================
-- Sample Profile Options
-- ============================================================================

-- Language Profile
INSERT INTO fnd_profile_options (
    profile_option_id, profile_option_name, application_id, 
    user_profile_option_name, description,
    user_changeable_flag, user_visible_flag
) VALUES (
    fnd_profile_options_s.NEXTVAL, 'FND_LANGUAGE', 100,
    'Default Language', 'Default language for the session',
    'Y', 'Y'
);

-- Currency Profile
INSERT INTO fnd_profile_options (
    profile_option_id, profile_option_name, application_id, 
    user_profile_option_name, description,
    user_changeable_flag, user_visible_flag
) VALUES (
    fnd_profile_options_s.NEXTVAL, 'GL_SET_OF_BOOKS_ID', 200,
    'Set of Books ID', 'Default Set of Books for GL transactions',
    'N', 'Y'
);

-- Date Format Profile
INSERT INTO fnd_profile_options (
    profile_option_id, profile_option_name, application_id, 
    user_profile_option_name, description,
    user_changeable_flag, user_visible_flag
) VALUES (
    fnd_profile_options_s.NEXTVAL, 'FND_DATE_FORMAT', 100,
    'Date Format', 'Display date format',
    'Y', 'Y'
);

-- Rows Per Page Profile
INSERT INTO fnd_profile_options (
    profile_option_id, profile_option_name, application_id, 
    user_profile_option_name, description,
    user_changeable_flag, user_visible_flag
) VALUES (
    fnd_profile_options_s.NEXTVAL, 'FND_ROWS_PER_PAGE', 100,
    'Rows Per Page', 'Number of rows to display per page',
    'Y', 'Y'
);

-- Debug Mode Profile
INSERT INTO fnd_profile_options (
    profile_option_id, profile_option_name, application_id, 
    user_profile_option_name, description,
    user_changeable_flag, user_visible_flag,
    user_enabled_flag, user_update_allowed_flag
) VALUES (
    fnd_profile_options_s.NEXTVAL, 'FND_DEBUG_MODE', 100,
    'Debug Mode', 'Enable debug logging',
    'N', 'Y', 'N', 'N'
);

-- Session Timeout Profile
INSERT INTO fnd_profile_options (
    profile_option_id, profile_option_name, application_id, 
    user_profile_option_name, description,
    user_changeable_flag, user_visible_flag
) VALUES (
    fnd_profile_options_s.NEXTVAL, 'FND_SESSION_TIMEOUT', 100,
    'Session Timeout (Minutes)', 'Session inactivity timeout in minutes',
    'N', 'Y'
);

-- AP Invoice Approval Amount Profile
INSERT INTO fnd_profile_options (
    profile_option_id, profile_option_name, application_id, 
    user_profile_option_name, description,
    user_changeable_flag, user_visible_flag
) VALUES (
    fnd_profile_options_s.NEXTVAL, 'AP_APPROVAL_AMOUNT', 300,
    'Invoice Approval Amount Limit', 'Maximum amount a user can approve',
    'N', 'Y'
);

-- Email Notification Profile
INSERT INTO fnd_profile_options (
    profile_option_id, profile_option_name, application_id, 
    user_profile_option_name, description,
    user_changeable_flag, user_visible_flag
) VALUES (
    fnd_profile_options_s.NEXTVAL, 'FND_EMAIL_NOTIFICATIONS', 100,
    'Email Notifications', 'Enable email notifications (Y/N)',
    'Y', 'Y'
);

COMMIT;

-- ============================================================================
-- Sample Profile Values at Different Levels
-- ============================================================================

-- Site Level Values
-- Get profile option IDs first
DECLARE
    v_lang_id NUMBER;
    v_date_id NUMBER;
    v_rows_id NUMBER;
    v_debug_id NUMBER;
    v_timeout_id NUMBER;
    v_email_id NUMBER;
    v_approval_id NUMBER;
BEGIN
    SELECT profile_option_id INTO v_lang_id FROM fnd_profile_options WHERE profile_option_name = 'FND_LANGUAGE';
    SELECT profile_option_id INTO v_date_id FROM fnd_profile_options WHERE profile_option_name = 'FND_DATE_FORMAT';
    SELECT profile_option_id INTO v_rows_id FROM fnd_profile_options WHERE profile_option_name = 'FND_ROWS_PER_PAGE';
    SELECT profile_option_id INTO v_debug_id FROM fnd_profile_options WHERE profile_option_name = 'FND_DEBUG_MODE';
    SELECT profile_option_id INTO v_timeout_id FROM fnd_profile_options WHERE profile_option_name = 'FND_SESSION_TIMEOUT';
    SELECT profile_option_id INTO v_email_id FROM fnd_profile_options WHERE profile_option_name = 'FND_EMAIL_NOTIFICATIONS';
    SELECT profile_option_id INTO v_approval_id FROM fnd_profile_options WHERE profile_option_name = 'AP_APPROVAL_AMOUNT';
    
    -- Site level values
    INSERT INTO fnd_profile_option_values (profile_option_id, level_id, level_value, profile_option_value)
    VALUES (v_lang_id, 10001, 0, 'US');
    
    INSERT INTO fnd_profile_option_values (profile_option_id, level_id, level_value, profile_option_value)
    VALUES (v_date_id, 10001, 0, 'DD-MON-YYYY');
    
    INSERT INTO fnd_profile_option_values (profile_option_id, level_id, level_value, profile_option_value)
    VALUES (v_rows_id, 10001, 0, '25');
    
    INSERT INTO fnd_profile_option_values (profile_option_id, level_id, level_value, profile_option_value)
    VALUES (v_debug_id, 10001, 0, 'N');
    
    INSERT INTO fnd_profile_option_values (profile_option_id, level_id, level_value, profile_option_value)
    VALUES (v_timeout_id, 10001, 0, '30');
    
    INSERT INTO fnd_profile_option_values (profile_option_id, level_id, level_value, profile_option_value)
    VALUES (v_email_id, 10001, 0, 'Y');
    
    INSERT INTO fnd_profile_option_values (profile_option_id, level_id, level_value, profile_option_value)
    VALUES (v_approval_id, 10001, 0, '1000');
    
    -- Application level values (GL application gets different date format)
    INSERT INTO fnd_profile_option_values (profile_option_id, level_id, level_value, profile_option_value)
    VALUES (v_date_id, 10002, 200, 'YYYY-MM-DD');
    
    -- Responsibility level values (AP Manager gets higher approval amount)
    INSERT INTO fnd_profile_option_values (profile_option_id, level_id, level_value, level_value_application_id, profile_option_value)
    VALUES (v_approval_id, 10003, 1004, 300, '50000');
    
    -- User level values
    -- Sysadmin gets debug mode enabled
    INSERT INTO fnd_profile_option_values (profile_option_id, level_id, level_value, profile_option_value)
    VALUES (v_debug_id, 10004, 1, 'Y');
    
    -- John Smith prefers more rows per page
    INSERT INTO fnd_profile_option_values (profile_option_id, level_id, level_value, profile_option_value)
    VALUES (v_rows_id, 10004, 100, '50');
    
    -- Mary Johnson prefers UK English
    INSERT INTO fnd_profile_option_values (profile_option_id, level_id, level_value, profile_option_value)
    VALUES (v_lang_id, 10004, 101, 'GB');
    
    COMMIT;
END;
/

-- ============================================================================
-- Verification Queries
-- ============================================================================
PROMPT
PROMPT ========================================
PROMPT Profile Options Summary
PROMPT ========================================
SELECT profile_option_name, user_profile_option_name, application_short_name
FROM fnd_profile_options_vl
ORDER BY profile_option_name;

PROMPT
PROMPT ========================================
PROMPT Profile Values at All Levels
PROMPT ========================================
SELECT profile_option_name, level_name, level_value_display, profile_option_value
FROM fnd_profile_option_values_v
ORDER BY profile_option_name, hierarchy_order DESC;

PROMPT
PROMPT ========================================
PROMPT Profile Summary Statistics
PROMPT ========================================
SELECT profile_option_name, site_value_count, app_value_count, resp_value_count, user_value_count, total_value_count
FROM fnd_profile_summary_v
ORDER BY profile_option_name;

/*
================================================================================
  End of Sample Data
================================================================================
*/
