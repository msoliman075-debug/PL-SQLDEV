/* Sample Forms Trigger Logic: WHEN-BUTTON-PRESSED */
DECLARE
    v_status VARCHAR2(10);
BEGIN
    SELECT status INTO v_status FROM orders WHERE order_id = :ORDER.ORDER_ID;
    
    IF v_status = 'CLOSED' THEN
        MESSAGE('Order is closed.');
        RAISE FORM_TRIGGER_FAILURE;
    END IF;
    
    -- Business Logic Issue: Committing in a trigger can be problematic in Forms
    COMMIT; 
    
    GO_BLOCK('ITEMS');
END;
