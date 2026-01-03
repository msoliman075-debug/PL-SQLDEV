# Oracle APEX Dynamic Authorization Scheme

A comprehensive, enterprise-grade dynamic authorization system for Oracle APEX applications that provides flexible, role-based access control for Menus, Pages, Regions, and Buttons.

## 🎯 Features

- **Role-Based Access Control (RBAC)**: Assign users to roles with specific permissions
- **Fine-Grained Control**: Secure Pages, Regions, Buttons, Menu Items, and Form Items
- **User-Specific Overrides**: Grant or deny access to individual users regardless of role
- **Temporal Validity**: Time-based access control with effective dates
- **Comprehensive Audit Trail**: Track all authorization checks for compliance
- **Performance Optimized**: Built-in caching mechanism with configurable timeout
- **Flexible Configuration**: End-user manageable without code changes
- **Super Admin Support**: Configurable bypass role for system administrators
- **Oracle 19c+ Compatible**: Uses modern Oracle features and APEX best practices

## 📋 Prerequisites

- Oracle Database 19c or higher
- Oracle APEX 19.1 or higher
- Appropriate privileges to create tables, sequences, and packages
- EXECUTE privilege on APEX_APPLICATION (for APEX context)

## 🚀 Quick Start

### 1. Installation

Execute the SQL scripts in the following order:

```sql
-- Step 1: Create database objects
@01_DDL_Authorization_Tables.sql

-- Step 2: Create package specification
@02_PKG_SPEC_Authorization.sql

-- Step 3: Create package body
@03_PKG_BODY_Authorization.sql

-- Step 4: Initialize with sample data (optional)
@04_Sample_Data_and_Tests.sql
```

### 2. Initialize the System

```sql
BEGIN
    apex_authorization_pkg.initialize_default_permissions;
END;
/
```

This creates default roles (SUPERADMIN, ADMIN, MANAGER, USER, GUEST) and permissions (VIEW, EDIT, DELETE, EXECUTE, ADMIN).

### 3. Create Your First User and Role Assignment

```sql
BEGIN
    -- Create a user
    apex_authorization_pkg.create_user(
        p_username => 'JOHN.DOE',
        p_email => 'john.doe@company.com',
        p_full_name => 'John Doe',
        p_is_active => 'Y'
    );
    
    -- Assign role to user
    apex_authorization_pkg.assign_role_to_user(
        p_username => 'JOHN.DOE',
        p_role_code => 'USER'
    );
END;
/
```

### 4. Register APEX Objects

```sql
BEGIN
    -- Register a page
    apex_authorization_pkg.register_object(
        p_application_id => 100,  -- Your APEX Application ID
        p_object_type => 'PAGE',
        p_object_code => 'PAGE_10',
        p_object_name => 'Dashboard',
        p_page_id => 10
    );
    
    -- Grant permission
    apex_authorization_pkg.grant_permission(
        p_role_code => 'USER',
        p_application_id => 100,
        p_object_code => 'PAGE_10',
        p_permission_code => 'VIEW'
    );
END;
/
```

## 🔧 APEX Configuration

### Create Authorization Scheme

1. Navigate to: **Shared Components > Security > Authorization Schemes**
2. Click **Create**
3. Configure:
   - **Name**: Dynamic Authorization - Pages
   - **Scheme Type**: PL/SQL Function Returning Boolean
   - **PL/SQL Function Body**:

```sql
RETURN apex_authorization_pkg.is_page_authorized(
    p_page_id => :APP_PAGE_ID,
    p_application_id => :APP_ID,
    p_username => :APP_USER
);
```

4. **Error Message**: "You do not have access to this page."
5. Click **Create Authorization Scheme**

### Apply to Page

1. Open page in Page Designer
2. Select page
3. Under **Security** section:
   - **Authorization Scheme**: Dynamic Authorization - Pages
4. Under **Advanced** section:
   - **Static ID**: PAGE_10 (must match registered object code)

## 📚 Usage Examples

### Role Management

