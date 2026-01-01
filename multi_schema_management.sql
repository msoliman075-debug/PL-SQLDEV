-- ============================================================================
-- ORDS Multi-Schema Management Utility
-- ============================================================================
-- Manage multiple ORDS-enabled schemas at once
-- Useful for bulk operations and enterprise environments
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET VERIFY OFF

PROMPT ========================================
PROMPT ORDS Multi-Schema Management Utility
PROMPT ========================================
PROMPT

-- ============================================================================
-- SECTION 1: Display All ORDS Schemas
-- ============================================================================
PROMPT *** All ORDS Schemas ***
PROMPT

SELECT 
    schema_name,
    CASE is_enabled 
        WHEN 'Y' THEN 'ENABLED'
        ELSE 'DISABLED'
    END as status,
    parsing_schema,
    has_credentials,
    TO_CHAR(created_on, 'YYYY-MM-DD HH24:MI:SS') as created_date
FROM ORDS_METADATA.ORDS_SCHEMAS
ORDER BY schema_name;

PROMPT

-- ============================================================================
-- SECTION 2: Count Modules per Schema
-- ============================================================================
PROMPT *** Module Count by Schema ***
PROMPT

SELECT 
    s.schema_name,
    COUNT(m.id) as module_count,
    COUNT(CASE WHEN m.status = 'PUBLISHED' THEN 1 END) as published_modules
FROM ORDS_METADATA.ORDS_SCHEMAS s
LEFT JOIN ORDS_METADATA.ORDS_MODULES m ON s.id = m.schema_id
GROUP BY s.schema_name
ORDER BY s.schema_name;

PROMPT

-- ============================================================================
-- SECTION 3: Base Paths Summary
-- ============================================================================
PROMPT *** Base Paths Summary ***
PROMPT

SELECT 
    s.schema_name,
    m.name as module_name,
    m.base_path,
    m.status
FROM ORDS_METADATA.ORDS_MODULES m
JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
ORDER BY s.schema_name, m.base_path;

PROMPT

-- ============================================================================
-- SECTION 4: Interactive Operations
-- ============================================================================
PROMPT ========================================
PROMPT Interactive Operations Menu
PROMPT ========================================
PROMPT 
PROMPT Choose an operation:
PROMPT   1 - Disable a schema
PROMPT   2 - Enable a schema
PROMPT   3 - Disable ALL schemas (use with caution!)
PROMPT   4 - Enable ALL schemas (use with caution!)
PROMPT   5 - Display detailed info for one schema
PROMPT   0 - Exit
PROMPT
ACCEPT operation NUMBER PROMPT 'Enter operation number (0-5): '

-- Operation 1: Disable a schema
WHENEVER SQLERROR CONTINUE
SET TERMOUT OFF

COLUMN dummy_col1 NEW_VALUE should_run_op1 NOPRINT
SELECT CASE WHEN &operation = 1 THEN 'TRUE' ELSE 'FALSE' END as dummy_col1 FROM DUAL;

SET TERMOUT ON
WHENEVER SQLERROR EXIT

PROMPT
SET SERVEROUTPUT ON

BEGIN
    IF '&should_run_op1' = 'TRUE' THEN
        DECLARE
            v_schema VARCHAR2(128);
        BEGIN
            -- Would use ACCEPT here but showing as example
            DBMS_OUTPUT.PUT_LINE('*** Disable Schema ***');
            DBMS_OUTPUT.PUT_LINE('Available schemas:');
            
            FOR rec IN (SELECT schema_name, is_enabled 
                       FROM ORDS_METADATA.ORDS_SCHEMAS 
                       WHERE is_enabled = 'Y'
                       ORDER BY schema_name) LOOP
                DBMS_OUTPUT.PUT_LINE('  - ' || rec.schema_name);
            END LOOP;
            
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('To disable a schema, run:');
            DBMS_OUTPUT.PUT_LINE('  @quick_disable_enable_ords.sql');
        END;
    END IF;
END;
/

-- Operation 2: Enable a schema
COLUMN dummy_col2 NEW_VALUE should_run_op2 NOPRINT
SELECT CASE WHEN &operation = 2 THEN 'TRUE' ELSE 'FALSE' END as dummy_col2 FROM DUAL;

BEGIN
    IF '&should_run_op2' = 'TRUE' THEN
        DECLARE
            v_schema VARCHAR2(128);
        BEGIN
            DBMS_OUTPUT.PUT_LINE('*** Enable Schema ***');
            DBMS_OUTPUT.PUT_LINE('Available disabled schemas:');
            
            FOR rec IN (SELECT schema_name 
                       FROM ORDS_METADATA.ORDS_SCHEMAS 
                       WHERE is_enabled = 'N'
                       ORDER BY schema_name) LOOP
                DBMS_OUTPUT.PUT_LINE('  - ' || rec.schema_name);
            END LOOP;
            
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('To enable a schema, run:');
            DBMS_OUTPUT.PUT_LINE('  @reenable_ords_schema.sql');
        END;
    END IF;
END;
/

-- Operation 3: Disable ALL schemas
COLUMN dummy_col3 NEW_VALUE should_run_op3 NOPRINT
SELECT CASE WHEN &operation = 3 THEN 'TRUE' ELSE 'FALSE' END as dummy_col3 FROM DUAL;

