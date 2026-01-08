create or replace package logger_pkg authid definer as
  ------------------------------------------------------------------------------
  -- Simple logger package (Oracle 19c+)
  -- - Logs to LOGGER_LOG table
  -- - Uses autonomous transaction so caller semantics are preserved
  -- - Never raises errors back to the caller
  ------------------------------------------------------------------------------

  -- Log levels (higher = more severe)
  c_level_debug constant varchar2(10) := 'DEBUG';
  c_level_info  constant varchar2(10) := 'INFO';
  c_level_warn  constant varchar2(10) := 'WARN';
  c_level_error constant varchar2(10) := 'ERROR';
  c_level_fatal constant varchar2(10) := 'FATAL';

  -- Enable/disable logging for the current session.
  procedure enable;
  procedure disable;

  -- Set minimum level for the current session (messages below are ignored).
  -- Example: set_min_level(logger_pkg.c_level_warn) will log WARN/ERROR/FATAL only.
  procedure set_min_level(p_level in varchar2);

  -- Generic log call.
  procedure log(
    p_level      in varchar2,
    p_message    in varchar2,
    p_scope      in varchar2 default null,
    p_extra      in clob     default null,
    p_callstack  in boolean  default false
  );

  -- Convenience helpers.
  procedure debug(p_message in varchar2, p_scope in varchar2 default null, p_extra in clob default null);
  procedure info (p_message in varchar2, p_scope in varchar2 default null, p_extra in clob default null);
  procedure warn (p_message in varchar2, p_scope in varchar2 default null, p_extra in clob default null);
  procedure error(p_message in varchar2, p_scope in varchar2 default null, p_extra in clob default null);
  procedure fatal(p_message in varchar2, p_scope in varchar2 default null, p_extra in clob default null);

  -- Optional maintenance.
  procedure purge_older_than_days(p_days in number);

end logger_pkg;

