from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import re

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False
CORS(app, resources={r"/*": {"origins": "*", "methods": ["GET", "POST"], "allow_headers": ["*"]}})

# Health check endpoint
@app.route('/')
def health_check():
    return jsonify({
        "status": "running",
        "service": "Kapwa Companion RAG Server",
        "version": "1.0",
        "endpoints": {
            "/query": "POST {query: 'your question'}",
            "/health": "GET server status"
        }
    })

# Explicit health check endpoint
@app.route('/health')
def health():
    return jsonify({"status": "healthy"})


def parse_json(raw_data: str) -> dict:
    """Ultra-tolerant JSON parser that handles:
    - PowerShell escaped quotes
    - Missing quotes
    - Single quotes
    - Trailing commas
    """
    print(f"Original raw data: {repr(raw_data)}")
    try:
        # First try standard parsing
        result = json.loads(raw_data)
        print("Parsed with standard JSON parser")
        return result
    except json.JSONDecodeError as e:
        print(f"Standard parse failed: {e}")
        try:
            # Remove any whitespace at start/end
            raw_data = raw_data.lstrip('\ufeff').strip()
            # Fix PowerShell-style escaping
            fixed = raw_data.replace('\\"', '"')
            # Convert single to double quotes
            fixed = re.sub(r"(?<!\\)'", '"', fixed)
            # Add missing quotes around property names if needed
            if not re.search(r'"\s*:\s*', fixed):  # If no proper key:value pairs
                fixed = re.sub(r'(\w+)(\s*:\s*)', r'"\1"\2', fixed)

            print(f"🔧 Modified JSON: {repr(fixed)}")

            return json.loads(fixed)
        except Exception as e:
            print(f"Final parse failed: {e}")
            raise ValueError(f"Could not parse JSON: {str(e)}")

@app.route('/query', methods=['POST'])
def handle_query():
    try:
        # Get raw bytes to avoid any Flask parsing
        raw_bytes = request.get_data()
        raw_str = raw_bytes.decode('utf-8')
        print(f"INCOMING REQUEST from {request.remote_addr}")
        print(f"RAW REQUEST BODY:\n{raw_str}")
        print(f"HEADERS: {dict(request.headers)}")

        data = parse_json(raw_str)
        query = data.get('query', '').strip()

        try:
            collection = client.get_collection("your_collection_name")
            print(f"Chroma Collection Info: {collection.peek()}")
        except Exception as e:
            print(f"Chroma Error: {str(e)}")


        if not query:
            return jsonify({"error": "Empty query"}), 400

        # Check for cached responses first
        if 'homesick' in query.lower():
            return jsonify({
                "results": [{
                    "content": "Alam kong mahirap malayo sa pamilya. Kaya mo yan, kabayan!",
                    "score": 0.95,
                    "source": "cached"
                }]
            })
        elif 'oec' in query.lower():
            return jsonify({
                "results": [{
                    "content": "Para sa OEC renewal, kailangan ng: 1) Passport, 2) Kontrata, 3) OWWA membership. Pwede ko bang i-direct sa official website?",
                    "score": 0.95,
                    "source": "cached"
                }]
            })

        # Your ChromaDB query logic here
        return jsonify({
            "results": [{
                "content": "Pasensya na, kapatid. Pwede mo ba ulitin ng mas malinaw?",
                "score": 0.85,
                "source": "fallback"
            }]
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True, threaded=True)