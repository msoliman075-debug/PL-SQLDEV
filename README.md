# Oracle EBS FND_PROFILE Database Structure

## Overview

This repository contains a complete implementation of an Oracle EBS-style profile management system, similar to the FND_PROFILE functionality in Oracle E-Business Suite. The system provides hierarchical profile option management with values that can be set at multiple levels (Site, Application, Responsibility, User, Server, Organization).

## Architecture

### Hierarchy Levels (Priority Order)

1. **User Level** (Highest Priority) - Individual user preferences
2. **Responsibility Level** - Role-based settings
3. **Application Level** - Application-specific defaults
4. **Organization Level** - Organization-specific settings
5. **Server Level** - Server-specific configurations
6. **Site Level** (Lowest Priority) - System-wide defaults

### Key Features

- **Hierarchical Value Resolution**: Values at higher priority levels override lower levels
- **Date Effectivity**: Profile options and values can be date-effective
- **User Preferences**: Users can change their own values when allowed
- **Read-Only Profiles**: System profiles that cannot be modified
- **Session Caching**: In-memory cache for performance optimization
- **Validation Support**: SQL validation for profile values
- **Comprehensive Auditing**: Full audit trail with who/when information

## Database Objects

### Tables

#### 1. FND_PROFILE_OPTIONS
Stores profile option definitions and metadata.

**Key Columns:**
- `profile_option_id`: Primary key
- `profile_option_name`: Internal name (unique, uppercase)
- `user_profile_option_name`: User-friendly display name
- `enabled_flag`: Enable/disable the profile option
- `user_changeable_flag`: Allow users to change their own value
- `user_visible_flag`: Show to users or hide (system use only)
- `read_only_flag`: Prevent any modifications
- `sql_validation`: Optional SQL query for value validation

#### 2. FND_PROFILE_OPTION_VALUES
Stores profile option values at different hierarchy levels.

**Key Columns:**
- `profile_option_value_id`: Primary key
- `profile_option_id`: Foreign key to FND_PROFILE_OPTIONS
- `level_id`: Hierarchy level (10001-10006)
- `level_value`: Specific ID at that level (e.g., User ID)
- `profile_option_value`: The actual stored value
- `enabled_flag`: Enable/disable this value

**Level IDs:**
- 10001 = Site
- 10002 = Application
- 10003 = Responsibility
- 10004 = User
- 10005 = Server
- 10006 = Organization

### Sequences

- `fnd_profile_options_s`: Generates profile_option_id
- `fnd_profile_option_values_s`: Generates profile_option_value_id

### Indexes

10 performance-optimized indexes for:
- Profile name lookups
- Hierarchy-level queries
- Date-effective queries
- Foreign key relationships
- Composite searches

### Package: FND_PROFILE

Complete API for profile management with the following procedures and functions:

#### Functions

**1. VALUE** - Primary function to retrieve profile values
```sql
FUNCTION value(
    p_profile_name      IN VARCHAR2,
    p_user_id           IN NUMBER DEFAULT NULL,
    p_responsibility_id IN NUMBER DEFAULT NULL,
    p_application_id    IN NUMBER DEFAULT NULL,
    p_org_id            IN NUMBER DEFAULT NULL,
    p_server_id         IN NUMBER DEFAULT NULL
) RETURN VARCHAR2;
```

**2. VALUE_SPECIFIC** - Get value at a specific level
```sql
FUNCTION value_specific(
    p_profile_name       IN VARCHAR2,
    p_level_id           IN NUMBER,
    p_level_value        IN NUMBER DEFAULT NULL,
    p_level_value_app_id IN NUMBER DEFAULT NULL
) RETURN VARCHAR2;
```

**3. DEFINED** - Check if profile option exists
```sql
FUNCTION defined(
    p_profile_name IN VARCHAR2
) RETURN BOOLEAN;
```

#### Procedures

**1. GET** - Procedure version of VALUE
```sql
PROCEDURE get(
    p_profile_name      IN  VARCHAR2,
    p_value             OUT VARCHAR2,
    p_user_id           IN  NUMBER DEFAULT NULL,
    p_responsibility_id IN  NUMBER DEFAULT NULL,
    p_application_id    IN  NUMBER DEFAULT NULL
);
```

