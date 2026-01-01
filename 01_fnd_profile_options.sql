-- ============================================================================
-- FND_PROFILE_OPTIONS Table
-- Description: Stores profile option definitions (similar to Oracle EBS)
-- ============================================================================

CREATE TABLE fnd_profile_options (
    profile_option_id       NUMBER NOT NULL,
    profile_option_name     VARCHAR2(240) NOT NULL,
    application_id          NUMBER,
    user_profile_option_name VARCHAR2(240) NOT NULL,
    description             VARCHAR2(2000),
    enabled_flag            VARCHAR2(1) DEFAULT 'Y' NOT NULL,
    start_date_active       DATE DEFAULT SYSDATE NOT NULL,
    end_date_active         DATE,
    user_changeable_flag    VARCHAR2(1) DEFAULT 'N' NOT NULL,
    user_visible_flag       VARCHAR2(1) DEFAULT 'Y' NOT NULL,
    read_only_flag          VARCHAR2(1) DEFAULT 'N' NOT NULL,
    sql_validation          VARCHAR2(2000),
    creation_date           DATE DEFAULT SYSDATE NOT NULL,
    created_by              NUMBER NOT NULL,
    last_update_date        DATE DEFAULT SYSDATE NOT NULL,
    last_updated_by         NUMBER NOT NULL,
    last_update_login       NUMBER,
    -- Constraints
    CONSTRAINT fnd_profile_options_pk 
        PRIMARY KEY (profile_option_id),
    CONSTRAINT fnd_profile_options_uk1 
        UNIQUE (profile_option_name),
    CONSTRAINT fnd_profile_opt_enabled_ck 
        CHECK (enabled_flag IN ('Y', 'N')),
    CONSTRAINT fnd_profile_opt_userchg_ck 
        CHECK (user_changeable_flag IN ('Y', 'N')),
    CONSTRAINT fnd_profile_opt_visible_ck 
        CHECK (user_visible_flag IN ('Y', 'N')),
    CONSTRAINT fnd_profile_opt_readonly_ck 
        CHECK (read_only_flag IN ('Y', 'N')),
    CONSTRAINT fnd_profile_opt_dates_ck 
        CHECK (end_date_active IS NULL OR end_date_active >= start_date_active)
) TABLESPACE users;

-- Comments on table
COMMENT ON TABLE fnd_profile_options IS 
    'Stores profile option definitions and metadata. Each profile option defines a configurable parameter that can be set at multiple levels (Site, Application, Responsibility, User).';

-- Comments on columns
COMMENT ON COLUMN fnd_profile_options.profile_option_id IS 
    'Primary key, unique identifier for the profile option';
COMMENT ON COLUMN fnd_profile_options.profile_option_name IS 
    'Internal name of the profile option (unique, uppercase)';
COMMENT ON COLUMN fnd_profile_options.application_id IS 
    'Application that owns this profile option';
COMMENT ON COLUMN fnd_profile_options.user_profile_option_name IS 
    'User-friendly display name for the profile option';
COMMENT ON COLUMN fnd_profile_options.description IS 
    'Detailed description of the profile option purpose and usage';
COMMENT ON COLUMN fnd_profile_options.enabled_flag IS 
    'Y=Enabled, N=Disabled. Only enabled profiles are active';
COMMENT ON COLUMN fnd_profile_options.start_date_active IS 
    'Date when this profile option becomes active';
COMMENT ON COLUMN fnd_profile_options.end_date_active IS 
    'Date when this profile option becomes inactive (NULL=no end date)';
COMMENT ON COLUMN fnd_profile_options.user_changeable_flag IS 
    'Y=Users can change their own value, N=Only administrators can change';
COMMENT ON COLUMN fnd_profile_options.user_visible_flag IS 
    'Y=Visible to users, N=Hidden (system use only)';
COMMENT ON COLUMN fnd_profile_options.read_only_flag IS 
    'Y=Read-only display, N=Can be updated';
COMMENT ON COLUMN fnd_profile_options.sql_validation IS 
    'Optional SQL query for value validation';
