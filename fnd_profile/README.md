# FND_PROFILE - Oracle Profile Options Management

A database structure similar to Oracle E-Business Suite (EBS) FND_PROFILE functionality for managing configuration values at different hierarchy levels.

## Overview

Profile options are configurable preferences that affect application behavior. They can be set at different levels with a defined hierarchy:

```
USER (Highest Priority)
  ↓
RESPONSIBILITY
  ↓
APPLICATION
  ↓
SITE (Lowest Priority)
```

When retrieving a profile value, the system searches from the highest level (USER) down to the lowest (SITE), returning the first value found.

## Features

- **Hierarchy-based value resolution** - Automatic resolution from User → Responsibility → Application → Site
- **In-memory caching** - Performance optimization with session-level cache
- **Audit trail** - Complete history of all profile value changes
- **Flexible API** - Functions and procedures for different use cases
- **Level-based permissions** - Control which levels are enabled and updateable

## Installation

Execute the SQL files in order:

```sql
@01_tables.sql      -- Create tables, sequences, and base data
@02_package_spec.sql -- Create package specification
@03_package_body.sql -- Create package body
@04_views.sql       -- Create views
@05_triggers.sql    -- Create triggers
@06_sample_data.sql -- Load sample data (optional)
@07_examples.sql    -- Run usage examples (optional)
```

## Database Objects

### Tables

| Table | Description |
|-------|-------------|
| `FND_PROFILE_OPTIONS` | Profile option definitions |
| `FND_PROFILE_OPTION_VALUES` | Profile values at each hierarchy level |
| `FND_PROFILE_OPTION_VALUES_H` | Audit history of value changes |
| `FND_PROFILE_LEVELS` | Hierarchy level definitions |
| `FND_APPLICATION` | Application definitions |
| `FND_RESPONSIBILITY` | Responsibility definitions |
| `FND_USER` | User definitions |
| `FND_USER_RESP_GROUPS` | User-to-responsibility assignments |

### Views

| View | Description |
|------|-------------|
| `FND_PROFILE_OPTIONS_VL` | Profile options with application info |
| `FND_PROFILE_OPTION_VALUES_V` | Profile values with descriptive info |
| `FND_PROFILE_VALUES_BY_USER_V` | Effective values for each user |
| `FND_PROFILE_SITE_VALUES_V` | Site-level values only |
| `FND_PROFILE_USER_VALUES_V` | User-level values |
| `FND_PROFILE_CHANGE_HISTORY_V` | Audit trail of changes |
| `FND_PROFILE_SUMMARY_V` | Summary with value counts |

### Package: FND_PROFILE

The main API package for profile operations.

## API Reference

### Constants

```sql
fnd_profile.SITE_LEVEL  -- 10001
fnd_profile.APPL_LEVEL  -- 10002
fnd_profile.RESP_LEVEL  -- 10003
fnd_profile.USER_LEVEL  -- 10004
```

### Session Initialization

```sql
-- Initialize session context
fnd_profile.initialize(
    p_user_id        => 100,
    p_resp_id        => 1001,
    p_resp_appl_id   => 200,
    p_application_id => 200
);
```

### Getting Values

```sql
-- Procedure version
DECLARE
    v_value VARCHAR2(240);
BEGIN
    fnd_profile.get('PROFILE_NAME', v_value);
END;

-- Function version (usable in SQL)
SELECT fnd_profile.value('PROFILE_NAME') FROM DUAL;

-- Get at specific level
v_value := fnd_profile.get_specific(
    p_name        => 'PROFILE_NAME',
    p_level_id    => fnd_profile.USER_LEVEL,
    p_level_value => 100  -- user_id
);

-- Get with specific context
v_value := fnd_profile.value_specific(
    p_name           => 'PROFILE_NAME',
    p_user_id        => 100,
    p_resp_id        => 1001,
    p_resp_appl_id   => 200,
    p_application_id => 200
);
```

### Setting Values

