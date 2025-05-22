# rag_server.py
from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import re
import chromadb
from chromadb.utils import embedding_functions
import logging
from llama_generator import generate_ollama_response
from openAI_generator import generate_openai_response
# import requests # Import for making HTTP requests to Ollama

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
    collection = None

def clean_text(text):
    text = re.sub(r'\n\s*\n', '\n', text)
    text = text.strip()
    return text


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
        return jsonify({"error": "ChromaDB not ready. Please check server logs."}), 500


    try:
        logging.info(f"==============================================================================")
        data = request.get_json()
        query_text = data.get('query')
        chat_history = data.get('chat_history', [])

        if not query_text:
            return jsonify({"error": "Query text is missing"}), 400

        logging.info(f"QUERY_TEXT:{query_text}")
        logging.info(f"CHAT_HISTORY:{json.dumps(chat_history, indent=2)}") # Log history

        # /////////////////////////RETRIEVAL/////////////////////////////////////////////////////////////////////////////////////////////////////////////
        try:
            # Step 1: Query ChromaDB for relevant documents (AUGMENTATION).  The query text will be automatically embeded
            initial_n_results = 10 # Get more results to filter later
            results = collection.query(
                query_texts=[query_text],
                n_results=initial_n_results,
                include=['documents', 'distances', 'metadatas']
            )

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

                logging.info(f"Filtered retrieved contexts from ChromaDB: {retrieved_contexts}")


            # Prepare messages for Ollama's chat API
            messages = list(chat_history) # Start with provided chat history from Flutter
            logging.info(f"messages: {messages}")

            context_string = "No relevant context found in the knowledge base."
            if retrieved_contexts:
                context_string = "\n\n".join([item['content'] for item in retrieved_contexts])

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

            # /////////////////////////GENERATION/////////////////////////////////////////////////////////////////////////////////////////////////////////

            logging.info(f"Messages to be sent to Ollama: {json.dumps(messages, indent=2)}")

            # ///////////////////////////USING LLAMA 3.1/////////////////////////////////////////////////////////////////
            # response = generate_ollama_response(messages)
            # ////////////////////////////////////////////////////////////////////////////////////////////////////
            response = generate_openai_response(messages)
            # ////////////////////////////////////////////////////////////////////////////////////////////////////
            if response['success']:
                generated_answer = response['content']
                final_source = retrieved_contexts[0]['source'] if retrieved_contexts else "LLM_generated"
                return jsonify({
                    "results": [{
                        "content": generated_answer,
                        "score": retrieved_contexts[0]['score'] if retrieved_contexts else 0.0,
                        "source": final_source
                    }]
                })
            else:
                # Handle error from llama_generator.py and return appropriate response
                return jsonify({
                    "results": [{
                        "content": response['content'], # This will be the error message from llama_generator
                        "score": 0.0,
                        "source": response.get('error_type', 'llm_error') # Use error_type if available
                    }]
                }), 500 # Return 500 for internal server errors originating from LLM generation
            # ///////////////////////////////////////////////////////////////////////////////////////////////////////

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