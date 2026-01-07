-- Grant SURETY least-privilege access to objects in schema SURETY_LOGS.
--
-- Requirement:
--   - SURETY can INSERT into any table in SURETY_LOGS
--   - SURETY can READ (SELECT) from any table in SURETY_LOGS
--   - SURETY can EXECUTE any procedure in SURETY_LOGS
--
-- Oracle best practice:
--   Use OBJECT privileges (GRANT ... ON schema.object) rather than system
--   privileges like SELECT ANY TABLE / EXECUTE ANY PROCEDURE, which apply to
--   the entire database.
--
-- Run this script connected as SURETY_LOGS (object owner), or as a user with
-- GRANT ANY OBJECT PRIVILEGE. It queries USER_* views (no DBA_* required).
--
-- Usage (SQL*Plus / SQLcl):
--   -- Connect as SURETY_LOGS
--   @oracle/grant_surety_access_to_surety_logs.sql SURETY
--
-- Arguments:
--   1: grantee username (e.g. SURETY)

set define '^'
set serveroutput on size unlimited
set verify off
set feedback on

declare
  v_user_grantee varchar2(128) := upper('^1');
  v_role         constant varchar2(128) := 'SURETY_LOGS_ACCESS_R';
  v_target       varchar2(128);

  procedure exec_ddl(p_sql in varchar2) is
  begin
    dbms_output.put_line('>> ' || p_sql);
    execute immediate p_sql;
  exception
    when others then
      dbms_output.put_line('!! failed: ' || sqlerrm);
      raise;
  end;

  function quote_ident(p in varchar2) return varchar2 is
  begin
    if regexp_like(p, '^[A-Z][A-Z0-9_$#]{0,127}$') then
      return p;
    end if;
    raise_application_error(-20000, 'Invalid identifier: ' || p);
  end;

  procedure grant_all(p_target in varchar2) is
  begin
    -- Tables: allow read and insert
    for r in (
      select table_name
        from user_tables
    ) loop
      exec_ddl('grant select, insert on ' || quote_ident(r.table_name) || ' to ' || p_target);
    end loop;

    -- Views: read only (in case the application queries views)
    for r in (
      select view_name
        from user_views
    ) loop
      exec_ddl('grant select on ' || quote_ident(r.view_name) || ' to ' || p_target);
    end loop;

    -- Sequences: common need when inserting rows
    for r in (
      select sequence_name
        from user_sequences
    ) loop
      exec_ddl('grant select on ' || quote_ident(r.sequence_name) || ' to ' || p_target);
    end loop;

    -- Program units: procedures/functions/packages (grant regardless of validity)
    for r in (
      select object_name
        from user_objects
       where object_type in ('PROCEDURE', 'FUNCTION', 'PACKAGE')
    ) loop
      exec_ddl('grant execute on ' || quote_ident(r.object_name) || ' to ' || p_target);
    end loop;
  end;

begin
  v_user_grantee := quote_ident(v_user_grantee);
  v_target := v_role;

  -- Create a role to group privileges.
  -- CREATE ROLE is a system privilege, so this may fail if you are not allowed.
  -- If it fails, you can skip the role and grant directly to v_grantee.
  begin
    exec_ddl('create role ' || v_role);
  exception
    when others then
      if sqlcode = -1921 then
        dbms_output.put_line('>> role exists: ' || v_role);
      else
        dbms_output.put_line('>> cannot create role; will grant directly to user: ' || sqlerrm);
        v_target := v_user_grantee;
      end if;
  end;

  -- Grant object privileges to either the role (preferred) or directly to the user.
  grant_all(v_target);

  -- If we used a role, grant the role to the user. If this fails, fall back to
  -- granting directly to the user so the requirement is still met.
  if v_target = v_role then
    begin
      exec_ddl('grant ' || v_role || ' to ' || v_user_grantee);
    exception
      when others then
        dbms_output.put_line('>> cannot grant role to user; granting directly to user: ' || sqlerrm);
        grant_all(v_user_grantee);
    end;
  end if;

  dbms_output.put_line('Done.');
end;
/

-- Optional: to keep future objects granted automatically, create an AFTER CREATE trigger
-- in schema SURETY_LOGS. This is powerful; review with your security policy first.
--
-- create or replace trigger surety_logs_auto_grant_trg
--   after create on schema
-- declare
--   l_target constant varchar2(128) := 'SURETY_LOGS_ACCESS_R';
-- begin
--   if ora_dict_obj_type = 'TABLE' then
--     execute immediate 'grant select, insert on ' || ora_dict_obj_name || ' to ' || l_target;
--   elsif ora_dict_obj_type = 'VIEW' then
--     execute immediate 'grant select on ' || ora_dict_obj_name || ' to ' || l_target;
--   elsif ora_dict_obj_type in ('PROCEDURE','FUNCTION','PACKAGE') then
--     execute immediate 'grant execute on ' || ora_dict_obj_name || ' to ' || l_target;
--   elsif ora_dict_obj_type = 'SEQUENCE' then
--     execute immediate 'grant select on ' || ora_dict_obj_name || ' to ' || l_target;
--   end if;
-- exception
--   when others then
--     -- Avoid breaking DDL; log if you have a logging table.
--     null;
-- end;
-- /

set define '&'

