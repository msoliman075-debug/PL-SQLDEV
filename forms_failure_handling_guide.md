# Handling FORM_TRIGGER_FAILURE and Execution Flow in Oracle Forms

## Why `RAISE FORM_TRIGGER_FAILURE` does not set `FORM_SUCCESS` to `FALSE`

There is a fundamental difference between **Oracle Forms Built-ins** and **User-Defined Procedures/Triggers**:

1.  **`FORM_SUCCESS` is for Built-ins Only:**
    The boolean functions `FORM_SUCCESS`, `FORM_FAILURE`, and `FORM_FATAL` strictly report the status of the **most recently executed Oracle Forms built-in** (e.g., `GO_BLOCK`, `EXECUTE_QUERY`, `NEXT_ITEM`).
    
    *   When you execute a built-in, Forms updates this internal flag.
    *   When you run your own PL/SQL code (assignments, loops, user procedures), this flag is **not touched**.

2.  **`FORM_TRIGGER_FAILURE` is an Exception:**
    `FORM_TRIGGER_FAILURE` is a predefined PL/SQL exception. When raised, it immediately aborts the processing of the current trigger.
    
    *   Raising this exception does **not** write to the internal "success" flag used by built-ins.
    *   Therefore, checking `FORM_SUCCESS` after a user procedure that raised this exception (and handled it internally, or if checking from a separate context) will simply return the status of the *last built-in* that ran before the procedure, which might be `TRUE`.

## Practical Solutions to Stop Execution

To reliably stop execution flow when an error occurs, you must choose a consistent error handling strategy.

### 1. The Exception Propagation Strategy (Best Practice)

The most robust method is to allow the `FORM_TRIGGER_FAILURE` exception to propagate up the call stack.

*   **In the Called Procedure:** Raise the exception.
*   **In the Calling Trigger:** Do **not** trap the exception (or trap and re-raise).

**Example:**

```sql
-- In a stored procedure or Program Unit
PROCEDURE validate_emp_id IS
BEGIN
  IF :EMP.EMPNO IS NULL THEN
    MESSAGE('Employee ID is required.');
    RAISE FORM_TRIGGER_FAILURE; -- Aborts this procedure
  END IF;
END;

-- In a WHEN-BUTTON-PRESSED trigger
BEGIN
  -- 1. Call validation
  validate_emp_id; 
  -- If validate_emp_id fails, execution STOPS here immediately.
  -- The exception propagates out of this trigger block.
  
  -- 2. This code runs ONLY if validation succeeded
  GO_BLOCK('DEPT'); 
  EXECUTE_QUERY;
END;
```

**Crucial Note:** If you use a `EXCEPTION WHEN OTHERS` block in your trigger, you **must** handle `FORM_TRIGGER_FAILURE` specifically or re-raise it, otherwise, you swallow the "stop" signal.

```sql
-- INCORRECT: Swallows the stop signal
EXCEPTION
  WHEN OTHERS THEN
    NULL; -- The form continues as if nothing happened!

-- CORRECT:
EXCEPTION
  WHEN FORM_TRIGGER_FAILURE THEN
    RAISE; -- Let it stop the form trigger
  WHEN OTHERS THEN
    -- Handle other unexpected errors
    MESSAGE(SQLERRM);
    RAISE FORM_TRIGGER_FAILURE;
```

### 2. The Check-After-Built-in Strategy

Since built-ins don't raise exceptions automatically on failure (usually), you must check their status explicitly and then raise the exception yourself to stop the flow.

```sql
BEGIN
  GO_BLOCK('ORDERS');
  -- Check if navigation worked
  IF NOT FORM_SUCCESS THEN
    MESSAGE('Cannot navigate to Orders block.');
    RAISE FORM_TRIGGER_FAILURE; -- Stop here!
  END IF;
  
  EXECUTE_QUERY;
  IF NOT FORM_SUCCESS THEN
    -- logic if query returned no records or failed
    NULL;
  END IF;
END;
```

### 3. User-Defined Functions for Status (Legacy Approach)

If you prefer `IF` statements over exceptions for your own logic, convert your procedures to functions that return a Boolean.

```sql
FUNCTION try_validate_emp RETURN BOOLEAN IS
BEGIN
  IF :EMP.EMPNO IS NULL THEN
    MESSAGE('Employee ID is required.');
    RETURN FALSE;
  END IF;
  RETURN TRUE;
END;

-- In Trigger
BEGIN
  IF try_validate_emp THEN
    -- Success logic
    COMMIT_FORM;
  ELSE
    -- Failure logic: Stop now
    RAISE FORM_TRIGGER_FAILURE;
  END IF;
END;
```

## Summary

*   **Why?** `FORM_SUCCESS` only tracks internal built-ins. Raising an exception is a PL/SQL control flow mechanism, not a Forms built-in operation.
*   **Solution:** Rely on **exception propagation**.
    1.  Raise `FORM_TRIGGER_FAILURE` in the sub-unit.
    2.  Ensure caller does not suppress it (avoid empty `WHEN OTHERS`).
    3.  For built-ins, always follow with `IF NOT FORM_SUCCESS THEN RAISE FORM_TRIGGER_FAILURE; END IF;`.
