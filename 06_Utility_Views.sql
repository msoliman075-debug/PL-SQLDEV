/*******************************************************************************
 * Oracle APEX Dynamic Authorization Scheme
 * Utility Views for Easier Querying
 * 
 * Purpose: Create convenient views for reporting and administration
 * 
 * Author: Generated for Oracle APEX 19c+
 * Date: January 2026
 ******************************************************************************/

-- ============================================================================
-- View 1: User Role Assignments with Details
-- ============================================================================
CREATE OR REPLACE VIEW apex_auth_v_user_roles AS
SELECT 
    u.user_id,
    u.username,
    u.email,
    u.full_name,
    u.is_active AS user_active,
    u.is_locked AS user_locked,
    r.role_id,
    r.role_code,
    r.role_name,
    r.role_description,
    ur.effective_from,
    ur.effective_to,
    ur.is_active AS assignment_active,
    CASE 
        WHEN u.is_active = 'N' THEN 'User Inactive'
        WHEN u.is_locked = 'Y' THEN 'User Locked'
        WHEN ur.is_active = 'N' THEN 'Assignment Inactive'
        WHEN SYSDATE < ur.effective_from THEN 'Not Yet Effective'
        WHEN ur.effective_to IS NOT NULL AND SYSDATE > ur.effective_to THEN 'Expired'
        ELSE 'Active'
    END AS status,
    ur.created_by,
    ur.created_date,
    ur.modified_by,
    ur.modified_date
FROM apex_auth_users u
INNER JOIN apex_auth_user_roles ur ON u.user_id = ur.user_id
INNER JOIN apex_auth_roles r ON ur.role_id = r.role_id;

COMMENT ON VIEW apex_auth_v_user_roles IS 
    'Complete view of user-role assignments with status';

-- ============================================================================
-- View 2: Role Permissions Matrix
-- ============================================================================
CREATE OR REPLACE VIEW apex_auth_v_role_permissions AS
SELECT 
    r.role_id,
    r.role_code,
    r.role_name,
    o.object_id,
    o.application_id,
    o.object_type,
    o.object_code,
    o.object_name,
    o.page_id,
    p.permission_id,
    p.permission_code,
    p.permission_type,
    rp.is_granted,
    rp.effective_from,
    rp.effective_to,
    CASE 
        WHEN rp.is_granted = 'N' THEN 'Explicitly Denied'
        WHEN SYSDATE < rp.effective_from THEN 'Not Yet Effective'
        WHEN rp.effective_to IS NOT NULL AND SYSDATE > rp.effective_to THEN 'Expired'
        ELSE 'Active'
    END AS status,
    rp.created_by,
    rp.created_date
FROM apex_auth_roles r
INNER JOIN apex_auth_role_permissions rp ON r.role_id = rp.role_id
INNER JOIN apex_auth_objects o ON rp.object_id = o.object_id
INNER JOIN apex_auth_permissions p ON rp.permission_id = p.permission_id;

COMMENT ON VIEW apex_auth_v_role_permissions IS 
    'Matrix view of role permissions across all objects';

-- ============================================================================
-- View 3: User Effective Permissions (Combined Role + User Overrides)
-- ============================================================================
CREATE OR REPLACE VIEW apex_auth_v_user_permissions AS
SELECT 
    u.user_id,
    u.username,
    u.full_name,
    o.object_id,
    o.application_id,
    o.object_type,
    o.object_code,
    o.object_name,
    o.page_id,
    p.permission_id,
    p.permission_code,
    p.permission_type,
    'ROLE' AS permission_source,
    r.role_code AS source_role,
    NULL AS override_flag,
    rp.is_granted,
    rp.effective_from,
    rp.effective_to,
    CASE 
        WHEN u.is_active = 'N' THEN 'User Inactive'
        WHEN u.is_locked = 'Y' THEN 'User Locked'
        WHEN ur.is_active = 'N' THEN 'Role Assignment Inactive'
        WHEN rp.is_granted = 'N' THEN 'Denied'
        WHEN SYSDATE < rp.effective_from THEN 'Not Yet Effective'
        WHEN rp.effective_to IS NOT NULL AND SYSDATE > rp.effective_to THEN 'Expired'
        ELSE 'Granted'
    END AS status
