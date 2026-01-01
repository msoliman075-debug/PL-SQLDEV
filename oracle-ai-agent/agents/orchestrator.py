"""
Oracle Development Orchestrator
Routes tasks to appropriate agents and manages workflow
"""
import os
import re
import yaml
from pathlib import Path
from typing import Annotated

from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain.agents import create_tool_calling_agent, AgentExecutor
from rich.console import Console
from rich.table import Table
from rich.panel import Panel

from .plsql_agent import PLSQLAgent
from .forms_agent import FormsAgent


console = Console()


ORCHESTRATOR_PROMPT = """You are an Oracle Development Orchestrator managing PL/SQL and Forms development tasks.

Your role is to:
1. Understand the user's request
2. Route tasks to the appropriate specialized agent (PL/SQL or Forms)
3. Coordinate multi-step workflows
4. Report results clearly

## Available Agents:
- **PL/SQL Agent**: Handles packages, procedures, functions, triggers, views
- **Forms Agent**: Handles Oracle Forms 12c modules (.fmb files)

## Task Routing:
- Database objects (PKG_, PRC_, FNC_) → PL/SQL Agent
- Forms files (.fmb, .fmx) → Forms Agent
- Mixed tasks → Coordinate between agents

## Workflow Examples:

### Fix compilation errors:
1. Get current source code
2. Analyze for issues
3. Generate fix
4. Deploy and verify
5. Save to git

### Create new procedure:
1. Check for existing object
2. Generate code following standards
3. Deploy to database
4. Verify compilation
5. Save to git

### Analyze form:
1. Convert to XML if needed
2. Extract structure and PL/SQL
3. Analyze for issues
4. Generate recommendations

Always provide clear status updates and summaries of actions taken.
"""


