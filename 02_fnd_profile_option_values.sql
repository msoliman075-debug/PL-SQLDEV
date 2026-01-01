-- ============================================================================
-- FND_PROFILE_OPTION_VALUES Table
-- Description: Stores profile option values at different levels
-- ============================================================================

CREATE TABLE fnd_profile_option_values (
    profile_option_value_id NUMBER NOT NULL,
    profile_option_id       NUMBER NOT NULL,
    application_id          NUMBER,
    level_id                NUMBER NOT NULL,
    level_value             NUMBER,
    level_value_application_id NUMBER,
    profile_option_value    VARCHAR2(2000),
    enabled_flag            VARCHAR2(1) DEFAULT 'Y' NOT NULL,
    start_date_active       DATE DEFAULT SYSDATE NOT NULL,
    end_date_active         DATE,
    creation_date           DATE DEFAULT SYSDATE NOT NULL,
    created_by              NUMBER NOT NULL,
    last_update_date        DATE DEFAULT SYSDATE NOT NULL,
    last_updated_by         NUMBER NOT NULL,
    last_update_login       NUMBER,
    -- Constraints
    CONSTRAINT fnd_profile_opt_values_pk 
        PRIMARY KEY (profile_option_value_id),
    CONSTRAINT fnd_profile_opt_values_uk1 
        UNIQUE (profile_option_id, level_id, level_value, 
                level_value_application_id, application_id),
    CONSTRAINT fnd_profile_opt_values_fk1 
        FOREIGN KEY (profile_option_id) 
        REFERENCES fnd_profile_options (profile_option_id),
    CONSTRAINT fnd_prof_val_enabled_ck 
        CHECK (enabled_flag IN ('Y', 'N')),
    CONSTRAINT fnd_prof_val_dates_ck 
        CHECK (end_date_active IS NULL OR end_date_active >= start_date_active),
    CONSTRAINT fnd_prof_val_level_ck 
        CHECK (level_id BETWEEN 10001 AND 10006)
) TABLESPACE users;

-- Comments on table
COMMENT ON TABLE fnd_profile_option_values IS 
    'Stores profile option values at different hierarchy levels. Each value represents a profile option setting at a specific level (Site, Application, Responsibility, User, etc.).';

-- Comments on columns
COMMENT ON COLUMN fnd_profile_option_values.profile_option_value_id IS 
    'Primary key, unique identifier for the profile option value';
COMMENT ON COLUMN fnd_profile_option_values.profile_option_id IS 
    'Foreign key to FND_PROFILE_OPTIONS';
COMMENT ON COLUMN fnd_profile_option_values.application_id IS 
    'Application context for this value';
COMMENT ON COLUMN fnd_profile_option_values.level_id IS 
    '10001=Site, 10002=Application, 10003=Responsibility, 10004=User, 10005=Server, 10006=Org';
COMMENT ON COLUMN fnd_profile_option_values.level_value IS 
    'The specific ID at this level (e.g., User ID if level_id=10004)';
COMMENT ON COLUMN fnd_profile_option_values.level_value_application_id IS 
    'Application ID associated with the level value (for responsibility level)';
COMMENT ON COLUMN fnd_profile_option_values.profile_option_value IS 
    'The actual value stored for this profile option at this level';
COMMENT ON COLUMN fnd_profile_option_values.enabled_flag IS 
    'Y=Enabled, N=Disabled. Only enabled values are considered';
COMMENT ON COLUMN fnd_profile_option_values.start_date_active IS 
    'Date when this profile value becomes active';
COMMENT ON COLUMN fnd_profile_option_values.end_date_active IS 
    'Date when this profile value becomes inactive (NULL=no end date)';
