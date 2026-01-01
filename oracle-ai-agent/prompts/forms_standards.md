# Oracle Forms 12c Development Standards

## Naming Conventions

| Object Type | Prefix | Example |
|-------------|--------|---------|
| Block | BLK_ | BLK_ORDERS |
| Canvas | CNV_ | CNV_MAIN |
| Window | WIN_ | WIN_ORDER_ENTRY |
| Item | ITM_ | ITM_ORDER_ID |
| Button | BTN_ | BTN_SAVE |
| LOV | LOV_ | LOV_CUSTOMERS |
| Parameter | PARAM_ | PARAM_ORDER_ID |
| Program Unit | PU_ | PU_VALIDATE_ORDER |
| Alert | ALT_ | ALT_CONFIRM_DELETE |
| Visual Attribute | VA_ | VA_REQUIRED_FIELD |

## Trigger Organization

### Form-Level Triggers
- WHEN-NEW-FORM-INSTANCE: Initialize form, set defaults
- PRE-FORM: Security checks, parameter validation
- POST-FORM: Cleanup
- ON-ERROR: Custom error handling
- ON-MESSAGE: Custom message handling

### Block-Level Triggers
- PRE-QUERY: Set default query criteria
- POST-QUERY: Derived field calculations
- WHEN-NEW-RECORD-INSTANCE: Record initialization
- WHEN-VALIDATE-RECORD: Cross-field validation

### Item-Level Triggers
- WHEN-VALIDATE-ITEM: Field validation
- WHEN-LIST-CHANGED: Dropdown handling
- WHEN-BUTTON-PRESSED: Button actions

## Best Practices

### 1. Use Program Units for Reusable Logic

```sql
-- In form program unit PU_VALIDATE_ORDER
PROCEDURE pu_validate_order IS
    v_valid BOOLEAN := TRUE;
BEGIN
    IF :BLK_ORDERS.ORDER_DATE > SYSDATE THEN
        SET_ITEM_PROPERTY('BLK_ORDERS.ORDER_DATE', VISUAL_ATTRIBUTE, 'VA_ERROR');
        v_valid := FALSE;
    END IF;
    
    IF NOT v_valid THEN
        RAISE FORM_TRIGGER_FAILURE;
    END IF;
END;
```

### 2. Centralize Database Calls

```sql
-- Call packaged procedures instead of direct SQL
PKG_ORDER_API.create_order(
    p_customer_id => :BLK_ORDERS.CUSTOMER_ID,
    p_order_date  => :BLK_ORDERS.ORDER_DATE,
    p_order_id    => :BLK_ORDERS.ORDER_ID
);
```

### 3. Error Handling

```sql
-- ON-ERROR trigger
DECLARE
    v_error_code NUMBER := ERROR_CODE;
    v_error_type VARCHAR2(3) := ERROR_TYPE;
BEGIN
    IF v_error_code = 40202 THEN  -- Field must be entered
        MESSAGE('Please enter a value for ' || ERROR_TEXT);
        RAISE FORM_TRIGGER_FAILURE;
    ELSE
        -- Log error and show generic message
        PKG_LOG.log_form_error(
            p_form_name => :SYSTEM.CURRENT_FORM,
            p_error_code => v_error_code,
            p_error_text => ERROR_TEXT
        );
        MESSAGE('An error occurred. Please contact support.');
        RAISE FORM_TRIGGER_FAILURE;
    END IF;
END;
```

### 4. Performance Tips

- Use POST-QUERY for calculations instead of database triggers
- Minimize LOV queries with RESTRICT_LOV_FETCH
- Use SET_BLOCK_PROPERTY with DEFAULT_WHERE instead of manual filtering
- Commit only when necessary, batch updates when possible

### 5. Security

- Never hardcode credentials in forms
- Use FND_PROFILE/APP_PROFILE for configuration
- Validate all user inputs before database operations
- Use database packages for all DML operations

## Forms 12c Specific Features

- **JavaScript Integration**: Use WEB.JAVASCRIPT_EVAL for client-side logic
- **REST Services**: Call REST APIs using UTL_HTTP from form triggers
- **Responsive Layout**: Use CSS styling for modern appearance
- **Browser Deployment**: Optimize for Java-free browser deployment
