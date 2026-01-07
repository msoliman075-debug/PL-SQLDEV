-- Oracle Database User Creation and Grants Script
-- Purpose: Create a user with common development privileges without granting the powerful DBA role.
-- Target: Oracle 19c+

-- 1. Create the user
-- Replace 'APP_USER' and 'StrongPassword123!' with your desired username and password.
-- Ensure the default tablespace exists (usually USERS).
CREATE USER app_user IDENTIFIED BY "StrongPassword123!"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;

-- 2. Grant Connection Privileges
GRANT CREATE SESSION TO app_user;

-- 3. Grant Object Creation Privileges (The "Common" Developer Set)
-- Instead of GRANT DBA, we grant only what is needed to build applications.

-- Tables and Indexes
GRANT CREATE TABLE TO app_user;
-- Note: In Oracle, CREATE TABLE includes the ability to create indexes on your own tables.

-- Views
GRANT CREATE VIEW TO app_user;

-- PL/SQL Objects
GRANT CREATE PROCEDURE TO app_user; -- Covers Procedures, Functions, and Packages
GRANT CREATE TRIGGER TO app_user;

-- Sequences for ID generation
GRANT CREATE SEQUENCE TO app_user;

-- Types and Synonyms
GRANT CREATE TYPE TO app_user;
GRANT CREATE SYNONYM TO app_user;

-- Materialized Views (Optional, often needed)
GRANT CREATE MATERIALIZED VIEW TO app_user;

-- 4. Optional: Debugging Privileges (Useful for developers)
GRANT DEBUG CONNECT SESSION TO app_user;
GRANT DEBUG ANY PROCEDURE TO app_user;

-- 5. Comments on Security
-- GRANT DBA is dangerous because it gives full system control.
-- The above privileges allow the user to manage their own schema objects
-- but prevents them from modifying system settings or other users' data.

-- Verify the grants
-- SELECT * FROM dba_sys_privs WHERE grantee = 'APP_USER';
