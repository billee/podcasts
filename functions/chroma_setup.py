import chromadb
from chromadb.utils import embedding_functions
import os
from typing import List, Dict, Any
import uuid # For generating unique IDs
import re # For simple text splitting

# Import our custom module for data reading
from data_source_reader import DataSourceReader


class ChromaVectorDatabase:
    """
    Single Responsibility: Manages ChromaDB vector database operations
    - Initialize ChromaDB collection
    - Clear existing data
    - Populate with document embeddings
    """

    def __init__(self, db_path: str = "./chroma_db", collection_name: str = "ofw_knowledge"):
        self.EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2" # Using a general-purpose embedding model
        self.CHROMA_DB_PATH = db_path
        self.CHROMA_COLLECTION_NAME = collection_name

        # Initialize ChromaDB components
        self.client = None
        self.collection = None

        # Initialize data reader (Dependency Injection following SOLID)
        self.data_reader = DataSourceReader()

        # Setup ChromaDB
        self._initialize_chroma_client()

    def _initialize_chroma_client(self):
        """Initialize ChromaDB client and collection with embedding function"""
        try:
            # Create persistent client
            self.client = chromadb.PersistentClient(path=self.CHROMA_DB_PATH)

            # Configure embedding function
            sentence_transformer_ef = embedding_functions.SentenceTransformerEmbeddingFunction(
                model_name=self.EMBEDDING_MODEL_NAME
            )

            # Get or create collection
            self.collection = self.client.get_or_create_collection(
                name=self.CHROMA_COLLECTION_NAME,
                embedding_function=sentence_transformer_ef,
                # metadata={"hnsw:space": "cosine"} # Optional: define distance function
            )
            print(f"✅ ChromaDB collection '{self.CHROMA_COLLECTION_NAME}' initialized.")
            print(f"   Using embedding model: {self.EMBEDDING_MODEL_NAME}")
            print(f"   Database path: {self.CHROMA_DB_PATH}")

        except Exception as e:
            print(f"❌ Error initializing ChromaDB client or collection: {e}")
            print("   Ensure you have internet access to download the embedding model if it's the first run.")
            raise

    def clear_vector_database(self):
        """Clears all data from the ChromaDB collection."""
        try:
            print(f"Clearing existing data from collection '{self.CHROMA_COLLECTION_NAME}'...")
            self.client.delete_collection(name=self.CHROMA_COLLECTION_NAME)
            # Re-create the collection after deletion
            self._initialize_chroma_client()
            print("✅ ChromaDB collection cleared successfully.")
        except Exception as e:
            print(f"❌ Error clearing ChromaDB collection: {e}")
            raise

    def _simple_chunk_text(self, text: str, max_chunk_size: int = 500, overlap: int = 50) -> List[str]:
        """
        A simple text chunking function by splitting on sentences or paragraphs.
        Attempts to split text into chunks no larger than max_chunk_size, with some overlap.
        """
        # Split by paragraphs first (double newline)
        paragraphs = text.split('\n\n')
        chunks = []
        current_chunk = ""

        for para in paragraphs:
            para = para.strip()
            if not para:
                continue

            if len(current_chunk) + len(para) + 1 <= max_chunk_size:
                current_chunk += (" " if current_chunk else "") + para
            else:
                if current_chunk:
                    chunks.append(current_chunk)
                current_chunk = para # Start new chunk with current paragraph

                # If a single paragraph is too large, split it further by sentences.
                while len(current_chunk) > max_chunk_size:
                    sentences = re.split(r'(?<=[.!?])\s+', current_chunk)
                    temp_sub_chunk = ""
                    added_sub_chunk = False
                    for sentence in sentences:
                        if len(temp_sub_chunk) + len(sentence) + 1 <= max_chunk_size:
                            temp_sub_chunk += (" " if temp_sub_chunk else "") + sentence
                        else:
                            if temp_sub_chunk:
                                chunks.append(temp_sub_chunk)
                                added_sub_chunk = True
                                # Add overlap if desired
                                if overlap > 0:
                                    last_words = temp_sub_chunk.split()[-overlap:]
                                    temp_sub_chunk = " ".join(last_words) + " " + sentence
                                else:
                                    temp_sub_chunk = sentence
                            else: # If a single sentence is larger than max_chunk_size
                                chunks.append(sentence[:max_chunk_size])
                                temp_sub_chunk = sentence[max_chunk_size:] # Remainder
                                added_sub_chunk = True
                    if temp_sub_chunk: # Add any remaining part of the oversized paragraph
                        chunks.append(temp_sub_chunk)
                    current_chunk = "" # Reset for next paragraph
                    break # Break inner while loop, continue with next paragraph

        if current_chunk: # Add any remaining content
            chunks.append(current_chunk)

        # Refine chunks to ensure max_chunk_size and add overlap
        final_chunks = []
        for i, chunk in enumerate(chunks):
            if len(chunk) > max_chunk_size: # If a chunk is still too large, split it again
                sub_chunks = [chunk[j:j+max_chunk_size] for j in range(0, len(chunk), max_chunk_size - overlap)]
                final_chunks.extend(sub_chunks)
            else:
                final_chunks.append(chunk)

        return [c.strip() for c in final_chunks if c.strip()]


    def populate_vector_database(self):
        """
        Populates the ChromaDB vector database with documents from data sources.
        It now uses the new read_all_files() method to get individual file contents
        with metadata and performs intelligent chunking.
        """
        print("Populating ChromaDB with documents...")

        # Read individual files from data sources with their metadata
        all_files_data = self.data_reader.read_all_files()

        if not all_files_data:
            print("No individual file content found from data sources. Vector database will not be populated.")
            return

        documents_to_add: List[str] = []
        metadatas_to_add: List[Dict[str, Any]] = []
        ids_to_add: List[str] = []

        print(f"Preparing {len(all_files_data)} files for embedding and chunking...")

        for file_data in all_files_data:
            content = file_data['content']
            filename = file_data['filename']
            file_type = file_data['file_type']

            # Apply chunking to each individual file's content
            # You can customize max_chunk_size and overlap based on your needs and embedding model
            chunks = self._simple_chunk_text(content, max_chunk_size=400, overlap=50) # Adjusted chunk size for MiniLM

            if not chunks:
                print(f"  Skipping '{filename}' as no substantial chunks were extracted.")
                continue

            print(f"  Processed '{filename}' ({file_type}) into {len(chunks)} chunks.")

            for i, chunk in enumerate(chunks):
                documents_to_add.append(chunk)
                # Attach specific metadata to each chunk
                metadatas_to_add.append({
                    "filename": filename,
                    "file_type": file_type,
                    "chunk_index": i,
                    "length": len(chunk),
                    "source_path": os.path.join(self.data_reader.data_sources_path, filename) # Full path can be useful
                })
                # Generate a unique ID for each chunk
                ids_to_add.append(str(uuid.uuid4()))


        if documents_to_add:
            try:
                self.add_documents_in_batches(documents_to_add, metadatas_to_add, ids_to_add)
                print(f"🎉 Successfully populated ChromaDB with {len(documents_to_add)} document chunks.")
            except Exception as e:
                print(f"❌ Failed to add documents to ChromaDB: {e}")
        else:
            print("No documents were substantial enough to be added to ChromaDB after chunking.")


    def add_documents_in_batches(self, documents: List[str], metadatas: List[dict], ids: List[str], batch_size: int = 100):
        """Add documents to ChromaDB in batches to handle large datasets efficiently"""
        total_added = 0

        for i in range(0, len(documents), batch_size):
            batch_docs = documents[i:i+batch_size]
            batch_metadata = metadatas[i:i+batch_size]
            batch_ids = ids[i:i+batch_size]

            try:
                self.collection.add(
                    documents=batch_docs,
                    metadatas=batch_metadata,
                    ids=batch_ids
                )
                total_added += len(batch_docs)
                print(f"Added batch {i//batch_size + 1}: {len(batch_docs)} documents")

            except Exception as e:
                print(f"Error adding batch {i//batch_size + 1}: {e}")
                raise

        print(f"Successfully added {total_added} documents in total")


def main():
    """
    Main execution function
    Simple interface following Single Responsibility Principle
    """
    try:
        print("🚀 Starting ChromaDB vector database setup...\n")

        # Initialize ChromaDB manager
        chroma_db = ChromaVectorDatabase()

        # It's good practice to clear existing data before a fresh populate,
        # especially if the source data or processing logic changes.
        # Uncomment the line below if you want to clear the DB before populating.
        # chroma_db.clear_vector_database()

        # Populate vector database
        chroma_db.populate_vector_database()

        print("\n🎉 ChromaDB setup completed successfully!")

    except Exception as e:
        print(f"\n❌ An error occurred during ChromaDB setup: {e}")
        import traceback
        traceback.print_exc() # Print full traceback for debugging


if __name__ == "__main__":
    main()