-- ============================================================================
-- ORDS Fix Verification Script
-- ============================================================================
-- Run this script after fixing ORA-20049 to verify everything is working
-- This script performs comprehensive checks without making any changes
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET VERIFY OFF
SET FEEDBACK OFF

PROMPT ========================================
PROMPT ORDS Fix Verification Report
PROMPT ========================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name to verify: '

DECLARE
    v_schema        VARCHAR2(128) := UPPER('&schema_name');
    v_is_enabled    VARCHAR2(1);
    v_module_count  NUMBER := 0;
    v_status        VARCHAR2(50);
    v_pass_count    NUMBER := 0;
    v_fail_count    NUMBER := 0;
    v_warn_count    NUMBER := 0;
    
    PROCEDURE report_pass(p_test VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('[PASS] ' || p_test);
        v_pass_count := v_pass_count + 1;
    END;
    
    PROCEDURE report_fail(p_test VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('[FAIL] ' || p_test);
        v_fail_count := v_fail_count + 1;
    END;
    
    PROCEDURE report_warn(p_test VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('[WARN] ' || p_test);
        v_warn_count := v_warn_count + 1;
    END;

BEGIN
    DBMS_OUTPUT.PUT_LINE('Verification Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('Schema: ' || v_schema);
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Running Verification Tests...');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- TEST 1: Schema exists in ORDS
    BEGIN
        SELECT COUNT(*) INTO v_module_count
        FROM ORDS_METADATA.ORDS_SCHEMAS
        WHERE schema_name = v_schema;
        
        IF v_module_count > 0 THEN
            report_pass('Schema exists in ORDS_METADATA');
        ELSE
            report_fail('Schema NOT found in ORDS_METADATA');
            RETURN; -- Cannot continue
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            report_fail('Error checking schema: ' || SQLERRM);
            RETURN;
    END;
    
    -- TEST 2: Schema is enabled
    BEGIN
        SELECT is_enabled INTO v_is_enabled
        FROM ORDS_METADATA.ORDS_SCHEMAS
        WHERE schema_name = v_schema;
        
        IF v_is_enabled = 'Y' THEN
            report_pass('Schema is ENABLED (REST endpoints active)');
        ELSE
            report_fail('Schema is DISABLED (REST endpoints NOT active)');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            report_fail('Error checking enabled status: ' || SQLERRM);
    END;
    
    -- TEST 3: Schema has modules
    BEGIN
        SELECT COUNT(*) INTO v_module_count
        FROM ORDS_METADATA.ORDS_MODULES m
        JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
        WHERE s.schema_name = v_schema;
        
        IF v_module_count > 0 THEN
            report_pass('Schema has ' || v_module_count || ' module(s) configured');
        ELSE
            report_warn('Schema has NO modules (this may be intentional)');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            report_fail('Error checking modules: ' || SQLERRM);
    END;
    
    -- TEST 4: Modules have valid base paths
    BEGIN
        FOR rec IN (
            SELECT m.name, m.base_path
            FROM ORDS_METADATA.ORDS_MODULES m
            JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
            WHERE s.schema_name = v_schema
        ) LOOP
            IF rec.base_path IS NOT NULL AND 
               rec.base_path LIKE '/%' THEN
                report_pass('Module "' || rec.name || '" has valid base path: ' || rec.base_path);
            ELSE
                report_fail('Module "' || rec.name || '" has invalid base path: ' || NVL(rec.base_path, 'NULL'));
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            report_fail('Error checking base paths: ' || SQLERRM);
    END;
    
    -- TEST 5: Modules are published
    BEGIN
        FOR rec IN (
            SELECT m.name, m.status
            FROM ORDS_METADATA.ORDS_MODULES m
            JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
            WHERE s.schema_name = v_schema
        ) LOOP
            IF rec.status = 'PUBLISHED' THEN
                report_pass('Module "' || rec.name || '" is PUBLISHED');
            ELSE
                report_warn('Module "' || rec.name || '" status is: ' || rec.status);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            report_fail('Error checking module status: ' || SQLERRM);
    END;
    
    -- TEST 6: Templates exist
    DECLARE
        v_template_count NUMBER := 0;
    BEGIN
        SELECT COUNT(*) INTO v_template_count
        FROM ORDS_METADATA.ORDS_TEMPLATES t
        JOIN ORDS_METADATA.ORDS_MODULES m ON t.module_id = m.id
        JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
        WHERE s.schema_name = v_schema;
        
        IF v_template_count > 0 THEN
            report_pass('Schema has ' || v_template_count || ' template(s) configured');
        ELSE
            report_warn('Schema has NO templates (REST endpoints may not work)');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            report_fail('Error checking templates: ' || SQLERRM);
    END;
    
    -- TEST 7: No duplicate base paths
    DECLARE
        v_dup_count NUMBER := 0;
    BEGIN
        SELECT COUNT(*) INTO v_dup_count
        FROM (
            SELECT m.base_path, COUNT(*) as cnt
            FROM ORDS_METADATA.ORDS_MODULES m
            JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
            WHERE s.schema_name = v_schema
            GROUP BY m.base_path
            HAVING COUNT(*) > 1
        );
        
        IF v_dup_count = 0 THEN
            report_pass('No duplicate base paths found');
        ELSE
            report_warn('Found ' || v_dup_count || ' duplicate base path(s)');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            report_fail('Error checking for duplicates: ' || SQLERRM);
    END;
    
    -- TEST 8: ORDS privileges configured
    DECLARE
        v_priv_count NUMBER := 0;
    BEGIN
        SELECT COUNT(*) INTO v_priv_count
        FROM ORDS_METADATA.ORDS_PRIVILEGES;
        
        IF v_priv_count > 0 THEN
            report_pass('ORDS has ' || v_priv_count || ' privilege(s) configured');
        ELSE
            report_warn('No ORDS privileges configured (may be intentional)');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            report_warn('Could not check privileges: ' || SQLERRM);
    END;
    
    -- Summary
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Verification Summary');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Tests Passed:  ' || v_pass_count);
    DBMS_OUTPUT.PUT_LINE('Tests Failed:  ' || v_fail_count);
    DBMS_OUTPUT.PUT_LINE('Warnings:      ' || v_warn_count);
    DBMS_OUTPUT.PUT_LINE('');
    
    IF v_fail_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Overall Status: SUCCESS ✓');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Your ORDS schema appears to be configured correctly.');
        DBMS_OUTPUT.PUT_LINE('REST endpoints should be accessible.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Overall Status: ISSUES FOUND ✗');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Please review failed tests above and take corrective action.');
    END IF;
    
    IF v_warn_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Note: Warnings may be acceptable depending on your configuration.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR');
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
END;
/

PROMPT
PROMPT ========================================
PROMPT Configuration Details
PROMPT ========================================

SET FEEDBACK ON

SELECT 
    'Schema Status' as check_type,
    schema_name,
    CASE is_enabled WHEN 'Y' THEN 'ENABLED' ELSE 'DISABLED' END as value
FROM ORDS_METADATA.ORDS_SCHEMAS
WHERE schema_name = UPPER('&schema_name')
UNION ALL
SELECT 
    'Parsing Schema' as check_type,
    schema_name,
    NVL(parsing_schema, 'N/A') as value
FROM ORDS_METADATA.ORDS_SCHEMAS
WHERE schema_name = UPPER('&schema_name')
UNION ALL
SELECT 
    'Module Count' as check_type,
    s.schema_name,
    TO_CHAR(COUNT(m.id)) as value
FROM ORDS_METADATA.ORDS_SCHEMAS s
LEFT JOIN ORDS_METADATA.ORDS_MODULES m ON s.id = m.schema_id
WHERE s.schema_name = UPPER('&schema_name')
GROUP BY s.schema_name;

PROMPT
PROMPT Modules and Base Paths:

SELECT 
    m.name as module_name,
    m.base_path,
    m.status
FROM ORDS_METADATA.ORDS_MODULES m
JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
WHERE s.schema_name = UPPER('&schema_name')
ORDER BY m.name;

PROMPT
PROMPT ========================================
PROMPT Testing Instructions
PROMPT ========================================
PROMPT
PROMPT To test your REST endpoints:
PROMPT   1. Ensure ORDS service is running
PROMPT   2. Get the base URL from your ORDS configuration
PROMPT   3. Test each endpoint:
PROMPT

SELECT 
    'curl http://your-server:port' || m.base_path as test_command
FROM ORDS_METADATA.ORDS_MODULES m
JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
WHERE s.schema_name = UPPER('&schema_name')
ORDER BY m.base_path;

PROMPT
PROMPT ========================================
PROMPT Verification Complete
PROMPT ========================================

SET VERIFY ON
SET FEEDBACK ON
