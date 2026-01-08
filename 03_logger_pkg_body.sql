CREATE OR REPLACE PACKAGE BODY logger_pkg AS

    /**
     * Private procedure to perform the actual insert.
     * Uses autonomous transaction to ensure logs are saved even if main transaction fails.
     */
    PROCEDURE log_internal(
        p_level       IN VARCHAR2,
        p_message     IN CLOB,
        p_error_stack IN CLOB DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO app_logs (
            log_level,
            message,
            error_stack
        ) VALUES (
            p_level,
            p_message,
            p_error_stack
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            -- In case logging fails, we don't want to break the application.
            -- However, we should rollback the autonomous transaction.
            ROLLBACK;
            -- Ideally, write to alert log or standard output, but strictly suppressing here to be safe.
            dbms_output.put_line('Error in logger_pkg: ' || SQLERRM);
    END log_internal;

    ----------------------------------------------------------------------------
    PROCEDURE log_info(
        p_message IN CLOB
    ) IS
    BEGIN
        log_internal(
            p_level   => c_level_info,
            p_message => p_message
        );
    EXCEPTION
        WHEN OTHERS THEN
            -- Safety net for the public procedure
            dbms_output.put_line('Error in log_info: ' || SQLERRM);
    END log_info;

    ----------------------------------------------------------------------------
    PROCEDURE log_warning(
        p_message IN CLOB
    ) IS
    BEGIN
        log_internal(
            p_level   => c_level_warning,
            p_message => p_message
        );
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Error in log_warning: ' || SQLERRM);
    END log_warning;

    ----------------------------------------------------------------------------
    PROCEDURE log_error(
        p_message     IN CLOB,
        p_error_stack IN CLOB DEFAULT NULL
    ) IS
        v_stack CLOB := p_error_stack;
    BEGIN
        -- If no stack provided, try to get the current format_error_backtrace
        IF v_stack IS NULL THEN
            v_stack := dbms_utility.format_error_stack || CHR(10) || dbms_utility.format_error_backtrace;
        END IF;

        log_internal(
            p_level       => c_level_error,
            p_message     => p_message,
            p_error_stack => v_stack
        );
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Error in log_error: ' || SQLERRM);
    END log_error;

    ----------------------------------------------------------------------------
    PROCEDURE purge_logs(
        p_days_to_keep IN NUMBER DEFAULT 30
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        DELETE FROM app_logs
        WHERE created_on < SYSTIMESTAMP - p_days_to_keep;
        
        COMMIT;
        
        log_info('Purged logs older than ' || p_days_to_keep || ' days. Rows deleted: ' || SQL%ROWCOUNT);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            -- Log the error of the purge itself (recursion risk if not careful, but log_internal is safe)
            -- Using dbms_output here to avoid infinite loop if log table is broken
            dbms_output.put_line('Error in purge_logs: ' || SQLERRM);
    END purge_logs;

END logger_pkg;
/
