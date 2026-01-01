/*
================================================================================
  FND_PROFILE Database Structure - Tables Definition
  Similar to Oracle EBS FND_PROFILE functionality
  
  Author: Database Team
  Version: 1.0
  Target: Oracle 19c+
  
  Description:
  Profile options management system that allows storing and retrieving 
  configuration values at different hierarchy levels:
  - SITE (Level 10001) - Applies to entire installation
  - APPLICATION (Level 10002) - Applies to specific application  
  - RESPONSIBILITY (Level 10003) - Applies to specific responsibility
  - USER (Level 10004) - Applies to specific user
  
  Hierarchy precedence: USER > RESPONSIBILITY > APPLICATION > SITE
================================================================================
*/

-- ============================================================================
-- Sequences
-- ============================================================================

CREATE SEQUENCE fnd_profile_options_s
  START WITH 1000
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

CREATE SEQUENCE fnd_profile_option_values_s
  START WITH 1000
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

-- ============================================================================
-- Lookup Tables
-- ============================================================================

-- Profile hierarchy levels lookup
CREATE TABLE fnd_profile_levels (
    level_id                NUMBER(15)      NOT NULL,
    level_name              VARCHAR2(80)    NOT NULL,
    level_value_column      VARCHAR2(30)    NOT NULL,
    hierarchy_order         NUMBER(5)       NOT NULL,
    enabled_flag            VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    description             VARCHAR2(240),
    created_by              NUMBER(15)      DEFAULT -1 NOT NULL,
    creation_date           DATE            DEFAULT SYSDATE NOT NULL,
    last_updated_by         NUMBER(15)      DEFAULT -1 NOT NULL,
    last_update_date        DATE            DEFAULT SYSDATE NOT NULL,
    last_update_login       NUMBER(15),
    CONSTRAINT fnd_profile_levels_pk PRIMARY KEY (level_id),
    CONSTRAINT fnd_profile_levels_u1 UNIQUE (level_name),
    CONSTRAINT fnd_profile_levels_c1 CHECK (enabled_flag IN ('Y', 'N'))
);

COMMENT ON TABLE fnd_profile_levels IS 'Stores profile hierarchy level definitions';
COMMENT ON COLUMN fnd_profile_levels.level_id IS 'Unique identifier for hierarchy level';
COMMENT ON COLUMN fnd_profile_levels.level_name IS 'Name of hierarchy level (SITE, APPLICATION, RESPONSIBILITY, USER)';
COMMENT ON COLUMN fnd_profile_levels.hierarchy_order IS 'Order for value retrieval - higher values have higher precedence';

-- Applications lookup (similar to FND_APPLICATION)
CREATE TABLE fnd_application (
    application_id          NUMBER(15)      NOT NULL,
    application_short_name  VARCHAR2(50)    NOT NULL,
    application_name        VARCHAR2(240)   NOT NULL,
    description             VARCHAR2(240),
    basepath                VARCHAR2(240),
    enabled_flag            VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    created_by              NUMBER(15)      DEFAULT -1 NOT NULL,
    creation_date           DATE            DEFAULT SYSDATE NOT NULL,
    last_updated_by         NUMBER(15)      DEFAULT -1 NOT NULL,
    last_update_date        DATE            DEFAULT SYSDATE NOT NULL,
    last_update_login       NUMBER(15),
    CONSTRAINT fnd_application_pk PRIMARY KEY (application_id),
    CONSTRAINT fnd_application_u1 UNIQUE (application_short_name),
    CONSTRAINT fnd_application_c1 CHECK (enabled_flag IN ('Y', 'N'))
);

COMMENT ON TABLE fnd_application IS 'Stores application definitions';

