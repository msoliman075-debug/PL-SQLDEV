# Agentic AI Starter

A basic agentic AI framework using LangChain and OpenAI.

## Setup

1.  **Install Dependencies:**
    ```bash
    pip install -r requirements.txt
    ```

2.  **Configuration:**
    Copy the example environment file and add your OpenAI API key:
    ```bash
    cp .env.example .env
    # Edit .env and add your OPENAI_API_KEY
    ```

3.  **Run the Agent:**
    ```bash
    python agent.py
    ```

## Extending

-   **Add Tools:** Define new functions decorated with `@tool` in `agent.py` and add them to the `tools` list.
-   **Change Model:** Update the `ChatOpenAI` initialization in `agent.py` to use a different model or provider.
