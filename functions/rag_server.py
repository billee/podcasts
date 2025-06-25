# rag_server.py
import sys
import os
# Add the current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import re
import chromadb
from chromadb.utils import embedding_functions
import logging
# from llama_generator import generate_ollama_response
from openAI_generator import generate_openai_response
# from seallm_generator import generate_seallm_response
# import requests # Import for making HTTP requests to Ollama
import tiktoken # <--- ADD THIS IMPORT for token counting
from scoring_utils import filter_results_by_score

PORT = int(os.environ.get('PORT', 5000))
app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False
CORS(app, resources={r"/*": {"origins": "*", "methods": ["GET", "POST"], "allow_headers": ["*"]}})

# Set up basic logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# --- ChromaDB Initialization ---
# EMBEDDING_MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"
# EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"
# EMBEDDING_MODEL_NAME = "all-mpnet-base-v2"
# SeaLLM ??????
# EMBEDDING_MODEL_NAME ="intfloat/multilingual-e5-base"
EMBEDDING_MODEL_NAME = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"
CHROMA_HOST = "localhost" # Or your ChromaDB server IP
CHROMA_PORT = 8000
CHROMA_COLLECTION_NAME = "ofw_knowledge"
CHROMA_DB_PATH = "./chroma_db"
MODEL = "gpt-4o-mini"
SUMMARIZE_THRESHOLD_TOKENS = 2000
SCORE_THRESHOLD = 0.15
CHROMA_DB_PATH = os.environ.get('CHROMA_DB_PATH', './chroma_db')


# Global variable for the collection - Initialize to None
collection = None

try:
    client = chromadb.PersistentClient(path=CHROMA_DB_PATH)
    # Ensure the embedding function is used when getting the collection
    sentence_transformer_ef = embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name=EMBEDDING_MODEL_NAME
    )
    collection = client.get_collection(
        name=CHROMA_COLLECTION_NAME,
        embedding_function=sentence_transformer_ef
    )

    logging.info(f"Successfully connected to ChromaDB collection: '{CHROMA_COLLECTION_NAME}'")
    logging.info(f"Collection count: {collection.count()} documents")
except Exception as e:
    logging.error(f"Failed to connect to ChromaDB or get collection: {e}")
    collection = None

def clean_text(text):
    text = re.sub(r'\n\s*\n', '\n', text)
    text = text.strip()
    return text

# --- NEW: Token Counting Function ---
# This helps us know how much 'space' our messages are taking up
def count_tokens(text: str, model: str = MODEL) -> int:
    """Returns the number of tokens in a text string for a given model."""
    try:
        encoding = tiktoken.encoding_for_model(model)
        return len(encoding.encode(text))
    except KeyError:
        logging.warning(f"Could not find tokenizer for model '{model}'. Estimating tokens by character count.")
        return len(text) // 4 # Rough estimation if tokenizer not found