FROM apex_auth_users u
INNER JOIN apex_auth_user_roles ur ON u.user_id = ur.user_id
INNER JOIN apex_auth_roles r ON ur.role_id = r.role_id
INNER JOIN apex_auth_role_permissions rp ON r.role_id = rp.role_id
INNER JOIN apex_auth_objects o ON rp.object_id = o.object_id
INNER JOIN apex_auth_permissions p ON rp.permission_id = p.permission_id
WHERE ur.is_active = 'Y'
AND SYSDATE BETWEEN ur.effective_from AND NVL(ur.effective_to, SYSDATE + 1)

UNION ALL

SELECT 
    u.user_id,
    u.username,
    u.full_name,
    o.object_id,
    o.application_id,
    o.object_type,
    o.object_code,
    o.object_name,
    o.page_id,
    p.permission_id,
    p.permission_code,
    p.permission_type,
    'USER_OVERRIDE' AS permission_source,
    NULL AS source_role,
    up.override_roles AS override_flag,
    up.is_granted,
    up.effective_from,
    up.effective_to,
    CASE 
        WHEN u.is_active = 'N' THEN 'User Inactive'
        WHEN u.is_locked = 'Y' THEN 'User Locked'
        WHEN up.is_granted = 'N' THEN 'Denied'
        WHEN SYSDATE < up.effective_from THEN 'Not Yet Effective'
        WHEN up.effective_to IS NOT NULL AND SYSDATE > up.effective_to THEN 'Expired'
        ELSE 'Granted'
    END AS status
FROM apex_auth_users u
INNER JOIN apex_auth_user_permissions up ON u.user_id = up.user_id
INNER JOIN apex_auth_objects o ON up.object_id = o.object_id
INNER JOIN apex_auth_permissions p ON up.permission_id = p.permission_id;

COMMENT ON VIEW apex_auth_v_user_permissions IS 
    'Combined view of user permissions from roles and user-specific overrides';

-- ============================================================================
-- View 4: Authorization Audit Summary
-- ============================================================================
CREATE OR REPLACE VIEW apex_auth_v_audit_summary AS
SELECT 
    TRUNC(audit_timestamp) AS audit_date,
    username,
    application_id,
    object_type,
    permission_type,
    authorization_result,
    COUNT(*) AS check_count,
    COUNT(DISTINCT session_id) AS unique_sessions,
    MIN(audit_timestamp) AS first_check,
    MAX(audit_timestamp) AS last_check
FROM apex_auth_audit_log
GROUP BY 
    TRUNC(audit_timestamp),
    username,
    application_id,
    object_type,
    permission_type,
    authorization_result;

COMMENT ON VIEW apex_auth_v_audit_summary IS 
    'Daily summary of authorization checks';

-- ============================================================================
-- View 5: Active Users with Roles Summary
-- ============================================================================
CREATE OR REPLACE VIEW apex_auth_v_active_users AS
SELECT 
    u.user_id,
    u.username,
    u.email,
    u.full_name,
    u.effective_from AS user_effective_from,
    u.effective_to AS user_effective_to,
    u.created_date,
    LISTAGG(r.role_code, ', ') WITHIN GROUP (ORDER BY r.role_code) AS roles,
    COUNT(DISTINCT r.role_id) AS role_count,
    MAX(u.modified_date) AS last_modified
FROM apex_auth_users u
LEFT JOIN apex_auth_user_roles ur 
    ON u.user_id = ur.user_id 
    AND ur.is_active = 'Y'
    AND SYSDATE BETWEEN ur.effective_from AND NVL(ur.effective_to, SYSDATE + 1)
LEFT JOIN apex_auth_roles r 
    ON ur.role_id = r.role_id
