#!/usr/bin/env python3
"""
Oracle AI Development Agent
Main entry point for PL/SQL and Forms development automation
"""
import argparse
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from rich.console import Console

# Load environment variables
load_dotenv()

from agents.orchestrator import OracleDevOrchestrator


console = Console()


def main():
    parser = argparse.ArgumentParser(
        description="Oracle AI Development Agent - Automate PL/SQL and Forms development"
    )
    parser.add_argument(
        "-c", "--config",
        default="config.yaml",
        help="Path to configuration file"
    )
    parser.add_argument(
        "-i", "--interactive",
        action="store_true",
        help="Run in interactive mode"
    )
    parser.add_argument(
        "task",
        nargs="?",
        help="Development task to execute"
    )

    # Subcommands for common operations
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Fix command
    fix_parser = subparsers.add_parser("fix", help="Fix compilation errors")
    fix_parser.add_argument("object_name", help="Object name to fix")
    fix_parser.add_argument("-o", "--owner", default="APPS", help="Schema owner")

    # Create procedure command
    proc_parser = subparsers.add_parser("create-proc", help="Create a procedure")
    proc_parser.add_argument("name", help="Procedure name")
    proc_parser.add_argument("-d", "--description", required=True, help="What it does")
    proc_parser.add_argument("-p", "--parameters", default="", help="Parameters")
    proc_parser.add_argument("-o", "--owner", default="APPS", help="Schema owner")

    # Create function command
    func_parser = subparsers.add_parser("create-func", help="Create a function")
    func_parser.add_argument("name", help="Function name")
    func_parser.add_argument("-d", "--description", required=True, help="What it does")
    func_parser.add_argument("-p", "--parameters", default="", help="Parameters")
    func_parser.add_argument("-r", "--returns", required=True, help="Return type")
    func_parser.add_argument("-o", "--owner", default="APPS", help="Schema owner")

    # Analyze command
    analyze_parser = subparsers.add_parser("analyze", help="Analyze an object")
    analyze_parser.add_argument("object_name", help="Object name")
    analyze_parser.add_argument("-t", "--type", default="PACKAGE", help="Object type")
    analyze_parser.add_argument("-o", "--owner", default="APPS", help="Schema owner")

    # Optimize command
    opt_parser = subparsers.add_parser("optimize", help="Optimize for performance")
    opt_parser.add_argument("object_name", help="Object name")
    opt_parser.add_argument("-t", "--type", default="PACKAGE", help="Object type")
    opt_parser.add_argument("-o", "--owner", default="APPS", help="Schema owner")

    # Form analyze command
    form_parser = subparsers.add_parser("analyze-form", help="Analyze Oracle Form")
    form_parser.add_argument("fmb_file", help="Path to .fmb file")

    args = parser.parse_args()

    # Validate environment
    if not os.getenv("OPENAI_API_KEY"):
        console.print("[red]Error: OPENAI_API_KEY not set[/red]")
        console.print("Set it in .env file or environment variable")
        sys.exit(1)

    # Initialize orchestrator
    try:
        orchestrator = OracleDevOrchestrator(args.config)
    except Exception as e:
        console.print(f"[red]Error initializing: {e}[/red]")
        sys.exit(1)

    # Handle commands
    if args.command == "fix":
        orchestrator.fix_compilation_errors(args.object_name, args.owner)

    elif args.command == "create-proc":
        orchestrator.create_procedure(
            args.name, args.description, args.parameters, args.owner
        )

    elif args.command == "create-func":
        orchestrator.create_function(
            args.name, args.description, args.parameters, args.returns, args.owner
        )

    elif args.command == "analyze":
        result = orchestrator.plsql_agent.analyze_object(
            args.object_name, args.type, args.owner
        )
        console.print_json(data=result)

    elif args.command == "optimize":
        orchestrator.optimize_object(args.object_name, args.type, args.owner)

    elif args.command == "analyze-form":
        orchestrator.analyze_and_fix_form(args.fmb_file)

    elif args.interactive:
        orchestrator.run_interactive()

    elif args.task:
        orchestrator.run(args.task)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
