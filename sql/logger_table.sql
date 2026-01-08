-- Simple logger table for Oracle 19c+
-- Stores application log messages with optional scope/extra payload.
--
-- Notes:
-- - Uses an identity column (no sequence required)
-- - Uses TIMESTAMP WITH LOCAL TIME ZONE for consistent display across time zones

create table logger_log (
  log_id            number generated always as identity not null,
  log_ts            timestamp(6) with local time zone default systimestamp not null,
  log_level         varchar2(10) not null,
  scope             varchar2(200),
  message           varchar2(4000) not null,
  extra             clob,
  call_stack        clob,
  error_stack       clob,
  created_user      varchar2(128) default sys_context('USERENV','SESSION_USER') not null,
  client_identifier varchar2(64)  default sys_context('USERENV','CLIENT_IDENTIFIER'),
  module            varchar2(64),
  action            varchar2(64),
  session_id        number        default sys_context('USERENV','SESSIONID'),
  constraint logger_log_pk primary key (log_id),
  constraint logger_log_level_ck check (log_level in ('DEBUG','INFO','WARN','ERROR','FATAL'))
);

create index logger_log_i1 on logger_log (log_ts);
create index logger_log_i2 on logger_log (log_level, log_ts);

