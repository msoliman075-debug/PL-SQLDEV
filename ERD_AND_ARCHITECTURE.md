# Entity Relationship Diagram (ERD)

## Database Schema Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     FND_PROFILE_OPTIONS                              │
├─────────────────────────────────────────────────────────────────────┤
│ PK  profile_option_id           NUMBER                               │
│ UK  profile_option_name         VARCHAR2(240)                        │
│     application_id              NUMBER                               │
│     user_profile_option_name    VARCHAR2(240)                        │
│     description                 VARCHAR2(2000)                       │
│     enabled_flag                VARCHAR2(1)  [Y/N]                   │
│     start_date_active           DATE                                 │
│     end_date_active             DATE                                 │
│     user_changeable_flag        VARCHAR2(1)  [Y/N]                   │
│     user_visible_flag           VARCHAR2(1)  [Y/N]                   │
│     read_only_flag              VARCHAR2(1)  [Y/N]                   │
│     sql_validation              VARCHAR2(2000)                       │
│     creation_date               DATE                                 │
│     created_by                  NUMBER                               │
│     last_update_date            DATE                                 │
│     last_updated_by             NUMBER                               │
│     last_update_login           NUMBER                               │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ 1
                                    │
                                    │ 
                                    │ *
┌─────────────────────────────────────────────────────────────────────┐
│                  FND_PROFILE_OPTION_VALUES                           │
├─────────────────────────────────────────────────────────────────────┤
│ PK  profile_option_value_id     NUMBER                               │
│ FK  profile_option_id           NUMBER                               │
│     application_id              NUMBER                               │
│     level_id                    NUMBER  [10001-10006]                │
│     level_value                 NUMBER                               │
│     level_value_application_id  NUMBER                               │
│     profile_option_value        VARCHAR2(2000)                       │
│     enabled_flag                VARCHAR2(1)  [Y/N]                   │
│     start_date_active           DATE                                 │
│     end_date_active             DATE                                 │
│     creation_date               DATE                                 │
│     created_by                  NUMBER                               │
│     last_update_date            DATE                                 │
│     last_updated_by             NUMBER                               │
│     last_update_login           NUMBER                               │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                           SEQUENCES                                  │
├─────────────────────────────────────────────────────────────────────┤
│ fnd_profile_options_s                                                │
│ fnd_profile_option_values_s                                          │
└─────────────────────────────────────────────────────────────────────┘
```

## Relationship Details

### FND_PROFILE_OPTIONS (Parent Table)
- **Purpose**: Stores profile option definitions
- **Primary Key**: `profile_option_id`
- **Unique Key**: `profile_option_name`
- **Cardinality**: One profile option can have many values (1:N)

### FND_PROFILE_OPTION_VALUES (Child Table)
- **Purpose**: Stores profile values at different hierarchy levels
- **Primary Key**: `profile_option_value_id`
- **Foreign Key**: `profile_option_id` → `FND_PROFILE_OPTIONS.profile_option_id`
- **Unique Constraint**: Combination of (profile_option_id, level_id, level_value, level_value_application_id, application_id)

## Level Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                     HIERARCHY LEVELS                             │
│                   (Priority: High to Low)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Priority 1: USER LEVEL (10004)                                 │
│  ↑          Individual user preferences                         │
│  │          level_value = User ID                               │
│  │                                                               │
│  │  Priority 2: RESPONSIBILITY LEVEL (10003)                    │
│  │          Role-based configuration                            │
│  │          level_value = Responsibility ID                     │
│  │          level_value_application_id = Application ID         │
│  │                                                               │
│  │  Priority 3: APPLICATION LEVEL (10002)                       │
│  │          Application-specific defaults                       │
│  │          level_value = Application ID                        │
│  │                                                               │
│  │  Priority 4: ORGANIZATION LEVEL (10006)                      │
│  │          Organization-specific settings                      │
│  │          level_value = Organization ID                       │
│  │                                                               │
│  │  Priority 5: SERVER LEVEL (10005)                            │
│  │          Server-specific configuration                       │
│  │          level_value = Server ID                             │
│  │                                                               │
│  │  Priority 6: SITE LEVEL (10001)                              │
│  ↓          System-wide defaults (lowest priority)              │
│             level_value = NULL                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Value Resolution Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                  PROFILE VALUE RESOLUTION                         │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  fnd_profile.value('PROFILE_NAME', user_id, resp_id, app_id)     │
│                           │                                       │
│                           ↓                                       │
│              ┌─────────────────────────┐                          │
│              │  Check Session Cache   │                          │
│              └────────────┬────────────┘                          │
│                           │                                       │
│                   Found? ─┼─ Yes → Return Value                  │
│                           │                                       │
│                           No                                      │
│                           ↓                                       │
│              ┌─────────────────────────┐                          │
│              │   Query Database        │                          │
│              │   with Hierarchy        │                          │
│              └────────────┬────────────┘                          │
│                           │                                       │
│                           ↓                                       │
│       ┌──────────────────────────────────────┐                   │
│       │  Search in Priority Order:           │                   │
│       │  1. User Level (user_id)             │                   │
│       │  2. Responsibility Level (resp_id)   │                   │
│       │  3. Application Level (app_id)       │                   │
│       │  4. Organization Level (org_id)      │                   │
│       │  5. Server Level (server_id)         │                   │
│       │  6. Site Level (always checked)      │                   │
│       └──────────────────┬───────────────────┘                   │
│                          │                                        │
│                          ↓                                        │
│              ┌─────────────────────────┐                          │
│              │  Return First Match     │                          │
│              │  or NULL if not found   │                          │
│              └─────────────────────────┘                          │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Index Strategy

### Performance-Critical Indexes

1. **fnd_profile_options_n1** (profile_option_name)
   - Used for: Profile lookup by name
   - Query pattern: `WHERE profile_option_name = 'NAME'`

2. **fnd_profile_options_n2** (enabled_flag, start_date_active, end_date_active)
   - Used for: Active profile queries
   - Query pattern: `WHERE enabled_flag = 'Y' AND date range check`

3. **fnd_profile_opt_values_n3** (profile_option_id, level_id, level_value, enabled_flag)
   - Used for: Main VALUE function hierarchy query
   - Query pattern: `WHERE profile_option_id = X AND level_id = Y AND level_value = Z`
   - **Most Important Index** - optimizes core functionality

4. **fnd_profile_opt_values_n2** (level_id, level_value)
   - Used for: Level-specific queries
   - Query pattern: `WHERE level_id = 10004 AND level_value = user_id`

## Data Flow Examples

### Example 1: User Login - Initialize Session

```
User Logs In (User ID: 1001, Resp ID: 50001, App ID: 101)
    ↓
