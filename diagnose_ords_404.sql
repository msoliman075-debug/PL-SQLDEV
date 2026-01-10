SET SERVEROUTPUT ON SIZE 1000000
DECLARE
    v_schema_alias VARCHAR2(100) := 'hr'; -- The schema alias in the URL
    v_module_pattern VARCHAR2(100) := 'empinfo'; -- The module or pattern in the URL
    v_schema_count NUMBER;
    v_module_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- ORDS Diagnosis Start ---');
    
    -- 1. Check if Schema is REST Enabled
    SELECT COUNT(*) INTO v_schema_count
    FROM user_ords_schemas
    WHERE url_mapping_pattern = v_schema_alias
       OR url_mapping_pattern = LOWER(v_schema_alias)
       OR url_mapping_pattern = UPPER(v_schema_alias);
       
    IF v_schema_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] Schema is REST enabled with alias: ' || v_schema_alias);
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Schema alias "' || v_schema_alias || '" not found in USER_ORDS_SCHEMAS.');
        DBMS_OUTPUT.PUT_LINE('       Action: Run ORDS.ENABLE_SCHEMA for the schema user.');
    END IF;

    -- 2. Check Module Definition
    SELECT COUNT(*) INTO v_module_count
    FROM user_ords_modules
    WHERE uri_prefix LIKE '%' || v_module_pattern || '%'
       OR status = 'PUBLISHED';

    IF v_module_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] Found ' || v_module_count || ' published modules.');
        
        FOR r IN (SELECT id, uri_prefix, status FROM user_ords_modules) LOOP
            DBMS_OUTPUT.PUT_LINE('       Module: ' || r.uri_prefix || ' Status: ' || r.status);
            
            -- Check Templates
            FOR t IN (SELECT uri_template FROM user_ords_templates WHERE module_id = r.id) LOOP
                DBMS_OUTPUT.PUT_LINE('         Template: ' || t.uri_template);
            END LOOP;
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('[WARN] No modules found matching "' || v_module_pattern || '".');
    END IF;

    DBMS_OUTPUT.PUT_LINE('--- ORDS Diagnosis End ---');
END;
/
