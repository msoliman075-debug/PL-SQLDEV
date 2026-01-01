-- ============================================================================
-- Views for Profile Management
-- Description: Views for easier querying and reporting
-- ============================================================================

-- ============================================================================
-- View: FND_PROFILE_OPTIONS_VL
-- Description: User-friendly view of profile options with status
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_options_vl AS
SELECT po.profile_option_id,
       po.profile_option_name,
       po.user_profile_option_name,
       po.description,
       po.application_id,
       po.enabled_flag,
       po.start_date_active,
       po.end_date_active,
       CASE 
           WHEN po.enabled_flag = 'N' THEN 'Disabled'
           WHEN SYSDATE < po.start_date_active THEN 'Not Yet Active'
           WHEN po.end_date_active IS NOT NULL 
                AND SYSDATE > po.end_date_active THEN 'Expired'
           ELSE 'Active'
       END AS status,
       po.user_changeable_flag,
       po.user_visible_flag,
       po.read_only_flag,
       po.sql_validation,
       po.creation_date,
       po.created_by,
       po.last_update_date,
       po.last_updated_by
FROM   fnd_profile_options po;

COMMENT ON VIEW fnd_profile_options_vl IS 
    'User-friendly view of profile options with computed status';

-- ============================================================================
-- View: FND_PROFILE_OPTION_VALUES_VL
-- Description: User-friendly view of profile values with level names
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_option_values_vl AS
SELECT pov.profile_option_value_id,
       po.profile_option_name,
       po.user_profile_option_name,
       pov.profile_option_id,
       pov.application_id,
       pov.level_id,
       CASE pov.level_id
           WHEN 10001 THEN 'Site'
           WHEN 10002 THEN 'Application'
           WHEN 10003 THEN 'Responsibility'
           WHEN 10004 THEN 'User'
           WHEN 10005 THEN 'Server'
           WHEN 10006 THEN 'Organization'
           ELSE 'Unknown'
       END AS level_name,
       pov.level_value,
       pov.level_value_application_id,
       pov.profile_option_value,
       pov.enabled_flag,
       pov.start_date_active,
       pov.end_date_active,
       CASE 
           WHEN pov.enabled_flag = 'N' THEN 'Disabled'
           WHEN SYSDATE < pov.start_date_active THEN 'Not Yet Active'
           WHEN pov.end_date_active IS NOT NULL 
                AND SYSDATE > pov.end_date_active THEN 'Expired'
           ELSE 'Active'
       END AS status,
       pov.creation_date,
       pov.created_by,
       pov.last_update_date,
       pov.last_updated_by
FROM   fnd_profile_option_values pov,
       fnd_profile_options po
WHERE  pov.profile_option_id = po.profile_option_id;

COMMENT ON VIEW fnd_profile_option_values_vl IS 
    'User-friendly view of profile values with level names and status';

-- ============================================================================
-- View: FND_PROFILE_HIERARCHY_V
-- Description: Shows profile value hierarchy with priorities
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_hierarchy_v AS
SELECT po.profile_option_name,
       po.user_profile_option_name,
       po.description,
       CASE pov.level_id
           WHEN 10001 THEN 'Site'
           WHEN 10002 THEN 'Application'
           WHEN 10003 THEN 'Responsibility'
           WHEN 10004 THEN 'User'
           WHEN 10005 THEN 'Server'
           WHEN 10006 THEN 'Organization'
       END AS level_name,
       CASE pov.level_id
           WHEN 10004 THEN 1  -- User (highest priority)
           WHEN 10003 THEN 2  -- Responsibility
           WHEN 10002 THEN 3  -- Application
           WHEN 10006 THEN 4  -- Organization
           WHEN 10005 THEN 5  -- Server
           WHEN 10001 THEN 6  -- Site (lowest priority)
       END AS priority,
       pov.level_id,
       pov.level_value,
       pov.profile_option_value,
       pov.enabled_flag,
       CASE 
           WHEN pov.enabled_flag = 'N' THEN 'Disabled'
           WHEN SYSDATE < pov.start_date_active THEN 'Not Yet Active'
           WHEN pov.end_date_active IS NOT NULL 
                AND SYSDATE > pov.end_date_active THEN 'Expired'
           ELSE 'Active'
       END AS status
FROM   fnd_profile_options po,
       fnd_profile_option_values pov
