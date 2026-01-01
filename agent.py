import os
from typing import Optional
from dotenv import load_dotenv
from langchain_openai import ChatOpenAI
from langchain.agents import tool, AgentExecutor, create_openai_tools_agent
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
import oracledb

# Load environment variables
load_dotenv()

# --- Oracle Database Tools ---

def get_connection():
    """Establishes a connection to the Oracle database using env vars."""
    try:
        user = os.getenv("ORACLE_USER")
        password = os.getenv("ORACLE_PASSWORD")
        dsn = os.getenv("ORACLE_DSN")
        
        if not (user and password and dsn):
            return None
            
        return oracledb.connect(user=user, password=password, dsn=dsn)
    except Exception as e:
        print(f"Connection failed: {e}")
        return None

@tool
def check_db_status() -> str:
    """Checks if the Oracle database is reachable."""
    conn = get_connection()
    if conn:
        conn.close()
        return "Oracle Database is reachable."
    else:
        return "Oracle Database is NOT reachable. Please check environment variables (ORACLE_USER, ORACLE_PASSWORD, ORACLE_DSN)."

@tool
def run_oracle_query(sql_query: str) -> str:
    """Executes a SELECT query against the Oracle database.
    Use this to inspect schema, existing objects, or data.
    """
    conn = get_connection()
    if not conn:
        return "Error: No database connection available."
    
    try:
        cursor = conn.cursor()
        cursor.execute(sql_query)
        columns = [col[0] for col in cursor.description]
        rows = cursor.fetchmany(10) # Limit to 10 rows for safety
        cursor.close()
        conn.close()
        
        result = f"Columns: {', '.join(columns)}\n"
        for row in rows:
            result += str(row) + "\n"
        return result
    except Exception as e:
        return f"SQL Execution Error: {str(e)}"

@tool
def execute_ddl(ddl_statement: str) -> str:
    """Executes a DDL statement (CREATE, ALTER, DROP) or DML (INSERT, UPDATE).
    Use this to compile packages, procedures, or modify tables.
    """
    # Safety check for destructive commands could go here
    conn = get_connection()
    if not conn:
        return "Error: No database connection available. I will generate the code but cannot execute it."
    
    try:
        cursor = conn.cursor()
        cursor.execute(ddl_statement)
        conn.commit()
        cursor.close()
        conn.close()
        return "Statement executed successfully."
    except Exception as e:
        return f"DDL Execution Error: {str(e)}"

# --- File System Tools ---

@tool
def read_file(file_path: str) -> str:
    """Reads the content of a local file (e.g., .sql, .pll, .txt)."""
    try:
        if not os.path.exists(file_path):
            return "File not found."
        with open(file_path, 'r') as f:
            return f.read()
    except Exception as e:
        return f"Error reading file: {str(e)}"

@tool
def save_file(file_path: str, content: str) -> str:
    """Saves text content to a file. Use this to save generated SQL/PLSQL code."""
    try:
        directory = os.path.dirname(file_path)
        if directory and not os.path.exists(directory):
            os.makedirs(directory)
        with open(file_path, 'w') as f:
            f.write(content)
        return f"File saved successfully to {file_path}"
    except Exception as e:
        return f"Error saving file: {str(e)}"

# --- Main Agent Builder ---

def build_agent():
    # Initialize LLM
    llm = ChatOpenAI(
        model="gpt-4o", 
        temperature=0,
        api_key=os.getenv("OPENAI_API_KEY")
    )

    # Define tools available to the agent
    tools = [
        check_db_status, 
        run_oracle_query, 
        execute_ddl,
        read_file,
        save_file
    ]

    # Create the prompt
    system_message = """You are an expert Oracle Developer and Automation Agent.
    Your capabilities include:
    1.  **PL/SQL Development**: Writing high-performance Packages, Procedures, and Functions.
        -   Follow best practices (BULK COLLECT, FORALL, Exception Handling).
        -   Target Oracle 11g-19c compatibility.
    2.  **Oracle Forms Assistance**:
        -   Analyzing logic from Forms (triggers, program units) provided as text.
        -   Suggesting fixes and enhancements for Forms logic.
    3.  **File Management**: Reading and writing SQL scripts to the local filesystem.

    When asked to build or fix something:
    -   First, plan the structure.
    -   If a DB connection is configured, check for existing objects.
    -   Generate the code and save it to a .sql file using `save_file`.
    -   If the user asks to "deploy" or "run", use `execute_ddl`.

    Always act with "Enterprise Security" in mind (least privilege, no hardcoded secrets).
    """

    prompt = ChatPromptTemplate.from_messages([
        ("system", system_message),
        ("user", "{input}"),
        MessagesPlaceholder(variable_name="agent_scratchpad"),
    ])

    # Construct the agent
    agent = create_openai_tools_agent(llm, tools, prompt)
    
    # Create the executor
    agent_executor = AgentExecutor(agent=agent, tools=tools, verbose=True)
    
    return agent_executor

if __name__ == "__main__":
    if not os.getenv("OPENAI_API_KEY"):
        print("Error: OPENAI_API_KEY not found in environment variables.")
        print("Please set it in .env file.")
        exit(1)

    agent = build_agent()
    
    print("Oracle Agentic AI Initialized.")
    print("Enter your request (or 'exit' to quit):")
    
    while True:
        try:
            user_query = input("> ")
            if user_query.lower() in ['exit', 'quit']:
                break
            
            result = agent.invoke({"input": user_query})
            print(f"\nResult: {result['output']}\n")
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}")
