/*******************************************************************************
 * Oracle APEX Dynamic Authorization Scheme
 * DDL Script - Table Creation
 * 
 * Purpose: Create comprehensive authorization tables for controlling access
 *          to Menus, Pages, Regions, and Buttons in Oracle APEX
 * 
 * Author: Generated for Oracle APEX 19c+
 * Date: January 2026
 ******************************************************************************/

-- ============================================================================
-- 1. ROLES TABLE
-- Stores all authorization roles in the system
-- ============================================================================
CREATE TABLE apex_auth_roles (
    role_id             NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_code           VARCHAR2(100) NOT NULL UNIQUE,
    role_name           VARCHAR2(200) NOT NULL,
    role_description    VARCHAR2(4000),
    is_active           VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (is_active IN ('Y', 'N')),
    created_by          VARCHAR2(100) DEFAULT USER NOT NULL,
    created_date        DATE DEFAULT SYSDATE NOT NULL,
    modified_by         VARCHAR2(100),
    modified_date       DATE,
    CONSTRAINT apex_auth_roles_uk1 UNIQUE (role_code)
);

COMMENT ON TABLE apex_auth_roles IS 'Stores authorization roles for APEX application';
COMMENT ON COLUMN apex_auth_roles.role_code IS 'Unique code for the role (e.g., ADMIN, MANAGER, USER)';
COMMENT ON COLUMN apex_auth_roles.role_name IS 'Display name for the role';
COMMENT ON COLUMN apex_auth_roles.is_active IS 'Y = Active, N = Inactive';

CREATE INDEX apex_auth_roles_idx1 ON apex_auth_roles(role_code, is_active);

-- ============================================================================
-- 2. USERS TABLE
-- Stores user information and their status
-- ============================================================================
CREATE TABLE apex_auth_users (
    user_id             NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username            VARCHAR2(100) NOT NULL UNIQUE,
    email               VARCHAR2(200),
    full_name           VARCHAR2(200),
    is_active           VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (is_active IN ('Y', 'N')),
    is_locked           VARCHAR2(1) DEFAULT 'N' NOT NULL CHECK (is_locked IN ('Y', 'N')),
    effective_from      DATE DEFAULT SYSDATE NOT NULL,
    effective_to        DATE,
    created_by          VARCHAR2(100) DEFAULT USER NOT NULL,
    created_date        DATE DEFAULT SYSDATE NOT NULL,
    modified_by         VARCHAR2(100),
    modified_date       DATE,
    CONSTRAINT apex_auth_users_uk1 UNIQUE (UPPER(username))
);

COMMENT ON TABLE apex_auth_users IS 'Stores user information for authorization';
COMMENT ON COLUMN apex_auth_users.username IS 'APEX username (case-insensitive)';
COMMENT ON COLUMN apex_auth_users.is_locked IS 'Y = Account locked, N = Active';
COMMENT ON COLUMN apex_auth_users.effective_from IS 'Start date for user access';
COMMENT ON COLUMN apex_auth_users.effective_to IS 'End date for user access (NULL = no end date)';

CREATE INDEX apex_auth_users_idx1 ON apex_auth_users(UPPER(username), is_active);
CREATE INDEX apex_auth_users_idx2 ON apex_auth_users(is_active, is_locked);

-- ============================================================================
-- 3. USER-ROLE ASSIGNMENTS
-- Maps users to roles with temporal validity
-- ============================================================================
CREATE TABLE apex_auth_user_roles (
    user_role_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id             NUMBER NOT NULL,
    role_id             NUMBER NOT NULL,
    effective_from      DATE DEFAULT SYSDATE NOT NULL,
    effective_to        DATE,
    is_active           VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (is_active IN ('Y', 'N')),
    created_by          VARCHAR2(100) DEFAULT USER NOT NULL,
    created_date        DATE DEFAULT SYSDATE NOT NULL,
    modified_by         VARCHAR2(100),
    modified_date       DATE,
    CONSTRAINT apex_auth_user_roles_fk1 FOREIGN KEY (user_id) 
        REFERENCES apex_auth_users(user_id) ON DELETE CASCADE,
    CONSTRAINT apex_auth_user_roles_fk2 FOREIGN KEY (role_id) 
        REFERENCES apex_auth_roles(role_id) ON DELETE CASCADE,
    CONSTRAINT apex_auth_user_roles_uk1 UNIQUE (user_id, role_id)
);

