-- ============================================================================
-- Sequences for Primary Keys
-- Description: Sequences for generating unique identifiers
-- ============================================================================

-- Sequence for FND_PROFILE_OPTIONS table
CREATE SEQUENCE fnd_profile_options_s
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE
    NOMAXVALUE;

COMMENT ON SEQUENCE fnd_profile_options_s IS 
    'Sequence for generating profile_option_id in FND_PROFILE_OPTIONS table';

-- Sequence for FND_PROFILE_OPTION_VALUES table
CREATE SEQUENCE fnd_profile_option_values_s
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE
    NOMAXVALUE;

COMMENT ON SEQUENCE fnd_profile_option_values_s IS 
    'Sequence for generating profile_option_value_id in FND_PROFILE_OPTION_VALUES table';
