"""
PL/SQL Development Agent
Handles package, procedure, and function development for Oracle 19c
"""
import os
from pathlib import Path
from typing import Annotated

from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain.agents import create_tool_calling_agent, AgentExecutor

from tools.oracle_executor import OracleExecutor
from tools.code_analyzer import PLSQLAnalyzer
from tools.git_ops import GitOperations


# Load standards from prompts
PROMPTS_DIR = Path(__file__).parent.parent / "prompts"
PLSQL_STANDARDS = ""
if (PROMPTS_DIR / "plsql_standards.md").exists():
    PLSQL_STANDARDS = (PROMPTS_DIR / "plsql_standards.md").read_text()


SYSTEM_PROMPT = f"""You are an expert Oracle PL/SQL developer specializing in Oracle 19c.
Your role is to develop, analyze, fix, and optimize PL/SQL code including packages, procedures, and functions.

## Your Capabilities:
1. Retrieve and analyze existing PL/SQL objects from the database
2. Create new packages, procedures, and functions
3. Fix compilation errors and bugs
4. Optimize code for performance
5. Ensure code follows standards and best practices
6. Save code to version control

## Development Standards:
{PLSQL_STANDARDS}

## Guidelines:
- Always retrieve existing code before making modifications
- Analyze code for issues before suggesting fixes
- Use BULK COLLECT/FORALL for processing >100 rows
- Include proper exception handling with SQLERRM logging
- Follow naming conventions strictly
- Validate changes by checking for compilation errors after deployment
- Save all changes to git with meaningful commit messages

When asked to fix or modify code:
1. First retrieve the current source
2. Analyze it for issues
3. Generate the corrected code
4. Deploy it to the database
5. Check for compilation errors
6. Save to version control if successful
"""


