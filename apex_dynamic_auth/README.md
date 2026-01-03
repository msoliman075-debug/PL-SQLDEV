# Dynamic Authorization Scheme for Oracle APEX

A comprehensive PL/SQL-based authorization framework that gives end users flexibility to control access to **Menus**, **Pages**, **Regions**, and **Buttons** in Oracle APEX applications.

## 📋 Features

- **Role-Based Access Control (RBAC)**: Define roles and assign them to users
- **Component-Level Authorization**: Control access to pages, regions, buttons, menu entries, and more
- **Granular Permissions**: VIEW, EDIT, DELETE, EXECUTE permissions per component
- **Time-Based Access**: Set effective dates for role assignments and permissions
- **Audit Logging**: Track all authorization checks and changes
- **Easy Integration**: Simple functions for APEX Authorization Schemes
- **Administration Ready**: SQL views and queries for building admin pages

## 📁 Files

| File | Description |
|------|-------------|
| `00_install.sql` | Master installation script |
| `01_ddl_tables.sql` | DDL for all authorization tables |
| `02_pkg_spec.sql` | Package specification |
| `03_pkg_body.sql` | Package body implementation |
| `04_sample_data.sql` | Sample roles, users, and permissions |
| `05_apex_usage_guide.sql` | APEX integration examples and views |

## 🚀 Installation

### Prerequisites
- Oracle Database 19c or higher
- Oracle APEX 21.1 or higher
- Schema with CREATE TABLE, CREATE PACKAGE privileges

### Quick Install

```sql
-- Connect to your schema
SQL> @00_install.sql
```

### Manual Install (Step by Step)

```sql
SQL> @01_ddl_tables.sql
SQL> @02_pkg_spec.sql
SQL> @03_pkg_body.sql
SQL> @05_apex_usage_guide.sql

-- Optional: Load sample data
SQL> @04_sample_data.sql
```

## 📊 Database Schema

### Tables

```
APEX_AUTH_ROLES              - Security roles/groups
APEX_AUTH_USER_ROLES         - User to role assignments
APEX_AUTH_COMPONENT_TYPES    - Component types (PAGE, REGION, BUTTON, etc.)
APEX_AUTH_COMPONENTS         - Registered APEX components
APEX_AUTH_PERMISSIONS        - Role-to-component permission mappings
APEX_AUTH_AUDIT_LOG          - Audit trail
```

### Entity Relationship

```
USERS ──┬──< USER_ROLES >──┬── ROLES
        │                   │
        │                   ├──< PERMISSIONS >──┬── COMPONENTS
        │                   │                   │
        └───────────────────┴───────────────────┴── (Authorization Check)
```

## 📖 Usage Guide

### 1. Create Roles

```sql
DECLARE
    l_role_id NUMBER;
BEGIN
    apex_auth_pkg.create_role(
        p_role_code        => 'ADMIN',
        p_role_name        => 'Administrator',
        p_role_description => 'Full system access',
        p_role_id          => l_role_id
    );
END;
/
```

### 2. Assign Users to Roles

```sql
BEGIN
    -- Permanent assignment
    apex_auth_pkg.assign_role_to_user('JOHN.SMITH', 'ADMIN');
    
    -- Temporary assignment (30 days)
    apex_auth_pkg.assign_role_to_user(
        p_username       => 'CONTRACTOR',
        p_role_code      => 'USER',
        p_effective_from => TRUNC(SYSDATE),
        p_effective_to   => TRUNC(SYSDATE) + 30
    );
END;
/
```

### 3. Register Components

```sql
BEGIN
    -- Register pages
    apex_auth_pkg.register_page(100, 1, 'Home Page');
    apex_auth_pkg.register_page(100, 10, 'Reports');
    
    -- Register regions
    apex_auth_pkg.register_region(100, 3, 'REGION_SALARY', 'Salary Information');
    
    -- Register buttons
    apex_auth_pkg.register_button(100, 3, 'BTN_SAVE', 'Save Employee');
    apex_auth_pkg.register_button(100, 3, 'BTN_DELETE', 'Delete Employee');
    
    -- Register menu entries
    apex_auth_pkg.register_menu_entry(100, 'MENU_ADMIN', 'Administration');
END;
/
```

### 4. Grant Permissions

```sql
BEGIN
    -- Grant page access
    apex_auth_pkg.grant_permission_by_name(
        p_role_code           => 'ADMIN',
        p_application_id      => 100,
        p_component_type_code => 'PAGE',
        p_component_name      => '1',
        p_page_id             => 1,
        p_can_view            => 'Y',
        p_can_edit            => 'Y',
        p_can_delete          => 'Y',
        p_can_execute         => 'Y'
    );
    
    -- Grant button access
    apex_auth_pkg.grant_permission_by_name(
        p_role_code           => 'MANAGER',
        p_application_id      => 100,
        p_component_type_code => 'BUTTON',
        p_component_name      => 'BTN_SAVE',
        p_page_id             => 3,
        p_can_view            => 'Y',
        p_can_execute         => 'Y'
    );
END;
/
```

## 🔧 APEX Integration

### Creating Authorization Schemes

In Oracle APEX, go to **Shared Components > Authorization Schemes** and create:

#### Page Authorization

```sql
-- Name: DYNAMIC_PAGE_AUTH
-- Type: PL/SQL Function Returning Boolean
RETURN apex_auth_pkg.can_access_page(
    p_page_id        => :APP_PAGE_ID,
    p_application_id => :APP_ID,
    p_username       => :APP_USER
);
```