```sql
-- Save to database
v_result := fnd_profile.save(
    p_name       => 'PROFILE_NAME',
    p_value      => 'NEW_VALUE',
    p_level_name => 'USER',    -- 'SITE', 'APPLICATION', 'RESPONSIBILITY', 'USER'
    p_level_value => '100'      -- user_id, resp_id, app_id, or NULL for site
);

-- Put in cache only (not persisted)
fnd_profile.put('PROFILE_NAME', 'TEMP_VALUE');
```

### Deleting Values

```sql
v_result := fnd_profile.delete_value(
    p_name        => 'PROFILE_NAME',
    p_level_name  => 'USER',
    p_level_value => '100'
);
```

### Utility Functions

```sql
-- Check if profile has a value
IF fnd_profile.defined('PROFILE_NAME') THEN ...

-- Check if level is enabled
IF fnd_profile.is_enabled('PROFILE_NAME', 'USER') THEN ...

-- Check if updates allowed at level
IF fnd_profile.is_update_allowed('PROFILE_NAME', 'USER') THEN ...

-- Get all values at all levels
fnd_profile.get_all_values('PROFILE_NAME', v_values, v_count);

-- Clear session cache
fnd_profile.clear_cache;
```

## Profile Option Configuration

Each profile option has flags controlling behavior at each level:

| Flag | Description |
|------|-------------|
| `site_enabled_flag` | Allow values at site level |
| `site_update_allowed_flag` | Allow updates at site level |
| `app_enabled_flag` | Allow values at application level |
| `app_update_allowed_flag` | Allow updates at application level |
| `resp_enabled_flag` | Allow values at responsibility level |
| `resp_update_allowed_flag` | Allow updates at responsibility level |
| `user_enabled_flag` | Allow values at user level |
| `user_update_allowed_flag` | Allow updates at user level |
| `user_changeable_flag` | Allow users to change their own value |
| `user_visible_flag` | Show profile to users |

## Hierarchy Types

| Type | Description |
|------|-------------|
| `SECURITY` | Standard User → Resp → App → Site hierarchy |
| `SERVER` | Server-based hierarchy (for server-specific configs) |
| `ORG` | Organization hierarchy |
| `SERVRESP` | Server + Responsibility combination |

## Example Usage

### Basic Usage

```sql
-- Initialize session
BEGIN
    fnd_profile.initialize(p_user_id => 100);
END;
/

-- Get a profile value
SELECT fnd_profile.value('FND_LANGUAGE') FROM DUAL;

-- Set a user-level value
DECLARE
    v_result BOOLEAN;
BEGIN
    v_result := fnd_profile.save(
        p_name       => 'FND_ROWS_PER_PAGE',
        p_value      => '50',
        p_level_name => 'USER',
        p_level_value => '100'
    );
    COMMIT;
END;
/
```

### Using in Applications

```sql
-- Conditional logic based on profile
BEGIN
    IF fnd_profile.value('FND_DEBUG_MODE') = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('Debug message...');
    END IF;
END;
/

-- Use in queries for pagination
SELECT *
FROM my_table
WHERE ROWNUM <= NVL(TO_NUMBER(fnd_profile.value('FND_ROWS_PER_PAGE')), 25);
```

## Audit History

All profile value changes are automatically logged to `FND_PROFILE_OPTION_VALUES_H`:

```sql
SELECT *
FROM fnd_profile_change_history_v
WHERE profile_option_name = 'FND_LANGUAGE'
ORDER BY change_date DESC;
```

## Best Practices

1. **Always initialize session** - Call `fnd_profile.initialize()` at session start
2. **Use appropriate level** - Set values at the most specific level needed
3. **Check permissions** - Use `is_enabled()` and `is_update_allowed()` before saves
4. **Use cache for temporary values** - Use `put()` for session-only values
5. **Commit after saves** - Profile saves require explicit COMMIT

## Differences from Oracle EBS

This implementation is similar to but not identical to Oracle EBS FND_PROFILE:

- Simplified table structure
- No translation tables (TL)
- No concurrent program integration
- No form personalization
- Standalone implementation

## License

This is a custom implementation for educational and development purposes.

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2024 | Initial release |