fnd_profile.initialize(1001, 50001, 101)
    ↓
Query all relevant profiles for this context
    ↓
Populate session cache (PL/SQL collection)
    ↓
All subsequent fnd_profile.value() calls use cache
```

### Example 2: Save User Preference

```
User Changes Preference: ROWS_PER_PAGE = 100
    ↓
fnd_profile.save(
    p_profile_name => 'ROWS_PER_PAGE',
    p_value => '100',
    p_level_id => 10004,  -- User level
    p_level_value => 1001
)
    ↓
MERGE INTO fnd_profile_option_values
    ↓
Update existing row OR insert new row
    ↓
Update session cache
    ↓
COMMIT
```

### Example 3: Retrieve Profile Value

```
Application needs date format for user 1001
    ↓
fnd_profile.value('DEFAULT_DATE_FORMAT', 1001)
    ↓
Check session cache → Not found
    ↓
Query database with hierarchy:
    ├─ User level (1001) → Found: 'MM/DD/YYYY'
    └─ Return 'MM/DD/YYYY' (don't check lower levels)
    ↓
Return value to application
```

## Constraints Summary

### Primary Keys
- `FND_PROFILE_OPTIONS.profile_option_id`
- `FND_PROFILE_OPTION_VALUES.profile_option_value_id`

### Unique Constraints
- `FND_PROFILE_OPTIONS.profile_option_name` (must be unique)
- `FND_PROFILE_OPTION_VALUES.(profile_option_id, level_id, level_value, level_value_application_id, application_id)`

### Foreign Keys
- `FND_PROFILE_OPTION_VALUES.profile_option_id` → `FND_PROFILE_OPTIONS.profile_option_id`

### Check Constraints
- `enabled_flag IN ('Y', 'N')`
- `user_changeable_flag IN ('Y', 'N')`
- `user_visible_flag IN ('Y', 'N')`
- `read_only_flag IN ('Y', 'N')`
- `level_id BETWEEN 10001 AND 10006`
- `end_date_active >= start_date_active`

## Views Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       BASE TABLES                            │
│  ┌──────────────────────┐  ┌──────────────────────┐         │
│  │ FND_PROFILE_OPTIONS  │  │ FND_PROFILE_OPTION_  │         │
│  │                      │  │     VALUES           │         │
│  └──────────┬───────────┘  └───────────┬──────────┘         │
│             │                          │                     │
└─────────────┼──────────────────────────┼─────────────────────┘
              │                          │
              └────────────┬─────────────┘
                          │
          ┌───────────────┴───────────────┐
          │                               │
┌─────────▼──────────┐         ┌──────────▼─────────┐
│ FND_PROFILE_       │         │ FND_PROFILE_       │
│ OPTIONS_VL         │         │ OPTION_VALUES_VL   │
│ (with status)      │         │ (with level names) │
└────────────────────┘         └────────────────────┘
          │                               │
          └───────────────┬───────────────┘
                          │
          ┌───────────────┴──────────────────────┐
          │                                      │
┌─────────▼──────────┐              ┌────────────▼──────────┐
│ FND_PROFILE_       │              │ FND_PROFILE_          │
│ HIERARCHY_V        │              │ SUMMARY_V             │
│ (shows priority)   │              │ (statistics)          │
└────────────────────┘              └───────────────────────┘
          │
┌─────────▼──────────┐              ┌───────────────────────┐
│ FND_PROFILE_       │              │ FND_PROFILE_          │
│ USER_VALUES_V      │              │ AUDIT_V               │
│ (user-level only)  │              │ (change tracking)     │
└────────────────────┘              └───────────────────────┘
```

## Storage Considerations

### Table Size Estimates (Approximate)

**FND_PROFILE_OPTIONS:**
- Small table (typically 100-1000 rows)
- ~1 KB per row
- Estimate: 1-10 MB

**FND_PROFILE_OPTION_VALUES:**
- Large table (can grow to millions of rows)
- Calculation: (# profiles) × (# users + # responsibilities + # applications + sites)
- Example: 500 profiles × (10,000 users + 100 responsibilities + 10 apps + 1 site) ≈ 5 million rows
- ~1 KB per row
- Estimate: 5-50 GB (depending on user count)

### Recommended Tablespace Settings

```sql
-- For production with many users:
ALTER TABLE fnd_profile_option_values 
    MOVE TABLESPACE large_data_ts;

-- Enable compression for large tables:
ALTER TABLE fnd_profile_option_values 
    MOVE COMPRESS FOR OLTP;

-- Partition by level_id for very large installations:
ALTER TABLE fnd_profile_option_values
    PARTITION BY LIST (level_id) (
        PARTITION p_site VALUES (10001),
        PARTITION p_app VALUES (10002),
        PARTITION p_resp VALUES (10003),
        PARTITION p_user VALUES (10004),
        PARTITION p_server VALUES (10005),
        PARTITION p_org VALUES (10006)
    );
```

## Package Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    FND_PROFILE PACKAGE                      │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────┐           │
│  │         PACKAGE SPECIFICATION                │           │
│  │  (Public API - visible to all users)        │           │
│  ├─────────────────────────────────────────────┤           │
│  │  • Constants (g_level_*)                    │           │
│  │  • Exceptions                                │           │
│  │  • Functions: VALUE, VALUE_SPECIFIC, DEFINED│           │
│  │  • Procedures: GET, PUT, SAVE, INITIALIZE   │           │
│  │               GET_ALL                        │           │
│  └─────────────────────────────────────────────┘           │
│                      │                                      │
│  ┌─────────────────────────────────────────────┐           │
│  │         PACKAGE BODY                         │           │
│  │  (Private implementation)                    │           │
│  ├─────────────────────────────────────────────┤           │
│  │  • Private Variables:                        │           │
│  │    - g_profile_cache (PL/SQL collection)    │           │
│  │    - g_cache_initialized (boolean)          │           │
│  │                                              │           │
│  │  • Private Functions:                        │           │
│  │    - get_profile_option_id()                │           │
│  │    - validate_level()                        │           │
│  │                                              │           │
│  │  • Public Function Implementations           │           │
│  └─────────────────────────────────────────────┘           │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

## Security Model

### Access Control
- Tables: Typically restricted to profile admin role
- Package: EXECUTE privilege granted to all application users
- Views: SELECT privilege based on role requirements

### Recommended Grants

```sql
-- Admin role (full access)
GRANT ALL ON fnd_profile_options TO profile_admin_role;
GRANT ALL ON fnd_profile_option_values TO profile_admin_role;

-- User role (read/execute only)
GRANT SELECT ON fnd_profile_options_vl TO app_user_role;
GRANT SELECT ON fnd_profile_hierarchy_v TO app_user_role;
GRANT EXECUTE ON fnd_profile TO app_user_role;

-- Report role (read views only)
GRANT SELECT ON fnd_profile_options_vl TO report_user_role;
GRANT SELECT ON fnd_profile_summary_v TO report_user_role;
GRANT SELECT ON fnd_profile_audit_v TO report_user_role;
```
