/*
================================================================================
  FND_PROFILE Views
  Similar to Oracle EBS FND_PROFILE views
  
  Author: Database Team
  Version: 1.0
  Target: Oracle 19c+
================================================================================
*/

-- ============================================================================
-- View: FND_PROFILE_OPTIONS_VL
-- Purpose: Profile options with display names
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_options_vl AS
SELECT 
    po.profile_option_id,
    po.profile_option_name,
    po.application_id,
    app.application_short_name,
    app.application_name,
    po.user_profile_option_name,
    po.description,
    po.user_changeable_flag,
    po.user_visible_flag,
    po.read_allowed_flag,
    po.write_allowed_flag,
    po.site_enabled_flag,
    po.site_update_allowed_flag,
    po.app_enabled_flag,
    po.app_update_allowed_flag,
    po.resp_enabled_flag,
    po.resp_update_allowed_flag,
    po.user_enabled_flag,
    po.user_update_allowed_flag,
    po.sql_validation,
    po.start_date_active,
    po.end_date_active,
    po.hierarchy_type,
    po.created_by,
    po.creation_date,
    po.last_updated_by,
    po.last_update_date
FROM fnd_profile_options po
JOIN fnd_application app ON po.application_id = app.application_id;

COMMENT ON TABLE fnd_profile_options_vl IS 'Profile options with application information';

-- ============================================================================
-- View: FND_PROFILE_OPTION_VALUES_V
-- Purpose: Profile option values with descriptive information
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_option_values_v AS
SELECT 
    pov.profile_option_value_id,
    po.profile_option_id,
    po.profile_option_name,
    po.user_profile_option_name,
    pl.level_id,
    pl.level_name,
    pov.level_value,
    pov.level_value_application_id,
    pov.profile_option_value,
    CASE pl.level_name
        WHEN 'SITE' THEN 'Site'
        WHEN 'APPLICATION' THEN (
            SELECT application_name 
            FROM fnd_application 
            WHERE application_id = pov.level_value
        )
        WHEN 'RESPONSIBILITY' THEN (
            SELECT responsibility_name 
            FROM fnd_responsibility 
            WHERE responsibility_id = pov.level_value
        )
        WHEN 'USER' THEN (
            SELECT user_name 
            FROM fnd_user 
            WHERE user_id = pov.level_value
        )
    END AS level_value_display,
    pl.hierarchy_order,
    pov.created_by,
    pov.creation_date,
    pov.last_updated_by,
    pov.last_update_date
FROM fnd_profile_option_values pov
JOIN fnd_profile_options po ON pov.profile_option_id = po.profile_option_id
JOIN fnd_profile_levels pl ON pov.level_id = pl.level_id;

COMMENT ON TABLE fnd_profile_option_values_v IS 'Profile option values with descriptive level information';

-- ============================================================================
-- View: FND_PROFILE_VALUES_BY_USER_V
-- Purpose: Get effective profile values for users
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_values_by_user_v AS
SELECT 
    u.user_id,
    u.user_name,
    po.profile_option_name,
    po.user_profile_option_name,
    COALESCE(
        user_val.profile_option_value,
        resp_val.profile_option_value,
        app_val.profile_option_value,
        site_val.profile_option_value
    ) AS effective_value,
    CASE 
        WHEN user_val.profile_option_value IS NOT NULL THEN 'USER'
        WHEN resp_val.profile_option_value IS NOT NULL THEN 'RESPONSIBILITY'
        WHEN app_val.profile_option_value IS NOT NULL THEN 'APPLICATION'
        WHEN site_val.profile_option_value IS NOT NULL THEN 'SITE'
    END AS effective_level,
    user_val.profile_option_value AS user_value,
    resp_val.profile_option_value AS resp_value,
    app_val.profile_option_value AS app_value,
    site_val.profile_option_value AS site_value
FROM fnd_user u
CROSS JOIN fnd_profile_options po
LEFT JOIN fnd_profile_option_values user_val 
    ON po.profile_option_id = user_val.profile_option_id
    AND user_val.level_id = 10004  -- USER level
    AND user_val.level_value = u.user_id
LEFT JOIN (
    -- Get responsibility value (uses first active responsibility for user)
    SELECT DISTINCT 
        pov.profile_option_id,
        urg.user_id,
        FIRST_VALUE(pov.profile_option_value) OVER (
            PARTITION BY pov.profile_option_id, urg.user_id 
            ORDER BY urg.start_date DESC
        ) AS profile_option_value
    FROM fnd_profile_option_values pov
    JOIN fnd_user_resp_groups urg 
        ON pov.level_value = urg.responsibility_id
        AND NVL(pov.level_value_application_id, 0) = NVL(urg.responsibility_application_id, 0)
    WHERE pov.level_id = 10003  -- RESP level
    AND SYSDATE BETWEEN urg.start_date AND NVL(urg.end_date, SYSDATE + 1)
) resp_val 
    ON po.profile_option_id = resp_val.profile_option_id
    AND resp_val.user_id = u.user_id
LEFT JOIN fnd_profile_option_values app_val 
    ON po.profile_option_id = app_val.profile_option_id
    AND app_val.level_id = 10002  -- APPLICATION level
    AND app_val.level_value = po.application_id
LEFT JOIN fnd_profile_option_values site_val 
    ON po.profile_option_id = site_val.profile_option_id
    AND site_val.level_id = 10001  -- SITE level
    AND site_val.level_value = 0
