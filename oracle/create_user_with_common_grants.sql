-- Oracle 19c+ / APEX-friendly: create user with common (least-privilege) grants.
--
-- Goal: avoid granting DBA. Instead, create a role with typical developer/schema-owner
-- privileges and grant that role to a user.
--
-- Notes:
-- - DDL cannot use bind variables directly; this script uses EXECUTE IMMEDIATE.
-- - Run as SYS, or as a user with CREATE USER / CREATE ROLE / GRANT ANY PRIVILEGE.
--
-- Usage (SQL*Plus / SQLcl):
--   @oracle/create_user_with_common_grants.sql APP_USER "Strong#Password1" USERS TEMP 500M
--
-- Arguments:
--   1: username
--   2: password (quoted in your call if it contains special chars)
--   3: default tablespace (e.g. USERS)
--   4: temporary tablespace (e.g. TEMP)
--   5: quota on default tablespace (e.g. 500M, 2G, UNLIMITED)
--
-- This script does NOT grant ANY dictionary access (e.g. SELECT ANY DICTIONARY).
-- Add such privileges only when you have a concrete requirement.

-- Use a non-default substitution character so passwords can contain '&'.
set define '^'
set serveroutput on size unlimited
set verify off
set feedback on

declare
  v_username   varchar2(128) := upper('^1');
  v_password   varchar2(4000) := '^2';
  v_def_ts     varchar2(128) := upper('^3');
  v_tmp_ts     varchar2(128) := upper('^4');
  v_quota      varchar2(128) := upper('^5');

  c_role_name  constant varchar2(128) := 'APP_COMMON_GRANTS_ROLE';

  procedure exec_ddl(p_sql in varchar2) is
  begin
    dbms_output.put_line('>> ' || p_sql);
    execute immediate p_sql;
  exception
    when others then
      dbms_output.put_line('!! failed: ' || sqlerrm);
      raise;
  end;

  function exists_user(p_username in varchar2) return boolean is
    l_cnt number;
  begin
    select count(*)
      into l_cnt
      from dba_users
     where username = p_username;
    return l_cnt > 0;
  end;

  function exists_role(p_role in varchar2) return boolean is
    l_cnt number;
  begin
    select count(*)
      into l_cnt
      from dba_roles
     where role = p_role;
    return l_cnt > 0;
  end;

  function quote_ident(p in varchar2) return varchar2 is
  begin
    -- We intentionally avoid quoted identifiers; enforce simple names.
    if regexp_like(p, '^[A-Z][A-Z0-9_$#]{0,127}$') then
      return p;
    end if;
    raise_application_error(-20000, 'Invalid identifier: ' || p);
  end;

  function quote_literal(p in varchar2) return varchar2 is
  begin
    return '''' || replace(p, '''', '''''') || '''';
  end;

begin
  v_username := quote_ident(v_username);
  v_def_ts   := quote_ident(v_def_ts);
  v_tmp_ts   := quote_ident(v_tmp_ts);

  if not exists_role(c_role_name) then
    exec_ddl('create role ' || c_role_name);
  else
    dbms_output.put_line('>> role exists: ' || c_role_name);
  end if;

  -- Common grants for a schema owner / developer (NOT DBA).
  -- Keep this list conservative; add privileges only when needed.
  exec_ddl('grant create session to ' || c_role_name);
  exec_ddl('grant create table to ' || c_role_name);
  exec_ddl('grant create view to ' || c_role_name);
  exec_ddl('grant create sequence to ' || c_role_name);
  exec_ddl('grant create procedure to ' || c_role_name);
  exec_ddl('grant create trigger to ' || c_role_name);
  exec_ddl('grant create type to ' || c_role_name);

  -- Optional (uncomment only if your tooling requires these):
  -- exec_ddl('grant create synonym to ' || c_role_name);
  -- exec_ddl('grant create materialized view to ' || c_role_name);
  -- exec_ddl('grant create job to ' || c_role_name); -- scheduler jobs

  if not exists_user(v_username) then
    exec_ddl(
      'create user ' || v_username ||
      ' identified by ' || quote_literal(v_password) ||
      ' default tablespace ' || v_def_ts ||
      ' temporary tablespace ' || v_tmp_ts
    );
  else
    dbms_output.put_line('>> user exists: ' || v_username || ' (updating settings)');
    exec_ddl('alter user ' || v_username || ' identified by ' || quote_literal(v_password));
    exec_ddl('alter user ' || v_username || ' default tablespace ' || v_def_ts);
    exec_ddl('alter user ' || v_username || ' temporary tablespace ' || v_tmp_ts);
  end if;

  -- Prefer explicit quotas over UNLIMITED TABLESPACE.
  exec_ddl('alter user ' || v_username || ' quota ' || v_quota || ' on ' || v_def_ts);
  exec_ddl('alter user ' || v_username || ' account unlock');

  -- Grant the common role to the user.
  exec_ddl('grant ' || c_role_name || ' to ' || v_username);

  -- If this user is a schema owner for an application, consider setting it as default:
  -- exec_ddl('alter user ' || v_username || ' default role all');

  dbms_output.put_line('Done.');
end;
/

-- Restore default substitution character.
set define '&'