# --- NEW: Conversation Summarization Function ---
# This function will call the LLM to summarize the chat history
def summarize_conversation_with_llm(history_to_summarize: list, llm_generator_func) -> str:
    """
    Uses the LLM to summarize a long chat history.
    It takes the history and the LLM generation function (e.g., generate_openai_response).
    """
    logging.info("Initiating conversation summarization with LLM, po.")
    summarization_prompt = (
        "You are an assistant whose only job is to create a very brief, clear, and coherent summary "
        "of the following chat history. This summary will help the user remember what we've discussed. "
        "Focus on the main topics, important questions asked, and key information provided. "
        "Keep it very concise, like a quick memory refresh, but make sure to include any critical context "
        "about the user's situation (e.g., if they are an OFW, their location, family details, or specific problems). "
        "Do not add any new information, conversational pleasantries, or advice. Just the summary itself."
    )

    # We only summarize user and assistant messages, not system instructions
    # because the system instruction will be added every time.
    messages_for_summarization = [{"role": "system", "content": summarization_prompt}]
    for msg in history_to_summarize:
        if msg['role'] in ['user', 'assistant']:
            messages_for_summarization.append(msg)

    try:
        # Use the provided LLM generator function (e.g., generate_openai_response)
        response = llm_generator_func(messages_for_summarization)
        if response['success']:
            logging.info("Conversation successfully summarized by LLM, opo.")
            return response['content']
        else:
            logging.error(f"Failed to summarize conversation with LLM: {response['content']}")
            return "Unable to summarize previous conversation." # Fallback
    except Exception as e:
        logging.error(f"Error calling LLM for summarization: {e}")
        return "Unable to summarize previous conversation." # Fallback


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
        # IMPORTANT: This chat_history is what's passed from the client for this turn.
        # It needs to be updated by the server if summarization occurs.
        chat_history = data.get('chat_history', [])

        if not query_text:
            return jsonify({"error": "Query text is missing"}), 400

        logging.info(f"QUERY_TEXT:{query_text}")
        # logging.info(f"\nCHAT_HISTORY:{json.dumps(chat_history)}") # Log history

        # --- NEW: Check if chat_history needs summarization ---
        # First, estimate total tokens of the current history (excluding current query and RAG context)
        current_history_tokens = count_tokens(json.dumps(chat_history), model=MODEL) # Adjust model if using a different one

        if current_history_tokens > SUMMARIZE_THRESHOLD_TOKENS:
            logging.info(f"Chat history tokens ({current_history_tokens}) exceed summarization threshold ({SUMMARIZE_THRESHOLD_TOKENS}). Summarizing, po.")
            # Determine which LLM generator function to use for summarization
            llm_generator_for_summary = generate_openai_response # Default to OpenAI for now
            # You could add logic here to use generate_ollama_response if preferred for summarization

            summarized_content = summarize_conversation_with_llm(chat_history, llm_generator_for_summary)
            # Replace the old, long chat_history with a single summary message
            # This message will act as the new starting point for the conversation context.
            chat_history = [{"role": "assistant", "content": f"Summary of our previous conversation:\n{summarized_content}"}]
            logging.info("Chat history summarized and updated, opo.")


        retrieved_contexts = []
        # Define short, conversational follow-ups that don't need new retrieval
        conversational_follow_ups = ["yes", "no", "tell me more", "elaborate", "can you elaborate", "please elaborate", "i would", "i would like to", "yes please", "no thanks"] # Added more common phrases

        # Check if the current query is a short conversational follow-up
        if query_text.lower() in conversational_follow_ups:
            logging.info(f"Skipping ChromaDB retrieval for conversational follow-up: '{query_text}'")
            # In this case, retrieved_contexts remains empty, and the LLM relies solely on chat_history
        else:
            # /////////////////////////RETRIEVAL/////////////////////////////////////////////////////////////////////////////////////////////////////////////
            try:
                # Step 1: Query ChromaDB for relevant documents (AUGMENTATION).  The query text will be automatically embeded
                initial_n_results = 5 # Get more results to filter later

                # logging.info(f"Original query for ChromaDB: '{query_text}'")

                # combined_query_for_rag = " ".join([msg['content'] for msg in chat_history if msg['role'] in ['user', 'assistant']]) + " " + query_text


                results = collection.query(
                    query_texts=[query_text],
                    # query_texts=[combined_query_for_rag],
                    n_results=initial_n_results,
                    include=['documents', 'distances', 'metadatas']
                )

                logging.info(f"results count: {len(results['documents'][0]) if results and results.get('documents') else 0}")

                retrieved_contexts = filter_results_by_score(results, SCORE_THRESHOLD)

                # Step 2: Filter results based on the similarity score threshold
                # if results and results.get('documents') and results['documents'][0]:
                #     for i in range(len(results['documents'][0])):
                #         content = results['documents'][0][i]
                #         distance = results['distances'][0][i]
                #         metadata = results['metadatas'][0][i]
                #
                #         if distance < 0:
                #             score = 1 / (1 + abs(distance))
                #         else:
                #             score = 1 / (1 + distance)
                #
                #         print(f"##############: Distance: {distance:.6f}, Score: {score:.6f}")
                #         print(f"Content: {content[:100]}...")
                #         print()
                #
                #         # Corrected filtering logic: Keep if score is greater than or equal to the minimum acceptable score
                #         if score > SCORE_THRESHOLD:
                #             logging.info(f"✅ Keeping result: Score {score:.6f} > Threshold {SCORE_THRESHOLD}")
                #             retrieved_contexts.append({
                #                 # "content": content,
                #                 "content": clean_text(content),
                #                 'distance': distance,
                #                 'metadata': metadata,
                #                 "score": score,
                #                 # "source": metadata.get('source', 'chromadb')
                #             })
                #         else:
                #             logging.info(f"❌ Skipping result: Score {score:.6f} < Threshold {SCORE_THRESHOLD}")
                #             print(f"Content: {content[:100]}...")
                #             print()
                #
                #
                #     retrieved_contexts.sort(key=lambda x: x['score'], reverse=True)


                if(retrieved_contexts):
                    MAX_CONTEXTS_FOR_LLM = 3 # Cap the number of contexts for the LLM prompt
                    if len(retrieved_contexts) > MAX_CONTEXTS_FOR_LLM:
                        retrieved_contexts = retrieved_contexts[:MAX_CONTEXTS_FOR_LLM]

                    logging.info(f"\nFiltered retrieved contexts from ChromaDB: {retrieved_contexts}")
                else:

                    logging.info(f"\nFiltered retrieved contexts from ChromaDB: {retrieved_contexts}")


            except Exception as e:
                logging.error(f"Error during ChromaDB query or RAG processing: {e}", exc_info=True)
                # Do not return immediately, let the LLM attempt to respond without context
                pass # Continue to LLM generation even if ChromaDB query fails for this part


        # Define the strict system instruction for the LLM
        # strict_system_instruction = (
        #     "You are a very helpful and dedicated assistant for Overseas Filipino Workers (OFWs), providing culturally appropriate advice in everyday spoken English. "
        #     "Your primary goal is to provide empathetic and informative responses based on the provided context. "
        #     "However, if the provided context is insufficient to fully answer the user's query or to offer comprehensive assistance, you may draw upon your general knowledge to provide additional relevant and useful information that is beneficial and relevant to OFWs. "
        #     "Always clearly distinguish between information from the provided context and general knowledge you are adding." # Optional: Add a directive to distinguish sources
        # )

        # strict_system_instruction = (
        #     "You are a very polite in Filipino way, helpful and dedicated assistant for Overseas Filipino Workers (OFWs), providing culturally appropriate advice in everyday spoken English in the Philippines. Your primary goal is to provide empathetic and informative responses based on the provided context and say that 'base on our data, ...'. However, if the provided context is insufficient to fully answer the user's query or to offer comprehensive assistance, you may draw upon your general knowledge to provide additional relevant and useful information that is only beneficial and only relevant to OFWs but say that this is your suggestion. They have to be specific not generalization. If there is none, then do not add it. Always put yourself in the shoe of the OFW. Always clearly distinguish between information from the provided context and general knowledge you are adding. Remember, most OFW did not get high education, so speak to them accordingly."
        # )

        # strict_system_instruction = """
        # Strict System Instruction
        #
        # You are:
        # - A polite and warm-hearted Filipina assistant from the Philippines who speaks in a culturally appropriate Filipino manner
        #   • Tell the person at start that you are just an AI, a friend or a companion, trying to help (to advice only) and understand the user.
        #   • Use polite expressions like “po” and “opo”
        #   • Make them feel like you are with them and on their side
        #   • named as Tita Ai
        # - A warm, respectful, and supportive presence, like a friend or family member
        # - Focused on giving empathetic, informative, and culturally aware advice tailored for Overseas Filipino Workers (OFWs)
        # - Talk in simple, everyday conversational Taglish, that's easy for an OFW to understand
        #
        # Your goals:
        # - Prioritize the well-being of the OFW in all responses
        # - Reflect common Filipino values like:
        #   • Family
        #   • Bayanihan (community spirit)
        #   • Resilience
        #
        # CRITICAL: Context Relevance Check
        # - FIRST, determine if the provided context relates to the user's actual question
        # - If context does not relate to the user's actual question, IGNORE the context
        # - Respond to what the person actually asked, not what the context suggests
        #
        # When answering:
        # - Read the user's question carefully.
        # - Check if provided context actually relates to their question.
        #     - If YES - use context appropriately
        #     - If NO - ignore context completely and respond with empathy + general advice
        # - Do not use numbering format.
        # - Do not use the person name to address that person,  just say "you".
        # - Do not be very formal in answering. Treat the person as a friend just like in a friendly conversation.
        # - Do not be too confident with your suggestions.  Be humble. Do not say something like "Do not worry." or "I can help you with..."
        # - Do not assume things which you do not know.
        # - Do not ask any question at the end of your answer. Remember you are just advising.
        # - Do not offer to help like filling out forms, applying, etc.  Just only advise them what to do.
        # - If the context is insufficient or empty, you are free to search general knowledge ONLY IF:
        #   • It's relevant and helpful to this specific OFW
        #   • You clearly say: “my suggestion…”
        #   • You avoid generalizations
        #   • You provide specific, actionable suggestions
        #   • You do NOT add unrelated or unhelpful information
        #   • Do not hallucinate and fabricate wrong informations such as dates, amounts,etc.
        # - If retrieved content mentions a location that contradicts the system context, exclude retrieved mismatches from the final answer.
        #
        # Tone and empathy:
        # - Always put yourself in the shoes of the OFW
        # - Your tone must show:
        #   • Understanding
        #   • Compassion
        #   • Support for the challenges OFWs face
        #
        # Clarity in information:
        # - Clearly distinguish between:
        #   • Information from the provided context
        #   • Information from your general knowledge
        #
        # Personalization:
        # - Always remember OFW's work location is Hong Kong. Treat this person just like your very good friend.
        # - Tailor your responses specifically to:
        #   • Name is Hilda
        #   • A 26-year-old Filipina working as a caregiver in Hong kong (Remember this location)
        #   • Married with 2 children in the Philippines
        #   • High school graduate in the Philippines
        # - Help OFW feel that you understand her situation and struggles
        # """

        strict_system_instruction = """
            Strict System Instruction
            
            You are:
            • A polite and warm-hearted religious Catholic Filipina assistant from the Philippines who speaks in a culturally appropriate Filipino manner, named Tita Ai.
            • Tell the person at the start that you are just an AI, a friend, or a companion, trying to help (to advise only) and understand the user.
            • Use polite expressions like “po” and “opo”.
            • Make them feel like you are with them and on their side.
            - A warm, respectful, and supportive presence, like a friend or family member.
            - Focused on giving empathetic, informative, and culturally aware advice tailored for Overseas Filipino Workers (OFWs).
            
            Your goals:
            - Prioritize the well-being of the OFW in all responses.
            - Reflect common Filipino values like:
            • Family
            • Bayanihan (community spirit)
            • Resilience.
            
            ---
            
            ## When Answering
            
            - Read the user's question carefully.
            - If context was deemed **relevant**:
            - Use the provided context appropriately to answer the question.
            - If context was deemed **irrelevant** or was **empty/insufficient**:
            - Respond with empathy and general advice that aligns with your persona.
            - If you use general knowledge, clearly state: “My suggestion…”
            - Ensure general knowledge is relevant, helpful, specific, and actionable.
            - Do NOT add unrelated or unhelpful information.
            - Do NOT hallucinate or fabricate wrong information (e.g., dates, amounts).
            
            ---
            
            ## IF CONTEXT IS IRRELEVANT (IMPORTANT)
            
            - If you ignore the provided context, focus solely on providing empathetic support and general, actionable advice based on your persona and general knowledge.
            - Do NOT mention the irrelevant context or try to explain why it was ignored.
            - Do NOT be too confident with your suggestions; be humble.
            - Do NOT assume things you do not know.
            - Do NOT offer to help with tasks like filling out forms or applying; only provide advice.
            - Do NOT ask any questions at the end of your answer.
            
            ---
            
            ## Tone and Empathy
            
            - Always put yourself in the shoes of the OFW.
            - Your tone must show:
                • Understanding
                • Compassion
                • Support for the challenges OFWs face.
            - Treat the person as a very good friend, just like in a friendly conversation.
            - Do not say something like "Do not worry" or "I can help you with...".
     
                 ---
            
            ## CRITICAL: Context Relevance Check
            
            - **FIRST AND FOREMOST, determine if the provided context directly relates to the user's actual question and immediate need.**
            - **If the provided context does NOT directly address the user's query, you MUST IGNORE the context entirely.**
            - **Your response MUST be based on what the person actually query, not what irrelevant context suggests.**
            
            ---
            
            ## Clarity and Personalization
            
            - Clearly distinguish between:
            • Information from the provided context.
            • Information from your general knowledge.
            - Always remember OFW's work location is Hong Kong.
            - Tailor your responses specifically to Hilda, a 26-year-old Filipina caregiver in Hong Kong, married with 2 children in the Philippines, and a high school graduate.
            - Help Hilda feel that you understand her situation and struggles.
            - If retrieved content mentions a location that contradicts the system context (Hong Kong), exclude retrieved mismatches from the final answer.
            - Talk in short, simple, everyday conversational Taglish.
        """


        messages = []

        # Ensure the strict system instruction is the first message
        messages.append({"role": "system", "content": strict_system_instruction})

        # Add the (potentially summarized) chat history.
        # This will now contain either the full short history or a single summary message.
        for msg in chat_history:
            messages.append(msg)


        context_string = "" # Initialize as empty, only fill if relevant contexts are found and not a follow-up
        if retrieved_contexts and query_text.lower() not in conversational_follow_ups:
            context_string = "\n\n".join([item['content'] for item in retrieved_contexts])
            logging.info(f"Context string sent to LLM:\n{context_string}")
        else:
            logging.info("No relevant contexts retrieved or retrieval skipped for conversational follow-up.")


        # Append the RAG context and the current query to the latest user message
        # The last message in the combined 'messages' list (after history) should be the current user query.
        # If for some reason the chat_history doesn't end with a user message, we append it.
        # For this setup, we'll always append the current query.
        final_user_message_content = query_text
        if context_string:
            final_user_message_content = (
                f"Context:\n{context_string}\n\n"
                f"Question: {query_text}"
            )
        messages.append({"role": "user", "content": final_user_message_content})



        # /////////////////////////GENERATION/////////////////////////////////////////////////////////////////////////////////////////////////////////

        logging.info(f"\nMessages to be sent to LLm: {json.dumps(messages, indent=2)}")

        # use ollama for development(free) and use openai for production(paid)
        # ///////////////////////////USING LLAMA 3.1/////////////////////////////////////////////////////////////////
        # response = generate_ollama_response(messages)
        # ////////////////////////////////////////////////////////////////////////////////////////////////////
        response = generate_openai_response(messages)
        # ////////////////////////////////////////////////////////////////////////////////////////////////////
        # ////////////////////////////////////////////////////////////////////////////////////////////////////
        # response = generate_seallm_response(messages)
        # ////////////////////////////////////////////////////////////////////////////////////////////////////



        if response['success']:
            generated_answer = response['content']
            final_source = retrieved_contexts[0]['metadata'].get('source', 'chromadb') if retrieved_contexts else "LLM_generated"

            # --- IMPORTANT: Return the updated chat_history to the client ---
            # The client needs to replace its local chat_history with this one for the next turn.
            # We return everything from `messages` *after* the initial system instruction.
            # updated_chat_history_for_client = messages[1:]
            # Append the new assistant response to this history
            # updated_chat_history_for_client.append({"role": "assistant", "content": generated_answer})


            # Prepare updated chat history for the client.
            # It should include the previous chat history received from the client,
            # the original current user query, and the new assistant response.
            # This ensures that the RAG context is NOT persisted in the chat history sent back.
            updated_chat_history_for_client = chat_history.copy() # Start with the clean history received from the client
            updated_chat_history_for_client.append({"role": "user", "content": query_text}) # Add the original user query
            updated_chat_history_for_client.append({"role": "assistant", "content": generated_answer}) # Add the assistant response


            return jsonify({
                "results": [{
                    "content": generated_answer,
                    "score": retrieved_contexts[0]['score'] if retrieved_contexts else 0.0,
                    "source": final_source
                }],
                "updated_chat_history": updated_chat_history_for_client
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

    except ValueError as ve:
        logging.error(f"Invalid JSON format: {ve}")
        return jsonify({"error": f"Invalid JSON format: {ve}"}), 400
    except Exception as e:
        logging.error(f"An unexpected error occurred in handle_query: {str(e)}", exc_info=True)
        return jsonify({"error": f"An unexpected error occurred: {str(e)}"}), 500


if __name__ == '__main__':
    # app.run(host='0.0.0.0', port=5000, debug=True, threaded=True)
    app.run(host='0.0.0.0', port=PORT, debug=False, threaded=True)

