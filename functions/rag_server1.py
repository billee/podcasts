# rag_server.py
from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import re
import chromadb
from chromadb.utils import embedding_functions
import logging

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

# Health check endpoint
@app.route('/')
def health_check():
    chroma_status = "connected" if collection else "disconnected"
    return jsonify({
        "status": "running",
        "service": "Kapwa Companion RAG Server",
        "version": "1.0",
        "chromadb_status": chroma_status,
        "endpoints": {
            "/query": "POST {query: 'your question'}",
            "/health": "GET server status"
        }
    })

# Explicit health check endpoint
@app.route('/health')
def health():
    chroma_status = "connected" if collection else "disconnected"
    return jsonify({"status": "healthy", "chromadb_status": chroma_status})

def parse_json(raw_data: str) -> dict:
    """Ultra-tolerant JSON parser for incoming requests."""
    try:
        result = json.loads(raw_data)
        return result
    except json.JSONDecodeError:
        try:
            raw_data = raw_data.lstrip('\ufeff').strip()
            fixed = raw_data.replace('\\"', '"') # Fix PowerShell-style escaping
            fixed = re.sub(r"(?<!\\)'", '"', fixed) # Convert single to double quotes
            # Add missing quotes around property names if needed (e.g., {query: "test"} -> {"query": "test"})
            fixed = re.sub(r'([{,]\s*)(\w+)(\s*:\s*)', r'\1"\2"\3', fixed)
            # Add missing quotes around string values if they look like unquoted words
            fixed = re.sub(r'(\s*:\s*)(\w+)(\s*[},])', r'\1"\2"\3', fixed)
            return json.loads(fixed)
        except Exception as e:
            raise ValueError(f"Could not parse JSON: {str(e)}")

@app.route('/query', methods=['POST'])
def handle_query():
    try:
        data = request.get_json()
        query_text = data.get('query')

        if not query_text:
            return jsonify({"error": "Query text is missing"}), 400

        logging.info(f"RAW REQUEST BODY:\n{json.dumps(data)}")
        logging.info(f"QUERY_TEXT:\n{query_text}")

        try:
            client = chromadb.PersistentClient(path="./chroma_db")
            collection = client.get_collection(name=CHROMA_COLLECTION_NAME)

            # Query ChromaDB for relevant documents
            results = collection.query(
                query_texts=[query_text],
                n_results=3,
                include=['documents', 'distances', 'metadatas']
            )
            logging.info(f"Raw ChromaDB Query Results: {json.dumps(results, indent=2)}")

            # Process ChromaDB results
            MIN_SIMILARITY_SCORE = 0.6 # Your desired threshold
            retrieved_contexts = []
            if results and results.get('documents') and results['documents'][0]:
                for i in range(len(results['documents'][0])):
                    content = results['documents'][0][i]
                    distance = results['distances'][0][i]
                    metadata = results['metadatas'][0][i]

                    # Convert distance to a similarity score (higher is better)
                    score = 1 - distance

                    if score >= MIN_SIMILARITY_SCORE: # Apply the threshold here
                        retrieved_contexts.append({
                            "content": content,
                            "score": score,
                            "source": metadata.get('source', 'chromadb')
                        })
                    else:
                        logging.info(f"Skipping result with score {score:.4f} below threshold {MIN_SIMILARITY_SCORE}")

                retrieved_contexts.sort(key=lambda x: x['score'], reverse=True)

                logging.info(f"Returning RAG Results: {retrieved_contexts}")
                return jsonify({"results": retrieved_contexts})
            else:
                logging.info("ChromaDB returned no documents for query.")
                # Fallback response if no documents found
                return jsonify({
                    "results": [{
                        "content": "Pasensya na, kapatid. Wala akong nakitang sagot sa knowledge base para sa tanong mo. Pwede mo bang ulitin ng mas malinaw o magtanong ng iba?",
                        "score": 0.0,
                        "source": "chroma_no_results"
                    }]
                })

        except Exception as e:
            logging.error(f"Error during ChromaDB query: {e}", exc_info=True)
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
    # Use a production WSGI server like Gunicorn or uWSGI for production deployment
    # For development, Flask's built-in server is fine.
    app.run(host='0.0.0.0', port=5000, debug=True, threaded=True)
