import chromadb
from chromadb.utils import embedding_functions

CHROMA_COLLECTION_NAME = "ofw_knowledge"
EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"

client = chromadb.PersistentClient(path="./chroma_db")

try:
    collection = client.get_collection(name=CHROMA_COLLECTION_NAME)
    print(f"Successfully connected to Chroma collection: '{CHROMA_COLLECTION_NAME}'")
    print(f"Collection contains {collection.count()} documents.")
except Exception as e:
    print(f"Error accessing Chroma collection '{CHROMA_COLLECTION_NAME}': {e}")
    print("Please ensure the client path/host is correct and the collection name matches.")
    exit()


test_query = "Who may register as overseas voters?" # A direct question from the PDF
print(f"Test Query: '{test_query}'")
try:
    test_results = collection.query(
        query_texts=[test_query],
        n_results=5, # Get top 5 results for the test
        include=['documents', 'distances', 'metadatas']
    )
    print("Test Query Results:")
    if test_results and test_results.get('documents') and test_results['documents'][0]:
        for i in range(len(test_results['documents'][0])):
            print(f"  Result {i+1}:")
            print(f"    Content: {test_results['documents'][0][i][:200]}...") # Print first 200 chars
            print(f"    Score: {1 - test_results['distances'][0][i]:.4f}") # Print similarity score
            print(f"    Metadata: {test_results['metadatas'][0][i]}")
    else:
        print("  No documents retrieved for the test query.")
except Exception as e:
    print(f"Error during post-indexing test query: {e}")