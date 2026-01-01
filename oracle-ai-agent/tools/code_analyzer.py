"""
PL/SQL Code Analyzer - Static analysis and quality checks
"""
import re
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class AnalysisResult:
    score: int = 100
    issues: list = field(default_factory=list)
    warnings: list = field(default_factory=list)
    suggestions: list = field(default_factory=list)
    metrics: dict = field(default_factory=dict)


class PLSQLAnalyzer:
    """Analyze PL/SQL code for quality, performance, and standards compliance."""

    def __init__(self, config: dict = None):
        self.config = config or {}
        self.naming = self.config.get("naming", {})
        self.bulk_threshold = self.config.get("bulk_threshold", 100)

    def analyze(self, code: str) -> AnalysisResult:
        """Perform full analysis on PL/SQL code."""
        result = AnalysisResult()

        # Calculate metrics
        result.metrics = self._calculate_metrics(code)

        # Run all checks
        self._check_select_star(code, result)
        self._check_exception_handling(code, result)
        self._check_bulk_operations(code, result)
        self._check_hardcoded_values(code, result)
        self._check_naming_conventions(code, result)
        self._check_sql_injection(code, result)
        self._check_deprecated_features(code, result)
        self._check_performance_issues(code, result)
        self._check_maintainability(code, result)

        # Calculate final score
        result.score = max(
            0, 100 - (len(result.issues) * 10) - (len(result.warnings) * 5)
        )

        return result

    def _calculate_metrics(self, code: str) -> dict:
        """Calculate code metrics."""
        lines = code.splitlines()
        code_lines = [l for l in lines if l.strip() and not l.strip().startswith("--")]

        return {
            "total_lines": len(lines),
            "code_lines": len(code_lines),
            "comment_lines": len([l for l in lines if l.strip().startswith("--")]),
            "procedures": len(re.findall(r"\bPROCEDURE\b", code, re.I)),
            "functions": len(re.findall(r"\bFUNCTION\b", code, re.I)),
            "cursors": len(re.findall(r"\bCURSOR\b", code, re.I)),
            "exceptions": len(re.findall(r"\bEXCEPTION\b", code, re.I)),
            "selects": len(re.findall(r"\bSELECT\b", code, re.I)),
            "inserts": len(re.findall(r"\bINSERT\b", code, re.I)),
            "updates": len(re.findall(r"\bUPDATE\b", code, re.I)),
            "deletes": len(re.findall(r"\bDELETE\b", code, re.I)),
        }

    def _check_select_star(self, code: str, result: AnalysisResult):
        """Check for SELECT * usage."""
        pattern = r"SELECT\s+\*\s+FROM"
        matches = re.findall(pattern, code, re.I)
        if matches:
            result.issues.append(
                {
                    "code": "PERF001",
                    "message": f"SELECT * found {len(matches)} time(s) - specify columns explicitly",
                    "severity": "high",
                }
            )

    def _check_exception_handling(self, code: str, result: AnalysisResult):
        """Check exception handling patterns."""
        # Check for swallowed exceptions
        if re.search(r"EXCEPTION\s+WHEN\s+OTHERS\s+THEN\s+NULL", code, re.I):
            result.issues.append(
                {
                    "code": "ERR001",
                    "message": "Exception swallowed with NULL - log or re-raise",
                    "severity": "critical",
                }
            )

        # Check for missing exception blocks
        begin_count = len(re.findall(r"\bBEGIN\b", code, re.I))
        exception_count = len(re.findall(r"\bEXCEPTION\b", code, re.I))
        if begin_count > exception_count + 1:
            result.warnings.append(
                {
                    "code": "ERR002",
                    "message": "Some BEGIN blocks may lack EXCEPTION handling",
                    "severity": "medium",
                }
            )

        # Check for proper SQLERRM/SQLCODE usage
        if "WHEN OTHERS" in code.upper() and "SQLERRM" not in code.upper():
            result.warnings.append(
                {
                    "code": "ERR003",
                    "message": "WHEN OTHERS without SQLERRM logging",
                    "severity": "medium",
                }
            )

    def _check_bulk_operations(self, code: str, result: AnalysisResult):
        """Check for missing BULK COLLECT / FORALL."""
        has_cursor = bool(re.search(r"\bCURSOR\b", code, re.I))
        has_loop = bool(re.search(r"\bLOOP\b", code, re.I))
        has_bulk = bool(re.search(r"\bBULK\s+COLLECT\b", code, re.I))
        has_forall = bool(re.search(r"\bFORALL\b", code, re.I))

        if has_cursor and has_loop and not has_bulk:
            result.suggestions.append(
                {
                    "code": "PERF002",
                    "message": "Consider BULK COLLECT for cursor loop processing",
                    "severity": "medium",
                }
            )

        # Check for row-by-row DML in loops
        if has_loop:
            dml_in_loop = re.search(
                r"LOOP\s+.*?(INSERT|UPDATE|DELETE)\s+", code, re.I | re.DOTALL
            )
            if dml_in_loop and not has_forall:
                result.suggestions.append(
                    {
                        "code": "PERF003",
                        "message": "Consider FORALL for DML operations in loops",
                        "severity": "medium",
                    }
                )

    def _check_hardcoded_values(self, code: str, result: AnalysisResult):
        """Check for hardcoded values that should be constants/parameters."""
        # Check for hardcoded schema names
        if re.search(r"FROM\s+\w+\.\w+", code, re.I):
            result.warnings.append(
                {
                    "code": "MAINT001",
                    "message": "Hardcoded schema names found - use synonyms or parameters",
                    "severity": "low",
                }
            )

        # Check for magic numbers
        magic_numbers = re.findall(r"(?<![.\w])(\d{4,})(?![.\w])", code)
        if magic_numbers:
            result.warnings.append(
                {
                    "code": "MAINT002",
                    "message": f"Magic numbers found: {magic_numbers[:3]} - use named constants",
                    "severity": "low",
                }
            )

    def _check_naming_conventions(self, code: str, result: AnalysisResult):
        """Check naming conventions."""
        # Check procedure naming
        proc_pattern = r"PROCEDURE\s+(\w+)"
        for match in re.finditer(proc_pattern, code, re.I):
            name = match.group(1)
            prefix = self.naming.get("procedure_prefix", "PRC_")
            if not name.upper().startswith(prefix):
                result.warnings.append(
                    {
                        "code": "NAME001",
                        "message": f"Procedure '{name}' doesn't follow naming convention ({prefix}*)",
                        "severity": "low",
                    }
                )

        # Check function naming
        func_pattern = r"FUNCTION\s+(\w+)"
        for match in re.finditer(func_pattern, code, re.I):
            name = match.group(1)
            prefix = self.naming.get("function_prefix", "FNC_")
            if not name.upper().startswith(prefix):
                result.warnings.append(
                    {
                        "code": "NAME002",
                        "message": f"Function '{name}' doesn't follow naming convention ({prefix}*)",
                        "severity": "low",
                    }
                )

    def _check_sql_injection(self, code: str, result: AnalysisResult):
        """Check for potential SQL injection vulnerabilities."""
        # Check for dynamic SQL with concatenation
        if re.search(r"EXECUTE\s+IMMEDIATE\s+.*\|\|", code, re.I):
            result.issues.append(
                {
                    "code": "SEC001",
                    "message": "Dynamic SQL with concatenation - use bind variables",
                    "severity": "critical",
                }
            )

        # Check for DBMS_SQL with string building
        if "DBMS_SQL" in code.upper() and "||" in code:
            result.warnings.append(
                {
                    "code": "SEC002",
                    "message": "DBMS_SQL with string concatenation - verify bind variable usage",
                    "severity": "high",
                }
            )

    def _check_deprecated_features(self, code: str, result: AnalysisResult):
        """Check for deprecated Oracle features."""
        deprecated = {
            "LONG": "Use CLOB instead of LONG datatype",
            "LONG RAW": "Use BLOB instead of LONG RAW datatype",
            "DBMS_JOB": "Use DBMS_SCHEDULER instead of DBMS_JOB (deprecated in 19c)",
            "UTL_FILE.FOPEN_NCHAR": "Deprecated - use UTL_FILE.FOPEN with charset",
        }

        for pattern, message in deprecated.items():
            if pattern in code.upper():
                result.warnings.append(
                    {
                        "code": "DEP001",
                        "message": message,
                        "severity": "medium",
                    }
                )

    def _check_performance_issues(self, code: str, result: AnalysisResult):
        """Check for common performance anti-patterns."""
        # Implicit cursor in loop
        if re.search(r"FOR\s+\w+\s+IN\s+\(\s*SELECT", code, re.I):
            result.suggestions.append(
                {
                    "code": "PERF004",
                    "message": "Implicit cursor in FOR loop - consider explicit cursor with BULK COLLECT",
                    "severity": "low",
                }
            )

        # COUNT(*) when EXISTS would suffice
        if re.search(r"SELECT\s+COUNT\s*\(\s*\*\s*\)\s+INTO.*IF.*[>=<]", code, re.I):
            result.suggestions.append(
                {
                    "code": "PERF005",
                    "message": "COUNT(*) may be replaceable with EXISTS for existence checks",
                    "severity": "low",
                }
            )

        # NVL in WHERE clause on indexed columns
        if re.search(r"WHERE.*NVL\s*\(", code, re.I):
            result.warnings.append(
                {
                    "code": "PERF006",
                    "message": "NVL in WHERE clause may prevent index usage",
                    "severity": "medium",
                }
            )

    def _check_maintainability(self, code: str, result: AnalysisResult):
        """Check maintainability issues."""
        lines = code.splitlines()

        # Check for very long procedures (>500 lines)
        if len(lines) > 500:
            result.warnings.append(
                {
                    "code": "MAINT003",
                    "message": f"Code is {len(lines)} lines - consider breaking into smaller units",
                    "severity": "medium",
                }
            )

        # Check for deeply nested code
        max_indent = max(
            (len(line) - len(line.lstrip()) for line in lines if line.strip()), default=0
        )
        if max_indent > 40:  # ~10 levels of nesting
            result.warnings.append(
                {
                    "code": "MAINT004",
                    "message": "Deep nesting detected - consider refactoring",
                    "severity": "medium",
                }
            )

        # Check for missing comments
        comment_ratio = (
            len([l for l in lines if "--" in l]) / max(len(lines), 1)
        ) * 100
        if comment_ratio < 5 and len(lines) > 50:
            result.suggestions.append(
                {
                    "code": "MAINT005",
                    "message": f"Low comment ratio ({comment_ratio:.1f}%) - add documentation",
                    "severity": "low",
                }
            )

    def suggest_improvements(self, code: str) -> list:
        """Generate specific improvement suggestions."""
        suggestions = []
        analysis = self.analyze(code)

        for issue in analysis.issues + analysis.warnings + analysis.suggestions:
            suggestions.append(
                {
                    "type": issue["code"],
                    "message": issue["message"],
                    "severity": issue["severity"],
                }
            )

        return suggestions
