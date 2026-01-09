CREATE OR REPLACE FUNCTION get_region_static_id (
    p_application_id IN NUMBER DEFAULT v('APP_ID'),
    p_page_id        IN NUMBER DEFAULT v('APP_PAGE_ID'),
    p_region_name    IN VARCHAR2
) RETURN VARCHAR2 IS
    v_static_id apex_application_page_regions.static_id%TYPE;
BEGIN
    -- Query the APEX dictionary view for the region
    -- Note: This requires the parsing schema to have access to the APEX views
    SELECT static_id
    INTO v_static_id
    FROM apex_application_page_regions
    WHERE application_id = p_application_id
      AND page_id = p_page_id
      AND region_name = p_region_name;

    RETURN v_static_id;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Region does not exist or name is incorrect
        RETURN NULL;
    WHEN TOO_MANY_ROWS THEN
        -- Multiple regions with the same name on the same page
        -- Return the first one or handle error as appropriate
        BEGIN
            SELECT static_id
            INTO v_static_id
            FROM (
                SELECT static_id
                FROM apex_application_page_regions
                WHERE application_id = p_application_id
                  AND page_id = p_page_id
                  AND region_name = p_region_name
                ORDER BY region_id
            )
            WHERE ROWNUM = 1;
            
            RETURN v_static_id;
        EXCEPTION
            WHEN OTHERS THEN
                RETURN NULL;
        END;
END;
/
