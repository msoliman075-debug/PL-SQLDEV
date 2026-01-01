# PL/SQL Development Standards

## Naming Conventions

| Object Type | Prefix | Example |
|-------------|--------|---------|
| Package | PKG_ | PKG_ORDER_PROCESS |
| Procedure | PRC_ | PRC_UPDATE_CUSTOMER |
| Function | FNC_ | FNC_GET_ORDER_TOTAL |
| Type | TYP_ | TYP_ORDER_REC |
| Cursor | CUR_ | cur_active_orders |
| Variable | v_ | v_order_id |
| Parameter | p_ | p_customer_id |
| Constant | c_ | c_max_retries |
| Exception | e_ | e_invalid_order |
| Record | r_ | r_order |
| Table/Array | t_ | t_order_list |

## Exception Handling

Always include exception handling with meaningful logging:

```sql
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        pkg_log.log_error(
            p_procedure => 'PRC_GET_CUSTOMER',
            p_error_msg => 'Customer not found: ' || p_customer_id
        );
        RAISE;
    WHEN OTHERS THEN
        pkg_log.log_error(
            p_procedure => 'PRC_GET_CUSTOMER',
            p_error_msg => SQLERRM,
            p_error_code => SQLCODE
        );
        RAISE;
```

## Performance Guidelines

### Use BULK COLLECT for large datasets (>100 rows)

```sql
-- Good
OPEN cur_orders;
LOOP
    FETCH cur_orders BULK COLLECT INTO t_orders LIMIT 1000;
    EXIT WHEN t_orders.COUNT = 0;
    
    FORALL i IN 1..t_orders.COUNT
        INSERT INTO order_archive VALUES t_orders(i);
    
    COMMIT;
END LOOP;
CLOSE cur_orders;

-- Avoid
FOR r_order IN cur_orders LOOP
    INSERT INTO order_archive VALUES r_order;
END LOOP;
```

### Use bind variables in dynamic SQL

```sql
-- Good
EXECUTE IMMEDIATE 'SELECT name FROM customers WHERE id = :1' 
    INTO v_name USING p_customer_id;

-- Avoid (SQL injection risk)
EXECUTE IMMEDIATE 'SELECT name FROM customers WHERE id = ' || p_customer_id
    INTO v_name;
```

### Avoid SELECT *

```sql
-- Good
SELECT customer_id, customer_name, email
INTO v_id, v_name, v_email
FROM customers
WHERE customer_id = p_id;

-- Avoid
SELECT * INTO r_customer FROM customers WHERE customer_id = p_id;
```

## Oracle 19c Features to Use

- **Polymorphic Table Functions** for flexible data transformations
- **Qualified Expressions** for collection initialization
- **JSON_TABLE** for JSON parsing
- **LISTAGG DISTINCT** for aggregation
- **Private Temporary Tables** for session-specific data

## Code Structure Template

```sql
CREATE OR REPLACE PACKAGE BODY pkg_example AS
    
    -- Private constants
    c_max_retries CONSTANT PLS_INTEGER := 3;
    
    -- Private variables
    g_initialized BOOLEAN := FALSE;
    
    -- Private procedures
    PROCEDURE initialize IS
    BEGIN
        IF NOT g_initialized THEN
            -- initialization logic
            g_initialized := TRUE;
        END IF;
    END initialize;
    
    -- Public procedures
    PROCEDURE prc_main_process(
        p_input_id  IN  NUMBER,
        p_result    OUT VARCHAR2
    ) IS
        v_count PLS_INTEGER;
    BEGIN
        initialize;
        
        -- Main logic here
        
        p_result := 'SUCCESS';
        
    EXCEPTION
        WHEN OTHERS THEN
            p_result := 'ERROR: ' || SQLERRM;
            RAISE;
    END prc_main_process;
    
END pkg_example;
/
```
