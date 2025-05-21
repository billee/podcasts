import chromadb
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction

# Initialize the SAME client type as setup
client = chromadb.PersistentClient(path="./chroma_db")  # Must match chroma_setup.py

print("Existing collections:", [col.name for col in client.list_collections()])

try:
    # Get collection with the same embedding function used during setup
    embedding_function = SentenceTransformerEmbeddingFunction(
        model_name="all-MiniLM-L6-v2"
    )
    collection = client.get_collection(
        name="ofw_knowledge",
        embedding_function=embedding_function
    )

    # Test query with parameters
    results = collection.query(
        query_texts=["What is the procedure for filing application for overseas voter?"],
        n_results=2,
        include=["documents", "metadatas", "distances"]
    )

    print("\nQuery Results:")
    for doc, meta, dist in zip(results['documents'][0],
                               results['metadatas'][0],
                               results['distances'][0]):
        print(f"\n📄 Document (score: {1-dist:.2f}):")
        print(doc[:200] + "...")
        print(f"Metadata: {meta}")

except chromadb.errors.NotFoundError:
    print("\nCollection not found. Please run chroma_setup.py first!")
    print("Run this command to initialize the database:")
    print("python chroma_setup.py")
except Exception as e:
    print(f"\nError: {str(e)}")