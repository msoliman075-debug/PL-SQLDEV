# Oracle AI Development Agent

Agentic AI for Oracle PL/SQL and Forms 12c development automation.

## Features

- **PL/SQL Development**: Create, analyze, fix, and optimize packages, procedures, and functions
- **Oracle Forms 12c**: Analyze form structure, extract PL/SQL, compile forms
- **Code Analysis**: Static analysis for quality, performance, and security issues
- **Git Integration**: Version control for all PL/SQL objects
- **Standards Compliance**: Enforces naming conventions and best practices

## Requirements

- Python 3.10+
- Oracle 19c database access
- Oracle Forms 12c (for forms features)
- OpenAI API key

## Installation

```bash
cd oracle-ai-agent
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Configuration

1. Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

2. Edit `.env` with your credentials:
```bash
ORACLE_HOST=your-db-host
ORACLE_SERVICE=PROD
ORACLE_USER=apps
ORACLE_PASSWORD=your-password
OPENAI_API_KEY=sk-your-key
```

3. Optionally customize `config.yaml` for naming conventions and paths.

## Usage

### Interactive Mode
```bash
python main.py -i
```

### Single Task
```bash
python main.py "Fix compilation errors in APPS.PKG_ORDER_PROCESS"
```

### Commands

```bash
# Fix compilation errors
python main.py fix PKG_ORDER_PROCESS -o APPS

# Create a procedure
python main.py create-proc PRC_ARCHIVE_ORDERS \
    -d "Archive orders older than 1 year" \
    -p "p_cutoff_date DATE, p_count OUT NUMBER"

# Create a function
python main.py create-func FNC_CALC_TAX \
    -d "Calculate tax for an order" \
    -p "p_order_id NUMBER, p_region VARCHAR2" \
    -r "NUMBER"

# Analyze an object
python main.py analyze PKG_INVENTORY -t PACKAGE -o APPS

# Optimize for performance
python main.py optimize PKG_INVENTORY -t PACKAGE

# Analyze Oracle Form
python main.py analyze-form /path/to/form.fmb
```

## Example Tasks

```python
from agents.orchestrator import OracleDevOrchestrator

agent = OracleDevOrchestrator()

# Fix errors
agent.fix_compilation_errors("PKG_ORDER_PROCESS")

# Create procedure
agent.create_procedure(
    name="PRC_UPDATE_CUSTOMER",
    description="Update customer contact information",
    parameters="p_customer_id NUMBER, p_email VARCHAR2, p_phone VARCHAR2"
)

# Optimize package
agent.optimize_object("PKG_INVENTORY", "PACKAGE")
```

## Project Structure

```
oracle-ai-agent/
├── agents/
│   ├── plsql_agent.py     # PL/SQL development agent
│   ├── forms_agent.py     # Oracle Forms agent
│   └── orchestrator.py    # Task orchestrator
├── tools/
│   ├── oracle_executor.py # Database operations
│   ├── forms_compiler.py  # Forms compilation
│   ├── code_analyzer.py   # Static analysis
│   └── git_ops.py         # Version control
├── prompts/
│   ├── plsql_standards.md # PL/SQL coding standards
│   └── forms_standards.md # Forms development standards
├── templates/             # Code templates
├── config.yaml           # Configuration
└── main.py               # Entry point
```

## Code Analysis Checks

| Code | Description | Severity |
|------|-------------|----------|
| PERF001 | SELECT * usage | High |
| PERF002 | Missing BULK COLLECT | Medium |
| PERF003 | Row-by-row DML in loop | Medium |
| ERR001 | Swallowed exceptions | Critical |
| ERR002 | Missing exception handling | Medium |
| SEC001 | SQL injection risk | Critical |
| NAME001 | Naming convention violation | Low |

## Security Notes

- Never store credentials in config files
- Use environment variables or Oracle Wallet
- Agent uses least-privilege database access
- All dynamic SQL uses bind variables
