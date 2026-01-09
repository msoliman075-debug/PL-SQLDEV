CREATE OR REPLACE PACKAGE BODY audit_pkg AS
/*******************************************************************************
* Package Body: AUDIT_PKG
* Purpose:      Implementation of audit table and trigger generation
*******************************************************************************/

    -- Private constant for maximum identifier length (Oracle 12.2+)
    gc_max_identifier_len CONSTANT PLS_INTEGER := 128;

    /***************************************************************************
    * Private Procedure: validate_table_exists
    * Purpose: Validates that the source table exists
    ***************************************************************************/
    PROCEDURE validate_table_exists(
        p_table_name  IN VARCHAR2,
        p_table_owner IN VARCHAR2
    ) IS
        l_count PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO l_count
          FROM all_tables
         WHERE table_name = UPPER(p_table_name)
           AND owner = UPPER(p_table_owner);

        IF l_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Table ' || UPPER(p_table_owner) || '.' || UPPER(p_table_name) ||
                ' does not exist or is not accessible.');
        END IF;
    END validate_table_exists;

    /***************************************************************************
    * Private Function: get_table_columns
    * Purpose: Returns cursor of columns for the source table
    ***************************************************************************/
    FUNCTION get_table_columns(
        p_table_name      IN VARCHAR2,
        p_table_owner     IN VARCHAR2,
        p_exclude_columns IN VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        l_cursor SYS_REFCURSOR;
    BEGIN
        OPEN l_cursor FOR
            SELECT column_name,
                   data_type,
                   data_length,
                   data_precision,
                   data_scale,
                   nullable
              FROM all_tab_columns
             WHERE table_name = UPPER(p_table_name)
               AND owner = UPPER(p_table_owner)
               AND (p_exclude_columns IS NULL
                    OR INSTR(UPPER(',' || p_exclude_columns || ','),
                             ',' || column_name || ',') = 0)
             ORDER BY column_id;

        RETURN l_cursor;
    END get_table_columns;

    /***************************************************************************
    * Private Function: build_column_definition
    * Purpose: Builds column definition string for audit table
    ***************************************************************************/
    FUNCTION build_column_definition(
        p_column_name   IN VARCHAR2,
        p_data_type     IN VARCHAR2,
        p_data_length   IN NUMBER,
        p_data_precision IN NUMBER,
        p_data_scale    IN NUMBER
    ) RETURN VARCHAR2 IS
        l_col_def VARCHAR2(500);
    BEGIN
        l_col_def := '"' || p_column_name || '" ';

        CASE
            WHEN p_data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') THEN
                l_col_def := l_col_def || p_data_type || '(' || p_data_length || ')';

            WHEN p_data_type = 'NUMBER' THEN
                IF p_data_precision IS NOT NULL THEN
                    l_col_def := l_col_def || 'NUMBER(' || p_data_precision;
                    IF p_data_scale IS NOT NULL AND p_data_scale > 0 THEN
                        l_col_def := l_col_def || ',' || p_data_scale;
                    END IF;
                    l_col_def := l_col_def || ')';
                ELSE
                    l_col_def := l_col_def || 'NUMBER';
                END IF;

            WHEN p_data_type = 'RAW' THEN
                l_col_def := l_col_def || 'RAW(' || p_data_length || ')';

            WHEN p_data_type LIKE 'TIMESTAMP%' THEN
                l_col_def := l_col_def || p_data_type;

            WHEN p_data_type IN ('CLOB', 'BLOB', 'NCLOB') THEN
                -- Store LOB audit as VARCHAR2 excerpt or NULL
                l_col_def := l_col_def || 'VARCHAR2(4000)';

            WHEN p_data_type = 'LONG' THEN
                -- LONG columns stored as CLOB in audit
                l_col_def := l_col_def || 'CLOB';

            ELSE
                l_col_def := l_col_def || p_data_type;
        END CASE;

        RETURN l_col_def;
    END build_column_definition;

    /***************************************************************************
    * Function: GET_AUDIT_DDL
    * Purpose:  Returns the DDL for audit table without executing
    ***************************************************************************/
    FUNCTION get_audit_ddl(
        p_table_name   IN VARCHAR2,
        p_table_owner  IN VARCHAR2 DEFAULT USER,
        p_audit_suffix IN VARCHAR2 DEFAULT '_AUDIT_LOG'
    ) RETURN CLOB IS
        l_ddl           CLOB;
        l_audit_table   VARCHAR2(128);
        l_column_name   VARCHAR2(128);
        l_data_type     VARCHAR2(128);
        l_data_length   NUMBER;
        l_data_precision NUMBER;
        l_data_scale    NUMBER;
        l_nullable      VARCHAR2(1);
        l_cursor        SYS_REFCURSOR;
        l_seq_name      VARCHAR2(128);
    BEGIN
        -- Validate source table exists
        validate_table_exists(p_table_name, p_table_owner);

        -- Build audit table name
        l_audit_table := UPPER(SUBSTR(p_table_name, 1,
                                       gc_max_identifier_len - LENGTH(p_audit_suffix)))
                         || UPPER(p_audit_suffix);

        l_seq_name := l_audit_table || '_SEQ';

        -- Start building DDL
        l_ddl := '-- Audit Table DDL for ' || UPPER(p_table_owner) || '.' ||
                 UPPER(p_table_name) || CHR(10) || CHR(10);

        -- Sequence for AUDIT_ID
        l_ddl := l_ddl || '-- Create sequence for audit ID' || CHR(10);
        l_ddl := l_ddl || 'CREATE SEQUENCE ' || l_seq_name ||
                 ' START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;' || CHR(10) || CHR(10);

        -- Create table statement
        l_ddl := l_ddl || 'CREATE TABLE ' || l_audit_table || ' (' || CHR(10);

        -- Standard audit columns
        l_ddl := l_ddl || '    AUDIT_ID           NUMBER           NOT NULL,' || CHR(10);
        l_ddl := l_ddl || '    DML_TYPE           VARCHAR2(6)      NOT NULL,' || CHR(10);
        l_ddl := l_ddl || '    DML_TIMESTAMP      TIMESTAMP(6)     DEFAULT SYSTIMESTAMP NOT NULL,' || CHR(10);
        l_ddl := l_ddl || '    DML_USER           VARCHAR2(128)    DEFAULT USER NOT NULL,' || CHR(10);
        l_ddl := l_ddl || '    SESSION_ID         NUMBER,' || CHR(10);
        l_ddl := l_ddl || '    CLIENT_HOST        VARCHAR2(64),' || CHR(10);
        l_ddl := l_ddl || '    CLIENT_IP          VARCHAR2(40),' || CHR(10);
        l_ddl := l_ddl || '    MODULE             VARCHAR2(64),' || CHR(10);
        l_ddl := l_ddl || '    ACTION             VARCHAR2(64),' || CHR(10);

        -- Get source table columns
        l_cursor := get_table_columns(p_table_name, p_table_owner);

        LOOP
            FETCH l_cursor INTO l_column_name, l_data_type, l_data_length,
                               l_data_precision, l_data_scale, l_nullable;
            EXIT WHEN l_cursor%NOTFOUND;

            -- OLD_ column
            l_ddl := l_ddl || '    OLD_' ||
                     build_column_definition(l_column_name, l_data_type,
                                            l_data_length, l_data_precision,
                                            l_data_scale) || ',' || CHR(10);

            -- NEW_ column
            l_ddl := l_ddl || '    NEW_' ||
                     build_column_definition(l_column_name, l_data_type,
                                            l_data_length, l_data_precision,
                                            l_data_scale) || ',' || CHR(10);
        END LOOP;
        CLOSE l_cursor;

        -- Primary key constraint
        l_ddl := l_ddl || '    CONSTRAINT ' || l_audit_table || '_PK PRIMARY KEY (AUDIT_ID)' || CHR(10);
        l_ddl := l_ddl || ')' || CHR(10);
        l_ddl := l_ddl || 'TABLESPACE USERS;' || CHR(10) || CHR(10);

        -- Index on timestamp for query performance
        l_ddl := l_ddl || '-- Index for timestamp-based queries' || CHR(10);
        l_ddl := l_ddl || 'CREATE INDEX ' || l_audit_table || '_TS_IDX ON ' ||
                 l_audit_table || ' (DML_TIMESTAMP DESC)' || CHR(10);
        l_ddl := l_ddl || 'TABLESPACE USERS;' || CHR(10) || CHR(10);

        -- Comment on table
        l_ddl := l_ddl || '-- Table comment' || CHR(10);
        l_ddl := l_ddl || 'COMMENT ON TABLE ' || l_audit_table ||
                 ' IS ''Audit log for ' || UPPER(p_table_owner) || '.' ||
                 UPPER(p_table_name) || ' - Auto-generated'';' || CHR(10);

        RETURN l_ddl;

    EXCEPTION
        WHEN OTHERS THEN
            IF l_cursor%ISOPEN THEN
                CLOSE l_cursor;
            END IF;
            RAISE;
    END get_audit_ddl;

    /***************************************************************************
    * Function: GET_TRIGGER_DDL
    * Purpose:  Returns the DDL for audit trigger without executing
    ***************************************************************************/
    FUNCTION get_trigger_ddl(
        p_table_name      IN VARCHAR2,
        p_table_owner     IN VARCHAR2 DEFAULT USER,
        p_audit_suffix    IN VARCHAR2 DEFAULT '_AUDIT_LOG',
        p_trigger_suffix  IN VARCHAR2 DEFAULT '_AUDIT_TRG',
        p_exclude_columns IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_ddl           CLOB;
        l_trigger_name  VARCHAR2(128);
        l_audit_table   VARCHAR2(128);
        l_seq_name      VARCHAR2(128);
        l_column_name   VARCHAR2(128);
        l_data_type     VARCHAR2(128);
        l_data_length   NUMBER;
        l_data_precision NUMBER;
        l_data_scale    NUMBER;
        l_nullable      VARCHAR2(1);
        l_cursor        SYS_REFCURSOR;
        l_col_list      CLOB;
        l_old_list      CLOB;
        l_new_list      CLOB;
        l_first         BOOLEAN := TRUE;
    BEGIN
        -- Validate source table exists
        validate_table_exists(p_table_name, p_table_owner);

        -- Build object names
        l_trigger_name := UPPER(SUBSTR(p_table_name, 1,
                                        gc_max_identifier_len - LENGTH(p_trigger_suffix)))
                          || UPPER(p_trigger_suffix);

        l_audit_table := UPPER(SUBSTR(p_table_name, 1,
                                       gc_max_identifier_len - LENGTH(p_audit_suffix)))
                         || UPPER(p_audit_suffix);

        l_seq_name := l_audit_table || '_SEQ';

        -- Build column lists
        l_cursor := get_table_columns(p_table_name, p_table_owner, p_exclude_columns);

        LOOP
            FETCH l_cursor INTO l_column_name, l_data_type, l_data_length,
                               l_data_precision, l_data_scale, l_nullable;
            EXIT WHEN l_cursor%NOTFOUND;

            IF NOT l_first THEN
                l_col_list := l_col_list || ',' || CHR(10);
                l_old_list := l_old_list || ',' || CHR(10);
                l_new_list := l_new_list || ',' || CHR(10);
            END IF;
            l_first := FALSE;

            l_col_list := l_col_list || '            OLD_' || l_column_name ||
                          ', NEW_' || l_column_name;

            -- Handle LOB types specially
            IF l_data_type IN ('CLOB', 'BLOB', 'NCLOB') THEN
                l_old_list := l_old_list || '            CASE WHEN :OLD.' ||
                              l_column_name || ' IS NOT NULL THEN SUBSTR(TO_CHAR(:OLD.' ||
                              l_column_name || '), 1, 4000) ELSE NULL END';
                l_new_list := l_new_list || '            CASE WHEN :NEW.' ||
                              l_column_name || ' IS NOT NULL THEN SUBSTR(TO_CHAR(:NEW.' ||
                              l_column_name || '), 1, 4000) ELSE NULL END';
            ELSE
                l_old_list := l_old_list || '            :OLD.' || l_column_name;
                l_new_list := l_new_list || '            :NEW.' || l_column_name;
            END IF;
        END LOOP;
        CLOSE l_cursor;

        -- Build trigger DDL
        l_ddl := '-- Audit Trigger for ' || UPPER(p_table_owner) || '.' ||
                 UPPER(p_table_name) || CHR(10) || CHR(10);

        l_ddl := l_ddl || 'CREATE OR REPLACE TRIGGER ' || l_trigger_name || CHR(10);
        l_ddl := l_ddl || 'AFTER INSERT OR UPDATE OR DELETE ON ' ||
                 UPPER(p_table_owner) || '.' || UPPER(p_table_name) || CHR(10);
        l_ddl := l_ddl || 'FOR EACH ROW' || CHR(10);
        l_ddl := l_ddl || 'DECLARE' || CHR(10);
        l_ddl := l_ddl || '    PRAGMA AUTONOMOUS_TRANSACTION;' || CHR(10);
        l_ddl := l_ddl || '    l_dml_type     VARCHAR2(6);' || CHR(10);
        l_ddl := l_ddl || '    l_session_id   NUMBER;' || CHR(10);
        l_ddl := l_ddl || '    l_client_host  VARCHAR2(64);' || CHR(10);
        l_ddl := l_ddl || '    l_client_ip    VARCHAR2(40);' || CHR(10);
        l_ddl := l_ddl || '    l_module       VARCHAR2(64);' || CHR(10);
        l_ddl := l_ddl || '    l_action       VARCHAR2(64);' || CHR(10);
        l_ddl := l_ddl || 'BEGIN' || CHR(10);
        l_ddl := l_ddl || '    -- Determine DML operation type' || CHR(10);
        l_ddl := l_ddl || '    IF INSERTING THEN' || CHR(10);
        l_ddl := l_ddl || '        l_dml_type := ''' || gc_insert || ''';' || CHR(10);
        l_ddl := l_ddl || '    ELSIF UPDATING THEN' || CHR(10);
        l_ddl := l_ddl || '        l_dml_type := ''' || gc_update || ''';' || CHR(10);
        l_ddl := l_ddl || '    ELSIF DELETING THEN' || CHR(10);
        l_ddl := l_ddl || '        l_dml_type := ''' || gc_delete || ''';' || CHR(10);
        l_ddl := l_ddl || '    END IF;' || CHR(10) || CHR(10);

        l_ddl := l_ddl || '    -- Capture session context' || CHR(10);
        l_ddl := l_ddl || '    l_session_id  := SYS_CONTEXT(''USERENV'', ''SESSIONID'');' || CHR(10);
        l_ddl := l_ddl || '    l_client_host := SYS_CONTEXT(''USERENV'', ''HOST'');' || CHR(10);
        l_ddl := l_ddl || '    l_client_ip   := SYS_CONTEXT(''USERENV'', ''IP_ADDRESS'');' || CHR(10);
        l_ddl := l_ddl || '    l_module      := SYS_CONTEXT(''USERENV'', ''MODULE'');' || CHR(10);
        l_ddl := l_ddl || '    l_action      := SYS_CONTEXT(''USERENV'', ''ACTION'');' || CHR(10) || CHR(10);

        l_ddl := l_ddl || '    -- Insert audit record' || CHR(10);
        l_ddl := l_ddl || '    INSERT INTO ' || l_audit_table || ' (' || CHR(10);
        l_ddl := l_ddl || '        AUDIT_ID,' || CHR(10);
        l_ddl := l_ddl || '        DML_TYPE,' || CHR(10);
        l_ddl := l_ddl || '        DML_TIMESTAMP,' || CHR(10);
        l_ddl := l_ddl || '        DML_USER,' || CHR(10);
        l_ddl := l_ddl || '        SESSION_ID,' || CHR(10);
        l_ddl := l_ddl || '        CLIENT_HOST,' || CHR(10);
        l_ddl := l_ddl || '        CLIENT_IP,' || CHR(10);
        l_ddl := l_ddl || '        MODULE,' || CHR(10);
        l_ddl := l_ddl || '        ACTION,' || CHR(10);
        l_ddl := l_ddl || l_col_list || CHR(10);
        l_ddl := l_ddl || '    ) VALUES (' || CHR(10);
        l_ddl := l_ddl || '        ' || l_seq_name || '.NEXTVAL,' || CHR(10);
        l_ddl := l_ddl || '        l_dml_type,' || CHR(10);
        l_ddl := l_ddl || '        SYSTIMESTAMP,' || CHR(10);
        l_ddl := l_ddl || '        USER,' || CHR(10);
        l_ddl := l_ddl || '        l_session_id,' || CHR(10);
        l_ddl := l_ddl || '        l_client_host,' || CHR(10);
        l_ddl := l_ddl || '        l_client_ip,' || CHR(10);
        l_ddl := l_ddl || '        l_module,' || CHR(10);
        l_ddl := l_ddl || '        l_action,' || CHR(10);
        l_ddl := l_ddl || l_old_list || ',' || CHR(10);
        l_ddl := l_ddl || l_new_list || CHR(10);
        l_ddl := l_ddl || '    );' || CHR(10) || CHR(10);
        l_ddl := l_ddl || '    COMMIT;' || CHR(10) || CHR(10);

        l_ddl := l_ddl || 'EXCEPTION' || CHR(10);
        l_ddl := l_ddl || '    WHEN OTHERS THEN' || CHR(10);
        l_ddl := l_ddl || '        -- Log error but do not fail the main transaction' || CHR(10);
        l_ddl := l_ddl || '        ROLLBACK;' || CHR(10);
        l_ddl := l_ddl || '        -- Optionally log to error table or alert log' || CHR(10);
        l_ddl := l_ddl || '        NULL; -- Silent fail to prevent main transaction failure' || CHR(10);
        l_ddl := l_ddl || 'END ' || l_trigger_name || ';' || CHR(10);
        l_ddl := l_ddl || '/' || CHR(10);

        RETURN l_ddl;

    EXCEPTION
        WHEN OTHERS THEN
            IF l_cursor%ISOPEN THEN
                CLOSE l_cursor;
            END IF;
            RAISE;
    END get_trigger_ddl;

    /***************************************************************************
    * Procedure: CREATE_AUDIT_TABLE
    * Purpose:   Creates an audit log table for the specified source table
    ***************************************************************************/
    PROCEDURE create_audit_table(
        p_table_name   IN VARCHAR2,
        p_table_owner  IN VARCHAR2 DEFAULT USER,
        p_audit_suffix IN VARCHAR2 DEFAULT '_AUDIT_LOG'
    ) IS
        l_ddl         CLOB;
        l_audit_table VARCHAR2(128);
        l_seq_name    VARCHAR2(128);
        l_count       PLS_INTEGER;
        l_lines       APEX_T_VARCHAR2;
        l_line        VARCHAR2(32767);
        l_pos         PLS_INTEGER := 1;
        l_next_pos    PLS_INTEGER;
    BEGIN
        -- Validate source table exists
        validate_table_exists(p_table_name, p_table_owner);

        -- Build audit table name
        l_audit_table := UPPER(SUBSTR(p_table_name, 1,
                                       gc_max_identifier_len - LENGTH(p_audit_suffix)))
                         || UPPER(p_audit_suffix);
        l_seq_name := l_audit_table || '_SEQ';

        -- Check if audit table already exists
        SELECT COUNT(*)
          INTO l_count
          FROM all_tables
         WHERE table_name = l_audit_table
           AND owner = UPPER(p_table_owner);

        IF l_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20002,
                'Audit table ' || l_audit_table || ' already exists.');
        END IF;

        -- Get DDL and execute statements
        l_ddl := get_audit_ddl(p_table_name, p_table_owner, p_audit_suffix);

        -- Parse and execute each statement (separated by semicolons followed by newline)
        LOOP
            l_next_pos := INSTR(l_ddl, ';' || CHR(10), l_pos);
            EXIT WHEN l_next_pos = 0;

            l_line := SUBSTR(l_ddl, l_pos, l_next_pos - l_pos);

            -- Skip comments
            IF l_line NOT LIKE '--%' AND TRIM(l_line) IS NOT NULL THEN
                BEGIN
                    EXECUTE IMMEDIATE TRIM(l_line);
                EXCEPTION
                    WHEN OTHERS THEN
                        -- Continue on comment-only lines
                        IF SQLCODE != -900 THEN
                            RAISE;
                        END IF;
                END;
            END IF;

            l_pos := l_next_pos + 2;
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('Audit table ' || l_audit_table || ' created successfully.');

    EXCEPTION
        WHEN e_audit_exists THEN
            RAISE;
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20003,
                'Error creating audit table: ' || SQLERRM);
    END create_audit_table;

    /***************************************************************************
    * Procedure: CREATE_AUDIT_TRIGGER
    * Purpose:   Creates an AFTER trigger to capture old/new values
    ***************************************************************************/
    PROCEDURE create_audit_trigger(
        p_table_name      IN VARCHAR2,
        p_table_owner     IN VARCHAR2 DEFAULT USER,
        p_audit_suffix    IN VARCHAR2 DEFAULT '_AUDIT_LOG',
        p_trigger_suffix  IN VARCHAR2 DEFAULT '_AUDIT_TRG',
        p_exclude_columns IN VARCHAR2 DEFAULT NULL
    ) IS
        l_ddl          CLOB;
        l_trigger_name VARCHAR2(128);
        l_audit_table  VARCHAR2(128);
        l_count        PLS_INTEGER;
    BEGIN
        -- Validate source table exists
        validate_table_exists(p_table_name, p_table_owner);

        -- Build object names
        l_trigger_name := UPPER(SUBSTR(p_table_name, 1,
                                        gc_max_identifier_len - LENGTH(p_trigger_suffix)))
                          || UPPER(p_trigger_suffix);

        l_audit_table := UPPER(SUBSTR(p_table_name, 1,
                                       gc_max_identifier_len - LENGTH(p_audit_suffix)))
                         || UPPER(p_audit_suffix);

        -- Check if audit table exists
        SELECT COUNT(*)
          INTO l_count
          FROM all_tables
         WHERE table_name = l_audit_table
           AND owner = UPPER(p_table_owner);

        IF l_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Audit table ' || l_audit_table ||
                ' does not exist. Run CREATE_AUDIT_TABLE first.');
        END IF;

        -- Get trigger DDL
        l_ddl := get_trigger_ddl(p_table_name, p_table_owner, p_audit_suffix,
                                 p_trigger_suffix, p_exclude_columns);

        -- Remove the trailing '/' for EXECUTE IMMEDIATE
        l_ddl := RTRIM(l_ddl, '/' || CHR(10));

        -- Find and execute only the CREATE TRIGGER statement
        DECLARE
            l_start PLS_INTEGER;
            l_stmt  CLOB;
        BEGIN
            l_start := INSTR(l_ddl, 'CREATE OR REPLACE TRIGGER');
            IF l_start > 0 THEN
                l_stmt := SUBSTR(l_ddl, l_start);
                EXECUTE IMMEDIATE l_stmt;
            END IF;
        END;

        DBMS_OUTPUT.PUT_LINE('Audit trigger ' || l_trigger_name || ' created successfully.');

    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Error creating audit trigger: ' || SQLERRM);
    END create_audit_trigger;

    /***************************************************************************
    * Procedure: DROP_AUDIT_OBJECTS
    * Purpose:   Removes audit table and trigger for a given source table
    ***************************************************************************/
    PROCEDURE drop_audit_objects(
        p_table_name     IN VARCHAR2,
        p_table_owner    IN VARCHAR2 DEFAULT USER,
        p_audit_suffix   IN VARCHAR2 DEFAULT '_AUDIT_LOG',
        p_trigger_suffix IN VARCHAR2 DEFAULT '_AUDIT_TRG'
    ) IS
        l_trigger_name VARCHAR2(128);
        l_audit_table  VARCHAR2(128);
        l_seq_name     VARCHAR2(128);
    BEGIN
        -- Build object names
        l_trigger_name := UPPER(SUBSTR(p_table_name, 1,
                                        gc_max_identifier_len - LENGTH(p_trigger_suffix)))
                          || UPPER(p_trigger_suffix);

        l_audit_table := UPPER(SUBSTR(p_table_name, 1,
                                       gc_max_identifier_len - LENGTH(p_audit_suffix)))
                         || UPPER(p_audit_suffix);

        l_seq_name := l_audit_table || '_SEQ';

        -- Drop trigger (ignore if not exists)
        BEGIN
            EXECUTE IMMEDIATE 'DROP TRIGGER ' || l_trigger_name;
            DBMS_OUTPUT.PUT_LINE('Trigger ' || l_trigger_name || ' dropped.');
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -4080 THEN -- trigger does not exist
                    DBMS_OUTPUT.PUT_LINE('Trigger ' || l_trigger_name || ' does not exist.');
                ELSE
                    RAISE;
                END IF;
        END;

        -- Drop table (ignore if not exists)
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || l_audit_table || ' PURGE';
            DBMS_OUTPUT.PUT_LINE('Table ' || l_audit_table || ' dropped.');
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -942 THEN -- table does not exist
                    DBMS_OUTPUT.PUT_LINE('Table ' || l_audit_table || ' does not exist.');
                ELSE
                    RAISE;
                END IF;
        END;

        -- Drop sequence (ignore if not exists)
        BEGIN
            EXECUTE IMMEDIATE 'DROP SEQUENCE ' || l_seq_name;
            DBMS_OUTPUT.PUT_LINE('Sequence ' || l_seq_name || ' dropped.');
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -2289 THEN -- sequence does not exist
                    DBMS_OUTPUT.PUT_LINE('Sequence ' || l_seq_name || ' does not exist.');
                ELSE
                    RAISE;
                END IF;
        END;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Error dropping audit objects: ' || SQLERRM);
    END drop_audit_objects;

END audit_pkg;
/