#### Region Authorization

```sql
-- Name: AUTH_REGION_SALARY
-- Type: PL/SQL Function Returning Boolean
RETURN apex_auth_pkg.can_view_region(
    p_region_static_id => 'REGION_SALARY',
    p_page_id          => :APP_PAGE_ID,
    p_application_id   => :APP_ID,
    p_username         => :APP_USER
);
```

#### Button Authorization

```sql
-- Name: AUTH_BTN_DELETE
-- Type: PL/SQL Function Returning Boolean
RETURN apex_auth_pkg.can_use_button(
    p_button_static_id => 'BTN_DELETE',
    p_page_id          => :APP_PAGE_ID,
    p_application_id   => :APP_ID,
    p_username         => :APP_USER
);
```

#### Menu Entry Authorization

```sql
-- Name: AUTH_MENU_ADMIN
-- Type: PL/SQL Function Returning Boolean
RETURN apex_auth_pkg.can_view_menu_entry(
    p_menu_entry_name => 'MENU_ADMIN',
    p_application_id  => :APP_ID,
    p_username        => :APP_USER
);
```

#### Role-Based Check

```sql
-- Name: IS_ADMIN
-- Type: PL/SQL Function Returning Boolean
RETURN apex_auth_pkg.has_role('ADMIN', :APP_USER);

-- Name: IS_MANAGER_OR_ADMIN
-- Type: PL/SQL Function Returning Boolean
RETURN apex_auth_pkg.has_any_role(
    apex_auth_pkg.t_role_list('ADMIN', 'MANAGER'),
    :APP_USER
);
```

## 📋 Available Functions

### Authorization Checks

| Function | Description |
|----------|-------------|
| `is_authorized()` | Main authorization check (returns BOOLEAN) |
| `is_authorized_yn()` | Same as above but returns Y/N (for SQL) |
| `can_access_page()` | Check page access |
| `can_view_region()` | Check region visibility |
| `can_use_button()` | Check button access |
| `can_view_menu_entry()` | Check menu entry visibility |
| `has_role()` | Check if user has specific role |
| `has_any_role()` | Check if user has any of specified roles |
| `has_all_roles()` | Check if user has all specified roles |
| `get_user_roles()` | Get comma-separated list of user's roles |

### Management Procedures

| Procedure | Description |
|-----------|-------------|
| `create_role()` | Create a new role |
| `update_role()` | Update role properties |
| `delete_role()` | Delete a role |
| `assign_role_to_user()` | Assign role to user |
| `remove_role_from_user()` | Remove role from user |
| `sync_user_roles()` | Synchronize user's roles |
| `register_component()` | Register an APEX component |
| `register_page()` | Register a page |
| `register_region()` | Register a region |
| `register_button()` | Register a button |
| `register_menu_entry()` | Register a menu entry |
| `grant_permission()` | Grant permission to a role |
| `grant_permission_by_name()` | Grant permission using names |
| `revoke_permission()` | Revoke a permission |
| `copy_role_permissions()` | Copy permissions between roles |

## 🔍 Administration Queries

### View User Permissions

```sql
SELECT * FROM v_apex_auth_user_effective_perms
WHERE username = :APP_USER
AND application_id = :APP_ID;
```

### View Role Permissions

```sql
SELECT * FROM v_apex_auth_role_perms
WHERE role_code = 'ADMIN'
AND application_id = 100;
```

### Audit Log

```sql
SELECT * FROM apex_auth_audit_log
WHERE audit_date >= SYSTIMESTAMP - INTERVAL '7' DAY
ORDER BY audit_date DESC;
```

## 🏗️ Building an Admin Interface

You can build APEX pages to manage authorization using Interactive Reports/Grids on:

1. **Role Management**: CRUD on `APEX_AUTH_ROLES`
2. **User Role Assignment**: CRUD on `APEX_AUTH_USER_ROLES`
3. **Component Registration**: CRUD on `APEX_AUTH_COMPONENTS`
4. **Permission Matrix**: CRUD on `APEX_AUTH_PERMISSIONS`
5. **Audit Log Viewer**: Report on `APEX_AUTH_AUDIT_LOG`

## ⚙️ Component Types

Pre-configured component types:

| Code | Name | Description |
|------|------|-------------|
| PAGE | Page | APEX Application Page |
| REGION | Region | Page Region |
| BUTTON | Button | Page Button |
| MENU | Navigation Menu | Navigation Menu Entry |
| LIST_ENTRY | List Entry | List Entry Item |
| TAB | Tab | Tab or Tab Set |
| ITEM | Page Item | Form/Display Item |
| REPORT_COL | Report Column | IR/Classic Report Column |
| PROCESS | Process | Page/Application Process |
| COMPUTATION | Computation | Page Computation |

## 🔒 Security Considerations

1. **Principle of Least Privilege**: Start with no access, grant as needed
2. **Audit Logging**: All checks are logged for security monitoring
3. **Time-Based Access**: Use effective dates for temporary access
4. **Centralized Control**: All authorization logic in one package
5. **Cache-Friendly**: Functions designed for efficient repeated calls

## 📝 License

This framework is provided as-is for Oracle APEX applications.

## 🤝 Support

For issues or enhancements, review the package code in `02_pkg_spec.sql` and `03_pkg_body.sql`.
