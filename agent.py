import os
from dotenv import load_dotenv
from langchain_openai import ChatOpenAI
from langchain.agents import tool, AgentExecutor, create_openai_tools_agent
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder

# Load environment variables
load_dotenv()

# Define a sample tool for the "process"
@tool
def check_system_status(service_name: str) -> str:
    """Checks the status of a specific system service."""
    # In a real scenario, this would check actual system processes
    return f"Service {service_name} is running normally."

@tool
def get_resource_usage() -> str:
    """Gets current CPU and Memory usage."""
    # Placeholder for actual resource monitoring
    return "CPU: 45%, Memory: 60%"

def build_agent():
    # Initialize LLM
    llm = ChatOpenAI(
        model="gpt-4o", 
        temperature=0,
        api_key=os.getenv("OPENAI_API_KEY")
    )

    # Define tools available to the agent
    tools = [check_system_status, get_resource_usage]

    # Create the prompt
    prompt = ChatPromptTemplate.from_messages([
        ("system", "You are a helpful automation assistant. Use the available tools to answer questions."),
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
    
    user_query = "Check the status of the database service and get resource usage."
    print(f"Processing query: {user_query}")
    
    result = agent.invoke({"input": user_query})
    print(f"\nResult: {result['output']}")
