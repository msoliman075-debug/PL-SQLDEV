"""
Oracle Database Executor - PL/SQL deployment and analysis tool
Compatible with Oracle 19c
"""
import os
import re
from typing import Optional
from dataclasses import dataclass

import oracledb


@dataclass
class ObjectInfo:
    owner: str
    name: str
    object_type: str
    status: str
    last_ddl_time: str


class OracleExecutor:
    """Execute PL/SQL operations against Oracle 19c database."""

    def __init__(
        self,
        host: str = None,
        port: int = 1521,
        service_name: str = None,
        user: str = None,
        password: str = None,
        wallet_path: Optional[str] = None,
    ):
        self.host = host or os.getenv("ORACLE_HOST", "localhost")
        self.port = port or int(os.getenv("ORACLE_PORT", 1521))
        self.service_name = service_name or os.getenv("ORACLE_SERVICE", "ORCL")
        self.user = user or os.getenv("ORACLE_USER")
        self.password = password or os.getenv("ORACLE_PASSWORD")
        self.wallet_path = wallet_path or os.getenv("ORACLE_WALLET_PATH")

        if not self.user or not self.password:
            raise ValueError("ORACLE_USER and ORACLE_PASSWORD must be set")

        self.dsn = f"{self.host}:{self.port}/{self.service_name}"

    def _get_connection(self):
        """Get database connection with optional wallet."""
        params = {"user": self.user, "password": self.password, "dsn": self.dsn}
        if self.wallet_path:
            params["config_dir"] = self.wallet_path
            params["wallet_location"] = self.wallet_path
            params["wallet_password"] = os.getenv("ORACLE_WALLET_PASSWORD", "")
        return oracledb.connect(**params)

    def execute_ddl(self, ddl: str) -> dict:
        """
        Deploy PL/SQL object (package, procedure, function, etc.)
        Returns deployment status and any compilation errors.
        """
        object_name = self._extract_object_name(ddl)
        object_type = self._extract_object_type(ddl)

        with self._get_connection() as conn:
            with conn.cursor() as cur:
                try:
                    cur.execute(ddl)
                    conn.commit()

                    # Check for compilation errors
                    errors = self.get_errors(object_name, self.user.upper())

                    return {
                        "status": "compiled_with_errors" if errors else "success",
                        "object_name": object_name,
                        "object_type": object_type,
                        "errors": errors,
                    }
                except oracledb.Error as e:
                    return {
                        "status": "failed",
                        "object_name": object_name,
                        "object_type": object_type,
                        "errors": [{"line": 0, "position": 0, "text": str(e)}],
                    }

    def get_source(self, object_type: str, object_name: str, owner: str) -> str:
        """Retrieve PL/SQL source code from database."""
        sql = """
            SELECT text 
            FROM all_source 
            WHERE owner = UPPER(:owner) 
              AND name = UPPER(:name) 
              AND type = UPPER(:type)
            ORDER BY line
        """
        with self._get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    sql, {"owner": owner, "name": object_name, "type": object_type}
                )
                rows = cur.fetchall()
                if not rows:
                    return f"-- Object {owner}.{object_name} ({object_type}) not found"
                return "".join(row[0] for row in rows)

    def get_package_source(self, package_name: str, owner: str) -> dict:
        """Get both package spec and body."""
        return {
            "specification": self.get_source("PACKAGE", package_name, owner),
            "body": self.get_source("PACKAGE BODY", package_name, owner),
        }

    def get_errors(self, object_name: str, owner: str) -> list:
        """Get compilation errors for an object."""
        sql = """
            SELECT line, position, text, attribute
            FROM all_errors
            WHERE owner = UPPER(:owner) 
              AND name = UPPER(:name)
            ORDER BY type, sequence
        """
        with self._get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, {"owner": owner, "name": object_name})
                return [
                    {
                        "line": row[0],
                        "position": row[1],
                        "text": row[2].strip(),
                        "type": row[3],
                    }
                    for row in cur.fetchall()
                ]

    def get_dependencies(self, object_name: str, owner: str) -> dict:
        """Get object dependencies (what it uses and what uses it)."""
        uses_sql = """
            SELECT referenced_owner, referenced_name, referenced_type
            FROM all_dependencies
            WHERE owner = UPPER(:owner) AND name = UPPER(:name)
            ORDER BY referenced_type, referenced_name
        """
        used_by_sql = """
            SELECT owner, name, type
            FROM all_dependencies
            WHERE referenced_owner = UPPER(:owner) AND referenced_name = UPPER(:name)
            ORDER BY type, name
        """
        with self._get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(uses_sql, {"owner": owner, "name": object_name})
                uses = [
                    {"owner": r[0], "name": r[1], "type": r[2]} for r in cur.fetchall()
                ]

                cur.execute(used_by_sql, {"owner": owner, "name": object_name})
                used_by = [
                    {"owner": r[0], "name": r[1], "type": r[2]} for r in cur.fetchall()
                ]

        return {"uses": uses, "used_by": used_by}

    def get_object_info(self, object_name: str, owner: str) -> Optional[ObjectInfo]:
        """Get object metadata."""
        sql = """
            SELECT owner, object_name, object_type, status, 
                   TO_CHAR(last_ddl_time, 'YYYY-MM-DD HH24:MI:SS') as last_ddl
            FROM all_objects
            WHERE owner = UPPER(:owner) AND object_name = UPPER(:name)
        """
        with self._get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, {"owner": owner, "name": object_name})
                row = cur.fetchone()
                if row:
                    return ObjectInfo(
                        owner=row[0],
                        name=row[1],
                        object_type=row[2],
                        status=row[3],
                        last_ddl_time=row[4],
                    )
        return None

    def search_objects(
        self, pattern: str, owner: str, object_type: str = None
    ) -> list:
        """Search for objects matching a pattern."""
        sql = """
            SELECT object_name, object_type, status
            FROM all_objects
            WHERE owner = UPPER(:owner)
              AND object_name LIKE UPPER(:pattern)
        """
        params = {"owner": owner, "pattern": f"%{pattern}%"}

        if object_type:
            sql += " AND object_type = UPPER(:obj_type)"
            params["obj_type"] = object_type

        sql += " ORDER BY object_type, object_name"

        with self._get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, params)
                return [
                    {"name": r[0], "type": r[1], "status": r[2]} for r in cur.fetchall()
                ]

    def search_code(self, pattern: str, owner: str, object_type: str = None) -> list:
        """Search for pattern in PL/SQL source code."""
        sql = """
            SELECT name, type, line, text
            FROM all_source
            WHERE owner = UPPER(:owner)
              AND UPPER(text) LIKE UPPER(:pattern)
        """
        params = {"owner": owner, "pattern": f"%{pattern}%"}

        if object_type:
            sql += " AND type = UPPER(:obj_type)"
            params["obj_type"] = object_type

        sql += " ORDER BY name, line FETCH FIRST 100 ROWS ONLY"

        with self._get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, params)
                return [
                    {"name": r[0], "type": r[1], "line": r[2], "text": r[3].strip()}
                    for r in cur.fetchall()
                ]

    def get_invalid_objects(self, owner: str) -> list:
        """Get all invalid objects for an owner."""
        sql = """
            SELECT object_name, object_type, 
                   TO_CHAR(last_ddl_time, 'YYYY-MM-DD HH24:MI:SS') as last_ddl
            FROM all_objects
            WHERE owner = UPPER(:owner) AND status = 'INVALID'
            ORDER BY object_type, object_name
        """
        with self._get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, {"owner": owner})
                return [
                    {"name": r[0], "type": r[1], "last_ddl": r[2]}
                    for r in cur.fetchall()
                ]

    def recompile_object(self, object_name: str, owner: str, object_type: str) -> dict:
        """Recompile an invalid object."""
        compile_sql = {
            "PACKAGE": f'ALTER PACKAGE "{owner}"."{object_name}" COMPILE',
            "PACKAGE BODY": f'ALTER PACKAGE "{owner}"."{object_name}" COMPILE BODY',
            "PROCEDURE": f'ALTER PROCEDURE "{owner}"."{object_name}" COMPILE',
            "FUNCTION": f'ALTER FUNCTION "{owner}"."{object_name}" COMPILE',
            "TRIGGER": f'ALTER TRIGGER "{owner}"."{object_name}" COMPILE',
            "VIEW": f'ALTER VIEW "{owner}"."{object_name}" COMPILE',
        }

        sql = compile_sql.get(object_type.upper())
        if not sql:
            return {"status": "failed", "error": f"Unknown object type: {object_type}"}

        with self._get_connection() as conn:
            with conn.cursor() as cur:
                try:
                    cur.execute(sql)
                    errors = self.get_errors(object_name, owner)
                    return {
                        "status": "compiled_with_errors" if errors else "success",
                        "errors": errors,
                    }
                except oracledb.Error as e:
                    return {"status": "failed", "error": str(e)}

    def execute_query(self, sql: str, params: dict = None) -> list:
        """Execute a SELECT query and return results."""
        with self._get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, params or {})
                columns = [col[0] for col in cur.description]
                return [dict(zip(columns, row)) for row in cur.fetchall()]

    def _extract_object_name(self, ddl: str) -> str:
        """Extract object name from DDL statement."""
        patterns = [
            r"CREATE\s+(?:OR\s+REPLACE\s+)?(?:PACKAGE|PROCEDURE|FUNCTION|TRIGGER|VIEW)\s+(?:BODY\s+)?(?:\w+\.)?(\w+)",
            r"CREATE\s+(?:OR\s+REPLACE\s+)?TYPE\s+(?:BODY\s+)?(?:\w+\.)?(\w+)",
        ]
        for pattern in patterns:
            match = re.search(pattern, ddl, re.IGNORECASE)
            if match:
                return match.group(1).upper()
        return "UNKNOWN"

    def _extract_object_type(self, ddl: str) -> str:
        """Extract object type from DDL statement."""
        ddl_upper = ddl.upper()
        if "PACKAGE BODY" in ddl_upper:
            return "PACKAGE BODY"
        elif "PACKAGE" in ddl_upper:
            return "PACKAGE"
        elif "PROCEDURE" in ddl_upper:
            return "PROCEDURE"
        elif "FUNCTION" in ddl_upper:
            return "FUNCTION"
        elif "TRIGGER" in ddl_upper:
            return "TRIGGER"
        elif "VIEW" in ddl_upper:
            return "VIEW"
        elif "TYPE BODY" in ddl_upper:
            return "TYPE BODY"
        elif "TYPE" in ddl_upper:
            return "TYPE"
        return "UNKNOWN"