class OracleDevOrchestrator:
    """Main orchestrator for Oracle development tasks."""

    def __init__(self, config_path: str = None):
        self.config = self._load_config(config_path)
        self.plsql_agent = PLSQLAgent(self.config)
        self.forms_agent = FormsAgent(self.config)

        self.llm = ChatOpenAI(
            model=self.config.get("llm", {}).get("model", "gpt-4o"),
            temperature=0,
        )

        self.tools = self._create_tools()
        self.agent = self._create_orchestrator()

    def _load_config(self, config_path: str = None) -> dict:
        """Load configuration from file or defaults."""
        if config_path and Path(config_path).exists():
            with open(config_path) as f:
                return yaml.safe_load(f)

        # Try default locations
        for path in ["config.yaml", "config/config.yaml"]:
            if Path(path).exists():
                with open(path) as f:
                    return yaml.safe_load(f)

        # Return defaults
        return {
            "llm": {"model": "gpt-4o", "temperature": 0},
            "standards": {
                "plsql": {
                    "naming": {
                        "package_prefix": "PKG_",
                        "procedure_prefix": "PRC_",
                        "function_prefix": "FNC_",
                    }
                }
            },
        }

    def _create_tools(self):
        """Create orchestrator tools."""
        plsql = self.plsql_agent
        forms = self.forms_agent

        @tool
        def execute_plsql_task(
            task: Annotated[str, "Description of the PL/SQL task to perform"],
        ) -> dict:
            """Execute a PL/SQL development task (packages, procedures, functions)."""
            return plsql.run(task)

        @tool
        def execute_forms_task(
            task: Annotated[str, "Description of the Forms task to perform"],
        ) -> dict:
            """Execute an Oracle Forms development task."""
            return forms.run(task)

        @tool
        def analyze_plsql_object(
            object_name: Annotated[str, "Name of the object"],
            object_type: Annotated[str, "PACKAGE, PROCEDURE, or FUNCTION"],
            owner: Annotated[str, "Schema owner"] = "APPS",
        ) -> dict:
            """Quick analysis of a PL/SQL object."""
            return plsql.analyze_object(object_name, object_type, owner)

        @tool
        def analyze_form_quick(
            fmb_file: Annotated[str, "Path to .fmb file"],
        ) -> dict:
            """Quick analysis of an Oracle Form."""
            return forms.analyze_form_quick(fmb_file)

        return [
            execute_plsql_task,
            execute_forms_task,
            analyze_plsql_object,
            analyze_form_quick,
        ]

    def _create_orchestrator(self):
        """Create the orchestrator agent."""
        prompt = ChatPromptTemplate.from_messages([
            ("system", ORCHESTRATOR_PROMPT),
            ("human", "{input}"),
            ("placeholder", "{agent_scratchpad}"),
        ])

        agent = create_tool_calling_agent(self.llm, self.tools, prompt)
        return AgentExecutor(
            agent=agent,
            tools=self.tools,
            verbose=True,
            max_iterations=20,
            handle_parsing_errors=True,
        )

    def run(self, task: str) -> dict:
        """Execute a development task."""
        console.print(Panel(f"[bold blue]Task:[/bold blue] {task}"))
        result = self.agent.invoke({"input": task})
        self._display_result(result)
        return result

    def run_interactive(self):
        """Run in interactive mode."""
        console.print(Panel(
            "[bold green]Oracle AI Development Agent[/bold green]\n"
            "Type your development tasks or 'quit' to exit.",
            title="Welcome"
        ))

        while True:
            try:
                task = console.input("\n[bold cyan]Task>[/bold cyan] ")
                if task.lower() in ("quit", "exit", "q"):
                    break
                if not task.strip():
                    continue

                self.run(task)

            except KeyboardInterrupt:
                console.print("\n[yellow]Interrupted[/yellow]")
                break

    def _display_result(self, result: dict):
        """Display result in a formatted way."""
        output = result.get("output", str(result))

        if isinstance(output, dict):
            if "status" in output:
                status_color = "green" if output["status"] == "success" else "red"
                console.print(f"[bold {status_color}]Status: {output['status']}[/bold {status_color}]")

            if "errors" in output and output["errors"]:
                console.print("[bold red]Errors:[/bold red]")
                for err in output["errors"]:
                    console.print(f"  • {err}")

        console.print(Panel(str(output)[:2000], title="Result"))

    # Direct methods for common tasks
    def fix_compilation_errors(self, object_name: str, owner: str = "APPS") -> dict:
        """Fix compilation errors for an object."""
        return self.run(
            f"Fix all compilation errors in {owner}.{object_name}. "
            "Get the current source, identify issues, fix them, and verify the fix."
        )

    def create_procedure(
        self, name: str, description: str, parameters: str, owner: str = "APPS"
    ) -> dict:
        """Create a new procedure."""
        return self.run(
            f"Create a new procedure {owner}.{name} that {description}. "
            f"Parameters: {parameters}. Follow all coding standards."
        )

    def create_function(
        self, name: str, description: str, parameters: str, return_type: str, owner: str = "APPS"
    ) -> dict:
        """Create a new function."""
        return self.run(
            f"Create a new function {owner}.{name} that {description}. "
            f"Parameters: {parameters}. Returns: {return_type}. Follow all coding standards."
        )

    def optimize_object(self, object_name: str, object_type: str, owner: str = "APPS") -> dict:
        """Analyze and optimize an object for performance."""
        return self.run(
            f"Analyze {owner}.{object_name} ({object_type}) for performance issues. "
            "Identify bottlenecks and apply optimizations using BULK COLLECT, FORALL, "
            "proper indexing hints, and other Oracle 19c best practices."
        )

    def analyze_and_fix_form(self, fmb_file: str) -> dict:
        """Analyze a form and fix identified issues."""
        return self.run(
            f"Analyze the Oracle Form {fmb_file}. "
            "Extract PL/SQL code, identify issues in triggers and program units, "
            "and suggest fixes following Forms 12c best practices."
        )
