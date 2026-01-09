/*******************************************************************************
* Script:  AUDIT_EXAMPLE_USAGE.SQL
* Purpose: Demonstrates usage of AUDIT_PKG for table auditing
* Target:  Oracle 19c+
*
* This script shows:
*   1. How to create audit infrastructure for a table
*   2. How to preview DDL before execution
*   3. How to query audit logs
*   4. How to clean up audit objects
*******************************************************************************/

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;

--------------------------------------------------------------------------------
-- STEP 1: Install the AUDIT_PKG package (run separately if not installed)
--------------------------------------------------------------------------------
-- @audit_pkg.pks
-- @audit_pkg.pkb

--------------------------------------------------------------------------------
-- STEP 2: Create a sample table for demonstration
--------------------------------------------------------------------------------
PROMPT Creating sample EMPLOYEES table...

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE employees_demo PURGE';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE employees_demo (
    employee_id   NUMBER(10)     PRIMARY KEY,
    first_name    VARCHAR2(50)   NOT NULL,
    last_name     VARCHAR2(50)   NOT NULL,
    email         VARCHAR2(100),
    salary        NUMBER(10,2),
    hire_date     DATE           DEFAULT SYSDATE,
    department_id NUMBER(5)
);

PROMPT Sample table created.

--------------------------------------------------------------------------------
-- STEP 3: Preview the Audit DDL (optional - useful for review before execution)
--------------------------------------------------------------------------------
PROMPT
PROMPT ============================================================
PROMPT Preview of Audit Table DDL:
PROMPT ============================================================

DECLARE
    l_ddl CLOB;
BEGIN
    l_ddl := audit_pkg.get_audit_ddl(
        p_table_name  => 'EMPLOYEES_DEMO',
        p_table_owner => USER
    );
    DBMS_OUTPUT.PUT_LINE(l_ddl);
END;
/

PROMPT
PROMPT ============================================================
PROMPT Preview of Audit Trigger DDL:
PROMPT ============================================================

DECLARE
    l_ddl CLOB;
BEGIN
    l_ddl := audit_pkg.get_trigger_ddl(
        p_table_name  => 'EMPLOYEES_DEMO',
        p_table_owner => USER
    );
    DBMS_OUTPUT.PUT_LINE(l_ddl);
END;
/

--------------------------------------------------------------------------------
-- STEP 4: Create Audit Table and Trigger
--------------------------------------------------------------------------------
PROMPT
PROMPT ============================================================
PROMPT Creating Audit Infrastructure...
PROMPT ============================================================

BEGIN
    -- Create the audit log table
    audit_pkg.create_audit_table(
        p_table_name  => 'EMPLOYEES_DEMO',
        p_table_owner => USER
    );

    -- Create the audit trigger
    audit_pkg.create_audit_trigger(
        p_table_name  => 'EMPLOYEES_DEMO',
        p_table_owner => USER
    );
END;
/

--------------------------------------------------------------------------------
-- STEP 5: Perform DML operations to generate audit records
--------------------------------------------------------------------------------
PROMPT
PROMPT ============================================================
PROMPT Performing DML Operations...
PROMPT ============================================================

-- INSERT operation
PROMPT Inserting new employee...
INSERT INTO employees_demo (employee_id, first_name, last_name, email, salary, department_id)
VALUES (1001, 'John', 'Smith', 'john.smith@example.com', 75000.00, 10);

INSERT INTO employees_demo (employee_id, first_name, last_name, email, salary, department_id)
VALUES (1002, 'Jane', 'Doe', 'jane.doe@example.com', 85000.00, 20);

COMMIT;

-- UPDATE operation
PROMPT Updating employee salary...
UPDATE employees_demo
   SET salary = 80000.00,
       email = 'john.smith.updated@example.com'
 WHERE employee_id = 1001;

COMMIT;

-- DELETE operation
PROMPT Deleting employee...
DELETE FROM employees_demo WHERE employee_id = 1002;

COMMIT;

--------------------------------------------------------------------------------
-- STEP 6: Query the Audit Log
--------------------------------------------------------------------------------
PROMPT
PROMPT ============================================================
PROMPT Audit Log Contents:
PROMPT ============================================================

COLUMN audit_id       FORMAT 9999
COLUMN dml_type       FORMAT A6
COLUMN dml_timestamp  FORMAT A26
COLUMN dml_user       FORMAT A15
COLUMN old_first_name FORMAT A12
COLUMN new_first_name FORMAT A12
COLUMN old_salary     FORMAT 999999.99
COLUMN new_salary     FORMAT 999999.99

SELECT audit_id,
       dml_type,
       TO_CHAR(dml_timestamp, 'YYYY-MM-DD HH24:MI:SS.FF3') AS dml_timestamp,
       dml_user,
       old_first_name,
       new_first_name,
       old_salary,
       new_salary
  FROM employees_demo_audit_log
 ORDER BY audit_id;

--------------------------------------------------------------------------------
-- STEP 7: Useful Audit Queries
--------------------------------------------------------------------------------
PROMPT
PROMPT ============================================================
PROMPT Audit Analysis Examples:
PROMPT ============================================================

-- Count by operation type
PROMPT Operations by type:
SELECT dml_type, COUNT(*) AS operation_count
  FROM employees_demo_audit_log
 GROUP BY dml_type
 ORDER BY dml_type;

-- Changes in last 24 hours
PROMPT Changes in last 24 hours by user:
SELECT dml_user,
       dml_type,
       COUNT(*) AS change_count
  FROM employees_demo_audit_log
 WHERE dml_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
 GROUP BY dml_user, dml_type
 ORDER BY dml_user, dml_type;

-- Find all salary changes
PROMPT All salary changes:
SELECT audit_id,
       dml_timestamp,
       dml_user,
       old_employee_id AS emp_id,
       old_salary,
       new_salary,
       NVL(new_salary, 0) - NVL(old_salary, 0) AS salary_change
  FROM employees_demo_audit_log
 WHERE old_salary != new_salary
    OR (old_salary IS NULL AND new_salary IS NOT NULL)
    OR (old_salary IS NOT NULL AND new_salary IS NULL)
 ORDER BY dml_timestamp;

--------------------------------------------------------------------------------
-- STEP 8: Create audit with column exclusions (optional example)
--------------------------------------------------------------------------------
PROMPT
PROMPT ============================================================
PROMPT Example: Creating audit with excluded columns
PROMPT ============================================================

-- You can exclude certain columns from auditing
-- audit_pkg.create_audit_trigger(
--     p_table_name      => 'EMPLOYEES_DEMO',
--     p_table_owner     => USER,
--     p_exclude_columns => 'CREATED_DATE,MODIFIED_DATE,PASSWORD_HASH'
-- );

--------------------------------------------------------------------------------
-- STEP 9: Cleanup (optional - uncomment to remove audit objects)
--------------------------------------------------------------------------------
PROMPT
PROMPT ============================================================
PROMPT Cleanup commands (commented out - run manually if needed):
PROMPT ============================================================

-- Uncomment to clean up:
-- BEGIN
--     audit_pkg.drop_audit_objects(
--         p_table_name  => 'EMPLOYEES_DEMO',
--         p_table_owner => USER
--     );
-- END;
-- /
--
-- DROP TABLE employees_demo PURGE;

PROMPT
PROMPT Script completed successfully.
PROMPT