class PLSQLAgent:
    """Agent for PL/SQL development tasks."""

    def __init__(self, config: dict = None):
        self.config = config or {}
        self.db = OracleExecutor()
        self.analyzer = PLSQLAnalyzer(self.config.get("standards", {}).get("plsql", {}))
        self.git = GitOperations(self.config.get("git", {}).get("repo_path"))

        self.llm = ChatOpenAI(
            model=self.config.get("llm", {}).get("model", "gpt-4o"),
            temperature=self.config.get("llm", {}).get("temperature", 0),
        )

        self.tools = self._create_tools()
        self.agent = self._create_agent()

    def _create_tools(self):
        """Create LangChain tools from methods."""
        db = self.db
        analyzer = self.analyzer
        git = self.git

        @tool
        def get_object_source(
            object_name: Annotated[str, "Name of the PL/SQL object"],
            object_type: Annotated[str, "Type: PACKAGE, PACKAGE BODY, PROCEDURE, FUNCTION"],
            owner: Annotated[str, "Schema owner, default APPS"] = "APPS",
        ) -> str:
            """Retrieve PL/SQL source code from the database."""
            return db.get_source(object_type, object_name, owner)

        @tool
        def get_package_full(
            package_name: Annotated[str, "Name of the package"],
            owner: Annotated[str, "Schema owner"] = "APPS",
        ) -> dict:
            """Get both package specification and body."""
            return db.get_package_source(package_name, owner)

        @tool
        def deploy_plsql(
            ddl_statement: Annotated[str, "Complete CREATE OR REPLACE statement"],
        ) -> dict:
            """Deploy PL/SQL code to the database. Returns status and any errors."""
            return db.execute_ddl(ddl_statement)

        @tool
        def get_compilation_errors(
            object_name: Annotated[str, "Name of the object"],
            owner: Annotated[str, "Schema owner"] = "APPS",
        ) -> list:
            """Get compilation errors for an object."""
            return db.get_errors(object_name, owner)

        @tool
        def analyze_code(
            plsql_code: Annotated[str, "PL/SQL code to analyze"],
        ) -> dict:
            """Analyze PL/SQL code for issues, anti-patterns, and improvements."""
            result = analyzer.analyze(plsql_code)
            return {
                "score": result.score,
                "issues": result.issues,
                "warnings": result.warnings,
                "suggestions": result.suggestions,
                "metrics": result.metrics,
            }

        @tool
        def get_dependencies(
            object_name: Annotated[str, "Name of the object"],
            owner: Annotated[str, "Schema owner"] = "APPS",
        ) -> dict:
            """Get object dependencies (what it uses and what uses it)."""
            return db.get_dependencies(object_name, owner)

        @tool
        def search_code(
            pattern: Annotated[str, "Search pattern"],
            owner: Annotated[str, "Schema owner"] = "APPS",
            object_type: Annotated[str, "Optional: filter by type"] = None,
        ) -> list:
            """Search for pattern in PL/SQL source code."""
            return db.search_code(pattern, owner, object_type)

        @tool
        def get_invalid_objects(
            owner: Annotated[str, "Schema owner"] = "APPS",
        ) -> list:
            """Get all invalid objects for a schema."""
            return db.get_invalid_objects(owner)

        @tool
        def recompile_object(
            object_name: Annotated[str, "Name of the object"],
            object_type: Annotated[str, "Type: PACKAGE, PROCEDURE, FUNCTION, etc."],
            owner: Annotated[str, "Schema owner"] = "APPS",
        ) -> dict:
            """Recompile an invalid object."""
            return db.recompile_object(object_name, owner, object_type)

        @tool
        def save_to_git(
            object_name: Annotated[str, "Name of the object"],
            object_type: Annotated[str, "Type: PACKAGE, PROCEDURE, FUNCTION"],
            code: Annotated[str, "PL/SQL source code"],
            commit_message: Annotated[str, "Git commit message"],
            owner: Annotated[str, "Schema owner"] = "APPS",
        ) -> dict:
            """Save PL/SQL code to git repository."""
            save_result = git.save_plsql(object_name, object_type, code, owner)
            if save_result["status"] == "saved":
                commit_result = git.commit_changes(
                    commit_message, [save_result["relative_path"]]
                )
                return {**save_result, **commit_result}
            return save_result

        @tool
        def execute_query(
            sql: Annotated[str, "SELECT query to execute"],
        ) -> list:
            """Execute a SELECT query and return results (max 100 rows)."""
            return db.execute_query(sql + " FETCH FIRST 100 ROWS ONLY")

        return [
            get_object_source,
            get_package_full,
            deploy_plsql,
            get_compilation_errors,
            analyze_code,
            get_dependencies,
            search_code,
            get_invalid_objects,
            recompile_object,
            save_to_git,
            execute_query,
        ]

    def _create_agent(self):
        """Create the LangChain agent."""
        prompt = ChatPromptTemplate.from_messages([
            ("system", SYSTEM_PROMPT),
            ("human", "{input}"),
            ("placeholder", "{agent_scratchpad}"),
        ])

        agent = create_tool_calling_agent(self.llm, self.tools, prompt)
        return AgentExecutor(
            agent=agent,
            tools=self.tools,
            verbose=True,
            max_iterations=15,
            handle_parsing_errors=True,
        )

    def run(self, task: str) -> dict:
        """Execute a PL/SQL development task."""
        return self.agent.invoke({"input": task})

    def analyze_object(self, object_name: str, object_type: str, owner: str = "APPS") -> dict:
        """Analyze a specific object and return recommendations."""
        code = self.db.get_source(object_type, object_name, owner)
        analysis = self.analyzer.analyze(code)
        errors = self.db.get_errors(object_name, owner)
        deps = self.db.get_dependencies(object_name, owner)

        return {
            "object": f"{owner}.{object_name}",
            "type": object_type,
            "analysis": {
                "score": analysis.score,
                "issues": analysis.issues,
                "warnings": analysis.warnings,
                "suggestions": analysis.suggestions,
            },
            "compilation_errors": errors,
            "dependencies": deps,
        }
