/*
================================================================================
  Dynamic Authorization Scheme - DDL Tables
  Oracle APEX Security Framework
  
  Purpose: Create tables to store dynamic authorization configuration
           allowing end users to control access to Menus, Pages, Regions, Buttons
  
  Target: Oracle 19c+ / Oracle APEX 21.1+
  Author: APEX Security Framework
  
================================================================================
*/

-- ============================================================================
-- Drop existing objects (for clean installation)
-- ============================================================================
BEGIN
    FOR rec IN (
        SELECT table_name 
        FROM user_tables 
        WHERE table_name IN (
            'APEX_AUTH_ROLES',
            'APEX_AUTH_USER_ROLES',
            'APEX_AUTH_COMPONENT_TYPES',
            'APEX_AUTH_COMPONENTS',
            'APEX_AUTH_PERMISSIONS',
            'APEX_AUTH_AUDIT_LOG'
        )
    ) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || rec.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
END;
/

-- ============================================================================
-- Table: APEX_AUTH_ROLES
-- Purpose: Define security roles/groups for authorization
-- ============================================================================
CREATE TABLE apex_auth_roles (
    role_id             NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_code           VARCHAR2(50)    NOT NULL,
    role_name           VARCHAR2(200)   NOT NULL,
    role_description    VARCHAR2(4000),
    is_active           VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    display_sequence    NUMBER          DEFAULT 0,
    created_by          VARCHAR2(255)   DEFAULT SYS_CONTEXT('APEX$SESSION', 'APP_USER'),
    created_date        TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    updated_by          VARCHAR2(255),
    updated_date        TIMESTAMP,
    --
    CONSTRAINT apex_auth_roles_uk1 UNIQUE (role_code),
    CONSTRAINT apex_auth_roles_ck1 CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT apex_auth_roles_ck2 CHECK (role_code = UPPER(role_code))
);

COMMENT ON TABLE apex_auth_roles IS 'Stores security roles for dynamic authorization';
COMMENT ON COLUMN apex_auth_roles.role_id IS 'Primary key - auto generated';
COMMENT ON COLUMN apex_auth_roles.role_code IS 'Unique role code (uppercase)';
COMMENT ON COLUMN apex_auth_roles.role_name IS 'Display name for the role';
COMMENT ON COLUMN apex_auth_roles.is_active IS 'Y=Active, N=Inactive';

