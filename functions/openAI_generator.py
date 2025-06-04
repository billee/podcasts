# openai_generator.py
import openai
from dotenv import load_dotenv
load_dotenv()
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
    client = None

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
            "content": f"There is an issue on retriving the answer (OpenAI API error: {api_e.status_code}). Please try again.",
            "success": False,
            "error_type": "openai_api_error"
        }
    except Exception as llm_e:
        logging.error(f"openai_generator: Error processing OpenAI response or general LLM error: {llm_e}", exc_info=True)
        return {
            "content": "There is an issue on retrieving the answer. Please try again. (General LLM Error)",
            "success": False,
            "error_type": "general_llm_error"
        }
