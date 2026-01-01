-- ============================================================================
-- Indexes for Performance Optimization
-- Description: Indexes to optimize query performance
-- ============================================================================

-- ============================================================================
-- Indexes for FND_PROFILE_OPTIONS
-- ============================================================================

-- Index on profile_option_name for lookups by name
CREATE INDEX fnd_profile_options_n1 
    ON fnd_profile_options(profile_option_name)
    TABLESPACE users;

-- Index on enabled_flag and dates for active profile options
CREATE INDEX fnd_profile_options_n2 
    ON fnd_profile_options(enabled_flag, start_date_active, end_date_active)
    TABLESPACE users;

-- Index on application_id for application-specific queries
CREATE INDEX fnd_profile_options_n3 
    ON fnd_profile_options(application_id)
    TABLESPACE users;

-- Index on user_visible_flag for UI queries
CREATE INDEX fnd_profile_options_n4 
    ON fnd_profile_options(user_visible_flag, enabled_flag)
    TABLESPACE users;

-- ============================================================================
-- Indexes for FND_PROFILE_OPTION_VALUES
-- ============================================================================

-- Index on profile_option_id for value lookups
CREATE INDEX fnd_profile_opt_values_n1 
    ON fnd_profile_option_values(profile_option_id)
    TABLESPACE users;

-- Index on level_id and level_value for hierarchy queries
CREATE INDEX fnd_profile_opt_values_n2 
    ON fnd_profile_option_values(level_id, level_value)
    TABLESPACE users;

-- Composite index for common profile value retrieval pattern
CREATE INDEX fnd_profile_opt_values_n3 
    ON fnd_profile_option_values(
        profile_option_id, 
        level_id, 
        level_value, 
        enabled_flag
    )
    TABLESPACE users;

-- Index on enabled_flag and dates for active values
CREATE INDEX fnd_profile_opt_values_n4 
    ON fnd_profile_option_values(
        enabled_flag, 
        start_date_active, 
        end_date_active
    )
    TABLESPACE users;

-- Index on application_id for application context queries
CREATE INDEX fnd_profile_opt_values_n5 
    ON fnd_profile_option_values(application_id)
    TABLESPACE users;

-- Index on level_value_application_id for responsibility level queries
CREATE INDEX fnd_profile_opt_values_n6 
    ON fnd_profile_option_values(level_value_application_id, level_id)
    TABLESPACE users;

-- ============================================================================
-- Comments on indexes
-- ============================================================================

COMMENT ON INDEX fnd_profile_options_n1 IS 
    'Optimizes lookups by profile option internal name';

COMMENT ON INDEX fnd_profile_options_n2 IS 
    'Optimizes queries for active/enabled profile options';

COMMENT ON INDEX fnd_profile_opt_values_n1 IS 
    'Optimizes foreign key queries from profile option to values';

COMMENT ON INDEX fnd_profile_opt_values_n2 IS 
    'Optimizes hierarchy-level value lookups (e.g., all user-level values)';

COMMENT ON INDEX fnd_profile_opt_values_n3 IS 
    'Optimizes the most common profile value retrieval pattern used by FND_PROFILE.VALUE';