COMMENT ON TABLE apex_auth_user_roles IS 'Assigns roles to users with temporal validity';
COMMENT ON COLUMN apex_auth_user_roles.effective_from IS 'Start date for role assignment';
COMMENT ON COLUMN apex_auth_user_roles.effective_to IS 'End date for role assignment (NULL = no end date)';

CREATE INDEX apex_auth_user_roles_idx1 ON apex_auth_user_roles(user_id, is_active);
CREATE INDEX apex_auth_user_roles_idx2 ON apex_auth_user_roles(role_id, is_active);
CREATE INDEX apex_auth_user_roles_idx3 ON apex_auth_user_roles(effective_from, effective_to);

-- ============================================================================
-- 4. AUTHORIZATION OBJECTS
-- Stores all objects that can be secured (Menus, Pages, Regions, Buttons)
-- ============================================================================
CREATE TABLE apex_auth_objects (
    object_id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    application_id      NUMBER NOT NULL,
    object_type         VARCHAR2(20) NOT NULL CHECK (object_type IN ('MENU', 'PAGE', 'REGION', 'BUTTON', 'ITEM')),
    object_code         VARCHAR2(200) NOT NULL,
    object_name         VARCHAR2(500) NOT NULL,
    page_id             NUMBER,
    parent_object_id    NUMBER,
    object_description  VARCHAR2(4000),
    is_active           VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (is_active IN ('Y', 'N')),
    created_by          VARCHAR2(100) DEFAULT USER NOT NULL,
    created_date        DATE DEFAULT SYSDATE NOT NULL,
    modified_by         VARCHAR2(100),
    modified_date       DATE,
    CONSTRAINT apex_auth_objects_fk1 FOREIGN KEY (parent_object_id) 
        REFERENCES apex_auth_objects(object_id) ON DELETE CASCADE,
    CONSTRAINT apex_auth_objects_uk1 UNIQUE (application_id, object_type, object_code)
);

COMMENT ON TABLE apex_auth_objects IS 'Stores all secureable objects in APEX application';
COMMENT ON COLUMN apex_auth_objects.object_type IS 'MENU, PAGE, REGION, BUTTON, or ITEM';
COMMENT ON COLUMN apex_auth_objects.object_code IS 'Unique identifier for the object (static ID in APEX)';
COMMENT ON COLUMN apex_auth_objects.page_id IS 'APEX page number (NULL for menus)';
COMMENT ON COLUMN apex_auth_objects.parent_object_id IS 'Parent object (e.g., page for region)';

CREATE INDEX apex_auth_objects_idx1 ON apex_auth_objects(application_id, object_type, is_active);
CREATE INDEX apex_auth_objects_idx2 ON apex_auth_objects(object_code);
CREATE INDEX apex_auth_objects_idx3 ON apex_auth_objects(page_id);
CREATE INDEX apex_auth_objects_idx4 ON apex_auth_objects(parent_object_id);

-- ============================================================================
-- 5. PERMISSIONS
-- Defines specific permissions that can be granted
-- ============================================================================
CREATE TABLE apex_auth_permissions (
    permission_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    permission_code     VARCHAR2(100) NOT NULL UNIQUE,
    permission_name     VARCHAR2(200) NOT NULL,
    permission_type     VARCHAR2(20) NOT NULL CHECK (permission_type IN ('VIEW', 'EDIT', 'DELETE', 'EXECUTE', 'ADMIN')),
    permission_desc     VARCHAR2(4000),
    is_active           VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (is_active IN ('Y', 'N')),
    created_by          VARCHAR2(100) DEFAULT USER NOT NULL,
    created_date        DATE DEFAULT SYSDATE NOT NULL,
    modified_by         VARCHAR2(100),
    modified_date       DATE
);

