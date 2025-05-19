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

    print(f"\nTotal documents in '{collection.name}': {collection.count()}")

    # Step 1: Try to fetch documents specifically marked as PDFs
    print("\n--- Attempting to fetch PDF documents by metadata ---")
    pdf_results = collection.get(
        where={"format": "pdf"}, # Looking for metadata you set in chroma_setup.py
        limit=5,
        include=["documents", "metadatas"]
    )

    if pdf_results and pdf_results['ids']:
        print(f"Found {len(pdf_results['ids'])} documents with 'format: pdf' metadata:")
        for i, doc_id in enumerate(pdf_results['ids']):
            print(f"\n📄 Document ID: {doc_id}")
            print(f"Metadata: {pdf_results['metadatas'][i]}")
            print(f"Content snippet:\n{pdf_results['documents'][i][:500]}...") # Print more content
    else:
        print("No documents found with 'format: pdf' metadata using collection.get().")
        print("This might mean PDFs weren't processed, metadata wasn't set as 'format: pdf', or there's an issue with the .get() filter.")

    # Step 2: If no PDFs found, or for general inspection, let's try a broad query
    # to see what kind of documents ARE in the collection.
    # If you know a very common word that should be in your PDFs, use that.
    # Otherwise, a very generic query might pull up varied documents.
    print("\n--- Attempting a broad query to inspect general documents ---")
    # You can change "information" to a term you are certain is in your PDFs
    # or remove the query_texts and where filter from query() to get random docs (if supported,
    # otherwise use .get() with just a limit)

    # Using .get() to retrieve a few general documents to inspect
    general_results = collection.get(
        limit=5, # Get up to 5 documents
        include=["documents", "metadatas"]
    )

    print(f"\nFound {len(general_results['ids'])} general documents for inspection:")
    if general_results and general_results['ids']:
        for i, doc_id in enumerate(general_results['ids']):
            print(f"\n📄 Document ID: {doc_id}")
            print(f"Metadata: {general_results['metadatas'][i]}") # Show all metadata
            # print(f"Content:\n{general_results['documents'][i]}") # Uncomment to print full content if needed, careful with very long docs
            print(f"Content snippet:\n{general_results['documents'][i][:500]}...")
    else:
        print("Could not retrieve any general documents from the collection using .get(). This is unusual if setup completed.")


    # Step 3: Example of querying with text if you want to try that again
    # AFTER inspecting the above.
    print("\n--- Example of a specific text query (for later testing) ---")
    specific_query_text = "What are the rights of an employee?" # Replace with a query relevant to your PDFs
    query_results = collection.query(
        query_texts=[specific_query_text],
        n_results=2,
        # You can also try with a where filter if PDF metadata seems correct from above
        # where={"format": "pdf"},
        include=["documents", "metadatas", "distances"]
    )

    print(f"\nQuery Results for: '{specific_query_text}'")
    if query_results and query_results['ids'][0]:
        for doc, meta, dist in zip(query_results['documents'][0],
                                   query_results['metadatas'][0],
                                   query_results['distances'][0]):
            print(f"\n📄 Document (score: {1-dist:.2f}):")
            print(f"Content snippet: {doc[:200]}...")
            print(f"Metadata: {meta}")
    else:
        print(f"No results for the query: '{specific_query_text}'")


except chromadb.errors.CollectionNotFoundError: # Corrected specific exception type
    print(f"\nCollection 'ofw_knowledge' not found. Please run chroma_setup.py first!")
    print("Run this command to initialize the database:")
    print("python chroma_setup.py")
except Exception as e:
    print(f"\nAn error occurred: {str(e)}")
    import traceback
    traceback.print_exc()