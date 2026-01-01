CREATE OR REPLACE PROCEDURE ${OWNER}.prc_bulk_process_example (
    /*
    ============================================================================
    Procedure:   PRC_BULK_PROCESS_EXAMPLE
    Description: Template for high-performance bulk processing using 
                 BULK COLLECT and FORALL
    Author:      AI Agent
    Created:     ${DATE}
    
    Performance Notes:
    - Uses BULK COLLECT with LIMIT for memory management
    - FORALL for efficient DML operations
    - Commits in batches to manage rollback segments
    ============================================================================
    */
    p_batch_size    IN  PLS_INTEGER DEFAULT 1000,
    p_rows_processed OUT PLS_INTEGER,
    p_status        OUT VARCHAR2
) AS
    -- Cursor for source data
    CURSOR cur_source IS
        SELECT id, col1, col2, col3
        FROM source_table
        WHERE status = 'PENDING'
        ORDER BY id;
    
    -- Collection types
    TYPE typ_id_table IS TABLE OF source_table.id%TYPE;
    TYPE typ_col1_table IS TABLE OF source_table.col1%TYPE;
    TYPE typ_col2_table IS TABLE OF source_table.col2%TYPE;
    TYPE typ_col3_table IS TABLE OF source_table.col3%TYPE;
    
    -- Collections
    t_ids       typ_id_table;
    t_col1      typ_col1_table;
    t_col2      typ_col2_table;
    t_col3      typ_col3_table;
    
    -- Variables
    v_total_processed PLS_INTEGER := 0;
    v_batch_count     PLS_INTEGER := 0;
    v_start_time      TIMESTAMP := SYSTIMESTAMP;
    
    -- DML error handling
    e_dml_errors EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_dml_errors, -24381);
    
BEGIN
    p_rows_processed := 0;
    p_status := 'SUCCESS';
    
    OPEN cur_source;
    
    LOOP
        -- Fetch batch
        FETCH cur_source BULK COLLECT INTO 
            t_ids, t_col1, t_col2, t_col3
        LIMIT p_batch_size;
        
        EXIT WHEN t_ids.COUNT = 0;
        
        v_batch_count := v_batch_count + 1;
        
        BEGIN
            -- Process: Insert into target with FORALL
            FORALL i IN 1..t_ids.COUNT SAVE EXCEPTIONS
                INSERT INTO target_table (id, col1, col2, col3, processed_date)
                VALUES (t_ids(i), t_col1(i), t_col2(i), t_col3(i), SYSDATE);
            
            -- Update source status with FORALL
            FORALL i IN 1..t_ids.COUNT
                UPDATE source_table 
                SET status = 'PROCESSED',
                    process_date = SYSDATE
                WHERE id = t_ids(i);
            
            v_total_processed := v_total_processed + t_ids.COUNT;
            
        EXCEPTION
            WHEN e_dml_errors THEN
                -- Log individual errors but continue processing
                FOR i IN 1..SQL%BULK_EXCEPTIONS.COUNT LOOP
                    INSERT INTO error_log (
                        procedure_name,
                        error_message,
                        error_details,
                        created_date
                    ) VALUES (
                        'PRC_BULK_PROCESS_EXAMPLE',
                        'DML Error at index ' || SQL%BULK_EXCEPTIONS(i).ERROR_INDEX,
                        SQLERRM(-SQL%BULK_EXCEPTIONS(i).ERROR_CODE),
                        SYSDATE
                    );
                END LOOP;
                
                -- Count successful rows
                v_total_processed := v_total_processed + 
                    (t_ids.COUNT - SQL%BULK_EXCEPTIONS.COUNT);
        END;
        
        -- Commit batch
        COMMIT;
        
        -- Progress logging
        IF MOD(v_batch_count, 10) = 0 THEN
            DBMS_OUTPUT.PUT_LINE(
                'Processed ' || v_total_processed || ' rows in ' || 
                v_batch_count || ' batches'
            );
        END IF;
        
    END LOOP;
    
    CLOSE cur_source;
    
    p_rows_processed := v_total_processed;
    
    -- Log completion
    DBMS_OUTPUT.PUT_LINE(
        'Completed: ' || p_rows_processed || ' rows in ' ||
        ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)), 2) || ' seconds'
    );
    
EXCEPTION
    WHEN OTHERS THEN
        IF cur_source%ISOPEN THEN
            CLOSE cur_source;
        END IF;
        
        p_status := 'ERROR: ' || SQLERRM;
        p_rows_processed := v_total_processed;
        
        -- Log error
        INSERT INTO error_log (
            procedure_name,
            error_message,
            error_stack,
            created_date
        ) VALUES (
            'PRC_BULK_PROCESS_EXAMPLE',
            SQLERRM,
            DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
            SYSDATE
        );
        COMMIT;
        
        RAISE;
END prc_bulk_process_example;
/