**2. PUT** - Set value in session cache (in-memory only)
```sql
PROCEDURE put(
    p_profile_name IN VARCHAR2,
    p_value        IN VARCHAR2
);
```

**3. SAVE** - Persist value to database
```sql
PROCEDURE save(
    p_profile_name       IN VARCHAR2,
    p_value              IN VARCHAR2,
    p_level_id           IN NUMBER,
    p_level_value        IN NUMBER DEFAULT NULL,
    p_level_value_app_id IN NUMBER DEFAULT NULL,
    p_user_id            IN NUMBER DEFAULT 0
);
```

**4. INITIALIZE** - Load profiles into session cache
```sql
PROCEDURE initialize(
    p_user_id           IN NUMBER,
    p_responsibility_id IN NUMBER DEFAULT NULL,
    p_application_id    IN NUMBER DEFAULT NULL
);
```

**5. GET_ALL** - Return all profile values for context
```sql
PROCEDURE get_all(
    p_user_id           IN  NUMBER,
    p_responsibility_id IN  NUMBER DEFAULT NULL,
    p_application_id    IN  NUMBER DEFAULT NULL,
    p_cursor            OUT SYS_REFCURSOR
);
```

### Views

1. **FND_PROFILE_OPTIONS_VL** - User-friendly view of profile options with status
2. **FND_PROFILE_OPTION_VALUES_VL** - Profile values with level names
3. **FND_PROFILE_HIERARCHY_V** - Shows value hierarchy with priorities
4. **FND_PROFILE_USER_VALUES_V** - User-specific profile values
5. **FND_PROFILE_AUDIT_V** - Audit trail of profile changes
6. **FND_PROFILE_SUMMARY_V** - Summary statistics per profile option

## Installation

### Prerequisites

- Oracle Database 19c or higher
- Appropriate tablespace for data (default: USERS)
- CREATE TABLE, CREATE SEQUENCE, CREATE INDEX privileges
- CREATE PROCEDURE privilege

### Installation Steps

1. **Connect to your Oracle database:**
   ```sql
   sqlplus username/password@database
   ```

2. **Run the master installation script:**
   ```sql
   @00_install_master.sql
   ```

   This will automatically execute all scripts in the correct order:
   - Create tables
   - Create sequences
   - Create indexes
   - Create package specification
   - Create package body
   - Create views
   - Load sample data
   - Run tests

### Manual Installation (Alternative)

If you prefer to install components individually:

```sql
@01_fnd_profile_options.sql
@02_fnd_profile_option_values.sql
@03_sequences.sql
@04_indexes.sql
@05_fnd_profile_pkg_spec.sql
@06_fnd_profile_pkg_body.sql
@07_views.sql
@08_sample_data_and_tests.sql
```

## Usage Examples

### Example 1: Retrieve a Profile Value

```sql
-- Get profile value for current user
SELECT fnd_profile.value('DEFAULT_DATE_FORMAT') FROM dual;

-- Get profile value for specific user
SELECT fnd_profile.value(
    p_profile_name => 'ROWS_PER_PAGE',
    p_user_id => 1001
) FROM dual;

-- Get profile value with full context
SELECT fnd_profile.value(
    p_profile_name => 'DEFAULT_LANGUAGE',
    p_user_id => 1001,
    p_responsibility_id => 50001,
    p_application_id => 101
) FROM dual;
```

### Example 2: Save a Profile Value

```sql
BEGIN
    -- Save user preference
    fnd_profile.save(
        p_profile_name => 'DEFAULT_DATE_FORMAT',
        p_value => 'DD/MM/YYYY',
        p_level_id => fnd_profile.g_level_user,
        p_level_value => 1001,
        p_user_id => 1001
    );
    
    -- Save site-level default
    fnd_profile.save(
        p_profile_name => 'SESSION_TIMEOUT',
        p_value => '60',
        p_level_id => fnd_profile.g_level_site,
        p_user_id => 0  -- System user
    );
END;
/
```

### Example 3: Use Session Cache

```sql
DECLARE
    l_value VARCHAR2(2000);
BEGIN
    -- Set value in session (does not persist)
    fnd_profile.put('ROWS_PER_PAGE', '50');
    
    -- Retrieve from session cache
    l_value := fnd_profile.value('ROWS_PER_PAGE');
    
    DBMS_OUTPUT.PUT_LINE('Session value: ' || l_value);
END;
/
```

