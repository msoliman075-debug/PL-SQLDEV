CREATE OR REPLACE PACKAGE ${OWNER}.${PACKAGE_NAME} AS
    /*
    ============================================================================
    Package:     ${PACKAGE_NAME}
    Description: ${DESCRIPTION}
    Author:      AI Agent
    Created:     ${DATE}
    
    Modification History:
    Date        Author          Description
    ----------  --------------  ------------------------------------------------
    ${DATE}     AI Agent        Initial creation
    ============================================================================
    */
    
    -- Types
    TYPE typ_varchar_table IS TABLE OF VARCHAR2(4000) INDEX BY PLS_INTEGER;
    
    -- Constants
    c_version CONSTANT VARCHAR2(10) := '1.0.0';
    
    -- Public Procedures
    PROCEDURE prc_initialize;
    
    -- Public Functions
    FUNCTION fnc_get_version RETURN VARCHAR2;
    
END ${PACKAGE_NAME};
/

CREATE OR REPLACE PACKAGE BODY ${OWNER}.${PACKAGE_NAME} AS
    
    -- Private variables
    g_initialized BOOLEAN := FALSE;
    
    -- Private constants
    c_module CONSTANT VARCHAR2(50) := '${PACKAGE_NAME}';
    
    /*
    -------------------------------------------------------------------------
    Private Procedures
    -------------------------------------------------------------------------
    */
    
    PROCEDURE log_error(
        p_procedure IN VARCHAR2,
        p_message   IN VARCHAR2,
        p_error     IN VARCHAR2 DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        -- Insert into error log table
        INSERT INTO error_log (
            module_name,
            procedure_name,
            error_message,
            error_stack,
            created_date
        ) VALUES (
            c_module,
            p_procedure,
            p_message,
            NVL(p_error, DBMS_UTILITY.FORMAT_ERROR_STACK),
            SYSDATE
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Don't fail on logging errors
    END log_error;
    
    /*
    -------------------------------------------------------------------------
    Public Procedures
    -------------------------------------------------------------------------
    */
    
    PROCEDURE prc_initialize IS
    BEGIN
        IF g_initialized THEN
            RETURN;
        END IF;
        
        -- Initialization logic here
        
        g_initialized := TRUE;
        
    EXCEPTION
        WHEN OTHERS THEN
            log_error('PRC_INITIALIZE', 'Initialization failed', SQLERRM);
            RAISE;
    END prc_initialize;
    
    /*
    -------------------------------------------------------------------------
    Public Functions
    -------------------------------------------------------------------------
    */
    
    FUNCTION fnc_get_version RETURN VARCHAR2 IS
    BEGIN
        RETURN c_version;
    END fnc_get_version;
    
END ${PACKAGE_NAME};
/

-- Grant execute to appropriate roles
-- GRANT EXECUTE ON ${OWNER}.${PACKAGE_NAME} TO APPS_READ_ROLE;
