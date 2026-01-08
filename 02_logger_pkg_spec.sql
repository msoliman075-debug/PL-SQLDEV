CREATE OR REPLACE PACKAGE logger_pkg AS
    /**
     * Simple PL/SQL Logger Package
     * Target: Oracle 19c+
     */

    -- Log Levels
    c_level_info    CONSTANT VARCHAR2(20) := 'INFO';
    c_level_warning CONSTANT VARCHAR2(20) := 'WARNING';
    c_level_error   CONSTANT VARCHAR2(20) := 'ERROR';

    /**
     * Logs an informational message.
     * @param p_message The message to log.
     */
    PROCEDURE log_info(
        p_message IN CLOB
    );

    /**
     * Logs a warning message.
     * @param p_message The warning message.
     */
    PROCEDURE log_warning(
        p_message IN CLOB
    );

    /**
     * Logs an error message.
     * Automatically captures the error stack if not provided, or can be passed explicitly.
     * @param p_message The error message.
     * @param p_error_stack Optional error stack trace.
     */
    PROCEDURE log_error(
        p_message     IN CLOB,
        p_error_stack IN CLOB DEFAULT NULL
    );

    /**
     * Purges old logs.
     * @param p_days_to_keep Number of days of logs to retain (default 30).
     */
    PROCEDURE purge_logs(
        p_days_to_keep IN NUMBER DEFAULT 30
    );

END logger_pkg;
/
