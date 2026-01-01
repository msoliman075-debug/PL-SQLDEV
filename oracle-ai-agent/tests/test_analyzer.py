"""
Tests for PL/SQL Code Analyzer
"""
import pytest
from tools.code_analyzer import PLSQLAnalyzer


@pytest.fixture
def analyzer():
    return PLSQLAnalyzer()


def test_detect_select_star(analyzer):
    code = """
    SELECT * FROM customers WHERE id = 1;
    """
    result = analyzer.analyze(code)
    assert any(i["code"] == "PERF001" for i in result.issues)


def test_detect_swallowed_exception(analyzer):
    code = """
    BEGIN
        some_procedure();
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    """
    result = analyzer.analyze(code)
    assert any(i["code"] == "ERR001" for i in result.issues)


def test_detect_sql_injection(analyzer):
    code = """
    EXECUTE IMMEDIATE 'SELECT * FROM users WHERE id = ' || p_user_id;
    """
    result = analyzer.analyze(code)
    assert any(i["code"] == "SEC001" for i in result.issues)


def test_suggest_bulk_collect(analyzer):
    code = """
    CURSOR cur_data IS SELECT id FROM big_table;
    BEGIN
        FOR r IN cur_data LOOP
            process(r.id);
        END LOOP;
    END;
    """
    result = analyzer.analyze(code)
    assert any(s["code"] == "PERF002" for s in result.suggestions)


def test_naming_convention_procedure(analyzer):
    config = {"naming": {"procedure_prefix": "PRC_"}}
    analyzer_with_config = PLSQLAnalyzer(config)
    
    code = """
    PROCEDURE update_customer IS
    BEGIN
        NULL;
    END;
    """
    result = analyzer_with_config.analyze(code)
    assert any(w["code"] == "NAME001" for w in result.warnings)


def test_clean_code_high_score(analyzer):
    code = """
    PROCEDURE PRC_UPDATE_CUSTOMER(
        p_customer_id IN NUMBER,
        p_name        IN VARCHAR2
    ) IS
        v_count PLS_INTEGER;
    BEGIN
        -- Update customer name
        UPDATE customers
        SET name = p_name,
            modified_date = SYSDATE
        WHERE customer_id = p_customer_id;
        
        v_count := SQL%ROWCOUNT;
        
        IF v_count = 0 THEN
            RAISE NO_DATA_FOUND;
        END IF;
        
        COMMIT;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Customer not found: ' || p_customer_id);
        WHEN OTHERS THEN
            ROLLBACK;
            log_error('PRC_UPDATE_CUSTOMER', SQLERRM);
            RAISE;
    END PRC_UPDATE_CUSTOMER;
    """
    result = analyzer.analyze(code)
    assert result.score >= 80
    assert len(result.issues) == 0


def test_metrics_calculation(analyzer):
    code = """
    -- Header comment
    PROCEDURE test IS
        CURSOR cur_test IS SELECT id FROM t;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM t;
        INSERT INTO t VALUES (1);
        UPDATE t SET x = 1;
        DELETE FROM t WHERE id = 1;
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    """
    result = analyzer.analyze(code)
    
    assert result.metrics["procedures"] == 1
    assert result.metrics["cursors"] == 1
    assert result.metrics["selects"] == 2  # COUNT and cursor
    assert result.metrics["inserts"] == 1
    assert result.metrics["updates"] == 1
    assert result.metrics["deletes"] == 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
