-- Seed Data for FND_PROFILE Structure

SET SERVEROUTPUT ON;

DECLARE
    v_profile_id NUMBER;
BEGIN
    -- 1. Create 'AFLOG_ENABLED' Profile Option
    INSERT INTO fnd_profile_options (
        profile_option_id, profile_option_name, user_profile_option_name, description, 
        hierarchy_type, site_enabled_flag, app_enabled_flag, resp_enabled_flag, user_enabled_flag
    ) VALUES (
        fnd_profile_options_s.NEXTVAL, 'AFLOG_ENABLED', 'FND: Debug Log Enabled', 'Enables FND Logging',
        'SECURITY', 'Y', 'Y', 'Y', 'Y'
    ) RETURNING profile_option_id INTO v_profile_id;

    -- Set Site Level Value to 'N'
    INSERT INTO fnd_profile_option_values (
        profile_option_value_id, profile_option_id, level_id, level_value, profile_option_value
    ) VALUES (
        fnd_profile_option_values_s.NEXTVAL, v_profile_id, 10001, 0, 'N'
    );

    -- Set User Level (User ID 101) Value to 'Y'
    INSERT INTO fnd_profile_option_values (
        profile_option_value_id, profile_option_id, level_id, level_value, profile_option_value
    ) VALUES (
        fnd_profile_option_values_s.NEXTVAL, v_profile_id, 10004, 101, 'Y'
    );
    
    DBMS_OUTPUT.PUT_LINE('Created profile AFLOG_ENABLED with Site=N and User(101)=Y');


    -- 2. Create 'CONC_REQ_OUTPUT_FORMAT' Profile Option
    INSERT INTO fnd_profile_options (
        profile_option_id, profile_option_name, user_profile_option_name, description, 
        hierarchy_type, site_enabled_flag, app_enabled_flag, resp_enabled_flag, user_enabled_flag
    ) VALUES (
        fnd_profile_options_s.NEXTVAL, 'CONC_REQ_OUTPUT_FORMAT', 'Concurrent: Output Format', 'Default output format for requests',
        'SECURITY', 'Y', 'Y', 'Y', 'Y'
    ) RETURNING profile_option_id INTO v_profile_id;

    -- Set Site Level Value to 'TEXT'
    INSERT INTO fnd_profile_option_values (
        profile_option_value_id, profile_option_id, level_id, level_value, profile_option_value
    ) VALUES (
        fnd_profile_option_values_s.NEXTVAL, v_profile_id, 10001, 0, 'TEXT'
    );
    
    DBMS_OUTPUT.PUT_LINE('Created profile CONC_REQ_OUTPUT_FORMAT with Site=TEXT');

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error seeding data: ' || SQLERRM);
END;
/