COMMENT ON TABLE apex_auth_permissions IS 'Defines available permissions in the system';
COMMENT ON COLUMN apex_auth_permissions.permission_type IS 'VIEW=Read, EDIT=Modify, DELETE=Remove, EXECUTE=Run, ADMIN=Full Control';

CREATE INDEX apex_auth_permissions_idx1 ON apex_auth_permissions(permission_code, is_active);

-- ============================================================================
-- 6. ROLE PERMISSIONS
-- Assigns permissions to roles for specific objects
-- ============================================================================
CREATE TABLE apex_auth_role_permissions (
    role_permission_id  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_id             NUMBER NOT NULL,
    object_id           NUMBER NOT NULL,
    permission_id       NUMBER NOT NULL,
    is_granted          VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (is_granted IN ('Y', 'N')),
    effective_from      DATE DEFAULT SYSDATE NOT NULL,
    effective_to        DATE,
    created_by          VARCHAR2(100) DEFAULT USER NOT NULL,
    created_date        DATE DEFAULT SYSDATE NOT NULL,
    modified_by         VARCHAR2(100),
    modified_date       DATE,
    CONSTRAINT apex_auth_role_perm_fk1 FOREIGN KEY (role_id) 
        REFERENCES apex_auth_roles(role_id) ON DELETE CASCADE,
    CONSTRAINT apex_auth_role_perm_fk2 FOREIGN KEY (object_id) 
        REFERENCES apex_auth_objects(object_id) ON DELETE CASCADE,
    CONSTRAINT apex_auth_role_perm_fk3 FOREIGN KEY (permission_id) 
        REFERENCES apex_auth_permissions(permission_id) ON DELETE CASCADE,
    CONSTRAINT apex_auth_role_perm_uk1 UNIQUE (role_id, object_id, permission_id)
);

COMMENT ON TABLE apex_auth_role_permissions IS 'Grants permissions to roles for specific objects';
COMMENT ON COLUMN apex_auth_role_permissions.is_granted IS 'Y = Permission granted, N = Explicitly denied';

CREATE INDEX apex_auth_role_perm_idx1 ON apex_auth_role_permissions(role_id, is_granted);
CREATE INDEX apex_auth_role_perm_idx2 ON apex_auth_role_permissions(object_id);
CREATE INDEX apex_auth_role_perm_idx3 ON apex_auth_role_permissions(permission_id);
CREATE INDEX apex_auth_role_perm_idx4 ON apex_auth_role_permissions(effective_from, effective_to);

-- ============================================================================
-- 7. USER-SPECIFIC OVERRIDES (Optional)
-- Allows user-level permissions that override role permissions
-- ============================================================================
CREATE TABLE apex_auth_user_permissions (
    user_permission_id  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id             NUMBER NOT NULL,
    object_id           NUMBER NOT NULL,
    permission_id       NUMBER NOT NULL,
    is_granted          VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (is_granted IN ('Y', 'N')),
    override_roles      VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (override_roles IN ('Y', 'N')),
    effective_from      DATE DEFAULT SYSDATE NOT NULL,
    effective_to        DATE,
    created_by          VARCHAR2(100) DEFAULT USER NOT NULL,
    created_date        DATE DEFAULT SYSDATE NOT NULL,
    modified_by         VARCHAR2(100),
    modified_date       DATE,
    CONSTRAINT apex_auth_user_perm_fk1 FOREIGN KEY (user_id) 
        REFERENCES apex_auth_users(user_id) ON DELETE CASCADE,
    CONSTRAINT apex_auth_user_perm_fk2 FOREIGN KEY (object_id) 
        REFERENCES apex_auth_objects(object_id) ON DELETE CASCADE,
    CONSTRAINT apex_auth_user_perm_fk3 FOREIGN KEY (permission_id) 
        REFERENCES apex_auth_permissions(permission_id) ON DELETE CASCADE,
    CONSTRAINT apex_auth_user_perm_uk1 UNIQUE (user_id, object_id, permission_id)
);

COMMENT ON TABLE apex_auth_user_permissions IS 'User-specific permission overrides';
COMMENT ON COLUMN apex_auth_user_permissions.override_roles IS 'Y = Override role permissions, N = Combine with roles';

