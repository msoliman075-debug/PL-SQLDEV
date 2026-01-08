SET SERVEROUTPUT ON
SET LINESIZE 200
SET TRIMOUT ON

-- Test Info
BEGIN
    logger_pkg.log_info('Starting application process...');
END;
/

-- Test Warning
BEGIN
    logger_pkg.log_warning('Disk space is running low (simulated)');
END;
/

-- Test Error with automatic stack trace
BEGIN
    -- Raise a dummy error
    RAISE_APPLICATION_ERROR(-20001, 'Simulated application error');
EXCEPTION
    WHEN OTHERS THEN
        logger_pkg.log_error('An unexpected error occurred during processing');
END;
/

-- Verify logs
COL log_id FORMAT 9999
COL log_level FORMAT A10
COL message FORMAT A50
COL created_on FORMAT A30

SELECT log_id, log_level, substr(message, 1, 50) as message, created_on 
FROM app_logs 
ORDER BY log_id DESC;
