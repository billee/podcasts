import chromadb
from prettytable import PrettyTable
from chromadb.utils import embedding_functions

# Initialize Chroma Client
client = chromadb.PersistentClient(path="./chroma_db")
print(client)

# Get collection
collection = client.get_collection(name="ofw_knowledge")
print(collection)

# Retrieve all items (FIXED INCLUDE PARAMETER)
items = collection.get(
    include=["documents", "metadatas"]  # Remove "ids" from include list
)

num_items = len(items['ids'])
print(f"Number of items retrieved: {num_items}")

try:
    embedding_func = collection._embedding_function
    print(f"Embedding function used by the collection: {embedding_func}")

    if isinstance(embedding_func, embedding_func.SentenceTransformerEmbeddingFunction):
        print(f"SentenceTransformer model name: {embedding_func.model_name}")
    else:
        print("This collection uses a custom or different type of embedding function.")

except AttributeError:
    print("Could not directly access the embedding function object from the collection.")
    print("This might be due to ChromaDB version or internal implementation details.")
    print("If you didn't specify one, it likely used the default (often 'all-MiniLM-L6-v2').")




print('---------------------------------------------------')
if len(items['ids']) > 0:
    first_id = items['ids'][0]
    first_document = items['documents'][0]
    first_metadata = items['metadatas'][0]

    print("\n--- First Item ---")
    print(f"ID: {first_id}")
    print(f"Document: {first_document}")
    print(f"Metadata: {first_metadata}")

# quit()

# Create table
table = PrettyTable()
table.field_names = ["ID", "Document", "Category", "Metadata"]
table.align = "l"

# Populate table (IDs are now directly accessible)
for id, doc, meta in zip(items["ids"], items["documents"], items["metadatas"]):
    table.add_row([id, doc, meta.get("category", ""), meta])

print("ChromaDB Contents:")
print(table)