CREATE INDEX apex_auth_user_perm_idx1 ON apex_auth_user_permissions(user_id, is_granted);
CREATE INDEX apex_auth_user_perm_idx2 ON apex_auth_user_permissions(object_id);
CREATE INDEX apex_auth_user_perm_idx3 ON apex_auth_user_permissions(effective_from, effective_to);

-- ============================================================================
-- 8. AUDIT LOG
-- Tracks authorization checks for compliance and debugging
-- ============================================================================
CREATE TABLE apex_auth_audit_log (
    audit_id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username            VARCHAR2(100) NOT NULL,
    application_id      NUMBER,
    page_id             NUMBER,
    object_type         VARCHAR2(20),
    object_code         VARCHAR2(200),
    permission_type     VARCHAR2(20),
    authorization_result VARCHAR2(10) NOT NULL CHECK (authorization_result IN ('GRANTED', 'DENIED')),
    reason              VARCHAR2(4000),
    session_id          NUMBER,
    ip_address          VARCHAR2(100),
    audit_timestamp     TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE apex_auth_audit_log IS 'Audit trail for authorization checks';
COMMENT ON COLUMN apex_auth_audit_log.authorization_result IS 'GRANTED or DENIED';

CREATE INDEX apex_auth_audit_log_idx1 ON apex_auth_audit_log(username, audit_timestamp);
CREATE INDEX apex_auth_audit_log_idx2 ON apex_auth_audit_log(authorization_result);
CREATE INDEX apex_auth_audit_log_idx3 ON apex_auth_audit_log(audit_timestamp);

-- ============================================================================
-- 9. CONFIGURATION PARAMETERS
-- System-wide authorization configuration
-- ============================================================================
CREATE TABLE apex_auth_config (
    config_id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    config_key          VARCHAR2(100) NOT NULL UNIQUE,
    config_value        VARCHAR2(4000),
    config_description  VARCHAR2(4000),
    data_type           VARCHAR2(20) DEFAULT 'STRING' CHECK (data_type IN ('STRING', 'NUMBER', 'BOOLEAN', 'DATE')),
    is_active           VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (is_active IN ('Y', 'N')),
    modified_by         VARCHAR2(100),
    modified_date       DATE
);

COMMENT ON TABLE apex_auth_config IS 'System configuration for authorization scheme';

CREATE INDEX apex_auth_config_idx1 ON apex_auth_config(config_key, is_active);

-- ============================================================================
-- Insert Default Configuration
-- ============================================================================
INSERT INTO apex_auth_config (config_key, config_value, config_description, data_type) VALUES
    ('ENABLE_AUDIT_LOG', 'Y', 'Enable authorization audit logging (Y/N)', 'BOOLEAN');

INSERT INTO apex_auth_config (config_key, config_value, config_description, data_type) VALUES
    ('DEFAULT_PERMISSION', 'DENY', 'Default permission when no rule exists (DENY/ALLOW)', 'STRING');

INSERT INTO apex_auth_config (config_key, config_value, config_description, data_type) VALUES
    ('CACHE_TIMEOUT_SECONDS', '300', 'Authorization cache timeout in seconds', 'NUMBER');

INSERT INTO apex_auth_config (config_key, config_value, config_description, data_type) VALUES
    ('SUPERADMIN_ROLE', 'SUPERADMIN', 'Role code that has full access to everything', 'STRING');

COMMIT;

-- ============================================================================
-- Create Sequences (if not using IDENTITY columns in older Oracle versions)
-- Uncomment if needed for Oracle < 12c
-- ============================================================================
/*
CREATE SEQUENCE apex_auth_roles_seq START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE apex_auth_users_seq START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE apex_auth_user_roles_seq START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE apex_auth_objects_seq START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE apex_auth_permissions_seq START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE apex_auth_role_perm_seq START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE apex_auth_user_perm_seq START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE apex_auth_audit_log_seq START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE apex_auth_config_seq START WITH 1 INCREMENT BY 1 NOCACHE;
*/

PROMPT
PROMPT ============================================================================
PROMPT Authorization Tables Created Successfully
PROMPT ============================================================================
PROMPT
