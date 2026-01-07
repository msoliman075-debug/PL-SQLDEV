# Oracle user creation without `DBA` (common grants)

This folder contains a reusable script to create an Oracle Database user with a **common, least-privilege grant set** using a role, instead of granting `DBA`.

## Script

- `create_user_with_common_grants.sql`

Creates/updates:

- A role: `APP_COMMON_GRANTS_ROLE`
- A user you specify
- A quota on the default tablespace
- Grants the role to the user

## Example

Run as `SYS` (or a user with `CREATE USER`, `CREATE ROLE`, and ability to grant the listed system privileges):

```sql
@oracle/create_user_with_common_grants.sql APP_USER "Strong#Password1" USERS TEMP 500M
```

The script sets `DEFINE` to `^` internally, so passwords containing `&` are safe.

## What “common grants” means here

The role grants typical **schema-owner / developer** privileges:

- `CREATE SESSION`
- `CREATE TABLE`
- `CREATE VIEW`
- `CREATE SEQUENCE`
- `CREATE PROCEDURE`
- `CREATE TRIGGER`
- `CREATE TYPE`

It **does not** grant powerful broad privileges like:

- `DBA`
- `UNLIMITED TABLESPACE`
- `SELECT ANY TABLE`, `INSERT ANY TABLE`, etc.
- `SELECT ANY DICTIONARY`

Add optional privileges only when you have a specific need (e.g. `CREATE JOB` for Scheduler usage).

## Execution / optimizer impact

Granting (or not granting) `DBA` **does not change Oracle optimizer behavior** for SQL execution plans in normal use. Privileges mainly affect:

- **What objects you can create/alter**
- **What data you can access**
- **Which operations succeed/fail at parse time due to permissions**

If you later add privileges like `SELECT ANY TABLE` or cross-schema object access, execution plans can change *indirectly* only because different objects/paths become available (not because the optimizer itself changes).

