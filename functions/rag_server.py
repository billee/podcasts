# rag_server.py
from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import re
import chromadb
from chromadb.utils import embedding_functions
import logging
import requests # Import for making HTTP requests to Ollama

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False
CORS(app, resources={r"/*": {"origins": "*", "methods": ["GET", "POST"], "allow_headers": ["*"]}})

# Set up basic logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# --- ChromaDB Initialization ---
EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"
CHROMA_HOST = "localhost" # Or your ChromaDB server IP
CHROMA_PORT = 8000
CHROMA_COLLECTION_NAME = "ofw_knowledge"

# Global variable for the collection - Initialize to None
collection = None

try:
    client = chromadb.PersistentClient(path="./chroma_db")
    # Ensure the embedding function is used when getting the collection
    sentence_transformer_ef = embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name=EMBEDDING_MODEL_NAME
    )
    collection = client.get_collection(
        name=CHROMA_COLLECTION_NAME,
        embedding_function=sentence_transformer_ef
    )

    logging.info(f"collection: {collection}")
    logging.info(f"Successfully connected to ChromaDB collection: '{CHROMA_COLLECTION_NAME}'")
    logging.info(f"Collection count: {collection.count()} documents")
except Exception as e:
    logging.error(f"Failed to connect to ChromaDB or get collection: {e}")

# --- Ollama Configuration ---
OLLAMA_API_URL = 'http://localhost:11434/api/chat' # Ollama's chat API endpoint
OLLAMA_MODEL_NAME = 'llama3.2:latest' # Your desired Ollama model

# Health check endpoint
@app.route('/')
def health_check():
    # Now 'collection' is guaranteed to exist, even if it's None
    chroma_status = "connected" if collection else "disconnected"
    return jsonify({
        "status": "running",
        "service": "Kapwa Companion RAG Server",
        "version": "1.0",
        "chromadb_status": chroma_status,
        "endpoints": {
            "/query": "POST {query: 'your question', chat_history: [...]}", # Update endpoint info
            "/health": "GET server status"
        }
    })

# Explicit health check endpoint
@app.route('/health')
def health():
    # Now 'collection' is guaranteed to exist, even if it's None
    chroma_status = "connected" if collection else "disconnected"
    return jsonify({"status": "healthy", "chroma_status": chroma_status})

def parse_json(raw_data: str) -> dict:
    """Ultra-tolerant JSON parser for incoming requests."""
    try:
        result = json.loads(raw_data)
        return result
    except json.JSONDecodeError:
        try:
            raw_data = raw_data.lstrip('\ufeff').strip()
            fixed = raw_data.replace('\\"', '"')
            fixed = re.sub(r"(?<!\\)'", '"', fixed)
            fixed = re.sub(r'([{,]\s*)(\w+)(\s*:\s*)', r'\1"\2"\3', fixed)
            fixed = re.sub(r'(\s*:\s*)(\w+)(\s*[},])', r'\1"\2"\3', fixed)
            return json.loads(fixed)
        except Exception as e:
            raise ValueError(f"Could not parse JSON: {str(e)}")

