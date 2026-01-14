/*
================================================================================
  ORDS DBA Grants - Direct Access to ORDS_METADATA Tables
================================================================================
  Purpose: Grant direct SELECT access to ORDS internal metadata tables
  Execute As: SYS, SYSTEM, or user with GRANT privilege on ORDS_METADATA
  
  WARNING: These grants expose ALL ORDS metadata across ALL schemas!
           Only use for administrative users who need cross-schema visibility.
  
  NOTE: Table names vary between ORDS versions. This script uses PL/SQL
        to safely grant on tables that exist, ignoring missing ones.
================================================================================
*/

SET SERVEROUTPUT ON

PROMPT ============================================================
PROMPT  Granting ORDS_METADATA table access to SURETY
PROMPT ============================================================
PROMPT
PROMPT  WARNING: This will allow SURETY to see ORDS configuration
PROMPT           for ALL schemas, not just their own!
PROMPT
PROMPT ============================================================

-- Safe grant procedure that handles missing tables
DECLARE
    PROCEDURE safe_grant(p_table_name VARCHAR2, p_grantee VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE 'GRANT SELECT ON ords_metadata.' || p_table_name || ' TO ' || p_grantee;
        DBMS_OUTPUT.PUT_LINE('GRANTED SELECT ON ords_metadata.' || p_table_name || ' TO ' || p_grantee);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -942 THEN
                DBMS_OUTPUT.PUT_LINE('SKIPPED: ords_metadata.' || p_table_name || ' does not exist');
            ELSE
                DBMS_OUTPUT.PUT_LINE('ERROR on ' || p_table_name || ': ' || SQLERRM);
            END IF;
    END;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== Granting ORDS_METADATA access to SURETY ===');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Core module tables (most ORDS versions)
    safe_grant('ords_modules', 'surety');
    safe_grant('ords_schemas', 'surety');
    safe_grant('ords_templates', 'surety');
    safe_grant('ords_handlers', 'surety');
    safe_grant('ords_parameters', 'surety');
    
    -- URL mapping tables
    safe_grant('ords_url_mappings', 'surety');
    safe_grant('ords_privilege_mappings', 'surety');
    
    -- Security tables (may not exist in all versions)
    safe_grant('ords_privileges', 'surety');
    safe_grant('ords_roles', 'surety');
    safe_grant('ords_privilege_roles', 'surety');
    safe_grant('ords_clients', 'surety');
    safe_grant('ords_client_roles', 'surety');
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== Grant process complete ===');
END;
/

COMMIT;

PROMPT
PROMPT ============================================================
PROMPT  Grants completed. SURETY can now run:
PROMPT ============================================================
PROMPT
PROMPT  SELECT s.parsing_schema, m.name, m.uri_prefix, m.status
PROMPT  FROM ords_metadata.ords_modules m
PROMPT  JOIN ords_metadata.ords_schemas s ON m.schema_id = s.id
PROMPT  WHERE s.parsing_schema = 'SURETY';
PROMPT
PROMPT ============================================================

/*
================================================================================
  REVOKE SECTION - Use to remove grants if needed
================================================================================
  Uncomment and run as SYS to revoke access
================================================================================

REVOKE SELECT ON ords_metadata.ords_modules FROM surety;
REVOKE SELECT ON ords_metadata.ords_schemas FROM surety;
REVOKE SELECT ON ords_metadata.ords_templates FROM surety;
REVOKE SELECT ON ords_metadata.ords_handlers FROM surety;
REVOKE SELECT ON ords_metadata.ords_parameters FROM surety;
REVOKE SELECT ON ords_metadata.ords_privileges FROM surety;
REVOKE SELECT ON ords_metadata.ords_roles FROM surety;
REVOKE SELECT ON ords_metadata.ords_privilege_roles FROM surety;
REVOKE SELECT ON ords_metadata.ords_privilege_mappings FROM surety;
REVOKE SELECT ON ords_metadata.ords_url_mappings FROM surety;

*/

/*
================================================================================
  ALTERNATIVE: Create a filtered view for controlled access
================================================================================
  This approach is more secure - creates a view that only shows
  specific schemas' data rather than all ORDS metadata
================================================================================
*/

PROMPT
PROMPT Creating filtered view for SURETY (recommended approach)...
PROMPT

CREATE OR REPLACE VIEW surety.v_ords_modules_filtered AS
SELECT 
    s.parsing_schema,
    m.name AS module_name,
    m.uri_prefix,
    m.status,
    m.items_per_page,
    m.created_on,
    m.updated_on
FROM ords_metadata.ords_modules m
JOIN ords_metadata.ords_schemas s ON m.schema_id = s.id
WHERE s.parsing_schema = 'SURETY'  -- Only show SURETY's modules
WITH READ ONLY;

GRANT SELECT ON surety.v_ords_modules_filtered TO surety;

PROMPT
PROMPT View created: surety.v_ords_modules_filtered
PROMPT This view only shows SURETY schema modules (more secure).
PROMPT

/*
================================================================================
  Grant to ORDS_ADMINISTRATOR Role (if using ORDS role-based security)
================================================================================
*/

-- Create an ORDS admin role if it doesn't exist
-- DECLARE
--     v_count NUMBER;
-- BEGIN
--     SELECT COUNT(*) INTO v_count FROM dba_roles WHERE role = 'ORDS_ADMIN_ROLE';
--     IF v_count = 0 THEN
--         EXECUTE IMMEDIATE 'CREATE ROLE ords_admin_role';
--     END IF;
-- END;
-- /

-- GRANT SELECT ON ords_metadata.ords_modules TO ords_admin_role;
-- GRANT SELECT ON ords_metadata.ords_schemas TO ords_admin_role;
-- GRANT SELECT ON ords_metadata.ords_templates TO ords_admin_role;
-- GRANT SELECT ON ords_metadata.ords_handlers TO ords_admin_role;
-- GRANT SELECT ON ords_metadata.ords_parameters TO ords_admin_role;

-- Then grant role to users who need admin access:
-- GRANT ords_admin_role TO surety;
