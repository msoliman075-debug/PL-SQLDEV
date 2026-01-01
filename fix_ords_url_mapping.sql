-- ============================================================================
-- Script: fix_ords_url_mapping.sql
-- Purpose: Disable ORDS schema, update URL mapping, and re-enable schema
-- Author: Oracle PL/SQL Expert
-- Target: Oracle 19c+ with ORDS
-- ============================================================================
-- 
-- USAGE:
--   1. Update the schema_name variable with your schema
--   2. Update the URL mapping parameters as needed
--   3. Run this script as a user with ORDS privileges
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF
SET ECHO ON

DECLARE
    -- Configuration Variables
    v_schema_name       VARCHAR2(128) := 'YOUR_SCHEMA_NAME';  -- Replace with your schema
    v_module_name       VARCHAR2(255) := 'YOUR_MODULE_NAME';  -- Replace if updating specific module
    v_base_path         VARCHAR2(255) := '/api/v1/';          -- Replace with your desired base path
    
    -- Status Variables
    v_schema_enabled    BOOLEAN;
    v_error_message     VARCHAR2(4000);
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('ORDS URL Mapping Fix - Starting Process');
    DBMS_OUTPUT.PUT_LINE('Schema: ' || v_schema_name);
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- STEP 1: Check if schema is currently enabled
    -- ========================================================================
    BEGIN
        SELECT COUNT(*) INTO v_schema_enabled
        FROM ORDS_METADATA.ORDS_SCHEMAS
        WHERE schema_name = UPPER(v_schema_name)
        AND is_enabled = 'Y';
        
        IF v_schema_enabled > 0 THEN
            DBMS_OUTPUT.PUT_LINE('[INFO] Schema ' || v_schema_name || ' is currently ENABLED');
            v_schema_enabled := TRUE;
        ELSE
            DBMS_OUTPUT.PUT_LINE('[INFO] Schema ' || v_schema_name || ' is currently DISABLED');
            v_schema_enabled := FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[ERROR] Unable to check schema status: ' || SQLERRM);
            RAISE;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- STEP 2: Disable the schema if it's enabled
    -- ========================================================================
    IF v_schema_enabled THEN
        BEGIN
            DBMS_OUTPUT.PUT_LINE('[ACTION] Disabling ORDS schema: ' || v_schema_name);
            
            ORDS.DISABLE_SCHEMA(
                p_schema => v_schema_name
            );
            
            DBMS_OUTPUT.PUT_LINE('[SUCCESS] Schema disabled successfully');
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('[ERROR] Failed to disable schema: ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('[ERROR] Error Code: ' || SQLCODE);
                RAISE;
        END;
    ELSE
        DBMS_OUTPUT.PUT_LINE('[INFO] Schema is already disabled, no action needed');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- STEP 3: Update the URL mapping
    -- ========================================================================
    BEGIN
        DBMS_OUTPUT.PUT_LINE('[ACTION] Updating URL mapping...');
        
        -- Example: Update the base path for the schema
        -- Uncomment and modify based on your specific needs
        
        /*
        ORDS.DEFINE_MODULE(
            p_module_name    => v_module_name,
            p_base_path      => v_base_path,
            p_items_per_page => 25,
            p_status         => 'PUBLISHED',
            p_comments       => 'Updated via fix_ords_url_mapping.sql'
        );
        */
        
        -- Or update existing mapping using ORDS_INTERNAL or direct table updates
        -- CAUTION: Direct table updates should be avoided; use ORDS APIs when possible
        
        /*
        UPDATE ORDS_METADATA.ORDS_MODULES
        SET base_path = v_base_path
        WHERE name = v_module_name
        AND schema_id = (SELECT id FROM ORDS_METADATA.ORDS_SCHEMAS 
                        WHERE schema_name = UPPER(v_schema_name));
        */
        
        DBMS_OUTPUT.PUT_LINE('[INFO] URL mapping update section ready');
        DBMS_OUTPUT.PUT_LINE('[INFO] Please uncomment and configure the appropriate ORDS API calls above');
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('[SUCCESS] Changes committed');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[ERROR] Failed to update URL mapping: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('[ERROR] Error Code: ' || SQLCODE);
            ROLLBACK;
            RAISE;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- STEP 4: Re-enable the schema if it was originally enabled
    -- ========================================================================
    IF v_schema_enabled THEN
        BEGIN
            DBMS_OUTPUT.PUT_LINE('[ACTION] Re-enabling ORDS schema: ' || v_schema_name);
            
            ORDS.ENABLE_SCHEMA(
                p_schema => v_schema_name,
                p_url_mapping_type => 'BASE_PATH',
                p_url_mapping_pattern => v_base_path,
                p_auto_rest_auth => FALSE
            );
            
            DBMS_OUTPUT.PUT_LINE('[SUCCESS] Schema re-enabled successfully');
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('[ERROR] Failed to re-enable schema: ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('[ERROR] Error Code: ' || SQLCODE);
                DBMS_OUTPUT.PUT_LINE('[WARNING] Schema remains DISABLED - manual intervention required');
                RAISE;
        END;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('ORDS URL Mapping Fix - Process Completed Successfully');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('=======================================================');
        DBMS_OUTPUT.PUT_LINE('[FATAL ERROR] Process failed with error:');
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
        DBMS_OUTPUT.PUT_LINE('Error Message: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('=======================================================');
        ROLLBACK;
        RAISE;
END;
/

-- ============================================================================
-- Verify the changes
-- ============================================================================
PROMPT
PROMPT Verifying ORDS schema status...
PROMPT

SELECT 
    schema_name,
    is_enabled,
    parsing_schema,
    CASE 
        WHEN is_enabled = 'Y' THEN 'Schema is ENABLED and ready to serve requests'
        ELSE 'Schema is DISABLED - no REST endpoints available'
    END as status_description
FROM ORDS_METADATA.ORDS_SCHEMAS
WHERE schema_name = UPPER('&schema_name_to_verify')
ORDER BY schema_name;

PROMPT
PROMPT Script execution completed.
PROMPT