### Example 4: Initialize Session Cache

```sql
BEGIN
    -- Load all relevant profiles for user 1001
    fnd_profile.initialize(
        p_user_id => 1001,
        p_responsibility_id => 50001,
        p_application_id => 101
    );
END;
/
```

### Example 5: Query All User Profiles

```sql
DECLARE
    l_cursor SYS_REFCURSOR;
    l_name VARCHAR2(240);
    l_value VARCHAR2(2000);
    l_level VARCHAR2(100);
BEGIN
    fnd_profile.get_all(
        p_user_id => 1001,
        p_cursor => l_cursor
    );
    
    LOOP
        FETCH l_cursor INTO l_name, l_value, l_level;
        EXIT WHEN l_cursor%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE(
            l_name || ' = ' || l_value || ' (' || l_level || ')'
        );
    END LOOP;
    
    CLOSE l_cursor;
END;
/
```

### Example 6: Query Using Views

```sql
-- View all active profile options
SELECT profile_option_name,
       user_profile_option_name,
       status,
       user_changeable_flag
FROM   fnd_profile_options_vl
WHERE  status = 'Active'
ORDER BY user_profile_option_name;

-- View profile hierarchy for a specific profile
SELECT profile_option_name,
       level_name,
       priority,
       level_value,
       profile_option_value
FROM   fnd_profile_hierarchy_v
WHERE  profile_option_name = 'DEFAULT_DATE_FORMAT'
ORDER BY priority;

-- View summary statistics
SELECT profile_option_name,
       total_values,
       site_values,
       user_values
FROM   fnd_profile_summary_v
ORDER BY total_values DESC;
```

## Performance Considerations

### Execution Impact

- **VALUE function**: Single hierarchical query with index usage
- **VALUE_SPECIFIC function**: Direct index lookup on composite key
- **DEFINED function**: Single index lookup
- **SAVE procedure**: MERGE statement (INSERT or UPDATE)
- **INITIALIZE procedure**: Bulk query to populate cache

### Optimization Tips

1. **Use Session Cache**: Call `INITIALIZE` at login to load frequently-used profiles
2. **Use VALUE_SPECIFIC**: When you know the exact level, use `VALUE_SPECIFIC` for faster lookup
3. **Index Usage**: All queries are optimized to use the composite indexes
4. **Minimize Context**: Only pass necessary context parameters to reduce search space
5. **Date Effectivity**: Archive expired profile values to reduce table size

## Best Practices

### 1. Profile Naming Convention
- Use uppercase for internal names
- Use descriptive, consistent naming (e.g., `DEFAULT_*`, `MAX_*`, `ENABLE_*`)
- Keep names under 30 characters for compatibility

### 2. Hierarchy Usage
- **Site**: System-wide defaults that apply to everyone
- **Application**: Application-specific overrides
- **Responsibility**: Role-based configurations
- **User**: Individual user preferences
- **Org**: Multi-org specific settings
- **Server**: Server-specific configurations (load balancing, etc.)

### 3. Date Effectivity
- Always set `start_date_active` to control when profiles become active
- Use `end_date_active` to deprecate old profiles gracefully
- Leave `end_date_active` NULL for perpetual profiles

### 4. User Changeability
- Set `user_changeable_flag = 'Y'` only for true user preferences
- System configurations should have `user_changeable_flag = 'N'`
- Use `user_visible_flag = 'N'` for internal system profiles

### 5. Read-Only Profiles
- Use `read_only_flag = 'Y'` for calculated or externally managed values
- Prevents accidental modifications through the API

## Sample Data

The installation includes 6 sample profile options:

1. **DEFAULT_DATE_FORMAT** - Date display format
2. **ROWS_PER_PAGE** - Pagination setting
3. **DEFAULT_LANGUAGE** - UI language preference
4. **SESSION_TIMEOUT** - Idle session timeout
5. **DEBUG_MODE** - Debug logging (system only)
6. **DEFAULT_CURRENCY** - Currency code

Sample values are provided at Site, Application, and User levels to demonstrate hierarchy.

