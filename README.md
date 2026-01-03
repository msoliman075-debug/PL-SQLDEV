# Dynamic Authorization Scheme for Oracle APEX

This project provides a robust, flexible, and database-driven authorization scheme for Oracle APEX applications. It allows you to control access to Pages, Regions, Buttons, and Menus dynamically by assigning Permissions to Roles, and Roles to Users.

## 1. Installation

### Step 1: Create Database Objects
Run the `ddl_tables.sql` script in your application schema (e.g., via SQL Workshop > SQL Scripts).

```sql
@ddl_tables.sql
```

### Step 2: Create PL/SQL Package
Run the `pkg_auth.sql` script to compile the logic.

```sql
@pkg_auth.sql
```

## 2. Configuration Data (Examples)

You need to populate the tables with your security model.

```sql
-- 1. Create Roles
INSERT INTO app_roles (role_key, role_name, description) 
VALUES ('ADMIN', 'Administrator', 'Full system access');

INSERT INTO app_roles (role_key, role_name, description) 
VALUES ('USER', 'Standard User', 'Basic access');

-- 2. Define Permissions (Granular)
-- Convention: OBJECT_TYPE:ID:ACTION
INSERT INTO app_permissions (permission_code, description) VALUES ('PAGE:1:VIEW', 'View Dashboard');
INSERT INTO app_permissions (permission_code, description) VALUES ('PAGE:2:EDIT', 'Edit Employee Data');
INSERT INTO app_permissions (permission_code, description) VALUES ('BTN:DELETE:EXECUTE', 'Click Delete Button');
INSERT INTO app_permissions (permission_code, description) VALUES ('MENU:ADMIN:VIEW', 'See Admin Menu Item');

-- 3. Assign Permissions to Roles
-- Give ADMIN everything
INSERT INTO app_role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM app_roles r, app_permissions p 
WHERE r.role_key = 'ADMIN';

-- Give USER only View Dashboard
INSERT INTO app_role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM app_roles r, app_permissions p 
WHERE r.role_key = 'USER' AND p.permission_code = 'PAGE:1:VIEW';

-- 4. Assign Roles to Users
-- Replace 'JDOE' with your actual APEX username
BEGIN
    pkg_auth.add_user_role('JDOE', 'ADMIN');
END;
/
```

## 3. Integration with APEX

You will create **Authorization Schemes** in APEX Shared Components. You can create a Generic one or specific ones.

### Option A: Generic "Check Permission" Scheme (Most Flexible)
If you want to check specific strings in specific places.

1.  Go to **Shared Components > Security > Authorization Schemes**.
2.  Click **Create**.
3.  **Name**: `AUTH_CHECK_PERMISSION` (This assumes you pass a value, but APEX schemes are boolean checks usually tied to the component).
    
    *Actually, APEX Authorization Schemes don't accept parameters easily.* 
    
    **Better Approach:** Create specific schemes for specific functional areas, or use the "PL/SQL Expression" on the component level directly (Conditions), BUT for true "Authorization Schemes":

    Create schemes for your Permissions:
    
    *   **Name**: `PERM_PAGE_1_VIEW`
    *   **Scheme Type**: PL/SQL Function Returning Boolean
    *   **PL/SQL Function Body**:
        ```plsql
        RETURN pkg_auth.has_permission('PAGE:1:VIEW');
        ```
    *   **Validate Authorization Scheme**: Once per page view (or session, depending on need).

### Option B: Dynamic component control
For every component (Page, Region, Button), scroll to the **Security** section.
*   **Authorization Scheme**: Select `PERM_PAGE_1_VIEW`.

### Option C: Role-Based Schemes (Simpler)
    *   **Name**: `ROLE_IS_ADMIN`
    *   **Code**: `RETURN pkg_auth.has_role('ADMIN');`

## 4. Usage in Menus (Lists)
1.  Go to Shared Components > Lists (Navigation Menu).
2.  Edit a List Entry.
3.  Set **Authorization Scheme** to your created scheme (e.g., `ROLE_IS_ADMIN` or `PERM_MENU_ADMIN`).

## 5. Administration UI
To manage this at runtime, build an APEX Page with Interactive Grids on:
1.  `APP_ROLES`
2.  `APP_PERMISSIONS`
3.  `APP_ROLE_PERMISSIONS`
4.  `APP_USER_ROLES`

This gives your "End User" (or Admin User) the flexibility to drag-and-drop permissions without deploying code.
