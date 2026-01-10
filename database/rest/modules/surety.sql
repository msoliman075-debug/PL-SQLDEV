
-- Define the REST module and handler for the surety upload policy endpoint
-- This script addresses the 404 error for: http://<server>/ords/surety/surety/upload_policy

DECLARE
  l_module_name VARCHAR2(255) := 'surety';
  l_base_path   VARCHAR2(255) := 'surety/';
BEGIN
  -- Enable the schema for ORDS if not already enabled (optional, usually done once per schema)
  -- ORDS.ENABLE_SCHEMA(
  --   p_enabled             => TRUE,
  --   p_schema              => 'SURETY',
  --   p_url_mapping_type    => 'BASE_PATH',
  --   p_url_mapping_pattern => 'surety',
  --   p_auto_rest_auth      => FALSE
  -- );

  -- Define the Module
  ORDS.DEFINE_MODULE(
    p_module_name    => l_module_name,
    p_base_path      => l_base_path,
    p_items_per_page => 25,
    p_status         => 'PUBLISHED',
    p_comments       => 'Surety Module'
  );

  -- Define the Template
  ORDS.DEFINE_TEMPLATE(
    p_module_name    => l_module_name,
    p_pattern        => 'upload_policy',
    p_priority       => 0,
    p_etag_type      => 'HASH',
    p_etag_query     => NULL,
    p_comments       => 'Upload Policy Template'
  );

  -- Define the Handler
  ORDS.DEFINE_HANDLER(
    p_module_name    => l_module_name,
    p_pattern        => 'upload_policy',
    p_method         => 'POST',
    p_source_type    => 'plsql/block',
    p_items_per_page => 0,
    p_mimes_allowed  => '',
    p_comments       => 'Upload Policy Handler',
    p_source         => '
DECLARE
    -- Variable declarations
    l_body BLOB;
BEGIN
    -- Retrieve the request body
    l_body := :body;

    -- TODO: Process the policy upload logic here
    -- Example:
    -- INSERT INTO policy_uploads (upload_content, upload_date) VALUES (l_body, SYSDATE);
    
    -- Set response status
    :status_code := 200;
    
    -- Optional: Return a JSON response
    -- APEX_JSON.open_object;
    -- APEX_JSON.write(''status'', ''success'');
    -- APEX_JSON.write(''message'', ''Policy uploaded successfully'');
    -- APEX_JSON.close_object;
EXCEPTION
    WHEN OTHERS THEN
        :status_code := 500;
        -- Log error
        -- INSERT INTO error_log ...
        RAISE;
END;'
  );

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/