-- Responsibilities lookup (similar to FND_RESPONSIBILITY)
CREATE TABLE fnd_responsibility (
    responsibility_id       NUMBER(15)      NOT NULL,
    application_id          NUMBER(15)      NOT NULL,
    responsibility_key      VARCHAR2(30)    NOT NULL,
    responsibility_name     VARCHAR2(100)   NOT NULL,
    description             VARCHAR2(240),
    start_date              DATE            DEFAULT SYSDATE NOT NULL,
    end_date                DATE,
    data_group_id           NUMBER(15),
    menu_id                 NUMBER(15),
    created_by              NUMBER(15)      DEFAULT -1 NOT NULL,
    creation_date           DATE            DEFAULT SYSDATE NOT NULL,
    last_updated_by         NUMBER(15)      DEFAULT -1 NOT NULL,
    last_update_date        DATE            DEFAULT SYSDATE NOT NULL,
    last_update_login       NUMBER(15),
    CONSTRAINT fnd_responsibility_pk PRIMARY KEY (responsibility_id),
    CONSTRAINT fnd_responsibility_u1 UNIQUE (application_id, responsibility_key),
    CONSTRAINT fnd_responsibility_fk1 FOREIGN KEY (application_id) 
        REFERENCES fnd_application(application_id)
);

COMMENT ON TABLE fnd_responsibility IS 'Stores responsibility definitions';

-- Users lookup (similar to FND_USER)
CREATE TABLE fnd_user (
    user_id                 NUMBER(15)      NOT NULL,
    user_name               VARCHAR2(100)   NOT NULL,
    email_address           VARCHAR2(240),
    employee_id             NUMBER(15),
    description             VARCHAR2(240),
    start_date              DATE            DEFAULT SYSDATE NOT NULL,
    end_date                DATE,
    password_date           DATE,
    last_logon_date         DATE,
    created_by              NUMBER(15)      DEFAULT -1 NOT NULL,
    creation_date           DATE            DEFAULT SYSDATE NOT NULL,
    last_updated_by         NUMBER(15)      DEFAULT -1 NOT NULL,
    last_update_date        DATE            DEFAULT SYSDATE NOT NULL,
    last_update_login       NUMBER(15),
    CONSTRAINT fnd_user_pk PRIMARY KEY (user_id),
    CONSTRAINT fnd_user_u1 UNIQUE (user_name)
);

COMMENT ON TABLE fnd_user IS 'Stores user definitions';

-- User responsibility assignments
CREATE TABLE fnd_user_resp_groups (
    user_id                 NUMBER(15)      NOT NULL,
    responsibility_id       NUMBER(15)      NOT NULL,
    responsibility_application_id NUMBER(15) NOT NULL,
    start_date              DATE            DEFAULT SYSDATE NOT NULL,
    end_date                DATE,
    description             VARCHAR2(240),
    created_by              NUMBER(15)      DEFAULT -1 NOT NULL,
    creation_date           DATE            DEFAULT SYSDATE NOT NULL,
    last_updated_by         NUMBER(15)      DEFAULT -1 NOT NULL,
    last_update_date        DATE            DEFAULT SYSDATE NOT NULL,
    last_update_login       NUMBER(15),
    CONSTRAINT fnd_user_resp_groups_pk PRIMARY KEY (user_id, responsibility_id, responsibility_application_id),
    CONSTRAINT fnd_user_resp_groups_fk1 FOREIGN KEY (user_id) 
        REFERENCES fnd_user(user_id),
    CONSTRAINT fnd_user_resp_groups_fk2 FOREIGN KEY (responsibility_id) 
        REFERENCES fnd_responsibility(responsibility_id)
);

COMMENT ON TABLE fnd_user_resp_groups IS 'Stores user to responsibility assignments';

-- ============================================================================
-- Main Profile Tables
-- ============================================================================

