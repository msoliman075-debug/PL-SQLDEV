# ORDS 404 Troubleshooting Guide

You are encountering a 404 Not Found error at: `http://80.238.234.247:8080/ords/surety/hr/empinfo/`

## Likely Causes

The 404 error usually means ORDS cannot match the URL to a valid resource handler. Based on your URL structure (`/ords/surety/hr/empinfo/`), here are the most probable issues:

1.  **URL Structure Mismatch**:
    *   Standard ORDS URL: `.../ords/<schema_alias>/<module_prefix>/<template_pattern>`
    *   **Scenario A**: `surety` is the Schema Alias, `hr` is the Module.
    *   **Scenario B**: `surety` is a Database Mapping (in `url-mapping.xml`), `hr` is the Schema Alias, `empinfo` is the Module.
    *   **Scenario C**: You are using APEX Workspaces, and the URL format requires specific workspace mapping.

2.  **Schema Not Enabled**: The schema (e.g., `hr` or `surety`) has not been enabled for REST services.
3.  **Module Not Published**: The REST module (e.g., `empinfo`) is not defined or its status is not `PUBLISHED`.
4.  **Trailing Slash**: ORDS patterns can be sensitive to trailing slashes. `/empinfo` vs `/empinfo/`.

## Diagnostic Steps

### 1. Run Database Diagnostics
Run the attached SQL scripts in your Oracle Database (via SQL Developer or SQLPlus).

**Option A: If you can log in as the Schema Owner (e.g., HR)**
Run `diagnose_ords_404.sql`. It checks:
*   If the current user is REST enabled.
*   If the `empinfo` module exists and is published.

**Option B: If you have SYSTEM/Admin access**
Run `diagnose_ords_sys.sql`. It searches:
*   All enabled schemas for `surety` or `hr`.
*   All modules matching `empinfo`.

### 2. Check ORDS Mapping (Tomcat Server)
If `surety` is intended to route to a specific PDB or connection, check the ORDS configuration on the Tomcat server:
*   **File**: `ords/conf/url-mapping.xml` (location varies by install).
*   **Check**: Is there a mapping for `pattern="/surety"`?

### 3. Verify Tomcat Logs
Check `catalina.out` or `localhost` logs in Tomcat (`$CATALINA_HOME/logs/`) for detailed error messages when hitting the endpoint. It often specifies *why* the match failed (e.g., "No matching pattern found").

## Quick Fixes

*   **Enable Schema**: `ORDS.ENABLE_SCHEMA(p_enabled => TRUE, p_schema => 'HR', p_url_mapping_pattern => 'hr', p_auto_rest_auth => FALSE);`
*   **Define Module**: Ensure the module prefix matches exactly.
