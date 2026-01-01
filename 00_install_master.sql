-- ============================================================================
-- MASTER INSTALLATION SCRIPT
-- Description: Complete installation of FND_PROFILE system
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT Installing FND_PROFILE System (Oracle EBS-like Profile Management)
PROMPT ============================================================================
PROMPT

SET ECHO ON
SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

PROMPT
PROMPT ============================================================================
PROMPT Step 1: Creating Tables
PROMPT ============================================================================
@@01_fnd_profile_options.sql
@@02_fnd_profile_option_values.sql

PROMPT
PROMPT ============================================================================
PROMPT Step 2: Creating Sequences
PROMPT ============================================================================
@@03_sequences.sql

PROMPT
PROMPT ============================================================================
PROMPT Step 3: Creating Indexes
PROMPT ============================================================================
@@04_indexes.sql

PROMPT
PROMPT ============================================================================
PROMPT Step 4: Creating Package Specification
PROMPT ============================================================================
@@05_fnd_profile_pkg_spec.sql

PROMPT
PROMPT ============================================================================
PROMPT Step 5: Creating Package Body
PROMPT ============================================================================
@@06_fnd_profile_pkg_body.sql

PROMPT
PROMPT ============================================================================
PROMPT Step 6: Creating Views
PROMPT ============================================================================
@@07_views.sql

PROMPT
PROMPT ============================================================================
PROMPT Step 7: Loading Sample Data and Running Tests
PROMPT ============================================================================
@@08_sample_data_and_tests.sql

PROMPT
PROMPT ============================================================================
PROMPT Installation Complete!
PROMPT ============================================================================
PROMPT
PROMPT Objects Created:
PROMPT   - Tables: FND_PROFILE_OPTIONS, FND_PROFILE_OPTION_VALUES
PROMPT   - Sequences: FND_PROFILE_OPTIONS_S, FND_PROFILE_OPTION_VALUES_S
PROMPT   - Indexes: 10 performance indexes
PROMPT   - Package: FND_PROFILE (spec and body)
PROMPT   - Views: 6 reporting views
PROMPT   - Sample Data: 6 profile options with values at multiple levels
PROMPT
PROMPT Next Steps:
PROMPT   1. Review the sample data in FND_PROFILE_OPTIONS_VL view
PROMPT   2. Test the API using: SELECT fnd_profile.value('PROFILE_NAME') FROM dual
PROMPT   3. Add your own profile options using the provided patterns
PROMPT
PROMPT ============================================================================

SET ECHO OFF
SET TIMING OFF
