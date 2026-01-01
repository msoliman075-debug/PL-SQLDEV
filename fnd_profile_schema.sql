-- FND_PROFILE Schema Imitation for Oracle 19c+
-- Designed to match Oracle EBS FND_PROFILE functionality

-- -----------------------------------------------------------------------------
-- Drop existing objects if they exist (clean slate)
-- -----------------------------------------------------------------------------
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE fnd_profile_option_values CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE fnd_profile_options CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP SEQUENCE fnd_profile_options_s';
    EXECUTE IMMEDIATE 'DROP SEQUENCE fnd_profile_option_values_s';
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- Ignore errors if objects do not exist
END;
/

-- -----------------------------------------------------------------------------
-- 1. FND_PROFILE_OPTIONS
-- Stores metadata about profile options
-- -----------------------------------------------------------------------------
CREATE TABLE fnd_profile_options (
    profile_option_id           NUMBER(15)          NOT NULL,
    profile_option_name         VARCHAR2(80)        NOT NULL, -- Internal Name (e.g., 'AFLOG_ENABLED')
    user_profile_option_name    VARCHAR2(240)       NOT NULL, -- Display Name
    description                 VARCHAR2(240),
    hierarchy_type              VARCHAR2(8)         DEFAULT 'SECURITY' NOT NULL, -- SECURITY or SERVER
    site_enabled_flag           VARCHAR2(1)         DEFAULT 'Y' NOT NULL,
    app_enabled_flag            VARCHAR2(1)         DEFAULT 'Y' NOT NULL,
    resp_enabled_flag           VARCHAR2(1)         DEFAULT 'Y' NOT NULL,
    user_enabled_flag           VARCHAR2(1)         DEFAULT 'Y' NOT NULL,
    org_enabled_flag            VARCHAR2(1)         DEFAULT 'N' NOT NULL,
    server_enabled_flag         VARCHAR2(1)         DEFAULT 'N' NOT NULL,
    sql_validation              VARCHAR2(2000),     -- SQL statement for LOV validation
    start_date_active           DATE                DEFAULT SYSDATE NOT NULL,
    end_date_active             DATE,
    -- WHO Columns
    created_by                  NUMBER(15)          DEFAULT -1 NOT NULL,
    creation_date               DATE                DEFAULT SYSDATE NOT NULL,
    last_updated_by             NUMBER(15)          DEFAULT -1 NOT NULL,
    last_update_date            DATE                DEFAULT SYSDATE NOT NULL,
    last_update_login           NUMBER(15)          DEFAULT -1,
    CONSTRAINT fnd_profile_options_pk PRIMARY KEY (profile_option_id),
    CONSTRAINT fnd_profile_options_u1 UNIQUE (profile_option_name),
    CONSTRAINT fnd_profile_options_u2 UNIQUE (user_profile_option_name),
    CONSTRAINT fnd_po_site_flag_chk CHECK (site_enabled_flag IN ('Y', 'N')),
    CONSTRAINT fnd_po_app_flag_chk CHECK (app_enabled_flag IN ('Y', 'N')),
    CONSTRAINT fnd_po_resp_flag_chk CHECK (resp_enabled_flag IN ('Y', 'N')),
    CONSTRAINT fnd_po_user_flag_chk CHECK (user_enabled_flag IN ('Y', 'N'))
);

CREATE SEQUENCE fnd_profile_options_s START WITH 1000 INCREMENT BY 1 NOCACHE;

COMMENT ON TABLE fnd_profile_options IS 'Stores definitions of profile options.';
COMMENT ON COLUMN fnd_profile_options.profile_option_name IS 'Internal name of the profile option used in code.';
COMMENT ON COLUMN fnd_profile_options.sql_validation IS 'SQL statement used to validate or provide LOV for the profile value.';

-- -----------------------------------------------------------------------------
-- 2. FND_PROFILE_OPTION_VALUES
-- Stores the actual values set at different levels
-- -----------------------------------------------------------------------------
CREATE TABLE fnd_profile_option_values (
    profile_option_value_id     NUMBER(15)          NOT NULL,
    profile_option_id           NUMBER(15)          NOT NULL,
    level_id                    NUMBER(15)          NOT NULL, 
    -- Level IDs usually: 10001=Site, 10002=App, 10003=Resp, 10004=User, 10005=Server, 10006=Org
    level_value                 NUMBER(15)          NOT NULL, -- ID of the specific level entity (e.g., User_ID)
    level_value_application_id  NUMBER(15),         -- Used when level is Responsibility to distinguish apps
    profile_option_value        VARCHAR2(240),
    -- WHO Columns
    created_by                  NUMBER(15)          DEFAULT -1 NOT NULL,
    creation_date               DATE                DEFAULT SYSDATE NOT NULL,
    last_updated_by             NUMBER(15)          DEFAULT -1 NOT NULL,
    last_update_date            DATE                DEFAULT SYSDATE NOT NULL,
    last_update_login           NUMBER(15)          DEFAULT -1,
    CONSTRAINT fnd_profile_option_values_pk PRIMARY KEY (profile_option_value_id),
    CONSTRAINT fnd_profile_option_values_fk1 FOREIGN KEY (profile_option_id) 
        REFERENCES fnd_profile_options (profile_option_id) ON DELETE CASCADE,
    -- Ensure one value per level/value combo for a profile
    CONSTRAINT fnd_profile_option_values_u1 UNIQUE (profile_option_id, level_id, level_value, level_value_application_id)
);

CREATE SEQUENCE fnd_profile_option_values_s START WITH 1000 INCREMENT BY 1 NOCACHE;

CREATE INDEX fnd_profile_option_values_n1 ON fnd_profile_option_values (profile_option_id, level_id);

COMMENT ON TABLE fnd_profile_option_values IS 'Stores values for profile options at specific hierarchy levels.';
COMMENT ON COLUMN fnd_profile_option_values.level_id IS 'Hierarchy level: 10001=Site, 10002=App, 10003=Resp, 10004=User.';
COMMENT ON COLUMN fnd_profile_option_values.level_value IS 'The ID of the specific Application, Responsibility, or User. 0 for Site.';

