CREATE OR REPLACE PACKAGE audit_pkg AS
/*******************************************************************************
* Package: AUDIT_PKG
* Purpose: Standard procedures to create audit log tables and triggers
*          for tracking old/new values on DML operations (INSERT/UPDATE/DELETE)
*
* Author:  Enterprise Audit Framework
* Version: 1.0
* Target:  Oracle 19c+
*
* Usage:
*   -- Create audit infrastructure for EMPLOYEES table
*   BEGIN
*       audit_pkg.create_audit_table(p_table_name => 'EMPLOYEES');
*       audit_pkg.create_audit_trigger(p_table_name => 'EMPLOYEES');
*   END;
*
* Execution Impact:
*   - Creates <TABLE_NAME>_AUDIT_LOG table with audit columns
*   - Creates AFTER trigger on source table (minimal overhead)
*   - Autonomous transaction ensures audit commits independently
*******************************************************************************/

    -- Constants for DML operation types
    gc_insert CONSTANT VARCHAR2(6) := 'INSERT';
    gc_update CONSTANT VARCHAR2(6) := 'UPDATE';
    gc_delete CONSTANT VARCHAR2(6) := 'DELETE';

    -- Exception for invalid table
    e_table_not_found EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_table_not_found, -20001);

    -- Exception for audit table already exists
    e_audit_exists EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_audit_exists, -20002);

    /***************************************************************************
    * Procedure: CREATE_AUDIT_TABLE
    * Purpose:   Creates an audit log table for the specified source table
    *
    * Parameters:
    *   p_table_name    - Name of the source table to audit (required)
    *   p_table_owner   - Owner of the source table (default: current user)
    *   p_audit_suffix  - Suffix for audit table name (default: '_AUDIT_LOG')
    *
    * Notes:
    *   - Audit table includes: AUDIT_ID, DML_TYPE, DML_TIMESTAMP, DML_USER,
    *     SESSION_ID, HOST, MODULE, plus OLD_/NEW_ columns for each source column
    *   - Primary key created on AUDIT_ID
    *   - Index created on DML_TIMESTAMP for query performance
    ***************************************************************************/
    PROCEDURE create_audit_table(
        p_table_name   IN VARCHAR2,
        p_table_owner  IN VARCHAR2 DEFAULT USER,
        p_audit_suffix IN VARCHAR2 DEFAULT '_AUDIT_LOG'
    );

    /***************************************************************************
    * Procedure: CREATE_AUDIT_TRIGGER
    * Purpose:   Creates an AFTER trigger to capture old/new values
    *
    * Parameters:
    *   p_table_name       - Name of the source table (required)
    *   p_table_owner      - Owner of the source table (default: current user)
    *   p_audit_suffix     - Suffix for audit table name (default: '_AUDIT_LOG')
    *   p_trigger_suffix   - Suffix for trigger name (default: '_AUDIT_TRG')
    *   p_exclude_columns  - Comma-separated list of columns to exclude
    *
    * Notes:
    *   - Creates AFTER INSERT OR UPDATE OR DELETE trigger
    *   - Uses autonomous transaction for independent commit
    *   - Captures session context (user, host, module)
    ***************************************************************************/
    PROCEDURE create_audit_trigger(
        p_table_name      IN VARCHAR2,
        p_table_owner     IN VARCHAR2 DEFAULT USER,
        p_audit_suffix    IN VARCHAR2 DEFAULT '_AUDIT_LOG',
        p_trigger_suffix  IN VARCHAR2 DEFAULT '_AUDIT_TRG',
        p_exclude_columns IN VARCHAR2 DEFAULT NULL
    );

    /***************************************************************************
    * Procedure: DROP_AUDIT_OBJECTS
    * Purpose:   Removes audit table and trigger for a given source table
    *
    * Parameters:
    *   p_table_name     - Name of the source table
    *   p_table_owner    - Owner of the source table (default: current user)
    *   p_audit_suffix   - Suffix for audit table name (default: '_AUDIT_LOG')
    *   p_trigger_suffix - Suffix for trigger name (default: '_AUDIT_TRG')
    ***************************************************************************/
    PROCEDURE drop_audit_objects(
        p_table_name     IN VARCHAR2,
        p_table_owner    IN VARCHAR2 DEFAULT USER,
        p_audit_suffix   IN VARCHAR2 DEFAULT '_AUDIT_LOG',
        p_trigger_suffix IN VARCHAR2 DEFAULT '_AUDIT_TRG'
    );

    /***************************************************************************
    * Function: GET_AUDIT_DDL
    * Purpose:  Returns the DDL for audit table without executing
    *
    * Parameters:
    *   p_table_name   - Name of the source table
    *   p_table_owner  - Owner of the source table (default: current user)
    *   p_audit_suffix - Suffix for audit table name (default: '_AUDIT_LOG')
    *
    * Returns: CLOB containing the CREATE TABLE statement
    ***************************************************************************/
    FUNCTION get_audit_ddl(
        p_table_name   IN VARCHAR2,
        p_table_owner  IN VARCHAR2 DEFAULT USER,
        p_audit_suffix IN VARCHAR2 DEFAULT '_AUDIT_LOG'
    ) RETURN CLOB;

    /***************************************************************************
    * Function: GET_TRIGGER_DDL
    * Purpose:  Returns the DDL for audit trigger without executing
    *
    * Parameters:
    *   p_table_name       - Name of the source table
    *   p_table_owner      - Owner of the source table (default: current user)
    *   p_audit_suffix     - Suffix for audit table name (default: '_AUDIT_LOG')
    *   p_trigger_suffix   - Suffix for trigger name (default: '_AUDIT_TRG')
    *   p_exclude_columns  - Comma-separated list of columns to exclude
    *
    * Returns: CLOB containing the CREATE TRIGGER statement
    ***************************************************************************/
    FUNCTION get_trigger_ddl(
        p_table_name      IN VARCHAR2,
        p_table_owner     IN VARCHAR2 DEFAULT USER,
        p_audit_suffix    IN VARCHAR2 DEFAULT '_AUDIT_LOG',
        p_trigger_suffix  IN VARCHAR2 DEFAULT '_AUDIT_TRG',
        p_exclude_columns IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

END audit_pkg;
/