WHERE  po.profile_option_id = pov.profile_option_id
AND    po.enabled_flag = 'Y'
AND    pov.enabled_flag = 'Y'
AND    SYSDATE BETWEEN po.start_date_active 
                   AND NVL(po.end_date_active, SYSDATE + 1)
AND    SYSDATE BETWEEN pov.start_date_active 
                   AND NVL(pov.end_date_active, SYSDATE + 1);

COMMENT ON VIEW fnd_profile_hierarchy_v IS 
    'Shows profile value hierarchy with priority ordering';

-- ============================================================================
-- View: FND_PROFILE_USER_VALUES_V
-- Description: Shows effective profile values for each user
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_user_values_v AS
SELECT DISTINCT
       pov.level_value AS user_id,
       po.profile_option_name,
       po.user_profile_option_name,
       pov.profile_option_value,
       CASE pov.level_id
           WHEN 10001 THEN 'Site'
           WHEN 10002 THEN 'Application'
           WHEN 10003 THEN 'Responsibility'
           WHEN 10004 THEN 'User'
           WHEN 10005 THEN 'Server'
           WHEN 10006 THEN 'Organization'
       END AS value_source
FROM   fnd_profile_options po,
       fnd_profile_option_values pov
WHERE  po.profile_option_id = pov.profile_option_id
AND    po.enabled_flag = 'Y'
AND    pov.enabled_flag = 'Y'
AND    pov.level_id = 10004  -- User level only
AND    SYSDATE BETWEEN po.start_date_active 
                   AND NVL(po.end_date_active, SYSDATE + 1)
AND    SYSDATE BETWEEN pov.start_date_active 
                   AND NVL(pov.end_date_active, SYSDATE + 1);

COMMENT ON VIEW fnd_profile_user_values_v IS 
    'Shows profile values set at user level';

-- ============================================================================
-- View: FND_PROFILE_AUDIT_V
-- Description: Audit trail view showing all profile changes
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_audit_v AS
SELECT po.profile_option_name,
       po.user_profile_option_name,
       CASE pov.level_id
           WHEN 10001 THEN 'Site'
           WHEN 10002 THEN 'Application'
           WHEN 10003 THEN 'Responsibility'
           WHEN 10004 THEN 'User'
           WHEN 10005 THEN 'Server'
           WHEN 10006 THEN 'Organization'
       END AS level_name,
       pov.level_value,
       pov.profile_option_value,
       pov.enabled_flag,
       pov.creation_date,
       pov.created_by,
       pov.last_update_date,
       pov.last_updated_by,
       CASE 
           WHEN pov.last_update_date > pov.creation_date THEN 'Updated'
           ELSE 'Created'
       END AS change_type
FROM   fnd_profile_options po,
       fnd_profile_option_values pov
WHERE  po.profile_option_id = pov.profile_option_id
ORDER BY pov.last_update_date DESC;

COMMENT ON VIEW fnd_profile_audit_v IS 
    'Audit trail showing creation and updates of profile values';

-- ============================================================================
-- View: FND_PROFILE_SUMMARY_V
-- Description: Summary statistics for profile options
-- ============================================================================
CREATE OR REPLACE VIEW fnd_profile_summary_v AS
SELECT po.profile_option_name,
       po.user_profile_option_name,
       po.enabled_flag,
       COUNT(pov.profile_option_value_id) AS total_values,
       SUM(CASE WHEN pov.level_id = 10001 THEN 1 ELSE 0 END) AS site_values,
       SUM(CASE WHEN pov.level_id = 10002 THEN 1 ELSE 0 END) AS application_values,
       SUM(CASE WHEN pov.level_id = 10003 THEN 1 ELSE 0 END) AS responsibility_values,
       SUM(CASE WHEN pov.level_id = 10004 THEN 1 ELSE 0 END) AS user_values,
       SUM(CASE WHEN pov.level_id = 10005 THEN 1 ELSE 0 END) AS server_values,
       SUM(CASE WHEN pov.level_id = 10006 THEN 1 ELSE 0 END) AS org_values,
       MAX(pov.last_update_date) AS last_modified_date
FROM   fnd_profile_options po
       LEFT OUTER JOIN fnd_profile_option_values pov
       ON po.profile_option_id = pov.profile_option_id
       AND pov.enabled_flag = 'Y'
WHERE  po.enabled_flag = 'Y'
GROUP BY po.profile_option_name,
         po.user_profile_option_name,
         po.enabled_flag;

COMMENT ON VIEW fnd_profile_summary_v IS 
    'Summary statistics showing count of values at each level per profile option';
