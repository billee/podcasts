import chromadb
from prettytable import PrettyTable

# Initialize Chroma Client
client = chromadb.PersistentClient(path="./chroma_db")

# Get collection
collection = client.get_collection(name="ofw_knowledge")

# Retrieve all items (FIXED INCLUDE PARAMETER)
items = collection.get(
    include=["documents", "metadatas"]  # Remove "ids" from include list
)

# Create table
table = PrettyTable()
table.field_names = ["ID", "Document", "Category", "Metadata"]
table.align = "l"

# Populate table (IDs are now directly accessible)
for id, doc, meta in zip(items["ids"], items["documents"], items["metadatas"]):
    table.add_row([id, doc, meta.get("category", ""), meta])

print("ChromaDB Contents:")
print(table)