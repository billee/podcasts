import chromadb
from prettytable import PrettyTable
from chromadb.utils import embedding_functions
import json

class ChromaDBViewer:
    def __init__(self, db_path: str = "./chroma_db", collection_name: str = "ofw_knowledge"):
        self.db_path = db_path
        self.collection_name = collection_name
        self.client = None
        self.collection = None
        self._initialize_client()

    def _initialize_client(self):
        """Initialize ChromaDB client and get collection"""
        try:
            self.client = chromadb.PersistentClient(path=self.db_path)
            print(f"✅ Connected to ChromaDB at: {self.db_path}")

            # Use the same embedding function that was used to create the collection
            embedding_function = embedding_functions.SentenceTransformerEmbeddingFunction(
                model_name="intfloat/multilingual-e5-base"
            )

            self.collection = self.client.get_collection(
                name=self.collection_name,
                embedding_function=embedding_function
            )
            print(f"✅ Retrieved collection: {self.collection_name}")

        except Exception as e:
            print(f"❌ Error connecting to ChromaDB: {e}")
            raise

    def show_collection_info(self):
        """Display basic information about the collection"""
        print("\n" + "="*60)
        print("CHROMADB COLLECTION INFORMATION")
        print("="*60)

        try:
            # Get collection count
            items = self.collection.get()
            total_items = len(items['ids'])

            print(f"Collection Name: {self.collection_name}")
            print(f"Total Documents: {total_items}")
            print(f"Database Path: {self.db_path}")

            # Try to get embedding function info
            try:
                embedding_func = self.collection._embedding_function
                if hasattr(embedding_func, 'model_name'):
                    print(f"Embedding Model: {embedding_func.model_name}")
                else:
                    print("Embedding Function: Custom or default")
            except:
                print("Embedding Function: Unable to determine")

            print("-" * 60)

        except Exception as e:
            print(f"Error getting collection info: {e}")

    def show_summary_table(self, limit: int = 10):
        """Show a summary table of documents"""
        print("\nDOCUMENT SUMMARY TABLE")
        print("-" * 60)

        try:
            items = self.collection.get(include=["documents", "metadatas"])

            if not items['ids']:
                print("No documents found in the collection.")
                return

            # DEBUG: Print raw data structure
            print(f"DEBUG: Total items retrieved: {len(items['ids'])}")
            print(f"DEBUG: First few IDs: {items['ids'][:3]}")
            if items['metadatas']:
                print(f"DEBUG: First metadata sample: {items['metadatas'][0]}")

            # Create summary table
            table = PrettyTable()
            table.field_names = ["#", "ID", "File", "Type", "Chunk", "Preview"]
            table.align = "l"
            table.max_width["Preview"] = 40
            table.max_width["ID"] = 25
            table.max_width["File"] = 35  # Add this to prevent file name overflow
            table.max_width = 150

            # Show limited items
            display_count = min(limit, len(items['ids']))
            print(f"DEBUG: Will display {display_count} items")

            file_chunk_counts = {}
            for metadata in items["metadatas"]:
                source = metadata.get("source", "Unknown")
                if source in file_chunk_counts:
                    file_chunk_counts[source] += 1
                else:
                    file_chunk_counts[source] = 1


            for i in range(display_count):

                    doc_id = items["ids"][i]
                    document = items["documents"][i]
                    metadata = items["metadatas"][i]

                    print(f"DEBUG: Processing item {i+1}, ID: {doc_id[:20]}...")
                    print(f"DEBUG: Metadata keys: {list(metadata.keys())}")

                    # Extract info from metadata - FIXED VERSION
                    source = metadata.get("source", "Unknown")

                    # Extract filename from source (remove path if present)
                    if "/" in source:
                        filename = source.split("/")[-1]
                    elif "\\" in source:
                        filename = source.split("\\")[-1]
                    else:
                        filename = source


                    # Derive file type
                    file_type = filename.split(".")[-1].upper() if "." in filename else "TXT"
                    print(f"DEBUG: Calculated file_type: '{file_type}'")

                    print(f"DEBUG: filename='{filename}', file_type='{file_type}'")

                    # Truncate filename if too long
                    if len(filename) > 32:
                        filename = filename[:29] + "..."

                    # Use chunk_id from metadata
                    chunk_id = metadata.get("chunk_id", 0)
                    total_chunks = file_chunk_counts.get(source, 1)
                    chunk_info = f"{chunk_id + 1}/{total_chunks}"  # We don't store total chunks

                    # Create preview (first 47 chars + "...")
                    preview = document[:37] + "..." if len(document) > 40 else document
                    preview = preview.replace('\n', ' ').replace('\r', ' ')

                    print(f"DEBUG: Row data - #{i+1}, File: {filename}, Type: {file_type}, Chunk: {chunk_info}")

                    table.add_row([
                        i+1,
                        doc_id[:22] + "..." if len(doc_id) > 25 else doc_id,
                        filename,
                        file_type,
                        chunk_info,
                        preview
                    ])



            print("\nDEBUG: About to print table...")
            print(table)

            if len(items['ids']) > limit:
                print(f"\n(Showing {display_count} of {len(items['ids'])} documents)")

        except Exception as e:
            print(f"Error creating summary table: {e}")
            import traceback
            traceback.print_exc()

    def show_document_details(self, document_index: int = 0):
        """Show detailed view of a specific document"""
        print(f"\nDETAILED DOCUMENT VIEW (Document #{document_index + 1})")
        print("-" * 60)

        try:
            items = self.collection.get(include=["documents", "metadatas"])

            if not items['ids'] or document_index >= len(items['ids']):
                print(f"Document #{document_index + 1} not found. Total documents: {len(items['ids'])}")
                return

            doc_id = items["ids"][document_index]
            document = items["documents"][document_index]
            metadata = items["metadatas"][document_index]

            print(f"ID: {doc_id}")
            print(f"Length: {len(document)} characters")
            print("\nMetadata:")
            for key, value in metadata.items():
                print(f"  {key}: {value}")

            print(f"\nDocument Content:")
            print("-" * 40)
            print(document)
            print("-" * 40)

        except Exception as e:
            print(f"Error showing document details: {e}")

    def show_files_breakdown(self):
        """Show breakdown by file types and sources"""
        print("\nFILES BREAKDOWN")
        print("-" * 60)

        try:
            items = self.collection.get(include=["metadatas"])

            if not items['ids']:
                print("No documents found.")
                return

            # Analyze metadata
            file_stats = {}
            type_stats = {}

            for metadata in items["metadatas"]:
                source = metadata.get("source", "Unknown")

                # Count by filename
                if "/" in source:
                    filename = source.split("/")[-1]
                elif "\\" in source:
                    filename = source.split("\\")[-1]
                else:
                    filename = source

                if "." in filename:
                    file_type = filename.split(".")[-1].upper()
                else:
                    file_type = "Unknown"

                # Count by file type
                if filename in file_stats:
                    file_stats[filename] += 1
                else:
                    file_stats[filename] = 1

                if file_type in type_stats:
                    type_stats[file_type] += 1
                else:
                    type_stats[file_type] = 1


            # Display file breakdown
            print("By File:")
            for filename, count in sorted(file_stats.items()):
                print(f"  {filename}: {count} chunks")

            print(f"\nBy Type:")
            for file_type, count in sorted(type_stats.items()):
                print(f"  {file_type}: {count} chunks")

            print(f"\nTotal: {len(items['ids'])} document chunks")

        except Exception as e:
            print(f"Error creating files breakdown: {e}")

    def search_documents(self, query: str, n_results: int = 5):
        """Search documents using vector similarity"""
        print(f"\nSEARCH RESULTS for: '{query}'")
        print("-" * 60)

        try:
            results = self.collection.query(
                query_texts=[query],
                n_results=n_results,
                include=["documents", "metadatas", "distances"]
            )

            if not results['ids'][0]:
                print("No results found.")
                return

            print(f"Found {len(results['ids'][0])} results:\n")

            for i, (doc_id, document, metadata, distance) in enumerate(zip(
                    results['ids'][0],
                    results['documents'][0],
                    results['metadatas'][0],
                    results['distances'][0]
            )):
                print(f"Result #{i+1} (Distance: {distance:.4f})")
                print(f"File: {metadata.get('filename', 'Unknown')}")
                print(f"Type: {metadata.get('file_type', 'Unknown')}")
                print(f"Content Preview: {document[:200]}...")
                print("-" * 40)

        except Exception as e:
            print(f"Error searching documents: {e}")

    def show_all_documents(self):
        """Show all documents in a detailed format"""
        print("\nALL DOCUMENTS")
        print("=" * 60)

        try:
            items = self.collection.get(include=["documents", "metadatas"])

            if not items['ids']:
                print("No documents found.")
                return

            for i, (doc_id, document, metadata) in enumerate(zip(
                    items["ids"],
                    items["documents"],
                    items["metadatas"]
            )):
                print(f"\nDocument #{i+1}")
                print(f"ID: {doc_id}")
                print(f"File: {metadata.get('filename', 'Unknown')}")
                print(f"Type: {metadata.get('file_type', 'Unknown')}")
                print(f"Chunk: {metadata.get('chunk_index', 0)+1}/{metadata.get('total_chunks', 1)}")
                print(f"Content ({len(document)} chars):")
                print("-" * 40)
                print(document)
                print("-" * 40)

        except Exception as e:
            print(f"Error showing all documents: {e}")