```sql
-- Create a new role
BEGIN
    apex_authorization_pkg.create_role(
        p_role_code => 'FINANCE',
        p_role_name => 'Finance Team',
        p_role_description => 'Finance department users'
    );
END;
/

-- Assign role to user with time limit
BEGIN
    apex_authorization_pkg.assign_role_to_user(
        p_username => 'JANE.SMITH',
        p_role_code => 'FINANCE',
        p_effective_from => SYSDATE,
        p_effective_to => SYSDATE + 90  -- 90-day access
    );
END;
/
```

### User-Specific Override

```sql
-- Grant special access to one user
BEGIN
    apex_authorization_pkg.grant_user_permission(
        p_username => 'JANE.SMITH',
        p_application_id => 100,
        p_object_code => 'FINANCIAL_REPORT',
        p_permission_code => 'VIEW',
        p_is_granted => 'Y',
        p_override_roles => 'Y'
    );
END;
/
```

### Secure a Region

```sql
-- In APEX Page Designer
-- Set Region Static ID to: FINANCIAL_REPORT
-- Server-side Condition Type: Function Body Returning Boolean
-- PL/SQL Function:

RETURN apex_authorization_pkg.is_region_authorized(
    p_region_code => 'FINANCIAL_REPORT',
    p_application_id => :APP_ID,
    p_username => :APP_USER
);
```

### Secure a Button

```sql
-- In APEX Page Designer
-- Set Button Static ID to: BTN_DELETE
-- Server-side Condition Type: Function Body Returning Boolean
-- PL/SQL Function:

RETURN apex_authorization_pkg.is_button_authorized(
    p_button_code => 'BTN_DELETE',
    p_application_id => :APP_ID,
    p_username => :APP_USER
);
```

### Check User Roles

```sql
-- Check if user has specific role
IF apex_authorization_pkg.has_role('JOHN.DOE', 'MANAGER') THEN
    -- User is a manager
END IF;

-- Check if user has any of multiple roles
IF apex_authorization_pkg.has_any_role('JOHN.DOE', 'ADMIN,MANAGER,SUPERADMIN') THEN
    -- User has at least one admin role
END IF;
```

## 📊 Database Schema

### Core Tables

| Table | Purpose |
|-------|---------|
| `APEX_AUTH_ROLES` | Stores all authorization roles |
| `APEX_AUTH_USERS` | User information and status |
| `APEX_AUTH_USER_ROLES` | Maps users to roles |
| `APEX_AUTH_OBJECTS` | Secureable objects (pages, regions, buttons, menus) |
| `APEX_AUTH_PERMISSIONS` | Available permission types |
| `APEX_AUTH_ROLE_PERMISSIONS` | Grants permissions to roles for objects |
| `APEX_AUTH_USER_PERMISSIONS` | User-specific permission overrides |
| `APEX_AUTH_AUDIT_LOG` | Audit trail of authorization checks |
| `APEX_AUTH_CONFIG` | System configuration parameters |

## 🎯 Key Functions

### Authorization Functions

- `is_authorized()` - Main authorization check
- `is_page_authorized()` - Page-level authorization
- `is_region_authorized()` - Region-level authorization
- `is_button_authorized()` - Button-level authorization
- `is_menu_authorized()` - Menu item authorization
- `has_role()` - Check if user has specific role
- `has_any_role()` - Check if user has any of specified roles
- `has_all_roles()` - Check if user has all specified roles

### Management Procedures

- `create_role()` / `update_role()` / `delete_role()`
- `create_user()` / `update_user()`
- `assign_role_to_user()` / `remove_role_from_user()`
- `register_object()` - Register APEX objects
- `grant_permission()` / `revoke_permission()`
- `grant_user_permission()` - User-specific overrides
- `clear_cache()` - Clear authorization cache

## ⚙️ Configuration Options

Configuration stored in `APEX_AUTH_CONFIG` table:

| Key | Default | Description |
|-----|---------|-------------|
| `ENABLE_AUDIT_LOG` | Y | Enable/disable audit logging |
| `DEFAULT_PERMISSION` | DENY | Default when no rule exists (DENY/ALLOW) |
| `CACHE_TIMEOUT_SECONDS` | 300 | Authorization cache timeout |
| `SUPERADMIN_ROLE` | SUPERADMIN | Role with full access |

