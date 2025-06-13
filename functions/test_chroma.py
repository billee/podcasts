import chromadb
from chromadb.utils import embedding_functions
import os

# Define your expected embedding model name and collection details
# These should match what's in chroma_setup.py and rag_server.py
# EMBEDDING_MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"
# EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"
# EMBEDDING_MODEL_NAME = "all-mpnet-base-v2"
# EMBEDDING_MODEL_NAME = "intfloat/multilingual-e5-base"
EMBEDDING_MODEL_NAME = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"
CHROMA_COLLECTION_NAME = "ofw_knowledge"
CHROMA_DB_PATH = "./chroma_db"
SCORE_THRESHOLD = 0.15
test_query = "are there scholarship programs?" # Example query

collection = None
try:
    # Initialize the ChromaDB client
    client = chromadb.PersistentClient(path=CHROMA_DB_PATH)

    # Instantiate the EXACT SAME embedding function used during collection creation
    sentence_transformer_ef = embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name=EMBEDDING_MODEL_NAME
    )

    collection = client.get_collection(
        name=CHROMA_COLLECTION_NAME,
        embedding_function=sentence_transformer_ef # Pass the same EF here
    )
    print(f"Successfully connected to ChromaDB and retrieved collection '{CHROMA_COLLECTION_NAME}'.")

    if collection is not None:
        print("\n--- Running a test query with the specified embedding model ---")

        try:
            # When you query, the query text is embedded using the EF associated with the collection.
            test_results = collection.query(
                query_texts=[test_query],
                n_results=5,
                include=['documents', 'distances', 'metadatas']
            )


            print(f"Test Query: '{test_query}'")
            print(f"Test Query Results (filtered with score > {SCORE_THRESHOLD}):")
            print("Test Query Results:")

            filtered_results = []
            if test_results and test_results.get('documents') and test_results['documents'][0]:
                for i in range(len(test_results['documents'][0])):
                    content = test_results['documents'][0][i]
                    distance = test_results['distances'][0][i]
                    # score = 1 - distance # Convert distance to similarity
                    metadata = test_results['metadatas'][0][i]

                    if distance < 0:
                        # For negative distances, use absolute value and invert
                        score = 1 / (1 + abs(distance))
                    else:
                        # For positive distances, use standard conversion
                        score = 1 / (1 + distance)

                    print(f"##############: Distance: {distance:.6f}, Score: {score:.6f}")
                    print(f"Content: {content[:100]}...")
                    print()

                    # Filter condition: score must be greater SCORE_THRESHOLD
                    if score > SCORE_THRESHOLD:
                        filtered_results.append({
                            'content': content,
                            'score': score,
                            'distance': distance,
                            'metadata': metadata
                        })

            if filtered_results:
                # Sort by score in descending order
                filtered_results.sort(key=lambda x: x['score'], reverse=True)
                print(f"\n✅ Found {len(filtered_results)} relevant results:")
                print("=" * 80)
                for i, result in enumerate(filtered_results):
                    print(f"Result {i+1}:")
                    print(f"  Score: {result['score']:.4f}")
                    print(f"  Distance: {result['distance']:.6f}")
                    print(f"  Content: {result['content'][:200]}...")
                    print(f"  Source: {result['metadata'].get('source', 'Unknown')}")
                    print("-" * 40)
            else:
                print(f"\n❌ No documents retrieved for the test query with score > {SCORE_THRESHOLD}.")
                print("This might mean:")
                print("1. The similarity threshold is too high")
                print("2. No relevant content exists in the database")
                print("3. The embedding model needs adjustment")

                # Show all results regardless of threshold for debugging
                print(f"\n🔍 All results (regardless of threshold):")
                all_results = []
                for i in range(len(test_results['documents'][0])):
                    content = test_results['documents'][0][i]
                    distance = test_results['distances'][0][i]

                    if distance < 0:
                        score = 1 / (1 + abs(distance))
                    else:
                        score = 1 / (1 + distance)

                    all_results.append({
                        'content': content,
                        'score': score,
                        'distance': distance
                    })

                # Sort and show top results
                all_results.sort(key=lambda x: x['score'], reverse=True)
                for i, result in enumerate(all_results[:3]):  # Show top 3
                    print(f"  {i+1}. Score: {result['score']:.4f}, Distance: {result['distance']:.6f}")
                    print(f"     Content: {result['content'][:150]}...")
                    print()


        except Exception as e:
            print(f"Error during test query: {e}")
            import traceback
            traceback.print_exc()
    else:
        print("Collection object is None. Cannot perform operations.")

except Exception as e:
    print(f"Error connecting to ChromaDB or accessing collection '{CHROMA_COLLECTION_NAME}': {e}")
    print("Please ensure ChromaDB is running and the 'chroma_db' directory exists and is accessible.")
    import traceback
    traceback.print_exc()