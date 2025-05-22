# llama_generator.py
import requests
import json
import logging

# Set up basic logging for this module
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# --- Ollama Configuration ---
# Ensure these match your Ollama setup
OLLAMA_API_URL = "http://localhost:11434/api/chat" # <-- Your Ollama API endpoint
OLLAMA_MODEL_NAME = "llama3.2:latest" # <-- Your Llama model name

def generate_ollama_response(messages: list) -> dict:
    """
    Makes an API call to Ollama to generate a response based on the given messages.
    Returns a dictionary containing the generated content, or an error message.
    """
    logging.info(f"llama_generator: Messages to be sent to Ollama: {json.dumps(messages, indent=2)}")

    try:
        ollama_payload = {
            'model': OLLAMA_MODEL_NAME,
            'messages': messages,
            'stream': False,
            'temperature': 0.7,
            'top_p': 0.9,
        }
        ollama_response = requests.post(
            OLLAMA_API_URL,
            headers={'Content-Type': 'application/json'},
            json=ollama_payload
        )
        ollama_response.raise_for_status() # Raise an HTTPError for bad responses (4xx or 5xx)

        ollama_data = ollama_response.json()
        generated_answer = ollama_data['message']['content']

        logging.info(f"llama_generator: Ollama Generated Answer: {generated_answer}")

        return {
            "content": generated_answer,
            "success": True,
        }

    except requests.exceptions.RequestException as req_e:
        logging.error(f"llama_generator: Error calling Ollama API: {req_e}", exc_info=True)
        return {
            "content": "May problema sa pagkuha ng sagot mula sa AI (Ollama API error). Subukan ulit mamaya.",
            "success": False,
            "error_type": "ollama_api_error"
        }
    except Exception as llm_e:
        logging.error(f"llama_generator: Error processing Ollama response or general LLM error: {llm_e}", exc_info=True)
        return {
            "content": "May problema sa pagbuo ng sagot. Subukan ulit mamaya. (General LLM Error)",
            "success": False,
            "error_type": "general_llm_error"
        }

# if __name__ == '__main__':
#     # Example usage for testing this module directly
#     test_messages = [
#         {"role": "system", "content": "You are a helpful assistant."},
#         {"role": "user", "content": "What is the capital of France?"}
#     ]
#     response = generate_ollama_response(test_messages)
#     print("\n--- Test Response from llama_generator ---")
#     print(response)