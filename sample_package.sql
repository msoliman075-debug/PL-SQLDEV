CREATE OR REPLACE PACKAGE pkg_employee_mgmt AS
    PROCEDURE onboard_employee(p_emp_id IN NUMBER, p_name IN VARCHAR2);
    FUNCTION get_salary(p_emp_id IN NUMBER) RETURN NUMBER;
END pkg_employee_mgmt;
/