-- ============================================================================
-- Table: APEX_AUTH_USER_ROLES
-- Purpose: Map users to roles (many-to-many relationship)
-- ============================================================================
CREATE TABLE apex_auth_user_roles (
    user_role_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username            VARCHAR2(255)   NOT NULL,
    role_id             NUMBER          NOT NULL,
    is_active           VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    effective_from      DATE            DEFAULT TRUNC(SYSDATE),
    effective_to        DATE,
    created_by          VARCHAR2(255)   DEFAULT SYS_CONTEXT('APEX$SESSION', 'APP_USER'),
    created_date        TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    updated_by          VARCHAR2(255),
    updated_date        TIMESTAMP,
    --
    CONSTRAINT apex_auth_user_roles_fk1 FOREIGN KEY (role_id)
        REFERENCES apex_auth_roles (role_id) ON DELETE CASCADE,
    CONSTRAINT apex_auth_user_roles_uk1 UNIQUE (username, role_id),
    CONSTRAINT apex_auth_user_roles_ck1 CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT apex_auth_user_roles_ck2 CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX apex_auth_user_roles_idx1 ON apex_auth_user_roles (username);
CREATE INDEX apex_auth_user_roles_idx2 ON apex_auth_user_roles (role_id);

COMMENT ON TABLE apex_auth_user_roles IS 'Maps users to roles with optional date effectivity';
COMMENT ON COLUMN apex_auth_user_roles.username IS 'APEX username (case as stored in APEX)';
COMMENT ON COLUMN apex_auth_user_roles.effective_from IS 'Date from which role assignment is effective';
COMMENT ON COLUMN apex_auth_user_roles.effective_to IS 'Date until which role assignment is effective (NULL=indefinite)';

-- ============================================================================
-- Table: APEX_AUTH_COMPONENT_TYPES
-- Purpose: Define types of APEX components that can be secured
-- ============================================================================
CREATE TABLE apex_auth_component_types (
    component_type_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    component_type_code VARCHAR2(30)    NOT NULL,
    component_type_name VARCHAR2(100)   NOT NULL,
    description         VARCHAR2(4000),
    is_active           VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    display_sequence    NUMBER          DEFAULT 0,
    --
    CONSTRAINT apex_auth_comp_types_uk1 UNIQUE (component_type_code),
    CONSTRAINT apex_auth_comp_types_ck1 CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT apex_auth_comp_types_ck2 CHECK (component_type_code = UPPER(component_type_code))
);

COMMENT ON TABLE apex_auth_component_types IS 'Defines types of APEX components (PAGE, REGION, BUTTON, MENU, etc.)';

-- Insert standard component types
INSERT INTO apex_auth_component_types (component_type_code, component_type_name, description, display_sequence)
VALUES ('PAGE', 'Page', 'APEX Application Page', 10);

INSERT INTO apex_auth_component_types (component_type_code, component_type_name, description, display_sequence)
VALUES ('REGION', 'Region', 'Page Region', 20);

INSERT INTO apex_auth_component_types (component_type_code, component_type_name, description, display_sequence)
VALUES ('BUTTON', 'Button', 'Page Button', 30);

INSERT INTO apex_auth_component_types (component_type_code, component_type_name, description, display_sequence)
VALUES ('MENU', 'Navigation Menu', 'Navigation Menu Entry', 40);

INSERT INTO apex_auth_component_types (component_type_code, component_type_name, description, display_sequence)
VALUES ('LIST_ENTRY', 'List Entry', 'List Entry Item', 50);

INSERT INTO apex_auth_component_types (component_type_code, component_type_name, description, display_sequence)
VALUES ('TAB', 'Tab', 'Tab or Tab Set', 60);

INSERT INTO apex_auth_component_types (component_type_code, component_type_name, description, display_sequence)
VALUES ('ITEM', 'Page Item', 'Form Item or Display Item', 70);

INSERT INTO apex_auth_component_types (component_type_code, component_type_name, description, display_sequence)
VALUES ('REPORT_COL', 'Report Column', 'Interactive Report or Classic Report Column', 80);

INSERT INTO apex_auth_component_types (component_type_code, component_type_name, description, display_sequence)
VALUES ('PROCESS', 'Process', 'Page Process or Application Process', 90);

INSERT INTO apex_auth_component_types (component_type_code, component_type_name, description, display_sequence)
VALUES ('COMPUTATION', 'Computation', 'Page Computation', 100);

COMMIT;

-- ============================================================================
-- Table: APEX_AUTH_COMPONENTS
-- Purpose: Register individual APEX components for authorization
-- ============================================================================
CREATE TABLE apex_auth_components (
    component_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    application_id      NUMBER          NOT NULL,
    component_type_id   NUMBER          NOT NULL,
    page_id             NUMBER,
    component_name      VARCHAR2(255)   NOT NULL,
    component_static_id VARCHAR2(255),
    display_name        VARCHAR2(500),
    description         VARCHAR2(4000),
    is_active           VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    parent_component_id NUMBER,
    display_sequence    NUMBER          DEFAULT 0,
    created_by          VARCHAR2(255)   DEFAULT SYS_CONTEXT('APEX$SESSION', 'APP_USER'),
    created_date        TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    updated_by          VARCHAR2(255),
    updated_date        TIMESTAMP,
    --
    CONSTRAINT apex_auth_comp_fk1 FOREIGN KEY (component_type_id)
        REFERENCES apex_auth_component_types (component_type_id),
    CONSTRAINT apex_auth_comp_fk2 FOREIGN KEY (parent_component_id)
        REFERENCES apex_auth_components (component_id),
    CONSTRAINT apex_auth_comp_ck1 CHECK (is_active IN ('Y', 'N'))
);

CREATE INDEX apex_auth_comp_idx1 ON apex_auth_components (application_id);
CREATE INDEX apex_auth_comp_idx2 ON apex_auth_components (component_type_id);
CREATE INDEX apex_auth_comp_idx3 ON apex_auth_components (application_id, page_id);
CREATE INDEX apex_auth_comp_idx4 ON apex_auth_components (component_static_id);
CREATE UNIQUE INDEX apex_auth_comp_uk1 ON apex_auth_components (
    application_id, 
    component_type_id, 
    NVL(page_id, -1), 
    component_name
);

COMMENT ON TABLE apex_auth_components IS 'Registered APEX components for authorization control';
COMMENT ON COLUMN apex_auth_components.application_id IS 'APEX Application ID';
COMMENT ON COLUMN apex_auth_components.page_id IS 'APEX Page ID (NULL for application-level components)';
COMMENT ON COLUMN apex_auth_components.component_name IS 'Component identifier as defined in APEX';
COMMENT ON COLUMN apex_auth_components.component_static_id IS 'Static ID of the component (for regions, buttons, etc.)';

-- ============================================================================
-- Table: APEX_AUTH_PERMISSIONS
-- Purpose: Define which roles have access to which components
-- ============================================================================
CREATE TABLE apex_auth_permissions (
    permission_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_id             NUMBER          NOT NULL,
    component_id        NUMBER          NOT NULL,
    can_view            VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    can_edit            VARCHAR2(1)     DEFAULT 'N' NOT NULL,
    can_delete          VARCHAR2(1)     DEFAULT 'N' NOT NULL,
    can_execute         VARCHAR2(1)     DEFAULT 'N' NOT NULL,
    is_active           VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    effective_from      DATE            DEFAULT TRUNC(SYSDATE),
    effective_to        DATE,
    created_by          VARCHAR2(255)   DEFAULT SYS_CONTEXT('APEX$SESSION', 'APP_USER'),
    created_date        TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    updated_by          VARCHAR2(255),
    updated_date        TIMESTAMP,
    --
    CONSTRAINT apex_auth_perm_fk1 FOREIGN KEY (role_id)
        REFERENCES apex_auth_roles (role_id) ON DELETE CASCADE,
    CONSTRAINT apex_auth_perm_fk2 FOREIGN KEY (component_id)
        REFERENCES apex_auth_components (component_id) ON DELETE CASCADE,
    CONSTRAINT apex_auth_perm_uk1 UNIQUE (role_id, component_id),
    CONSTRAINT apex_auth_perm_ck1 CHECK (can_view IN ('Y', 'N')),
    CONSTRAINT apex_auth_perm_ck2 CHECK (can_edit IN ('Y', 'N')),
    CONSTRAINT apex_auth_perm_ck3 CHECK (can_delete IN ('Y', 'N')),
    CONSTRAINT apex_auth_perm_ck4 CHECK (can_execute IN ('Y', 'N')),
    CONSTRAINT apex_auth_perm_ck5 CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT apex_auth_perm_ck6 CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX apex_auth_perm_idx1 ON apex_auth_permissions (role_id);
CREATE INDEX apex_auth_perm_idx2 ON apex_auth_permissions (component_id);

COMMENT ON TABLE apex_auth_permissions IS 'Maps roles to components with specific permissions';
COMMENT ON COLUMN apex_auth_permissions.can_view IS 'Y=Can view/access the component';
COMMENT ON COLUMN apex_auth_permissions.can_edit IS 'Y=Can edit/modify data in the component';
COMMENT ON COLUMN apex_auth_permissions.can_delete IS 'Y=Can delete data via the component';
COMMENT ON COLUMN apex_auth_permissions.can_execute IS 'Y=Can execute processes/buttons';

-- ============================================================================
-- Table: APEX_AUTH_AUDIT_LOG
-- Purpose: Audit trail for authorization checks and changes
-- ============================================================================
CREATE TABLE apex_auth_audit_log (
    audit_id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    audit_date          TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    audit_type          VARCHAR2(50)    NOT NULL,
    username            VARCHAR2(255),
    application_id      NUMBER,
    page_id             NUMBER,
    component_type      VARCHAR2(30),
    component_name      VARCHAR2(255),
    action_taken        VARCHAR2(100),
    auth_result         VARCHAR2(20),
    ip_address          VARCHAR2(100),
    session_id          VARCHAR2(100),
    details             CLOB,
    --
    CONSTRAINT apex_auth_audit_ck1 CHECK (audit_type IN (
        'AUTH_CHECK', 'ROLE_CHANGE', 'PERMISSION_CHANGE', 
        'COMPONENT_CHANGE', 'LOGIN', 'LOGOUT', 'ERROR'
    ))
);

CREATE INDEX apex_auth_audit_idx1 ON apex_auth_audit_log (audit_date);
CREATE INDEX apex_auth_audit_idx2 ON apex_auth_audit_log (username);
CREATE INDEX apex_auth_audit_idx3 ON apex_auth_audit_log (application_id, page_id);

COMMENT ON TABLE apex_auth_audit_log IS 'Audit trail for all authorization activities';

-- ============================================================================
-- Create Sequences (optional - for custom ID generation if needed)
-- ============================================================================
-- Using IDENTITY columns instead, but sequence available if needed
CREATE SEQUENCE apex_auth_seq START WITH 1000 INCREMENT BY 1 NOCACHE;

-- ============================================================================
-- Summary
-- ============================================================================
PROMPT ========================================
PROMPT Dynamic Authorization DDL Installation Complete
PROMPT ========================================
PROMPT Tables Created:
PROMPT   - APEX_AUTH_ROLES
PROMPT   - APEX_AUTH_USER_ROLES  
PROMPT   - APEX_AUTH_COMPONENT_TYPES
PROMPT   - APEX_AUTH_COMPONENTS
PROMPT   - APEX_AUTH_PERMISSIONS
PROMPT   - APEX_AUTH_AUDIT_LOG
PROMPT ========================================