-- Profile Options Definition Table
CREATE TABLE fnd_profile_options (
    profile_option_id       NUMBER(15)      NOT NULL,
    profile_option_name     VARCHAR2(80)    NOT NULL,
    application_id          NUMBER(15)      NOT NULL,
    user_profile_option_name VARCHAR2(240)  NOT NULL,
    description             VARCHAR2(240),
    user_changeable_flag    VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    user_visible_flag       VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    read_allowed_flag       VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    write_allowed_flag      VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    site_enabled_flag       VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    site_update_allowed_flag VARCHAR2(1)    DEFAULT 'Y' NOT NULL,
    app_enabled_flag        VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    app_update_allowed_flag VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    resp_enabled_flag       VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    resp_update_allowed_flag VARCHAR2(1)    DEFAULT 'Y' NOT NULL,
    user_enabled_flag       VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
    user_update_allowed_flag VARCHAR2(1)    DEFAULT 'Y' NOT NULL,
    sql_validation          VARCHAR2(2000),
    start_date_active       DATE            DEFAULT SYSDATE NOT NULL,
    end_date_active         DATE,
    hierarchy_type          VARCHAR2(8)     DEFAULT 'SECURITY',
    created_by              NUMBER(15)      DEFAULT -1 NOT NULL,
    creation_date           DATE            DEFAULT SYSDATE NOT NULL,
    last_updated_by         NUMBER(15)      DEFAULT -1 NOT NULL,
    last_update_date        DATE            DEFAULT SYSDATE NOT NULL,
    last_update_login       NUMBER(15),
    CONSTRAINT fnd_profile_options_pk PRIMARY KEY (profile_option_id),
    CONSTRAINT fnd_profile_options_u1 UNIQUE (profile_option_name),
    CONSTRAINT fnd_profile_options_fk1 FOREIGN KEY (application_id) 
        REFERENCES fnd_application(application_id),
    CONSTRAINT fnd_profile_options_c1 CHECK (user_changeable_flag IN ('Y', 'N')),
    CONSTRAINT fnd_profile_options_c2 CHECK (user_visible_flag IN ('Y', 'N')),
    CONSTRAINT fnd_profile_options_c3 CHECK (read_allowed_flag IN ('Y', 'N')),
    CONSTRAINT fnd_profile_options_c4 CHECK (write_allowed_flag IN ('Y', 'N')),
    CONSTRAINT fnd_profile_options_c5 CHECK (site_enabled_flag IN ('Y', 'N')),
    CONSTRAINT fnd_profile_options_c6 CHECK (app_enabled_flag IN ('Y', 'N')),
    CONSTRAINT fnd_profile_options_c7 CHECK (resp_enabled_flag IN ('Y', 'N')),
    CONSTRAINT fnd_profile_options_c8 CHECK (user_enabled_flag IN ('Y', 'N')),
    CONSTRAINT fnd_profile_options_c9 CHECK (hierarchy_type IN ('SECURITY', 'SERVER', 'ORG', 'SERVRESP'))
);

COMMENT ON TABLE fnd_profile_options IS 'Stores profile option definitions';
COMMENT ON COLUMN fnd_profile_options.profile_option_id IS 'Unique identifier for profile option';
COMMENT ON COLUMN fnd_profile_options.profile_option_name IS 'Internal name used in API calls';
COMMENT ON COLUMN fnd_profile_options.user_profile_option_name IS 'Display name shown to users';
COMMENT ON COLUMN fnd_profile_options.user_changeable_flag IS 'Y if users can change this profile';
COMMENT ON COLUMN fnd_profile_options.hierarchy_type IS 'SECURITY (default), SERVER, ORG, SERVRESP';

-- Profile Option Values Table
CREATE TABLE fnd_profile_option_values (
    profile_option_value_id NUMBER(15)      NOT NULL,
    profile_option_id       NUMBER(15)      NOT NULL,
    level_id                NUMBER(15)      NOT NULL,
    level_value             NUMBER(15)      DEFAULT 0 NOT NULL,
    level_value_application_id NUMBER(15)   DEFAULT 0,
    profile_option_value    VARCHAR2(240),
    created_by              NUMBER(15)      DEFAULT -1 NOT NULL,
    creation_date           DATE            DEFAULT SYSDATE NOT NULL,
    last_updated_by         NUMBER(15)      DEFAULT -1 NOT NULL,
    last_update_date        DATE            DEFAULT SYSDATE NOT NULL,
    last_update_login       NUMBER(15),
    CONSTRAINT fnd_profile_opt_values_pk PRIMARY KEY (profile_option_value_id),
    CONSTRAINT fnd_profile_opt_values_u1 UNIQUE (profile_option_id, level_id, level_value, level_value_application_id),
    CONSTRAINT fnd_profile_opt_values_fk1 FOREIGN KEY (profile_option_id) 
        REFERENCES fnd_profile_options(profile_option_id),
    CONSTRAINT fnd_profile_opt_values_fk2 FOREIGN KEY (level_id) 
        REFERENCES fnd_profile_levels(level_id)
);