WHERE SYSDATE BETWEEN po.start_date_active AND NVL(po.end_date_active, SYSDATE + 1)
AND SYSDATE BETWEEN u.start_date AND NVL(u.end_date, SYSDATE + 1);

COMMENT ON TABLE fnd_profile_values_by_user_v IS 'Effective profile values for each user with hierarchy resolution';

-- ============================================================================
-- View: FND_PROFILE_SITE_VALUES_V
-- Purpose: Site-level profile values only
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_site_values_v AS
SELECT 
    po.profile_option_id,
    po.profile_option_name,
    po.user_profile_option_name,
    pov.profile_option_value,
    po.site_enabled_flag,
    po.site_update_allowed_flag,
    pov.created_by,
    pov.creation_date,
    pov.last_updated_by,
    pov.last_update_date
FROM fnd_profile_options po
LEFT JOIN fnd_profile_option_values pov 
    ON po.profile_option_id = pov.profile_option_id
    AND pov.level_id = 10001
    AND pov.level_value = 0
WHERE po.site_enabled_flag = 'Y'
AND SYSDATE BETWEEN po.start_date_active AND NVL(po.end_date_active, SYSDATE + 1);

COMMENT ON TABLE fnd_profile_site_values_v IS 'Site-level profile values';

-- ============================================================================
-- View: FND_PROFILE_USER_VALUES_V
-- Purpose: User-level profile values
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_user_values_v AS
SELECT 
    u.user_id,
    u.user_name,
    po.profile_option_id,
    po.profile_option_name,
    po.user_profile_option_name,
    pov.profile_option_value,
    po.user_enabled_flag,
    po.user_update_allowed_flag,
    po.user_changeable_flag,
    po.user_visible_flag,
    pov.created_by,
    pov.creation_date,
    pov.last_updated_by,
    pov.last_update_date
FROM fnd_user u
JOIN fnd_profile_option_values pov ON pov.level_value = u.user_id
JOIN fnd_profile_options po ON pov.profile_option_id = po.profile_option_id
WHERE pov.level_id = 10004
AND po.user_enabled_flag = 'Y'
AND SYSDATE BETWEEN po.start_date_active AND NVL(po.end_date_active, SYSDATE + 1)
AND SYSDATE BETWEEN u.start_date AND NVL(u.end_date, SYSDATE + 1);

COMMENT ON TABLE fnd_profile_user_values_v IS 'User-level profile values';

-- ============================================================================
-- View: FND_PROFILE_CHANGE_HISTORY_V
-- Purpose: Audit trail of profile changes
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_change_history_v AS
SELECT 
    h.history_id,
    po.profile_option_name,
    po.user_profile_option_name,
    pl.level_name,
    CASE pl.level_name
        WHEN 'SITE' THEN 'Site'
        WHEN 'APPLICATION' THEN (
            SELECT application_name 
            FROM fnd_application 
            WHERE application_id = h.level_value
        )
        WHEN 'RESPONSIBILITY' THEN (
            SELECT responsibility_name 
            FROM fnd_responsibility 
            WHERE responsibility_id = h.level_value
        )
        WHEN 'USER' THEN (
            SELECT user_name 
            FROM fnd_user 
            WHERE user_id = h.level_value
        )
    END AS level_value_display,
    h.old_profile_option_value,
    h.new_profile_option_value,
    h.change_type,
    h.changed_by,
    (SELECT user_name FROM fnd_user WHERE user_id = h.changed_by) AS changed_by_name,
    h.change_date
FROM fnd_profile_option_values_h h
JOIN fnd_profile_options po ON h.profile_option_id = po.profile_option_id
JOIN fnd_profile_levels pl ON h.level_id = pl.level_id
ORDER BY h.change_date DESC;

COMMENT ON TABLE fnd_profile_change_history_v IS 'Audit trail of all profile option value changes';

-- ============================================================================
-- View: FND_PROFILE_SUMMARY_V
-- Purpose: Summary of profile options with value counts at each level
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_summary_v AS
SELECT 
    po.profile_option_id,
    po.profile_option_name,
    po.user_profile_option_name,
    app.application_short_name,
    COUNT(CASE WHEN pov.level_id = 10001 THEN 1 END) AS site_value_count,
    COUNT(CASE WHEN pov.level_id = 10002 THEN 1 END) AS app_value_count,
    COUNT(CASE WHEN pov.level_id = 10003 THEN 1 END) AS resp_value_count,
    COUNT(CASE WHEN pov.level_id = 10004 THEN 1 END) AS user_value_count,
    COUNT(pov.profile_option_value_id) AS total_value_count,
    po.start_date_active,
    po.end_date_active,
    CASE 
        WHEN SYSDATE BETWEEN po.start_date_active AND NVL(po.end_date_active, SYSDATE + 1) 
        THEN 'Active' 
        ELSE 'Inactive' 
    END AS status
FROM fnd_profile_options po
JOIN fnd_application app ON po.application_id = app.application_id
LEFT JOIN fnd_profile_option_values pov ON po.profile_option_id = pov.profile_option_id
GROUP BY 
    po.profile_option_id,
    po.profile_option_name,
    po.user_profile_option_name,
    app.application_short_name,
    po.start_date_active,
    po.end_date_active;

COMMENT ON TABLE fnd_profile_summary_v IS 'Summary of profile options with value counts at each hierarchy level';

/*
================================================================================
  End of Views
================================================================================
*/