WHERE u.is_active = 'Y'
AND u.is_locked = 'N'
AND SYSDATE BETWEEN u.effective_from AND NVL(u.effective_to, SYSDATE + 1)
GROUP BY 
    u.user_id,
    u.username,
    u.email,
    u.full_name,
    u.effective_from,
    u.effective_to,
    u.created_date;

COMMENT ON VIEW apex_auth_v_active_users IS 
    'Active users with comma-separated list of their roles';

-- ============================================================================
-- View 6: Object Security Summary
-- ============================================================================
CREATE OR REPLACE VIEW apex_auth_v_object_security AS
SELECT 
    o.application_id,
    o.object_type,
    o.object_code,
    o.object_name,
    o.page_id,
    COUNT(DISTINCT rp.role_id) AS roles_with_access,
    COUNT(DISTINCT up.user_id) AS users_with_override,
    LISTAGG(DISTINCT r.role_code, ', ') WITHIN GROUP (ORDER BY r.role_code) AS authorized_roles,
    o.created_date AS registered_date,
    o.is_active AS object_active
FROM apex_auth_objects o
LEFT JOIN apex_auth_role_permissions rp 
    ON o.object_id = rp.object_id 
    AND rp.is_granted = 'Y'
    AND SYSDATE BETWEEN rp.effective_from AND NVL(rp.effective_to, SYSDATE + 1)
LEFT JOIN apex_auth_roles r 
    ON rp.role_id = r.role_id
LEFT JOIN apex_auth_user_permissions up 
    ON o.object_id = up.object_id
WHERE o.is_active = 'Y'
GROUP BY 
    o.application_id,
    o.object_type,
    o.object_code,
    o.object_name,
    o.page_id,
    o.created_date,
    o.is_active
ORDER BY 
    o.application_id,
    o.object_type,
    o.page_id NULLS FIRST,
    o.object_code;

COMMENT ON VIEW apex_auth_v_object_security IS 
    'Security summary for each registered object';

-- ============================================================================
-- View 7: Recent Authorization Denials
-- ============================================================================
CREATE OR REPLACE VIEW apex_auth_v_recent_denials AS
SELECT 
    audit_timestamp,
    username,
    application_id,
    page_id,
    object_type,
    object_code,
    permission_type,
    reason,
    session_id,
    ip_address
FROM apex_auth_audit_log
WHERE authorization_result = 'DENIED'
AND audit_timestamp > SYSDATE - 7  -- Last 7 days
ORDER BY audit_timestamp DESC;

COMMENT ON VIEW apex_auth_v_recent_denials IS 
    'Recent authorization denials for security monitoring';

-- ============================================================================
-- View 8: Expiring User Role Assignments
-- ============================================================================
CREATE OR REPLACE VIEW apex_auth_v_expiring_roles AS
SELECT 
    u.username,
    u.email,
    u.full_name,
    r.role_code,
    r.role_name,
    ur.effective_to AS expiration_date,
    TRUNC(ur.effective_to - SYSDATE) AS days_until_expiration,
    CASE 
        WHEN ur.effective_to <= SYSDATE THEN 'EXPIRED'
        WHEN ur.effective_to <= SYSDATE + 7 THEN 'EXPIRES THIS WEEK'
        WHEN ur.effective_to <= SYSDATE + 30 THEN 'EXPIRES THIS MONTH'
        ELSE 'FUTURE'
    END AS expiration_status
FROM apex_auth_users u
INNER JOIN apex_auth_user_roles ur ON u.user_id = ur.user_id
INNER JOIN apex_auth_roles r ON ur.role_id = r.role_id
WHERE ur.effective_to IS NOT NULL
AND ur.effective_to <= SYSDATE + 30  -- Next 30 days
AND ur.is_active = 'Y'
AND u.is_active = 'Y'
ORDER BY ur.effective_to;

COMMENT ON VIEW apex_auth_v_expiring_roles IS 
    'User role assignments expiring in the next 30 days';