COMMENT ON TABLE fnd_profile_option_values IS 'Stores profile option values at different hierarchy levels';
COMMENT ON COLUMN fnd_profile_option_values.level_id IS 'Hierarchy level (10001=Site, 10002=App, 10003=Resp, 10004=User)';
COMMENT ON COLUMN fnd_profile_option_values.level_value IS 'ID of entity at this level (0 for Site, app_id for App, resp_id for Resp, user_id for User)';
COMMENT ON COLUMN fnd_profile_option_values.level_value_application_id IS 'Application ID for responsibility level';
COMMENT ON COLUMN fnd_profile_option_values.profile_option_value IS 'The actual value stored for this profile at this level';

-- Profile Change History Table (for auditing)
CREATE TABLE fnd_profile_option_values_h (
    history_id              NUMBER(15)      NOT NULL,
    profile_option_value_id NUMBER(15)      NOT NULL,
    profile_option_id       NUMBER(15)      NOT NULL,
    level_id                NUMBER(15)      NOT NULL,
    level_value             NUMBER(15)      NOT NULL,
    level_value_application_id NUMBER(15),
    old_profile_option_value VARCHAR2(240),
    new_profile_option_value VARCHAR2(240),
    change_type             VARCHAR2(10)    NOT NULL,
    changed_by              NUMBER(15)      NOT NULL,
    change_date             DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fnd_profile_opt_values_h_pk PRIMARY KEY (history_id),
    CONSTRAINT fnd_profile_opt_values_h_c1 CHECK (change_type IN ('INSERT', 'UPDATE', 'DELETE'))
);

CREATE SEQUENCE fnd_profile_option_values_h_s
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

COMMENT ON TABLE fnd_profile_option_values_h IS 'Audit history for profile option value changes';

-- ============================================================================
-- Indexes for Performance
-- ============================================================================

CREATE INDEX fnd_profile_options_n1 ON fnd_profile_options(application_id);
CREATE INDEX fnd_profile_options_n2 ON fnd_profile_options(start_date_active, end_date_active);
CREATE INDEX fnd_profile_opt_values_n1 ON fnd_profile_option_values(profile_option_id, level_id);
CREATE INDEX fnd_profile_opt_values_n2 ON fnd_profile_option_values(level_id, level_value);
CREATE INDEX fnd_responsibility_n1 ON fnd_responsibility(application_id);
CREATE INDEX fnd_user_resp_groups_n1 ON fnd_user_resp_groups(responsibility_id);

-- ============================================================================
-- Insert Default Profile Levels
-- ============================================================================

INSERT INTO fnd_profile_levels (level_id, level_name, level_value_column, hierarchy_order, description)
VALUES (10001, 'SITE', 'SITE_ID', 1, 'Site level - applies to entire installation');

INSERT INTO fnd_profile_levels (level_id, level_name, level_value_column, hierarchy_order, description)
VALUES (10002, 'APPLICATION', 'APPLICATION_ID', 2, 'Application level - applies to specific application');

INSERT INTO fnd_profile_levels (level_id, level_name, level_value_column, hierarchy_order, description)
VALUES (10003, 'RESPONSIBILITY', 'RESPONSIBILITY_ID', 3, 'Responsibility level - applies to specific responsibility');

INSERT INTO fnd_profile_levels (level_id, level_name, level_value_column, hierarchy_order, description)
VALUES (10004, 'USER', 'USER_ID', 4, 'User level - applies to specific user');

COMMIT;

/*
================================================================================
  End of Tables Definition
================================================================================
*/