@app.route('/query', methods=['POST'])
def handle_query():
    if collection is None:
        logging.error("ChromaDB collection is not initialized. Cannot perform query.")
        return jsonify({
            "results": [{
                "content": "Server error: Knowledge base is not available.",
                "score": 0.0,
                "source": "server_error"
            }]
        }), 500

    try:
        logging.info(f"==============================================================================")
        data = request.get_json()
        query_text = data.get('query')
        chat_history = data.get('chat_history', []) # NEW: Get chat history from request

        logging.info(f"data: {data}")
        logging.info(f"chat history: {chat_history}")


        if not query_text:
            return jsonify({"error": "Query text is missing"}), 400

        logging.info(f"RAW REQUEST BODY:{json.dumps(data)}")
        logging.info(f"QUERY_TEXT:{query_text}")
        logging.info(f"CHAT_HISTORY:{json.dumps(chat_history, indent=2)}") # Log history

        try:
            # Step 1: Query ChromaDB for relevant documents
            initial_n_results = 10 # Get more results to filter later
            results = collection.query(
                query_texts=[query_text],
                n_results=initial_n_results,
                include=['documents', 'distances', 'metadatas']
            )
            # logging.info(f"Raw ChromaDB Query Results (initial {initial_n_results}): {json.dumps(results, indent=2)}")
            logging.info(f"results count: {len(results)}")

            # Step 2: Filter results based on the similarity score threshold
            MIN_SIMILARITY_SCORE = 0.6
            retrieved_contexts = []
            if results and results.get('documents') and results['documents'][0]:
                for i in range(len(results['documents'][0])):
                    content = results['documents'][0][i]
                    distance = results['distances'][0][i]
                    metadata = results['metadatas'][0][i]

                    score = 1 - distance

                    if score >= MIN_SIMILARITY_SCORE:
                        retrieved_contexts.append({
                            "content": content,
                            "score": score,
                            "source": metadata.get('source', 'chromadb')
                        })
                    else:
                        logging.info(f"Skipping result with score {score:.4f} below threshold {MIN_SIMILARITY_SCORE}")

                retrieved_contexts.sort(key=lambda x: x['score'], reverse=True)

                MAX_CONTEXTS_FOR_LLM = 3 # Cap the number of contexts for the LLM prompt
                if len(retrieved_contexts) > MAX_CONTEXTS_FOR_LLM:
                    logging.info(f"Limiting retrieved contexts from {len(retrieved_contexts)} to {MAX_CONTEXTS_FOR_LLM}")
                    retrieved_contexts = retrieved_contexts[:MAX_CONTEXTS_FOR_LLM]

                # logging.info(f"Filtered retrieved contexts from ChromaDB: {retrieved_contexts}")

            # --- LLM Integration (calling Ollama directly from Flask) ---
            # Prepare messages for Ollama's chat API
            messages = list(chat_history) # Start with provided chat history from Flutter
            logging.info(f"messages: {messages}")


            # If no RAG contexts are found that meet the threshold, tell the LLM it has no specific context
            context_string = "No relevant context found in the knowledge base."
            if retrieved_contexts:
                context_string = "\n\n".join([item['content'] for item in retrieved_contexts])

            # IMPORTANT: Adjust this prompt structure to match Llama 3.1 Instruct's expected format.
            # Llama 3.1 Instruct expects messages in the format:
            # [{"role": "system", "content": "..."}]
            # [{"role": "user", "content": "..."}]
            # [{"role": "assistant", "content": "..."}]
            # ... and so on.

            # Ensure a system message is at the start, defining the persona and RAG instructions
            # If a system message already exists from chat_history, update it, otherwise add it.
            system_message_content = (
                "You are a helpful assistant for Overseas Filipino Workers (OFWs), providing culturally appropriate advice in everyday spoken English. "
                "Your response should be based ONLY on the provided context. If the context does not provide enough information to answer the question, state that you cannot answer based on the provided information and offer to search for other information. "
                "Do not invent information. If the user asks a question not covered by the context, you may use your general knowledge, but always prioritize the context for factual answers."
            )

            if messages and messages[0]['role'] == 'system':
                messages[0]['content'] = system_message_content
            else:
                messages.insert(0, {"role": "system", "content": system_message_content})


            logging.info(f"next_messages: {messages}")


            # Append the RAG context and the current query to the latest user message
            # The last message in chat_history should be the current query from the user.
            if messages and messages[-1]['role'] == 'user':
                current_user_message_content = messages[-1]['content']
                messages[-1]['content'] = (
                    f"Context:\n{context_string}\n\n"
                    f"Question: {current_user_message_content}"
                )
            else:
                # This case should ideally not happen if Flutter sends the current query correctly
                logging.warning("Last message in chat_history is not user's current query. Appending as a new user message with context.")
                messages.append({"role": "user", "content":
                    f"Context:\n{context_string}\n\n"
                    f"Question: {query_text}"
                                 })


            logging.info(f"Messages sent to Ollama: {json.dumps(messages, indent=2)}")

            try:
                ollama_payload = {
                    'model': OLLAMA_MODEL_NAME,
                    'messages': messages,
                    'stream': False, # Set to True if you want to handle streaming responses
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

                logging.info(f"Ollama Generated Answer: {generated_answer}")

                final_source = retrieved_contexts[0]['source'] if retrieved_contexts else "LLM_generated"
                return jsonify({
                    "results": [{
                        "content": generated_answer,
                        "score": retrieved_contexts[0]['score'] if retrieved_contexts else 0.0,
                        "source": final_source
                    }]
                })

            except requests.exceptions.RequestException as req_e:
                logging.error(f"Error calling Ollama API: {req_e}", exc_info=True)
                return jsonify({
                    "results": [{
                        "content": "May problema sa pagkuha ng sagot mula sa AI (Ollama API error). Subukan ulit mamaya.",
                        "score": 0.0,
                        "source": "ollama_api_error"
                    }]
                }), 500
            except Exception as llm_e:
                logging.error(f"Error processing Ollama response or general LLM error: {llm_e}", exc_info=True)
                return jsonify({
                    "results": [{
                        "content": "May problema sa pagbuo ng sagot. Subukan ulit mamaya. (General LLM Error)",
                        "score": 0.0,
                        "source": "llm_error"
                    }]
                }), 500

        except Exception as e:
            logging.error(f"Error during ChromaDB query or RAG processing: {e}", exc_info=True)
            return jsonify({
                "results": [{
                    "content": "May problema sa pagkuha ng impormasyon mula sa knowledge base. Subukan ulit mamaya.",
                    "score": 0.0,
                    "source": "chroma_error"
                }]
            }), 500

    except ValueError as ve:
        logging.error(f"Invalid JSON format: {ve}")
        return jsonify({"error": f"Invalid JSON format: {ve}"}), 400
    except Exception as e:
        logging.error(f"An unexpected error occurred in handle_query: {str(e)}", exc_info=True)
        return jsonify({"error": f"An unexpected error occurred: {str(e)}"}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True, threaded=True)