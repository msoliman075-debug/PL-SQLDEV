/*******************************************************************************
* Script:  GENERATE_AUDIT_DDL.SQL
* Purpose: Standalone script to generate audit table and trigger DDL
*          for a specific table without installing AUDIT_PKG
*
* Usage:   1. Set the variables in the configuration section below
*          2. Run this script in SQL*Plus or SQL Developer
*          3. Copy the generated DDL and execute as needed
*
* Target:  Oracle 19c+
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET FEEDBACK OFF;
SET VERIFY OFF;

--------------------------------------------------------------------------------
-- CONFIGURATION - Set these values for your target table
--------------------------------------------------------------------------------
DEFINE source_table_name = 'YOUR_TABLE_NAME'
DEFINE source_table_owner = 'YOUR_SCHEMA'
DEFINE audit_table_suffix = '_AUDIT_LOG'
DEFINE trigger_suffix = '_AUDIT_TRG'

-- Comma-separated list of columns to exclude (leave empty for none)
DEFINE exclude_columns = ''

--------------------------------------------------------------------------------
-- Generate DDL
--------------------------------------------------------------------------------
DECLARE
    c_source_table   CONSTANT VARCHAR2(128) := UPPER('&source_table_name');
    c_source_owner   CONSTANT VARCHAR2(128) := UPPER('&source_table_owner');
    c_audit_suffix   CONSTANT VARCHAR2(30)  := '&audit_table_suffix';
    c_trigger_suffix CONSTANT VARCHAR2(30)  := '&trigger_suffix';
    c_exclude_cols   CONSTANT VARCHAR2(4000):= '&exclude_columns';

    l_audit_table    VARCHAR2(128);
    l_trigger_name   VARCHAR2(128);
    l_seq_name       VARCHAR2(128);
    l_ddl            CLOB;
    l_col_list       CLOB;
    l_old_list       CLOB;
    l_new_list       CLOB;
    l_first          BOOLEAN := TRUE;
    l_table_exists   PLS_INTEGER;

    CURSOR c_columns IS
        SELECT column_name,
               data_type,
               data_length,
               data_precision,
               data_scale,
               nullable
          FROM all_tab_columns
         WHERE table_name = c_source_table
           AND owner = c_source_owner
           AND (c_exclude_cols IS NULL
                OR INSTR(UPPER(',' || c_exclude_cols || ','),
                         ',' || column_name || ',') = 0)
         ORDER BY column_id;

    FUNCTION build_column_def(
        p_col_name  VARCHAR2,
        p_data_type VARCHAR2,
        p_length    NUMBER,
        p_precision NUMBER,
        p_scale     NUMBER
    ) RETURN VARCHAR2 IS
        l_def VARCHAR2(500);
    BEGIN
        l_def := '"' || p_col_name || '" ';
        CASE
            WHEN p_data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') THEN
                l_def := l_def || p_data_type || '(' || p_length || ')';
            WHEN p_data_type = 'NUMBER' THEN
                IF p_precision IS NOT NULL THEN
                    l_def := l_def || 'NUMBER(' || p_precision;
                    IF p_scale IS NOT NULL AND p_scale > 0 THEN
                        l_def := l_def || ',' || p_scale;
                    END IF;
                    l_def := l_def || ')';
                ELSE
                    l_def := l_def || 'NUMBER';
                END IF;
            WHEN p_data_type = 'RAW' THEN
                l_def := l_def || 'RAW(' || p_length || ')';
            WHEN p_data_type LIKE 'TIMESTAMP%' THEN
                l_def := l_def || p_data_type;
            WHEN p_data_type IN ('CLOB', 'BLOB', 'NCLOB') THEN
                l_def := l_def || 'VARCHAR2(4000)';
            WHEN p_data_type = 'LONG' THEN
                l_def := l_def || 'CLOB';
            ELSE
                l_def := l_def || p_data_type;
        END CASE;
        RETURN l_def;
    END build_column_def;

BEGIN
    -- Validate table exists
    SELECT COUNT(*) INTO l_table_exists
      FROM all_tables
     WHERE table_name = c_source_table
       AND owner = c_source_owner;

    IF l_table_exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Table ' || c_source_owner || '.' ||
                             c_source_table || ' does not exist!');
        RETURN;
    END IF;

    -- Build object names
    l_audit_table  := SUBSTR(c_source_table, 1, 128 - LENGTH(c_audit_suffix)) || c_audit_suffix;
    l_trigger_name := SUBSTR(c_source_table, 1, 128 - LENGTH(c_trigger_suffix)) || c_trigger_suffix;
    l_seq_name     := l_audit_table || '_SEQ';

    -------------------------------------------------------------------------
    -- Generate Audit Table DDL
    -------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('-- AUDIT TABLE DDL FOR: ' || c_source_owner || '.' || c_source_table);
    DBMS_OUTPUT.PUT_LINE('-- Generated: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('');

    -- Sequence
    DBMS_OUTPUT.PUT_LINE('-- Create sequence for audit ID');
    DBMS_OUTPUT.PUT_LINE('CREATE SEQUENCE ' || l_seq_name ||
                         ' START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;');
    DBMS_OUTPUT.PUT_LINE('');

    -- Table
    DBMS_OUTPUT.PUT_LINE('-- Create audit log table');
    DBMS_OUTPUT.PUT_LINE('CREATE TABLE ' || l_audit_table || ' (');
    DBMS_OUTPUT.PUT_LINE('    AUDIT_ID           NUMBER           NOT NULL,');
    DBMS_OUTPUT.PUT_LINE('    DML_TYPE           VARCHAR2(6)      NOT NULL,');
    DBMS_OUTPUT.PUT_LINE('    DML_TIMESTAMP      TIMESTAMP(6)     DEFAULT SYSTIMESTAMP NOT NULL,');
    DBMS_OUTPUT.PUT_LINE('    DML_USER           VARCHAR2(128)    DEFAULT USER NOT NULL,');
    DBMS_OUTPUT.PUT_LINE('    SESSION_ID         NUMBER,');
    DBMS_OUTPUT.PUT_LINE('    CLIENT_HOST        VARCHAR2(64),');
    DBMS_OUTPUT.PUT_LINE('    CLIENT_IP          VARCHAR2(40),');
    DBMS_OUTPUT.PUT_LINE('    MODULE             VARCHAR2(64),');
    DBMS_OUTPUT.PUT_LINE('    ACTION             VARCHAR2(64),');

    -- Add OLD_ and NEW_ columns for each source column
    FOR rec IN c_columns LOOP
        DBMS_OUTPUT.PUT_LINE('    OLD_' ||
            build_column_def(rec.column_name, rec.data_type, rec.data_length,
                            rec.data_precision, rec.data_scale) || ',');
        DBMS_OUTPUT.PUT_LINE('    NEW_' ||
            build_column_def(rec.column_name, rec.data_type, rec.data_length,
                            rec.data_precision, rec.data_scale) || ',');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('    CONSTRAINT ' || l_audit_table || '_PK PRIMARY KEY (AUDIT_ID)');
    DBMS_OUTPUT.PUT_LINE(');');
    DBMS_OUTPUT.PUT_LINE('');

    -- Index
    DBMS_OUTPUT.PUT_LINE('-- Create index for timestamp-based queries');
    DBMS_OUTPUT.PUT_LINE('CREATE INDEX ' || l_audit_table || '_TS_IDX');
    DBMS_OUTPUT.PUT_LINE('    ON ' || l_audit_table || ' (DML_TIMESTAMP DESC);');
    DBMS_OUTPUT.PUT_LINE('');

    -- Comment
    DBMS_OUTPUT.PUT_LINE('-- Add table comment');
    DBMS_OUTPUT.PUT_LINE('COMMENT ON TABLE ' || l_audit_table ||
                         ' IS ''Audit log for ' || c_source_owner || '.' ||
                         c_source_table || ''';');
    DBMS_OUTPUT.PUT_LINE('');

    -------------------------------------------------------------------------
    -- Generate Audit Trigger DDL
    -------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('-- AUDIT TRIGGER DDL');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('');

    -- Build column lists for trigger
    l_first := TRUE;
    FOR rec IN c_columns LOOP
        IF NOT l_first THEN
            l_col_list := l_col_list || ',' || CHR(10);
            l_old_list := l_old_list || ',' || CHR(10);
            l_new_list := l_new_list || ',' || CHR(10);
        END IF;
        l_first := FALSE;

        l_col_list := l_col_list || '            OLD_' || rec.column_name ||
                      ', NEW_' || rec.column_name;

        IF rec.data_type IN ('CLOB', 'BLOB', 'NCLOB') THEN
            l_old_list := l_old_list || '            CASE WHEN :OLD.' ||
                          rec.column_name || ' IS NOT NULL THEN SUBSTR(TO_CHAR(:OLD.' ||
                          rec.column_name || '), 1, 4000) ELSE NULL END';
            l_new_list := l_new_list || '            CASE WHEN :NEW.' ||
                          rec.column_name || ' IS NOT NULL THEN SUBSTR(TO_CHAR(:NEW.' ||
                          rec.column_name || '), 1, 4000) ELSE NULL END';
        ELSE
            l_old_list := l_old_list || '            :OLD.' || rec.column_name;
            l_new_list := l_new_list || '            :NEW.' || rec.column_name;
        END IF;
    END LOOP;

    -- Output trigger DDL
    DBMS_OUTPUT.PUT_LINE('CREATE OR REPLACE TRIGGER ' || l_trigger_name);
    DBMS_OUTPUT.PUT_LINE('AFTER INSERT OR UPDATE OR DELETE ON ' ||
                         c_source_owner || '.' || c_source_table);
    DBMS_OUTPUT.PUT_LINE('FOR EACH ROW');
    DBMS_OUTPUT.PUT_LINE('DECLARE');
    DBMS_OUTPUT.PUT_LINE('    PRAGMA AUTONOMOUS_TRANSACTION;');
    DBMS_OUTPUT.PUT_LINE('    l_dml_type     VARCHAR2(6);');
    DBMS_OUTPUT.PUT_LINE('    l_session_id   NUMBER;');
    DBMS_OUTPUT.PUT_LINE('    l_client_host  VARCHAR2(64);');
    DBMS_OUTPUT.PUT_LINE('    l_client_ip    VARCHAR2(40);');
    DBMS_OUTPUT.PUT_LINE('    l_module       VARCHAR2(64);');
    DBMS_OUTPUT.PUT_LINE('    l_action       VARCHAR2(64);');
    DBMS_OUTPUT.PUT_LINE('BEGIN');
    DBMS_OUTPUT.PUT_LINE('    -- Determine DML operation type');
    DBMS_OUTPUT.PUT_LINE('    IF INSERTING THEN');
    DBMS_OUTPUT.PUT_LINE('        l_dml_type := ''INSERT'';');
    DBMS_OUTPUT.PUT_LINE('    ELSIF UPDATING THEN');
    DBMS_OUTPUT.PUT_LINE('        l_dml_type := ''UPDATE'';');
    DBMS_OUTPUT.PUT_LINE('    ELSIF DELETING THEN');
    DBMS_OUTPUT.PUT_LINE('        l_dml_type := ''DELETE'';');
    DBMS_OUTPUT.PUT_LINE('    END IF;');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('    -- Capture session context');
    DBMS_OUTPUT.PUT_LINE('    l_session_id  := SYS_CONTEXT(''USERENV'', ''SESSIONID'');');
    DBMS_OUTPUT.PUT_LINE('    l_client_host := SYS_CONTEXT(''USERENV'', ''HOST'');');
    DBMS_OUTPUT.PUT_LINE('    l_client_ip   := SYS_CONTEXT(''USERENV'', ''IP_ADDRESS'');');
    DBMS_OUTPUT.PUT_LINE('    l_module      := SYS_CONTEXT(''USERENV'', ''MODULE'');');
    DBMS_OUTPUT.PUT_LINE('    l_action      := SYS_CONTEXT(''USERENV'', ''ACTION'');');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('    -- Insert audit record');
    DBMS_OUTPUT.PUT_LINE('    INSERT INTO ' || l_audit_table || ' (');
    DBMS_OUTPUT.PUT_LINE('        AUDIT_ID,');
    DBMS_OUTPUT.PUT_LINE('        DML_TYPE,');
    DBMS_OUTPUT.PUT_LINE('        DML_TIMESTAMP,');
    DBMS_OUTPUT.PUT_LINE('        DML_USER,');
    DBMS_OUTPUT.PUT_LINE('        SESSION_ID,');
    DBMS_OUTPUT.PUT_LINE('        CLIENT_HOST,');
    DBMS_OUTPUT.PUT_LINE('        CLIENT_IP,');
    DBMS_OUTPUT.PUT_LINE('        MODULE,');
    DBMS_OUTPUT.PUT_LINE('        ACTION,');

    -- Output column list (handle CLOB chunking)
    DECLARE
        l_chunk VARCHAR2(4000);
        l_pos   PLS_INTEGER := 1;
        l_len   PLS_INTEGER := LENGTH(l_col_list);
    BEGIN
        WHILE l_pos <= l_len LOOP
            l_chunk := SUBSTR(l_col_list, l_pos, 200);
            DBMS_OUTPUT.PUT(l_chunk);
            l_pos := l_pos + 200;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('');
    END;

    DBMS_OUTPUT.PUT_LINE('    ) VALUES (');
    DBMS_OUTPUT.PUT_LINE('        ' || l_seq_name || '.NEXTVAL,');
    DBMS_OUTPUT.PUT_LINE('        l_dml_type,');
    DBMS_OUTPUT.PUT_LINE('        SYSTIMESTAMP,');
    DBMS_OUTPUT.PUT_LINE('        USER,');
    DBMS_OUTPUT.PUT_LINE('        l_session_id,');
    DBMS_OUTPUT.PUT_LINE('        l_client_host,');
    DBMS_OUTPUT.PUT_LINE('        l_client_ip,');
    DBMS_OUTPUT.PUT_LINE('        l_module,');
    DBMS_OUTPUT.PUT_LINE('        l_action,');

    -- Output OLD values
    DECLARE
        l_chunk VARCHAR2(4000);
        l_pos   PLS_INTEGER := 1;
        l_len   PLS_INTEGER := LENGTH(l_old_list);
    BEGIN
        WHILE l_pos <= l_len LOOP
            l_chunk := SUBSTR(l_old_list, l_pos, 200);
            DBMS_OUTPUT.PUT(l_chunk);
            l_pos := l_pos + 200;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(',');
    END;

    -- Output NEW values
    DECLARE
        l_chunk VARCHAR2(4000);
        l_pos   PLS_INTEGER := 1;
        l_len   PLS_INTEGER := LENGTH(l_new_list);
    BEGIN
        WHILE l_pos <= l_len LOOP
            l_chunk := SUBSTR(l_new_list, l_pos, 200);
            DBMS_OUTPUT.PUT(l_chunk);
            l_pos := l_pos + 200;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('');
    END;

    DBMS_OUTPUT.PUT_LINE('    );');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('    COMMIT;');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('EXCEPTION');
    DBMS_OUTPUT.PUT_LINE('    WHEN OTHERS THEN');
    DBMS_OUTPUT.PUT_LINE('        -- Log error but do not fail the main transaction');
    DBMS_OUTPUT.PUT_LINE('        ROLLBACK;');
    DBMS_OUTPUT.PUT_LINE('        NULL; -- Silent fail to prevent main transaction failure');
    DBMS_OUTPUT.PUT_LINE('END ' || l_trigger_name || ';');
    DBMS_OUTPUT.PUT_LINE('/');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('-- DDL Generation Complete');
    DBMS_OUTPUT.PUT_LINE('================================================================================');

END;
/

SET FEEDBACK ON;
SET VERIFY ON;
