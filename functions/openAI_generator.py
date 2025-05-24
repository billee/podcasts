# openai_generator.py
import openai
from dotenv import load_dotenv
load_dotenv() # This loads the variables from .env into os.environ
import os
import logging
import json

# Set up basic logging for this module
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# --- OpenAI Configuration ---
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL_NAME = "gpt-4o-mini"

# Initialize OpenAI client
if OPENAI_API_KEY:
    client = openai.OpenAI(api_key=OPENAI_API_KEY)
else:
    logging.error("OPENAI_API_KEY environment variable not set. OpenAI calls will fail.")
    client = None # Set client to None if API key is missing

def generate_openai_response(messages: list) -> dict:
    if client is None:
        return {
            "content": "OpenAI API key is not configured. Please set the OPENAI_API_KEY environment variable.",
            "success": False,
            "error_type": "api_key_missing"
        }

    # logging.info(f"openai_generator: Messages to be sent to OpenAI: {json.dumps(messages, indent=2)}")

    try:
        completion = client.chat.completions.create(
            model=OPENAI_MODEL_NAME,
            messages=messages,
            temperature=0,
            top_p=0.9,
            max_tokens=500 # Set a reasonable max_tokens to control response length
        )

        generated_answer = completion.choices[0].message.content

        logging.info(f"\nopenai_generator: OpenAI Generated Answer: {generated_answer}")

        return {
            "content": generated_answer,
            "success": True
        }

    except openai.APIError as api_e:
        logging.error(f"openai_generator: Error calling OpenAI API: {api_e}", exc_info=True)
        return {
            "content": f"May problema sa pagkuha ng sagot mula sa AI (OpenAI API error: {api_e.status_code}). Subukan ulit mamaya.",
            "success": False,
            "error_type": "openai_api_error"
        }
    except Exception as llm_e:
        logging.error(f"openai_generator: Error processing OpenAI response or general LLM error: {llm_e}", exc_info=True)
        return {
            "content": "May problema sa pagbuo ng sagot. Subukan ulit mamaya. (General LLM Error)",
            "success": False,
            "error_type": "general_llm_error"
        }

# if __name__ == '__main__':
#     # Example usage for testing this module directly
#     # NOTE: For this to work, you MUST have OPENAI_API_KEY set in your environment
#     print("--- Running openai_generator.py test ---")
#     test_messages = [
#         {"role": "system", "content": "You are a helpful assistant."},
#         {"role": "user", "content": "What is the capital of Canada?"}
#     ]
#     response = generate_openai_response(test_messages)
#     print("\n--- Test Response from openai_generator ---")
#     print(response)
#
#     test_messages_2 = [
#         {"role": "user", "content": "Tell me a short story."}
#     ]
#     response_2 = generate_openai_response(test_messages_2)
#     print("\n--- Another Test Response ---")
#     print(response_2)