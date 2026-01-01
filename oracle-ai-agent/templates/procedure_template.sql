CREATE OR REPLACE PROCEDURE ${OWNER}.${PROCEDURE_NAME} (
    /*
    ============================================================================
    Procedure:   ${PROCEDURE_NAME}
    Description: ${DESCRIPTION}
    Author:      AI Agent
    Created:     ${DATE}
    
    Parameters:
        p_param1    - Input parameter description
        p_result    - Output result status
    
    Modification History:
    Date        Author          Description
    ----------  --------------  ------------------------------------------------
    ${DATE}     AI Agent        Initial creation
    ============================================================================
    */
    p_param1    IN  VARCHAR2,
    p_result    OUT VARCHAR2
) AS
    -- Local variables
    v_count     PLS_INTEGER := 0;
    v_start     TIMESTAMP := SYSTIMESTAMP;
    
    -- Constants
    c_procedure CONSTANT VARCHAR2(50) := '${PROCEDURE_NAME}';
    
    -- Exceptions
    e_validation_error EXCEPTION;
    
BEGIN
    -- Input validation
    IF p_param1 IS NULL THEN
        RAISE e_validation_error;
    END IF;
    
    -- Main processing logic
    -- TODO: Implement business logic
    
    -- Set success result
    p_result := 'SUCCESS';
    
    -- Log execution time (optional)
    DBMS_OUTPUT.PUT_LINE(
        c_procedure || ' completed in ' || 
        EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)) || ' seconds'
    );
    
EXCEPTION
    WHEN e_validation_error THEN
        p_result := 'ERROR: Invalid input parameters';
        -- Log error
        INSERT INTO error_log (procedure_name, error_message, created_date)
        VALUES (c_procedure, p_result, SYSDATE);
        COMMIT;
        
    WHEN NO_DATA_FOUND THEN
        p_result := 'ERROR: No data found';
        INSERT INTO error_log (procedure_name, error_message, created_date)
        VALUES (c_procedure, p_result, SYSDATE);
        COMMIT;
        
    WHEN OTHERS THEN
        p_result := 'ERROR: ' || SQLERRM;
        INSERT INTO error_log (
            procedure_name, 
            error_message, 
            error_stack,
            created_date
        ) VALUES (
            c_procedure, 
            SQLERRM, 
            DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
            SYSDATE
        );
        COMMIT;
        RAISE;
END ${PROCEDURE_NAME};
/
