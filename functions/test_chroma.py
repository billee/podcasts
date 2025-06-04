import chromadb
from chromadb.utils import embedding_functions
import os

# Define your expected embedding model name and collection details
# These should match what's in chroma_setup.py and rag_server.py
# EMBEDDING_MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"
# EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"
EMBEDDING_MODEL_NAME = "all-mpnet-base-v2"
CHROMA_COLLECTION_NAME = "ofw_knowledge"
CHROMA_DB_PATH = "./chroma_db" # Ensure this path is correct for your ChromaDB data
test_query = "balikbayan box pro tips?" # Example query

collection = None
try:
    # Initialize the ChromaDB client
    client = chromadb.PersistentClient(path=CHROMA_DB_PATH)

    # Instantiate the EXACT SAME embedding function used during collection creation
    sentence_transformer_ef = embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name=EMBEDDING_MODEL_NAME
    )

    # Retrieve the collection, specifying the embedding function.
    # While this doesn't *change* a pre-existing collection's EF, it ensures
    # that your client-side operations (like query embedding) use this EF.
    # It also ensures that if the collection *doesn't* exist, it's created with this EF.
    collection = client.get_collection(
        name=CHROMA_COLLECTION_NAME,
        embedding_function=sentence_transformer_ef # Pass the same EF here
    )
    print(f"Successfully connected to ChromaDB and retrieved collection '{CHROMA_COLLECTION_NAME}'.")

    if collection is not None:
        # Removed the block that was attempting to print the model name and check its type,
        # as per your request to "take out the model name of the embedding function after the collection."

        # --- Now, perform a test query using the same embedding function ---
        print("\n--- Running a test query with the specified embedding model ---")

        try:
            # When you query, the query text is embedded using the EF associated with the collection.
            test_results = collection.query(
                query_texts=[test_query],
                n_results=5,
                include=['documents', 'distances', 'metadatas']
            )

            print(f"Test Query: '{test_query}'")
            print("Test Query Results:")
            if test_results and test_results.get('documents') and test_results['documents'][0]:
                for i in range(len(test_results['documents'][0])):
                    print(f"  Result {i+1}::::::::::::::::::::::::::::::::::::::::::::::::")
                    print(f"    Content: {test_results['documents'][0][i][:200]}...")
                    print(f"    Score (cosine similarity): {1 - test_results['distances'][0][i]:.4f}") # Convert distance to similarity
                    print(f"    Metadata: {test_results['metadatas'][0][i]}")
            else:
                print("  No documents retrieved for the test query. This might indicate an issue with embeddings or data.")
        except Exception as e:
            print(f"Error during test query: {e}")

    else:
        print("Collection object is None. Cannot perform operations.")

except Exception as e:
    print(f"Error connecting to ChromaDB or accessing collection '{CHROMA_COLLECTION_NAME}': {e}")
    print("Please ensure ChromaDB is running and the 'chroma_db' directory exists and is accessible.")