# Developer Integration Guide

## Table of Contents
1. [Quick Start for Developers](#quick-start-for-developers)
2. [API Reference](#api-reference)
3. [Common Use Cases](#common-use-cases)
4. [Best Practices](#best-practices)
5. [Integration Patterns](#integration-patterns)
6. [Code Examples](#code-examples)
7. [Debugging Tips](#debugging-tips)

---

## Quick Start for Developers

### 30-Second Integration

```sql
-- 1. Retrieve a profile value
DECLARE
    l_date_format VARCHAR2(2000);
BEGIN
    l_date_format := fnd_profile.value('DEFAULT_DATE_FORMAT');
    DBMS_OUTPUT.PUT_LINE('Date format: ' || l_date_format);
END;
/

-- 2. Save a user preference
BEGIN
    fnd_profile.save(
        p_profile_name => 'ROWS_PER_PAGE',
        p_value => '50',
        p_level_id => fnd_profile.g_level_user,
        p_level_value => 1001,  -- User ID
        p_user_id => 1001
    );
END;
/
```

### 5-Minute Integration

```sql
-- Application startup sequence
DECLARE
    l_user_id NUMBER := 1001;
    l_resp_id NUMBER := 50001;
    l_app_id NUMBER := 101;
BEGIN
    -- 1. Initialize profile cache for session
    fnd_profile.initialize(
        p_user_id => l_user_id,
        p_responsibility_id => l_resp_id,
        p_application_id => l_app_id
    );
    
    -- 2. Retrieve commonly used profiles
    g_date_format := fnd_profile.value('DEFAULT_DATE_FORMAT');
    g_rows_per_page := TO_NUMBER(fnd_profile.value('ROWS_PER_PAGE'));
    g_language := fnd_profile.value('DEFAULT_LANGUAGE');
    
    DBMS_OUTPUT.PUT_LINE('Session initialized for user ' || l_user_id);
END;
/
```

---

## API Reference

### Core Functions

#### fnd_profile.value()

**Purpose:** Retrieves profile value with hierarchical resolution

**Signature:**
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

**Returns:** Profile value as VARCHAR2, or NULL if not found

**Example:**
```sql
-- Simple usage (checks session cache first)
l_value := fnd_profile.value('PROFILE_NAME');

-- With full context
l_value := fnd_profile.value(
    p_profile_name => 'DEFAULT_LANGUAGE',
    p_user_id => 1001,
    p_responsibility_id => 50001,
    p_application_id => 101
);
```

**Performance:** O(1) if cached, O(log n) with database query

---

#### fnd_profile.value_specific()

**Purpose:** Retrieves profile value at a specific level only

**Signature:**
```sql
FUNCTION value_specific(
    p_profile_name       IN VARCHAR2,
    p_level_id           IN NUMBER,
    p_level_value        IN NUMBER DEFAULT NULL,
    p_level_value_app_id IN NUMBER DEFAULT NULL
) RETURN VARCHAR2;
```

**Example:**
```sql
-- Get site-level value only
l_value := fnd_profile.value_specific(
    p_profile_name => 'SESSION_TIMEOUT',
    p_level_id => fnd_profile.g_level_site
);

-- Get user-level value only
l_value := fnd_profile.value_specific(
    p_profile_name => 'ROWS_PER_PAGE',
    p_level_id => fnd_profile.g_level_user,
    p_level_value => 1001
);
```

**Performance:** O(1) - Direct lookup with composite index

---

#### fnd_profile.defined()

**Purpose:** Checks if profile option exists and is enabled

**Signature:**
```sql
FUNCTION defined(
    p_profile_name IN VARCHAR2
) RETURN BOOLEAN;
```

**Example:**
```sql
IF fnd_profile.defined('MY_CUSTOM_PROFILE') THEN
    l_value := fnd_profile.value('MY_CUSTOM_PROFILE');
ELSE
    l_value := 'DEFAULT_VALUE';
END IF;
```

**Performance:** O(1) - Index lookup

---

### Core Procedures

#### fnd_profile.save()

**Purpose:** Persists profile value to database

**Signature:**
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

**Example:**
```sql
-- Save user preference
BEGIN
    fnd_profile.save(
        p_profile_name => 'ROWS_PER_PAGE',
        p_value => '100',
        p_level_id => fnd_profile.g_level_user,
        p_level_value => 1001,
        p_user_id => 1001
    );
    DBMS_OUTPUT.PUT_LINE('User preference saved');
EXCEPTION
    WHEN fnd_profile.e_read_only_profile THEN
        DBMS_OUTPUT.PUT_LINE('Error: Profile is read-only');
    WHEN fnd_profile.e_profile_not_found THEN
        DBMS_OUTPUT.PUT_LINE('Error: Profile not found');
END;
/
```

**Side Effects:** 
- Updates database (commits automatically)
- Updates session cache if present

---

#### fnd_profile.put()

**Purpose:** Sets profile value in session cache only (in-memory)

**Signature:**
```sql
PROCEDURE put(
    p_profile_name IN VARCHAR2,
    p_value        IN VARCHAR2
);
```

**Example:**
```sql
-- Temporarily override a profile for this session
fnd_profile.put('ROWS_PER_PAGE', '200');

-- Value persists only for this session
l_value := fnd_profile.value('ROWS_PER_PAGE'); -- Returns '200'
```

**Use Case:** Temporary overrides, testing, session-specific behavior

---

#### fnd_profile.initialize()

**Purpose:** Loads profiles into session cache for performance

**Signature:**
```sql
PROCEDURE initialize(
    p_user_id           IN NUMBER,
    p_responsibility_id IN NUMBER DEFAULT NULL,
    p_application_id    IN NUMBER DEFAULT NULL
);
```

**Example:**
```sql
-- Call at login/session start
BEGIN
    fnd_profile.initialize(
        p_user_id => :g_user_id,
        p_responsibility_id => :g_resp_id,
        p_application_id => :g_app_id
    );
END;
/
```

**Performance Impact:** 
- Initial load: O(n) where n = number of applicable profiles
- Subsequent calls to value(): O(1)

---

### Level Constants

```sql
fnd_profile.g_level_site            = 10001  -- System-wide defaults
fnd_profile.g_level_application     = 10002  -- Application-specific
fnd_profile.g_level_responsibility  = 10003  -- Role-based
fnd_profile.g_level_user            = 10004  -- User preferences
fnd_profile.g_level_server          = 10005  -- Server-specific
fnd_profile.g_level_org             = 10006  -- Organization-specific
```

---

## Common Use Cases

### Use Case 1: Application Preferences

```sql
-- Define application-wide preferences
CREATE OR REPLACE PACKAGE app_config AS
    g_date_format    VARCHAR2(20);
    g_rows_per_page  NUMBER;
    g_timeout        NUMBER;
    
    PROCEDURE initialize_session(p_user_id IN NUMBER);
END app_config;
/

CREATE OR REPLACE PACKAGE BODY app_config AS
    PROCEDURE initialize_session(p_user_id IN NUMBER) IS
    BEGIN
        -- Load profiles into package globals
        fnd_profile.initialize(p_user_id);
        
        g_date_format := NVL(fnd_profile.value('DEFAULT_DATE_FORMAT'), 'DD-MON-YYYY');
        g_rows_per_page := NVL(TO_NUMBER(fnd_profile.value('ROWS_PER_PAGE')), 25);
        g_timeout := NVL(TO_NUMBER(fnd_profile.value('SESSION_TIMEOUT')), 30);
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Use defaults if profile system unavailable
            g_date_format := 'DD-MON-YYYY';
            g_rows_per_page := 25;
            g_timeout := 30;
    END initialize_session;
END app_config;
/
```

### Use Case 2: User Preference Form

```sql
-- Procedure to save user preferences from UI form
CREATE OR REPLACE PROCEDURE save_user_preferences(
    p_user_id       IN NUMBER,
    p_date_format   IN VARCHAR2,
    p_rows_per_page IN NUMBER,
    p_language      IN VARCHAR2
) IS
    l_error_msg VARCHAR2(4000);
BEGIN
    -- Validate inputs
    IF p_user_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'User ID is required');
    END IF;
    
    -- Save date format preference
    IF p_date_format IS NOT NULL THEN
        fnd_profile.save(
            p_profile_name => 'DEFAULT_DATE_FORMAT',
            p_value => p_date_format,
            p_level_id => fnd_profile.g_level_user,
            p_level_value => p_user_id,
            p_user_id => p_user_id
        );
    END IF;
    
    -- Save rows per page preference
    IF p_rows_per_page IS NOT NULL THEN
        fnd_profile.save(
            p_profile_name => 'ROWS_PER_PAGE',
            p_value => TO_CHAR(p_rows_per_page),
            p_level_id => fnd_profile.g_level_user,
            p_level_value => p_user_id,
            p_user_id => p_user_id
        );
    END IF;
    
    -- Save language preference
    IF p_language IS NOT NULL THEN
        fnd_profile.save(
            p_profile_name => 'DEFAULT_LANGUAGE',
            p_value => p_language,
            p_level_id => fnd_profile.g_level_user,
            p_level_value => p_user_id,
            p_user_id => p_user_id
        );
    END IF;
    
    COMMIT;
    
EXCEPTION
    WHEN fnd_profile.e_read_only_profile THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20002, 'Profile is read-only and cannot be changed');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END save_user_preferences;
/
```

### Use Case 3: Multi-Tenant Configuration

```sql
-- Set organization-specific configurations
CREATE OR REPLACE PROCEDURE setup_org_profiles(
    p_org_id      IN NUMBER,
    p_currency    IN VARCHAR2,
    p_timezone    IN VARCHAR2,
    p_date_format IN VARCHAR2
) IS
BEGIN
    -- Set organization-level defaults
    fnd_profile.save(
        p_profile_name => 'DEFAULT_CURRENCY',
        p_value => p_currency,
        p_level_id => fnd_profile.g_level_org,
        p_level_value => p_org_id,
        p_user_id => 0
    );
    
    fnd_profile.save(
        p_profile_name => 'DEFAULT_TIMEZONE',
        p_value => p_timezone,
        p_level_id => fnd_profile.g_level_org,
        p_level_value => p_org_id,
        p_user_id => 0
    );
    
    fnd_profile.save(
        p_profile_name => 'DEFAULT_DATE_FORMAT',
        p_value => p_date_format,
        p_level_id => fnd_profile.g_level_org,
        p_level_value => p_org_id,
        p_user_id => 0
    );
    
    COMMIT;
END setup_org_profiles;
/
```

### Use Case 4: Feature Flags

```sql
-- Use profiles as feature flags
CREATE OR REPLACE FUNCTION is_feature_enabled(
    p_feature_name IN VARCHAR2,
    p_user_id      IN NUMBER DEFAULT NULL
) RETURN BOOLEAN IS
    l_value VARCHAR2(2000);
BEGIN
    l_value := fnd_profile.value(
        p_profile_name => 'FEATURE_' || p_feature_name,
        p_user_id => p_user_id
    );
    
    RETURN (NVL(l_value, 'N') = 'Y');
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END is_feature_enabled;
/

-- Usage in application code
IF is_feature_enabled('NEW_DASHBOARD', l_user_id) THEN
    show_new_dashboard();
ELSE
    show_old_dashboard();
END IF;
```

---

## Best Practices

### 1. Initialize at Session Start

```sql
-- Always initialize profiles at login
BEGIN
    fnd_profile.initialize(
        p_user_id => :g_user_id,
        p_responsibility_id => :g_resp_id,
        p_application_id => :g_app_id
    );
END;
/
```

**Benefits:**
- Reduces database calls (O(1) lookups after initialization)
- Improves response time
- Consistent behavior throughout session

---

### 2. Provide Defaults

```sql
-- Always provide fallback defaults
l_rows_per_page := NVL(
    TO_NUMBER(fnd_profile.value('ROWS_PER_PAGE')), 
    25  -- Default value
);

-- Or use COALESCE for multiple fallbacks
l_currency := COALESCE(
    fnd_profile.value('DEFAULT_CURRENCY'),
    fnd_profile.value_specific('DEFAULT_CURRENCY', fnd_profile.g_level_site),
    'USD'  -- Hard-coded default
);
```

---

### 3. Cache in Package Globals

```sql
-- For frequently accessed profiles
CREATE OR REPLACE PACKAGE app_globals AS
    g_date_format VARCHAR2(20);
    g_rows_per_page NUMBER;
    
    PROCEDURE load_profiles(p_user_id IN NUMBER);
END;
/

CREATE OR REPLACE PACKAGE BODY app_globals AS
    PROCEDURE load_profiles(p_user_id IN NUMBER) IS
    BEGIN
        g_date_format := fnd_profile.value('DEFAULT_DATE_FORMAT', p_user_id);
        g_rows_per_page := TO_NUMBER(fnd_profile.value('ROWS_PER_PAGE', p_user_id));
    END;
END;
/
```

---

### 4. Handle Exceptions

```sql
-- Always handle potential exceptions
DECLARE
    l_value VARCHAR2(2000);
BEGIN
    fnd_profile.save(
        p_profile_name => 'MY_PROFILE',
        p_value => 'MY_VALUE',
        p_level_id => fnd_profile.g_level_user,
        p_level_value => l_user_id,
        p_user_id => l_user_id
    );
EXCEPTION
    WHEN fnd_profile.e_profile_not_found THEN
        log_error('Profile not found: MY_PROFILE');
    WHEN fnd_profile.e_read_only_profile THEN
        log_error('Profile is read-only: MY_PROFILE');
    WHEN fnd_profile.e_invalid_level THEN
        log_error('Invalid level specified');
    WHEN OTHERS THEN
        log_error('Unexpected error: ' || SQLERRM);
        RAISE;
END;
/
```

---

### 5. Use Type Conversion Wrappers

```sql
-- Create type-safe wrappers
CREATE OR REPLACE PACKAGE profile_utils AS
    FUNCTION get_number(
        p_profile_name IN VARCHAR2,
        p_default      IN NUMBER DEFAULT NULL,
        p_user_id      IN NUMBER DEFAULT NULL
    ) RETURN NUMBER;
    
    FUNCTION get_boolean(
        p_profile_name IN VARCHAR2,
        p_default      IN BOOLEAN DEFAULT FALSE,
        p_user_id      IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN;
    
    FUNCTION get_date(
        p_profile_name IN VARCHAR2,
        p_default      IN DATE DEFAULT NULL,
        p_user_id      IN NUMBER DEFAULT NULL
    ) RETURN DATE;
END profile_utils;
/

CREATE OR REPLACE PACKAGE BODY profile_utils AS
    FUNCTION get_number(
        p_profile_name IN VARCHAR2,
        p_default      IN NUMBER DEFAULT NULL,
        p_user_id      IN NUMBER DEFAULT NULL
    ) RETURN NUMBER IS
        l_value VARCHAR2(2000);
    BEGIN
        l_value := fnd_profile.value(p_profile_name, p_user_id);
        RETURN NVL(TO_NUMBER(l_value), p_default);
    EXCEPTION
        WHEN VALUE_ERROR THEN
            RETURN p_default;
    END get_number;
    
    FUNCTION get_boolean(
        p_profile_name IN VARCHAR2,
        p_default      IN BOOLEAN DEFAULT FALSE,
        p_user_id      IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN IS
        l_value VARCHAR2(2000);
    BEGIN
        l_value := UPPER(fnd_profile.value(p_profile_name, p_user_id));
        IF l_value IN ('Y', 'YES', 'TRUE', '1') THEN
            RETURN TRUE;
        ELSIF l_value IN ('N', 'NO', 'FALSE', '0') THEN
            RETURN FALSE;
        ELSE
            RETURN p_default;
        END IF;
    END get_boolean;
    
    FUNCTION get_date(
        p_profile_name IN VARCHAR2,
        p_default      IN DATE DEFAULT NULL,
        p_user_id      IN NUMBER DEFAULT NULL
    ) RETURN DATE IS
        l_value VARCHAR2(2000);
    BEGIN
        l_value := fnd_profile.value(p_profile_name, p_user_id);
        RETURN NVL(TO_DATE(l_value, 'YYYY-MM-DD'), p_default);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN p_default;
    END get_date;
END profile_utils;
/

-- Usage
l_timeout := profile_utils.get_number('SESSION_TIMEOUT', 30, l_user_id);
l_debug_mode := profile_utils.get_boolean('DEBUG_MODE', FALSE, l_user_id);
```

---

## Integration Patterns

### Pattern 1: Singleton Configuration Manager

```sql
CREATE OR REPLACE PACKAGE config_manager AS
    -- Singleton pattern for configuration management
    PROCEDURE initialize(
        p_user_id           IN NUMBER,
        p_responsibility_id IN NUMBER DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL
    );
    
    FUNCTION get_config(p_name IN VARCHAR2) RETURN VARCHAR2;
    
    PROCEDURE set_config(
        p_name  IN VARCHAR2,
        p_value IN VARCHAR2
    );
END config_manager;
/

CREATE OR REPLACE PACKAGE BODY config_manager AS
    g_initialized BOOLEAN := FALSE;
    g_user_id NUMBER;
    
    PROCEDURE initialize(
        p_user_id           IN NUMBER,
        p_responsibility_id IN NUMBER DEFAULT NULL,
        p_application_id    IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        g_user_id := p_user_id;
        fnd_profile.initialize(p_user_id, p_responsibility_id, p_application_id);
        g_initialized := TRUE;
    END initialize;
    
    FUNCTION get_config(p_name IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF NOT g_initialized THEN
            RAISE_APPLICATION_ERROR(-20001, 'Config manager not initialized');
        END IF;
        
        RETURN fnd_profile.value(p_name, g_user_id);
    END get_config;
    
    PROCEDURE set_config(
        p_name  IN VARCHAR2,
        p_value IN VARCHAR2
    ) IS
    BEGIN
        IF NOT g_initialized THEN
            RAISE_APPLICATION_ERROR(-20001, 'Config manager not initialized');
        END IF;
        
        fnd_profile.save(
            p_profile_name => p_name,
            p_value => p_value,
            p_level_id => fnd_profile.g_level_user,
            p_level_value => g_user_id,
            p_user_id => g_user_id
        );
    END set_config;
END config_manager;
/
```

### Pattern 2: Repository Pattern

```sql
CREATE OR REPLACE PACKAGE user_preferences_repo AS
    -- Repository for user preferences
    TYPE preference_rec IS RECORD (
        name  VARCHAR2(240),
        value VARCHAR2(2000)
    );
    
    TYPE preference_tab IS TABLE OF preference_rec;
    
    FUNCTION get_all_preferences(
        p_user_id IN NUMBER
    ) RETURN preference_tab PIPELINED;
    
    PROCEDURE update_preferences(
        p_user_id     IN NUMBER,
        p_preferences IN preference_tab
    );
END user_preferences_repo;
/
```

---

## Debugging Tips

### Enable Debug Output

```sql
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200

-- Check what profiles are loaded
DECLARE
    l_cursor SYS_REFCURSOR;
    l_name VARCHAR2(240);
    l_value VARCHAR2(2000);
BEGIN
    fnd_profile.get_all(
        p_user_id => 1001,
        p_cursor => l_cursor
    );
    
    LOOP
        FETCH l_cursor INTO l_name, l_value;
        EXIT WHEN l_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(l_name || ' = ' || l_value);
    END LOOP;
    
    CLOSE l_cursor;
END;
/
```

### Trace Profile Lookups

```sql
-- Add logging to VALUE function (for development)
CREATE TABLE profile_access_log (
    log_id NUMBER GENERATED ALWAYS AS IDENTITY,
    profile_name VARCHAR2(240),
    user_id NUMBER,
    value_returned VARCHAR2(2000),
    access_time TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Create trigger or modify package to log access
```

### Query Effective Values

```sql
-- See all levels for a specific profile
SELECT level_name,
       priority,
       level_value,
       profile_option_value
FROM   fnd_profile_hierarchy_v
WHERE  profile_option_name = 'DEFAULT_DATE_FORMAT'
ORDER BY priority;
```

---

## Performance Monitoring

```sql
-- Monitor profile access performance
SELECT sql_text,
       executions,
       elapsed_time/1000000 AS elapsed_sec,
       elapsed_time/executions/1000 AS avg_ms_per_exec
FROM   v$sql
WHERE  UPPER(sql_text) LIKE '%FND_PROFILE%'
AND    sql_text NOT LIKE '%V$SQL%'
ORDER BY elapsed_time DESC;
```

---

**End of Developer Integration Guide**

For more information, see:
- README.md - Complete system documentation
- ERD_AND_ARCHITECTURE.md - Database design details
- 09_quick_reference.sql - Quick SQL reference
