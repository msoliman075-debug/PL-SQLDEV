--------------------------------------------------------------------------------
-- DEBUG SCRIPT FOR ORDS 404 ERROR
-- Run this script in the Oracle Schema where the REST service is defined.
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON
DECLARE
    v_schema_alias VARCHAR2(100);
    v_module_cnt   NUMBER;
    v_template_cnt NUMBER;
    v_handler_cnt  NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- ORDS DIAGNOSTIC START ---');

    -- 1. Check Schema Alias
    SELECT MAX(schema_alias) INTO v_schema_alias FROM user_ords_schemas;
    
    IF v_schema_alias IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('[ERROR] Schema is NOT REST Enabled.');
    ELSIF v_schema_alias != 'surety_ws' THEN
        DBMS_OUTPUT.PUT_LINE('[WARNING] Schema alias is "' || v_schema_alias || '", but URL uses "surety_ws".');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[OK] Schema alias matches "surety_ws".');
    END IF;

    -- 2. Check Module
    -- Note: ORDS modules often have a trailing slash in the definition.
    SELECT COUNT(*) INTO v_module_cnt 
    FROM user_ords_modules 
    WHERE uri_prefix = 'ic.policy/' OR uri_prefix = 'ic.policy';

    IF v_module_cnt = 0 THEN
        DBMS_OUTPUT.PUT_LINE('[ERROR] Module "ic.policy" not found. Check user_ords_modules.');
        FOR r IN (SELECT name, uri_prefix FROM user_ords_modules) LOOP
            DBMS_OUTPUT.PUT_LINE('   Found Module: ' || r.name || ' (Prefix: ' || r.uri_prefix || ')');
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('[OK] Module "ic.policy" found.');
    END IF;

    -- 3. Check Template
    SELECT COUNT(*) INTO v_template_cnt
    FROM user_ords_templates t
    JOIN user_ords_modules m ON t.module_id = m.id
    WHERE (m.uri_prefix = 'ic.policy/' OR m.uri_prefix = 'ic.policy')
    AND t.uri_template = 'policy_upload';

    IF v_template_cnt = 0 THEN
        DBMS_OUTPUT.PUT_LINE('[ERROR] Template "policy_upload" not found under module "ic.policy".');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[OK] Template "policy_upload" found.');
    END IF;

    -- 4. Check Handler
    SELECT COUNT(*) INTO v_handler_cnt
    FROM user_ords_handlers h
    JOIN user_ords_templates t ON h.template_id = t.id
    JOIN user_ords_modules m ON t.module_id = m.id
    WHERE (m.uri_prefix = 'ic.policy/' OR m.uri_prefix = 'ic.policy')
    AND t.uri_template = 'policy_upload';

    IF v_handler_cnt = 0 THEN
        DBMS_OUTPUT.PUT_LINE('[ERROR] No Handler (GET/POST) defined for this template.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[OK] Handler exists. Count: ' || v_handler_cnt);
        FOR r IN (
            SELECT h.method, h.source_type 
            FROM user_ords_handlers h
            JOIN user_ords_templates t ON h.template_id = t.id
            JOIN user_ords_modules m ON t.module_id = m.id
            WHERE (m.uri_prefix = 'ic.policy/' OR m.uri_prefix = 'ic.policy')
            AND t.uri_template = 'policy_upload'
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('   Method: ' || r.method || ', Source Type: ' || r.source_type);
        END LOOP;
    END IF;

    DBMS_OUTPUT.PUT_LINE('--- ORDS DIAGNOSTIC END ---');
END;
/
