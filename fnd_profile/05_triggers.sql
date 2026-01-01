/*
================================================================================
  FND_PROFILE Triggers
  Database triggers for audit and data integrity
  
  Author: Database Team
  Version: 1.0
  Target: Oracle 19c+
================================================================================
*/

-- ============================================================================
-- Trigger: FND_PROFILE_OPTIONS_BIU
-- Purpose: Set audit columns on insert/update for profile options
-- ============================================================================
CREATE OR REPLACE TRIGGER fnd_profile_options_biu
BEFORE INSERT OR UPDATE ON fnd_profile_options
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.profile_option_id IS NULL THEN
            :NEW.profile_option_id := fnd_profile_options_s.NEXTVAL;
        END IF;
        :NEW.creation_date := SYSDATE;
        :NEW.created_by := NVL(:NEW.created_by, -1);
    END IF;
    
    :NEW.last_update_date := SYSDATE;
    :NEW.last_updated_by := NVL(:NEW.last_updated_by, -1);
    :NEW.profile_option_name := UPPER(:NEW.profile_option_name);
END;
/

-- ============================================================================
-- Trigger: FND_PROFILE_OPT_VALUES_BIU
-- Purpose: Set audit columns on insert/update for profile option values
-- ============================================================================
CREATE OR REPLACE TRIGGER fnd_profile_opt_values_biu
BEFORE INSERT OR UPDATE ON fnd_profile_option_values
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.profile_option_value_id IS NULL THEN
            :NEW.profile_option_value_id := fnd_profile_option_values_s.NEXTVAL;
        END IF;
        :NEW.creation_date := SYSDATE;
        :NEW.created_by := NVL(:NEW.created_by, -1);
    END IF;
    
    :NEW.last_update_date := SYSDATE;
    :NEW.last_updated_by := NVL(:NEW.last_updated_by, -1);
    :NEW.level_value := NVL(:NEW.level_value, 0);
    :NEW.level_value_application_id := NVL(:NEW.level_value_application_id, 0);
END;
/

-- ============================================================================
-- Trigger: FND_APPLICATION_BIU
-- Purpose: Set audit columns for applications
-- ============================================================================
CREATE OR REPLACE TRIGGER fnd_application_biu
BEFORE INSERT OR UPDATE ON fnd_application
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creation_date := SYSDATE;
        :NEW.created_by := NVL(:NEW.created_by, -1);
    END IF;
    
    :NEW.last_update_date := SYSDATE;
    :NEW.last_updated_by := NVL(:NEW.last_updated_by, -1);
    :NEW.application_short_name := UPPER(:NEW.application_short_name);
END;
/

-- ============================================================================
-- Trigger: FND_RESPONSIBILITY_BIU
-- Purpose: Set audit columns for responsibilities
-- ============================================================================
CREATE OR REPLACE TRIGGER fnd_responsibility_biu
BEFORE INSERT OR UPDATE ON fnd_responsibility
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creation_date := SYSDATE;
        :NEW.created_by := NVL(:NEW.created_by, -1);
    END IF;
    
    :NEW.last_update_date := SYSDATE;
    :NEW.last_updated_by := NVL(:NEW.last_updated_by, -1);
    :NEW.responsibility_key := UPPER(:NEW.responsibility_key);
END;
/

-- ============================================================================
-- Trigger: FND_USER_BIU
-- Purpose: Set audit columns for users
-- ============================================================================
CREATE OR REPLACE TRIGGER fnd_user_biu
BEFORE INSERT OR UPDATE ON fnd_user
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creation_date := SYSDATE;
        :NEW.created_by := NVL(:NEW.created_by, -1);
    END IF;
    
    :NEW.last_update_date := SYSDATE;
    :NEW.last_updated_by := NVL(:NEW.last_updated_by, -1);
    :NEW.user_name := UPPER(:NEW.user_name);
END;
/

-- ============================================================================
-- Trigger: FND_USER_RESP_GROUPS_BIU
-- Purpose: Set audit columns for user-responsibility assignments
-- ============================================================================
CREATE OR REPLACE TRIGGER fnd_user_resp_groups_biu
BEFORE INSERT OR UPDATE ON fnd_user_resp_groups
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.creation_date := SYSDATE;
        :NEW.created_by := NVL(:NEW.created_by, -1);
    END IF;
    
    :NEW.last_update_date := SYSDATE;
    :NEW.last_updated_by := NVL(:NEW.last_updated_by, -1);
END;
/

/*
================================================================================
  End of Triggers
================================================================================
*/