## Testing

The installation script includes 8 comprehensive tests:

1. View all profile options
2. View profile hierarchy
3. View summary statistics
4. Test VALUE function for User 1001
5. Test VALUE function for User 1002
6. Test SAVE procedure
7. Test PUT (session cache)
8. Test GET_ALL procedure

Run tests manually:
```sql
SET SERVEROUTPUT ON SIZE UNLIMITED
@08_sample_data_and_tests.sql
```

## Troubleshooting

### Issue: Profile value not found
- Check if profile option is enabled: `SELECT * FROM fnd_profile_options_vl WHERE profile_option_name = 'YOUR_PROFILE'`
- Verify date effectivity: Check `start_date_active` and `end_date_active`
- Check if value exists at any level: `SELECT * FROM fnd_profile_hierarchy_v WHERE profile_option_name = 'YOUR_PROFILE'`

### Issue: Wrong value returned
- Review hierarchy: Use `fnd_profile_hierarchy_v` to see all values and priorities
- Check context parameters: Ensure you're passing correct `user_id`, `responsibility_id`, etc.
- Verify enabled flags: Both option and value must be enabled

### Issue: Cannot save value
- Check if profile is read-only: `SELECT read_only_flag FROM fnd_profile_options WHERE profile_option_name = 'YOUR_PROFILE'`
- Verify profile exists and is active
- Check privileges on the tables

## Extension Points

### Adding New Profile Options

```sql
-- 1. Insert the profile option definition
INSERT INTO fnd_profile_options (
    profile_option_id,
    profile_option_name,
    user_profile_option_name,
    description,
    enabled_flag,
    start_date_active,
    user_changeable_flag,
    user_visible_flag,
    read_only_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_options_s.NEXTVAL,
    'MY_CUSTOM_PROFILE',
    'My Custom Profile',
    'Description of what this profile controls',
    'Y',
    SYSDATE,
    'Y',
    'Y',
    'N',
    SYSDATE,
    0,
    SYSDATE,
    0
);

-- 2. Set site-level default value
INSERT INTO fnd_profile_option_values (
    profile_option_value_id,
    profile_option_id,
    level_id,
    profile_option_value,
    enabled_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by
) VALUES (
    fnd_profile_option_values_s.NEXTVAL,
    (SELECT profile_option_id FROM fnd_profile_options 
     WHERE profile_option_name = 'MY_CUSTOM_PROFILE'),
    10001,  -- Site level
    'DEFAULT_VALUE',
    'Y',
    SYSDATE,
    0,
    SYSDATE,
    0
);

COMMIT;
```

### Adding Custom Views

Create additional views for your specific reporting needs:

```sql
CREATE OR REPLACE VIEW my_custom_profile_report AS
SELECT po.profile_option_name,
       pov.profile_option_value,
       pov.level_id,
       -- Add your custom logic here
FROM   fnd_profile_options po,
       fnd_profile_option_values pov
WHERE  po.profile_option_id = pov.profile_option_id
-- Add your custom filters
;
```

## API Reference

### Constants

```sql
fnd_profile.g_level_site            = 10001
fnd_profile.g_level_application     = 10002
fnd_profile.g_level_responsibility  = 10003
fnd_profile.g_level_user            = 10004
fnd_profile.g_level_server          = 10005
fnd_profile.g_level_org             = 10006
```

### Exceptions

```sql
fnd_profile.e_profile_not_found     (-20001)
fnd_profile.e_invalid_level         (-20002)
fnd_profile.e_invalid_value         (-20003)
fnd_profile.e_read_only_profile     (-20004)
```

## License

This implementation is provided as-is for educational and development purposes. The design is inspired by Oracle E-Business Suite's FND_PROFILE system but is an independent implementation.

## Support

For issues or questions:
1. Review the troubleshooting section
2. Check the test scripts for usage examples
3. Query the views for current state analysis

## Version History

- **1.0** - Initial implementation
  - Core tables and structures
  - FND_PROFILE package with all major APIs
  - 6 reporting views
  - Comprehensive sample data and tests
  - Full documentation

## Contributors

Database structure designed to mirror Oracle EBS FND_PROFILE functionality while maintaining Oracle 19c+ best practices.
