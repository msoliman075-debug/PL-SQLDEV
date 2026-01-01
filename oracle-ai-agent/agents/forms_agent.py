"""
Oracle Forms 12c Development Agent
Handles form analysis, fixes, and enhancements
"""
import os
from pathlib import Path
from typing import Annotated

from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain.agents import create_tool_calling_agent, AgentExecutor

from tools.forms_compiler import FormsCompiler
from tools.code_analyzer import PLSQLAnalyzer
from tools.git_ops import GitOperations


# Load standards
PROMPTS_DIR = Path(__file__).parent.parent / "prompts"
FORMS_STANDARDS = ""
if (PROMPTS_DIR / "forms_standards.md").exists():
    FORMS_STANDARDS = (PROMPTS_DIR / "forms_standards.md").read_text()


SYSTEM_PROMPT = f"""You are an expert Oracle Forms 12c developer.
Your role is to analyze, fix, and enhance Oracle Forms modules.

## Your Capabilities:
1. Analyze form structure (blocks, items, triggers, program units)
2. Extract and analyze PL/SQL code from forms
3. Fix issues in form triggers and program units
4. Compile forms and report errors
5. Suggest improvements and optimizations
6. Convert forms to/from XML for analysis

## Development Standards:
{FORMS_STANDARDS}

## Guidelines:
- Always analyze the form structure before making changes
- Extract PL/SQL code for detailed analysis
- Use database packages for complex logic instead of form triggers
- Follow naming conventions for all form objects
- Test compilation after making changes
- Document all changes made

When fixing form issues:
1. First analyze the form to understand its structure
2. Extract relevant PL/SQL code
3. Identify the root cause of issues
4. Suggest fixes with proper code
5. Compile and verify the fix
"""


class FormsAgent:
    """Agent for Oracle Forms development tasks."""

    def __init__(self, config: dict = None):
        self.config = config or {}
        self.forms = FormsCompiler(
            oracle_home=self.config.get("forms", {}).get("oracle_home"),
            domain_home=self.config.get("forms", {}).get("domain_home"),
            source_path=self.config.get("forms", {}).get("source_path"),
        )
        self.analyzer = PLSQLAnalyzer()
        self.git = GitOperations(self.config.get("git", {}).get("repo_path"))

        self.llm = ChatOpenAI(
            model=self.config.get("llm", {}).get("model", "gpt-4o"),
            temperature=self.config.get("llm", {}).get("temperature", 0),
        )

        self.tools = self._create_tools()
        self.agent = self._create_agent()

    def _create_tools(self):
        """Create LangChain tools."""
        forms = self.forms
        analyzer = self.analyzer
        git = self.git

        @tool
        def list_forms(
            pattern: Annotated[str, "Glob pattern to match forms"] = "*.fmb",
        ) -> list:
            """List all forms matching the pattern in the source directory."""
            return forms.list_forms(pattern)

        @tool
        def analyze_form(
            fmb_file: Annotated[str, "Path to .fmb file"],
        ) -> dict:
            """Analyze form structure - blocks, triggers, program units."""
            return forms.analyze_form(fmb_file)

        @tool
        def extract_form_plsql(
            fmb_file: Annotated[str, "Path to .fmb file"],
        ) -> dict:
            """Extract all PL/SQL code from a form."""
            return forms.extract_plsql(fmb_file)

        @tool
        def compile_form(
            fmb_file: Annotated[str, "Path to .fmb file"],
            userid: Annotated[str, "Database connection (user/pass@db)"] = None,
        ) -> dict:
            """Compile .fmb to .fmx and report any errors."""
            return forms.compile_form(fmb_file, userid)

        @tool
        def convert_form_to_xml(
            fmb_file: Annotated[str, "Path to .fmb file"],
        ) -> dict:
            """Convert .fmb to XML for text-based analysis and editing."""
            return forms.convert_to_xml(fmb_file)

        @tool
        def convert_xml_to_form(
            xml_file: Annotated[str, "Path to XML file"],
        ) -> dict:
            """Convert XML back to .fmb binary."""
            return forms.convert_from_xml(xml_file)

        @tool
        def analyze_plsql_code(
            code: Annotated[str, "PL/SQL code to analyze"],
        ) -> dict:
            """Analyze PL/SQL code for issues and improvements."""
            result = analyzer.analyze(code)
            return {
                "score": result.score,
                "issues": result.issues,
                "warnings": result.warnings,
                "suggestions": result.suggestions,
            }

        @tool
        def save_form_changes(
            form_name: Annotated[str, "Name of the form"],
            change_description: Annotated[str, "Description of changes made"],
            files: Annotated[list, "List of modified files"],
        ) -> dict:
            """Commit form changes to git."""
            return git.commit_changes(
                f"Forms: {form_name} - {change_description}",
                files
            )

        return [
            list_forms,
            analyze_form,
            extract_form_plsql,
            compile_form,
            convert_form_to_xml,
            convert_xml_to_form,
            analyze_plsql_code,
            save_form_changes,
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
            max_iterations=10,
            handle_parsing_errors=True,
        )

    def run(self, task: str) -> dict:
        """Execute a Forms development task."""
        return self.agent.invoke({"input": task})

    def analyze_form_quick(self, fmb_file: str) -> dict:
        """Quick analysis of a form without full agent execution."""
        analysis = self.forms.analyze_form(fmb_file)
        if analysis["status"] != "success":
            return analysis

        # Analyze PL/SQL in program units
        plsql_issues = []
        for pu in analysis.get("program_units", []):
            if pu.get("code"):
                result = self.analyzer.analyze(pu["code"])
                if result.issues or result.warnings:
                    plsql_issues.append({
                        "program_unit": pu["name"],
                        "issues": result.issues,
                        "warnings": result.warnings,
                    })

        return {
            "form_name": analysis["form_name"],
            "blocks": len(analysis.get("blocks", [])),
            "triggers": len(analysis.get("triggers", [])),
            "program_units": len(analysis.get("program_units", [])),
            "plsql_issues": plsql_issues,
        }