-- ============================================================================
-- View 9: Users Without Roles
-- ============================================================================
CREATE OR REPLACE VIEW apex_auth_v_users_without_roles AS
SELECT 
    u.user_id,
    u.username,
    u.email,
    u.full_name,
    u.is_active,
    u.is_locked,
    u.created_date,
    u.created_by
FROM apex_auth_users u
WHERE u.is_active = 'Y'
AND u.is_locked = 'N'
AND NOT EXISTS (
    SELECT 1 
    FROM apex_auth_user_roles ur
    WHERE ur.user_id = u.user_id
    AND ur.is_active = 'Y'
    AND SYSDATE BETWEEN ur.effective_from AND NVL(ur.effective_to, SYSDATE + 1)
)
ORDER BY u.created_date DESC;

COMMENT ON VIEW apex_auth_v_users_without_roles IS 
    'Active users with no role assignments';

-- ============================================================================
-- View 10: Configuration Settings
-- ============================================================================
CREATE OR REPLACE VIEW apex_auth_v_config AS
SELECT 
    config_key,
    config_value,
    config_description,
    data_type,
    is_active,
    modified_by,
    modified_date,
    CASE 
        WHEN config_key = 'ENABLE_AUDIT_LOG' THEN 
            CASE WHEN config_value = 'Y' THEN 'Audit logging is ENABLED' 
                 ELSE 'Audit logging is DISABLED' END
        WHEN config_key = 'DEFAULT_PERMISSION' THEN 
            'Default permission when no rule exists: ' || config_value
        WHEN config_key = 'CACHE_TIMEOUT_SECONDS' THEN 
            'Cache expires after ' || config_value || ' seconds'
        WHEN config_key = 'SUPERADMIN_ROLE' THEN 
            'Super admin role code: ' || config_value
        ELSE config_description
    END AS setting_explanation
FROM apex_auth_config
WHERE is_active = 'Y'
ORDER BY config_key;

COMMENT ON VIEW apex_auth_v_config IS 
    'Active configuration settings with explanations';

-- ============================================================================
-- Grant SELECT on Views (adjust schema/roles as needed)
-- ============================================================================
-- Uncomment and modify as needed for your environment:
-- GRANT SELECT ON apex_auth_v_user_roles TO apex_user_role;
-- GRANT SELECT ON apex_auth_v_role_permissions TO apex_user_role;
-- etc.

PROMPT
PROMPT ============================================================================
PROMPT Authorization Views Created Successfully
PROMPT ============================================================================
PROMPT
PROMPT Available Views:
PROMPT   1. APEX_AUTH_V_USER_ROLES          - User-role assignments with status
PROMPT   2. APEX_AUTH_V_ROLE_PERMISSIONS    - Role permissions matrix
PROMPT   3. APEX_AUTH_V_USER_PERMISSIONS    - Combined user permissions
PROMPT   4. APEX_AUTH_V_AUDIT_SUMMARY       - Daily audit summary
PROMPT   5. APEX_AUTH_V_ACTIVE_USERS        - Active users with roles
PROMPT   6. APEX_AUTH_V_OBJECT_SECURITY     - Object security summary
PROMPT   7. APEX_AUTH_V_RECENT_DENIALS      - Recent authorization denials
PROMPT   8. APEX_AUTH_V_EXPIRING_ROLES      - Expiring role assignments
PROMPT   9. APEX_AUTH_V_USERS_WITHOUT_ROLES - Users without any roles
PROMPT  10. APEX_AUTH_V_CONFIG              - Configuration settings
PROMPT
PROMPT Usage Examples:
PROMPT   -- View all active users and their roles
PROMPT   SELECT * FROM apex_auth_v_active_users;
PROMPT
PROMPT   -- Check permissions for a specific user
PROMPT   SELECT * FROM apex_auth_v_user_permissions WHERE username = 'JOHN.DOE';
PROMPT
PROMPT   -- Monitor recent denials
PROMPT   SELECT * FROM apex_auth_v_recent_denials;
PROMPT
PROMPT   -- Check expiring roles
PROMPT   SELECT * FROM apex_auth_v_expiring_roles;
PROMPT
PROMPT ============================================================================