def main():
    """Main function with interactive options"""
    try:
        viewer = ChromaDBViewer()

        # Show collection info
        viewer.show_collection_info()

        # Show summary table
        viewer.show_summary_table()

        # Show files breakdown
        viewer.show_files_breakdown()

        # Interactive menu
        while True:
            print("\n" + "="*60)
            print("CHROMADB VIEWER OPTIONS")
            print("="*60)
            print("1. Show summary table")
            print("2. Show files breakdown")
            print("3. View specific document details")
            print("4. Search documents")
            print("5. Show all documents (detailed)")
            print("6. Exit")

            choice = input("\nSelect option (1-6): ").strip()

            if choice == '1':
                limit = input("Enter number of documents to show (default 10): ").strip()
                limit = int(limit) if limit.isdigit() else 10
                viewer.show_summary_table(limit)

            elif choice == '2':
                viewer.show_files_breakdown()

            elif choice == '3':
                doc_num = input("Enter document number to view: ").strip()
                if doc_num.isdigit():
                    viewer.show_document_details(int(doc_num) - 1)
                else:
                    print("Please enter a valid number.")

            elif choice == '4':
                query = input("Enter search query: ").strip()
                if query:
                    n_results = input("Number of results (default 5): ").strip()
                    n_results = int(n_results) if n_results.isdigit() else 5
                    viewer.search_documents(query, n_results)
                else:
                    print("Please enter a search query.")

            elif choice == '5':
                confirm = input("This will show ALL documents. Continue? (y/N): ").strip().lower()
                if confirm == 'y':
                    viewer.show_all_documents()

            elif choice == '6':
                print("Goodbye!")
                break

            else:
                print("Invalid option. Please select 1-6.")

    except Exception as e:
        print(f"Fatal error: {e}")


if __name__ == "__main__":
    main()