BEGIN
    IF '&should_run_op3' = 'TRUE' THEN
        DECLARE
            v_count NUMBER := 0;
        BEGIN
            DBMS_OUTPUT.PUT_LINE('*** Disable ALL Schemas ***');
            DBMS_OUTPUT.PUT_LINE('WARNING: This will disable all ORDS-enabled schemas!');
            DBMS_OUTPUT.PUT_LINE('All REST endpoints will become unavailable.');
            DBMS_OUTPUT.PUT_LINE('');
            
            FOR rec IN (SELECT schema_name 
                       FROM ORDS_METADATA.ORDS_SCHEMAS 
                       WHERE is_enabled = 'Y'
                       ORDER BY schema_name) LOOP
                
                DBMS_OUTPUT.PUT_LINE('Disabling schema: ' || rec.schema_name);
                
                BEGIN
                    ORDS.DISABLE_SCHEMA(p_schema => rec.schema_name);
                    v_count := v_count + 1;
                    DBMS_OUTPUT.PUT_LINE('  SUCCESS');
                EXCEPTION
                    WHEN OTHERS THEN
                        DBMS_OUTPUT.PUT_LINE('  ERROR: ' || SQLERRM);
                END;
            END LOOP;
            
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Total schemas disabled: ' || v_count);
            
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
                ROLLBACK;
        END;
    END IF;
END;
/

-- Operation 4: Enable ALL schemas
COLUMN dummy_col4 NEW_VALUE should_run_op4 NOPRINT
SELECT CASE WHEN &operation = 4 THEN 'TRUE' ELSE 'FALSE' END as dummy_col4 FROM DUAL;

BEGIN
    IF '&should_run_op4' = 'TRUE' THEN
        DECLARE
            v_count NUMBER := 0;
        BEGIN
            DBMS_OUTPUT.PUT_LINE('*** Enable ALL Schemas ***');
            DBMS_OUTPUT.PUT_LINE('WARNING: This will enable all ORDS schemas!');
            DBMS_OUTPUT.PUT_LINE('');
            
            FOR rec IN (SELECT schema_name 
                       FROM ORDS_METADATA.ORDS_SCHEMAS 
                       WHERE is_enabled = 'N'
                       ORDER BY schema_name) LOOP
                
                DBMS_OUTPUT.PUT_LINE('Enabling schema: ' || rec.schema_name);
                
                BEGIN
                    ORDS.ENABLE_SCHEMA(
                        p_schema           => rec.schema_name,
                        p_url_mapping_type => 'BASE_PATH',
                        p_auto_rest_auth   => FALSE
                    );
                    v_count := v_count + 1;
                    DBMS_OUTPUT.PUT_LINE('  SUCCESS');
                EXCEPTION
                    WHEN OTHERS THEN
                        DBMS_OUTPUT.PUT_LINE('  ERROR: ' || SQLERRM);
                END;
            END LOOP;
            
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Total schemas enabled: ' || v_count);
            
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
                ROLLBACK;
        END;
    END IF;
END;
/

-- Operation 5: Detailed info for one schema
COLUMN dummy_col5 NEW_VALUE should_run_op5 NOPRINT
SELECT CASE WHEN &operation = 5 THEN 'TRUE' ELSE 'FALSE' END as dummy_col5 FROM DUAL;

SET TERMOUT ON

ACCEPT schema_to_detail CHAR PROMPT 'Enter schema name for details (or press Enter to skip): '

BEGIN
    IF '&should_run_op5' = 'TRUE' AND '&schema_to_detail' IS NOT NULL THEN
        DECLARE
            v_schema VARCHAR2(128) := UPPER('&schema_to_detail');
        BEGIN
            DBMS_OUTPUT.PUT_LINE('========================================');
            DBMS_OUTPUT.PUT_LINE('Detailed Info for Schema: ' || v_schema);
            DBMS_OUTPUT.PUT_LINE('========================================');
            DBMS_OUTPUT.PUT_LINE('');
            
            -- Schema info
            FOR rec IN (SELECT * FROM ORDS_METADATA.ORDS_SCHEMAS 
                       WHERE schema_name = v_schema) LOOP
                DBMS_OUTPUT.PUT_LINE('Status: ' || CASE rec.is_enabled WHEN 'Y' THEN 'ENABLED' ELSE 'DISABLED' END);
                DBMS_OUTPUT.PUT_LINE('Parsing Schema: ' || NVL(rec.parsing_schema, 'N/A'));
                DBMS_OUTPUT.PUT_LINE('Has Credentials: ' || rec.has_credentials);
                DBMS_OUTPUT.PUT_LINE('Created: ' || TO_CHAR(rec.created_on, 'YYYY-MM-DD HH24:MI:SS'));
            END LOOP;
            
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Modules:');
            
            -- Module info
            FOR rec IN (SELECT m.* FROM ORDS_METADATA.ORDS_MODULES m
                       JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
                       WHERE s.schema_name = v_schema
                       ORDER BY m.name) LOOP
                DBMS_OUTPUT.PUT_LINE('  - ' || rec.name);
                DBMS_OUTPUT.PUT_LINE('    Base Path: ' || rec.base_path);
                DBMS_OUTPUT.PUT_LINE('    Status: ' || rec.status);
                DBMS_OUTPUT.PUT_LINE('    Items/Page: ' || rec.items_per_page);
            END LOOP;
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('Schema not found: ' || v_schema);
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        END;
    END IF;
END;
/

PROMPT
PROMPT ========================================
PROMPT Operations Complete
PROMPT ========================================
PROMPT
PROMPT To run this utility again:
PROMPT   @multi_schema_management.sql
PROMPT

SET VERIFY ON
