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
            'options': {
                'temperature': 0.7,
                'top_p': 0.9,
                'num_predict': 1000,  # Add max tokens
            }
        }

        logging.info(f"llama_generator: Sending payload to Ollama: {json.dumps(ollama_payload, indent=2)}")


        ollama_response = requests.post(
            OLLAMA_API_URL,
            headers={'Content-Type': 'application/json'},
            json=ollama_payload,
            timeout=120
        )

        logging.info(f"llama_generator: Ollama response status: {ollama_response.status_code}")
        logging.info(f"llama_generator: Ollama response headers: {dict(ollama_response.headers)}")


        ollama_response.raise_for_status() # Raise an HTTPError for bad responses (4xx or 5xx)

        ollama_data = ollama_response.json()
        logging.info(f"llama_generator: Raw Ollama response: {json.dumps(ollama_data, indent=2)}")

        if 'message' in ollama_data and 'content' in ollama_data['message']:
            generated_answer = ollama_data['message']['content'].strip()

            if not generated_answer:
                logging.warning("llama_generator: Generated answer is empty")
                return {
                    "content": "Walang natanggap na sagot mula sa AI. Subukan ulit mamaya.",
                    "success": False,
                    "error_type": "empty_response"
                }

            logging.info(f"llama_generator: Ollama Generated Answer: {generated_answer}")

            return {
                "content": generated_answer,
                "success": True,
            }
        else:
            logging.error(f"llama_generator: Unexpected Ollama response structure: {ollama_data}")
            return {
                "content": "May problema sa format ng sagot mula sa AI. Subukan ulit mamaya.",
                "success": False,
                "error_type": "response_format_error"
            }

    except requests.exceptions.Timeout:
        logging.error("llama_generator: Ollama request timed out")
        return {
            "content": "Ang AI ay naging mabagal sa pagsagot. Subukan ulit mamaya.",
            "success": False,
            "error_type": "timeout_error"
        }
    except requests.exceptions.ConnectionError as conn_e:
        logging.error(f"llama_generator: Cannot connect to Ollama server: {conn_e}")
        return {
            "content": "Hindi ma-connect sa AI server. Siguraduhing nakabukas ang Ollama.",
            "success": False,
            "error_type": "connection_error"
        }

    except requests.exceptions.HTTPError as http_e:
        logging.error(f"llama_generator: HTTP error from Ollama API: {http_e}")
        logging.error(f"llama_generator: Response text: {ollama_response.text if 'ollama_response' in locals() else 'No response'}")

        # Try to extract error message from response
        error_detail = "Unknown HTTP error"
        try:
            if 'ollama_response' in locals():
                error_data = ollama_response.json()
                error_detail = error_data.get('error', error_data.get('message', str(error_data)))
        except:
            error_detail = ollama_response.text[:200] if 'ollama_response' in locals() and ollama_response.text else "No error details"

        return {
            "content": f"May problema sa AI server (HTTP {ollama_response.status_code if 'ollama_response' in locals() else 'unknown'}): {error_detail}. Subukan ulit mamaya.",
            "success": False,
            "error_type": "http_error"
        }
    except requests.exceptions.RequestException as req_e:
        logging.error(f"llama_generator: General request error calling Ollama API: {req_e}", exc_info=True)
        return {
            "content": "May problema sa pagkuha ng sagot mula sa AI (Request error). Subukan ulit mamaya.",
            "success": False,
            "error_type": "request_error"
        }
    except json.JSONDecodeError as json_e:
        logging.error(f"llama_generator: Error parsing Ollama JSON response: {json_e}")
        logging.error(f"llama_generator: Raw response: {ollama_response.text if 'ollama_response' in locals() else 'No response'}")
        return {
            "content": "May problema sa pag-parse ng sagot mula sa AI. Subukan ulit mamaya.",
            "success": False,
            "error_type": "json_parse_error"
        }
    except Exception as llm_e:
        logging.error(f"llama_generator: Unexpected error processing Ollama response: {llm_e}", exc_info=True)
        return {
            "content": "May hindi inaasahang problema sa pagbuo ng sagot. Subukan ulit mamaya.",
            "success": False,
            "error_type": "unexpected_error"
        }



if __name__ == '__main__':
    # Example usage for testing this module directly
    test_messages = [
        {"role": "system", "content": "You are a helpful assistant for Overseas Filipino Workers."},
        {"role": "user", "content": "What are the basic rights of OFWs?"}
    ]
    print("Testing llama_generator...")
    response = generate_ollama_response(test_messages)
    print("\n--- Test Response from llama_generator ---")
    print(json.dumps(response, indent=2))




# if __name__ == '__main__':
#     # Example usage for testing this module directly
#     test_messages = [
#         {"role": "system", "content": "You are a helpful assistant."},
#         {"role": "user", "content": "What is the capital of France?"}
#     ]
#     response = generate_ollama_response(test_messages)
#     print("\n--- Test Response from llama_generator ---")
#     print(response)