-- Example usage
-- Run after creating LOGGER_LOG table and compiling LOGGER_PKG.

begin
  logger_pkg.set_min_level(logger_pkg.c_level_debug);

  logger_pkg.debug('debug message', p_scope => 'demo');
  logger_pkg.info ('info message',  p_scope => 'demo');
  logger_pkg.warn ('warn message',  p_scope => 'demo');
  logger_pkg.error('error message', p_scope => 'demo');
end;
/

select log_id, log_ts, log_level, scope, message, module, action
  from logger_log
 order by log_id desc fetch first 20 rows only;

