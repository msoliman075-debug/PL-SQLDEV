SET SERVEROUTPUT ON SIZE 1000000
SET LINESIZE 200
SET PAGESIZE 100

DECLARE
    v_url_schema VARCHAR2(50) := 'hr';   -- Potential schema part
    v_url_part1  VARCHAR2(50) := 'surety'; -- Potential mapping part
    v_module     VARCHAR2(50) := 'empinfo';
BEGIN
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('ORDS 404 DIAGNOSTIC REPORT');
    DBMS_OUTPUT.PUT_LINE('=======================================================');

    -- 1. Check for Schemas matching 'surety' or 'hr'
    DBMS_OUTPUT.PUT_LINE('1. Checking ORDS Enabled Schemas (DBA_ORDS_SCHEMAS)...');
    FOR r IN (
        SELECT schema_name, url_mapping_pattern, status 
        FROM all_ords_schemas 
        WHERE LOWER(url_mapping_pattern) IN (LOWER(v_url_schema), LOWER(v_url_part1))
           OR LOWER(schema_name) IN (LOWER(v_url_schema), LOWER(v_url_part1))
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('   FOUND: Schema: ' || r.schema_name || 
                             ' | Pattern: ' || r.url_mapping_pattern || 
                             ' | Status: ' || r.status);
    END LOOP;

    -- 2. Check for Modules matching 'empinfo' in any schema
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('2. Checking Modules matching "' || v_module || '"...');
    FOR r IN (
        SELECT s.schema_name, m.uri_prefix, m.status, m.id
        FROM all_ords_modules m
        JOIN all_ords_schemas s ON m.schema_id = s.id
        WHERE m.uri_prefix LIKE '%' || v_module || '%'
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('   FOUND: Schema: ' || r.schema_name || 
                             ' | Prefix: ' || r.uri_prefix || 
                             ' | Status: ' || r.status);
                             
        -- Check Templates for this module
        FOR t IN (SELECT uri_template, method FROM all_ords_templates WHERE module_id = r.id) LOOP
             DBMS_OUTPUT.PUT_LINE('      -> Template: ' || t.uri_template);
        END LOOP;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('RECOMMENDATIONS:');
    DBMS_OUTPUT.PUT_LINE('1. If no schema is found: Run ORDS.ENABLE_SCHEMA for the target user.');
    DBMS_OUTPUT.PUT_LINE('2. If schema found but wrong pattern: Adjust pattern or URL.');
    DBMS_OUTPUT.PUT_LINE('   - Standard URL: http://<server>:<port>/ords/<schema_alias>/<module_prefix>/<template>');
    DBMS_OUTPUT.PUT_LINE('   - Your URL: .../ords/surety/hr/empinfo/');
    DBMS_OUTPUT.PUT_LINE('   - Possibility A: "surety" is a database mapping (check url-mapping.xml).');
    DBMS_OUTPUT.PUT_LINE('   - Possibility B: You intended "/ords/hr/empinfo/" and "surety" is extraneous.');
    DBMS_OUTPUT.PUT_LINE('3. Check trailing slashes. "empinfo" vs "empinfo/".');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
END;
/
