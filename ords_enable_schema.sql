-- Enable a schema for ORDS access with a custom alias
-- Run this as a user with ORDS_ADMINISTRATOR_ROLE or execute privileges on ORDS package

BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'YOUR_USERNAME',     -- The DB User (e.g., HR, SCOTT, MY_APP_USER)
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'your_alias',        -- The Alias/Path (e.g., hr_dev, app_v1)
        p_auto_rest_auth      => TRUE                 -- Protect with default authentication
    );
    
    COMMIT;
END;
/

-- Verification Query
-- Check if the schema is enabled and what the alias is
SELECT id, parsing_schema, parsing_object, pattern, status
FROM user_ords_schemas;
-- OR if you are admin:
-- SELECT * FROM all_ords_schemas WHERE parsing_schema = 'YOUR_USERNAME';
