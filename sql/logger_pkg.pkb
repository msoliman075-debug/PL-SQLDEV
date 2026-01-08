create or replace package body logger_pkg as

  g_enabled   boolean := true;
  g_min_level pls_integer := 10; -- default DEBUG+

  function level_to_number(p_level in varchar2) return pls_integer is
    l_level varchar2(10) := upper(trim(p_level));
  begin
    return case l_level
             when c_level_debug then 10
             when c_level_info  then 20
             when c_level_warn  then 30
             when c_level_error then 40
             when c_level_fatal then 50
             else 999
           end;
  end level_to_number;

  procedure read_module(
    p_module out varchar2,
    p_action out varchar2
  ) is
  begin
    dbms_application_info.read_module(module_name => p_module, action_name => p_action);
  exception
    when others then
      p_module := null;
      p_action := null;
  end read_module;

  procedure enable is
  begin
    g_enabled := true;
  end enable;

  procedure disable is
  begin
    g_enabled := false;
  end disable;

  procedure set_min_level(p_level in varchar2) is
    l_num pls_integer;
  begin
    l_num := level_to_number(p_level);
    if l_num = 999 then
      -- Unknown levels treated as most restrictive.
      g_min_level := 999;
    else
      g_min_level := l_num;
    end if;
  end set_min_level;

  procedure log(
    p_level      in varchar2,
    p_message    in varchar2,
    p_scope      in varchar2 default null,
    p_extra      in clob     default null,
    p_callstack  in boolean  default false
  ) is
    pragma autonomous_transaction;
    l_level_num  pls_integer;
    l_level      varchar2(10);
    l_module     varchar2(64);
    l_action     varchar2(64);
    l_call_stack clob;
    l_error_stack clob;
  begin
    if not g_enabled then
      return;
    end if;

    l_level := upper(trim(p_level));
    l_level_num := level_to_number(l_level);
    if l_level_num < g_min_level then
      return;
    end if;

    read_module(p_module => l_module, p_action => l_action);

    if p_callstack then
      l_call_stack := dbms_utility.format_call_stack;
    else
      l_call_stack := null;
    end if;

    -- Only meaningful if caller passes error text; keep column for app usage.
    l_error_stack := null;

    insert into logger_log (
      log_level,
      scope,
      message,
      extra,
      call_stack,
      error_stack,
      module,
      action
    ) values (
      l_level,
      p_scope,
      substr(p_message, 1, 4000),
      p_extra,
      l_call_stack,
      l_error_stack,
      l_module,
      l_action
    );

    commit;
  exception
    when others then
      -- Never allow logging to affect the caller.
      rollback;
      null;
  end log;

  procedure debug(p_message in varchar2, p_scope in varchar2 default null, p_extra in clob default null) is
  begin
    log(p_level => c_level_debug, p_message => p_message, p_scope => p_scope, p_extra => p_extra, p_callstack => false);
  end debug;

  procedure info(p_message in varchar2, p_scope in varchar2 default null, p_extra in clob default null) is
  begin
    log(p_level => c_level_info, p_message => p_message, p_scope => p_scope, p_extra => p_extra, p_callstack => false);
  end info;

  procedure warn(p_message in varchar2, p_scope in varchar2 default null, p_extra in clob default null) is
  begin
    log(p_level => c_level_warn, p_message => p_message, p_scope => p_scope, p_extra => p_extra, p_callstack => false);
  end warn;

  procedure error(p_message in varchar2, p_scope in varchar2 default null, p_extra in clob default null) is
  begin
    log(p_level => c_level_error, p_message => p_message, p_scope => p_scope, p_extra => p_extra, p_callstack => true);
  end error;

  procedure fatal(p_message in varchar2, p_scope in varchar2 default null, p_extra in clob default null) is
  begin
    log(p_level => c_level_fatal, p_message => p_message, p_scope => p_scope, p_extra => p_extra, p_callstack => true);
  end fatal;

  procedure purge_older_than_days(p_days in number) is
  begin
    if p_days is null or p_days <= 0 then
      return;
    end if;

    delete from logger_log
     where log_ts < (systimestamp - numtodsinterval(p_days, 'DAY'));
  exception
    when others then
      -- Purge should never break callers either.
      null;
  end purge_older_than_days;

end logger_pkg;