Update configuration:

```sql
BEGIN
    apex_authorization_pkg.set_config('ENABLE_AUDIT_LOG', 'Y');
    apex_authorization_pkg.set_config('CACHE_TIMEOUT_SECONDS', '600');
END;
/
```

## 🔍 Monitoring and Audit

### View Authorization Audit Log

```sql
SELECT 
    username,
    object_code,
    object_type,
    permission_type,
    authorization_result,
    reason,
    audit_timestamp
FROM apex_auth_audit_log
WHERE audit_timestamp > SYSDATE - 1
ORDER BY audit_timestamp DESC;
```

### Check User Permissions

```sql
SELECT 
    u.username,
    r.role_code,
    o.object_code,
    o.object_type,
    p.permission_type,
    rp.is_granted
FROM apex_auth_users u
JOIN apex_auth_user_roles ur ON u.user_id = ur.user_id
JOIN apex_auth_roles r ON ur.role_id = r.role_id
JOIN apex_auth_role_permissions rp ON r.role_id = rp.role_id
JOIN apex_auth_objects o ON rp.object_id = o.object_id
JOIN apex_auth_permissions p ON rp.permission_id = p.permission_id
WHERE u.username = 'JOHN.DOE'
AND o.application_id = 100;
```

## 🚀 Performance Tips

1. **Use Cache**: Built-in caching reduces database calls
2. **Set Validation Frequency**: Use "Once per session" for authorization schemes when possible
3. **Index Maintenance**: Keep statistics updated with `DBMS_STATS.GATHER_SCHEMA_STATS`
4. **Clear Cache After Changes**: Call `clear_cache()` after permission updates
5. **Partition Audit Log**: Consider partitioning by date for large volumes

## 🛠️ Troubleshooting

### Authorization Always Fails

```sql
-- Check if user exists and is active
SELECT * FROM apex_auth_users WHERE UPPER(username) = 'JOHN.DOE';

-- Check user roles
SELECT r.* FROM apex_auth_roles r
JOIN apex_auth_user_roles ur ON r.role_id = ur.role_id
JOIN apex_auth_users u ON ur.user_id = u.user_id
WHERE UPPER(u.username) = 'JOHN.DOE';

-- Check object is registered
SELECT * FROM apex_auth_objects 
WHERE object_code = 'PAGE_10' AND application_id = 100;

-- Check permissions
SELECT * FROM apex_auth_role_permissions rp
JOIN apex_auth_roles r ON rp.role_id = r.role_id
JOIN apex_auth_objects o ON rp.object_id = o.object_id
WHERE o.object_code = 'PAGE_10';
```

### Clear Cache

```sql
BEGIN
    apex_authorization_pkg.clear_cache;
END;
/
```

## 📖 Documentation

For detailed implementation guide, see:
- **05_Implementation_Guide.txt** - Complete step-by-step instructions
- **04_Sample_Data_and_Tests.sql** - Working examples and test cases

## 🏗️ Architecture

The system follows Oracle best practices:
- **Exception Handling**: All procedures include proper exception handling
- **Autonomous Transactions**: Audit logging uses autonomous transactions
- **Temporal Validity**: Time-based access control with effective dates
- **Defensive Coding**: NULL checks and fallback logic throughout
- **Performance**: Optimized queries with proper indexing
- **Security**: Uppercase username normalization, validation checks

## 🤝 Contributing

This is an enterprise-grade authorization system. Suggested enhancements:
- Add hierarchy support for roles
- Implement approval workflows
- Add bulk operations for role assignments
- Create REST APIs for external integration
- Build APEX admin pages for management

## 📄 License

This code is provided as-is for Oracle APEX implementations.

## 👤 Support

Review the Implementation Guide (05_Implementation_Guide.txt) for:
- Detailed setup instructions
- Common use cases
- Performance tuning
- Troubleshooting guide

---

**Built with Oracle PL/SQL best practices for Oracle APEX 19c+**
