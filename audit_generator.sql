CREATE OR REPLACE PROCEDURE generate_audit_log (
    p_table_name IN VARCHAR2
) AUTHID CURRENT_USER IS
    v_audit_table_name VARCHAR2(128);
    v_trigger_name     VARCHAR2(128);
    v_sql              CLOB;
    v_cols             CLOB;
    v_cols_insert      CLOB;
    v_cols_new         CLOB;
    v_cols_old         CLOB;
    v_pk_col           VARCHAR2(128);
    
    -- Exception for table not found
    e_table_not_found  EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_table_not_found, -00942);

    v_count NUMBER;

BEGIN
    -- 1. Validate input and standardize name
    IF p_table_name IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Table name cannot be null.');
    END IF;

    -- Verify table exists
    SELECT COUNT(*) INTO v_count
    FROM user_tables
    WHERE table_name = UPPER(p_table_name);
    
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Table ' || UPPER(p_table_name) || ' does not exist.');
    END IF;

    v_audit_table_name := UPPER(p_table_name) || '_LOG';
    v_trigger_name := UPPER(p_table_name) || '_TRG_AUDIT';

    -- 2. Construct the Audit Table DDL
    -- We want to mirror the columns of the source table.
    -- We will check if the audit table already exists to avoid errors, or drop/recreate (safer to just fail or skip if exists)
    -- For this procedure, let's assume we want to create it if it doesn't exist.
    
    SELECT COUNT(*) INTO v_count
    FROM user_tables
    WHERE table_name = v_audit_table_name;

    IF v_count = 0 THEN
        v_sql := 'CREATE TABLE ' || v_audit_table_name || ' (' || CHR(10) ||
                 '    audit_id          NUMBER GENERATED ALWAYS AS IDENTITY,' || CHR(10) ||
                 '    audit_action      VARCHAR2(10),' || CHR(10) ||
                 '    audit_timestamp   TIMESTAMP DEFAULT SYSTIMESTAMP,' || CHR(10) ||
                 '    audit_user        VARCHAR2(100),' || CHR(10);
        
        -- Loop through columns to add them to the CREATE statement
        FOR r IN (SELECT column_name, data_type, data_length, data_precision, data_scale
                  FROM user_tab_columns
                  WHERE table_name = UPPER(p_table_name)
                  ORDER BY column_id) 
        LOOP
            v_sql := v_sql || '    ' || r.column_name || ' ' || r.data_type;
            
            -- Add length/precision for relevant types
            IF r.data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2') THEN
                v_sql := v_sql || '(' || r.data_length || ')';
            ELSIF r.data_type = 'NUMBER' AND r.data_precision IS NOT NULL THEN
                 v_sql := v_sql || '(' || r.data_precision;
                 IF r.data_scale IS NOT NULL THEN
                    v_sql := v_sql || ',' || r.data_scale;
                 END IF;
                 v_sql := v_sql || ')';
            END IF;
            
            v_sql := v_sql || ',' || CHR(10);
        END LOOP;
        
        -- Remove trailing comma and close parenthesis
        v_sql := SUBSTR(v_sql, 1, LENGTH(v_sql) - 2) || CHR(10) || ')';
        
        DBMS_OUTPUT.PUT_LINE('Creating Audit Table: ' || v_audit_table_name);
        EXECUTE IMMEDIATE v_sql;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Audit Table ' || v_audit_table_name || ' already exists. Skipping creation.');
    END IF;

    -- 3. Construct the Trigger DDL
    -- We need to build the column lists for the INSERT statement in the trigger
    
    v_cols := '';
    v_cols_new := '';
    v_cols_old := '';
    
    FOR r IN (SELECT column_name 
              FROM user_tab_columns 
              WHERE table_name = UPPER(p_table_name) 
              ORDER BY column_id) 
    LOOP
        v_cols := v_cols || r.column_name || ', ';
        v_cols_new := v_cols_new || ':NEW.' || r.column_name || ', ';
        v_cols_old := v_cols_old || ':OLD.' || r.column_name || ', ';
    END LOOP;
    
    -- Trim trailing comma and space
    v_cols := SUBSTR(v_cols, 1, LENGTH(v_cols) - 2);
    v_cols_new := SUBSTR(v_cols_new, 1, LENGTH(v_cols_new) - 2);
    v_cols_old := SUBSTR(v_cols_old, 1, LENGTH(v_cols_old) - 2);

    v_sql := 'CREATE OR REPLACE TRIGGER ' || v_trigger_name || CHR(10) ||
             'AFTER INSERT OR UPDATE OR DELETE ON ' || UPPER(p_table_name) || CHR(10) ||
             'FOR EACH ROW' || CHR(10) ||
             'DECLARE' || CHR(10) ||
             '    v_user VARCHAR2(100) := SYS_CONTEXT(''USERENV'', ''OS_USER'');' || CHR(10) ||
             'BEGIN' || CHR(10) ||
             '    IF INSERTING THEN' || CHR(10) ||
             '        INSERT INTO ' || v_audit_table_name || ' (audit_action, audit_user, ' || v_cols || ')' || CHR(10) ||
             '        VALUES (''INSERT'', v_user, ' || v_cols_new || ');' || CHR(10) ||
             '    ELSIF DELETING THEN' || CHR(10) ||
             '        INSERT INTO ' || v_audit_table_name || ' (audit_action, audit_user, ' || v_cols || ')' || CHR(10) ||
             '        VALUES (''DELETE'', v_user, ' || v_cols_old || ');' || CHR(10) ||
             '    ELSIF UPDATING THEN' || CHR(10) ||
             '        INSERT INTO ' || v_audit_table_name || ' (audit_action, audit_user, ' || v_cols || ')' || CHR(10) ||
             '        VALUES (''UPDATE'', v_user, ' || v_cols_new || ');' || CHR(10) ||
             '    END IF;' || CHR(10) ||
             'END;';

    DBMS_OUTPUT.PUT_LINE('Creating Trigger: ' || v_trigger_name);
    EXECUTE IMMEDIATE v_sql;
    
    DBMS_OUTPUT.PUT_LINE('Audit infrastructure successfully generated for table ' || UPPER(p_table_name));

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END;
/
