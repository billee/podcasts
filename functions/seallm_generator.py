# seallm_generator.py
import requests
import json
import logging

# Set up basic logging for this module
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# --- SeaLLM Configuration (optimized for Filipino/Tagalog) ---
SEALLM_API_URL = "http://localhost:11434/api/chat"
SEALLM_MODEL_NAME = "seallm-7b-v2-taglish"

def generate_seallm_response(messages: list) -> dict:
    """
    Makes an API call to SeaLLM (via Ollama) to generate culturally appropriate responses.
    SeaLLM has excellent multilingual support including Filipino/Tagalog for OFW assistance.
    """
    logging.info(f"seallm_generator: Preparing to send messages to SeaLLM for Filipino OFW response")

    try:
        seallm_payload = {
            'model': SEALLM_MODEL_NAME,
            'messages': messages,
            'stream': False,
            'options': {
                'temperature': 0.4,      # Slightly higher for more natural Filipino responses
                'top_p': 0.9,
                'num_predict': 1200,
                'repeat_penalty': 1.1,
                'top_k': 40,
                'system': "You are optimized for Taglish cultural context and OFW assistance."
            }
        }

        response = requests.post(
            SEALLM_API_URL,
            headers={'Content-Type': 'application/json'},
            json=seallm_payload,
            timeout=150
        )

        logging.info(f"seallm_generator: SeaLLM response status: {response.status_code}")
        response.raise_for_status()

        data = response.json()

        if 'message' in data and 'content' in data['message']:
            generated_answer = data['message']['content'].strip()

            if not generated_answer:
                return {
                    "content": "Walang natanggap na sagot mula sa AI, po. Subukan ulit mamaya.",
                    "success": False,
                    "error_type": "empty_response"
                }

            logging.info(f"seallm_generator: Generated response successfully")
            return {
                "content": generated_answer,
                "success": True,
            }
        else:
            logging.error(f"seallm_generator: Unexpected response structure")
            return {
                "content": "May problema sa format ng sagot mula sa AI, po. Subukan ulit mamaya.",
                "success": False,
                "error_type": "response_format_error"
            }

    except requests.exceptions.Timeout:
        logging.error("seallm_generator: Request timed out")
        return {
            "content": "Ang AI ay naging mabagal sa pagsagot, po. Subukan ulit mamaya.",
            "success": False,
            "error_type": "timeout_error"
        }
    except requests.exceptions.ConnectionError:
        logging.error("seallm_generator: Cannot connect to Ollama server")
        return {
            "content": "Hindi ma-connect sa AI server, po. Siguraduhing nakabukas ang Ollama.",
            "success": False,
            "error_type": "connection_error"
        }
    except Exception as e:
        logging.error(f"seallm_generator: Unexpected error: {e}", exc_info=True)
        return {
            "content": "May hindi inaasahang problema sa AI, po. Subukan ulit mamaya.",
            "success": False,
            "error_type": "unexpected_error"
        }