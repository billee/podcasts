"""
ChromaDB Setup with Pure Regex Chunking
- No NLTK dependencies
- Reliable sentence splitting using regex
- Preserves all core functionality
"""

import chromadb
from chromadb.utils import embedding_functions
import os
import uuid
import re
from typing import List, Dict, Any

# Import our custom module for data reading
from data_source_reader import DataSourceReader

class ChromaVectorDatabase:
    def __init__(self, db_path: str = "./chroma_db", collection_name: str = "ofw_knowledge"):
        # self.EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"
        self.EMBEDDING_MODEL_NAME = "all-mpnet-base-v2"
        self.CHROMA_DB_PATH = db_path
        self.CHROMA_COLLECTION_NAME = collection_name
        self.client = None
        self.collection = None
        self.data_reader = DataSourceReader()
        self._initialize_chroma_client()

    def _initialize_chroma_client(self):
        """Initialize ChromaDB client and collection"""
        try:
            self.client = chromadb.PersistentClient(path=self.CHROMA_DB_PATH)
            sentence_transformer_ef = embedding_functions.SentenceTransformerEmbeddingFunction(
                model_name=self.EMBEDDING_MODEL_NAME
            )
            self.collection = self.client.get_or_create_collection(
                name=self.CHROMA_COLLECTION_NAME,
                embedding_function=sentence_transformer_ef
            )
            print(f"✅ ChromaDB collection '{self.CHROMA_COLLECTION_NAME}' initialized.")
        except Exception as e:
            print(f"❌ Error initializing ChromaDB client: {e}")
            raise

    def clear_vector_database(self):
        """Clears all data from the ChromaDB collection."""
        try:
            print(f"Clearing collection '{self.CHROMA_COLLECTION_NAME}'...")
            self.client.delete_collection(name=self.CHROMA_COLLECTION_NAME)
            self._initialize_chroma_client()
            print("✅ ChromaDB collection cleared.")
        except Exception as e:
            print(f"❌ Error clearing collection: {e}")
            raise

    def _clean_text(self, text: str) -> str:
        """Basic text cleaning before chunking"""
        text = re.sub(r'\s+', ' ', text)  # Normalize whitespace
        text = re.sub(r'\[\d+\]', '', text)  # Remove citation numbers
        return text.strip()

    def _regex_sent_tokenize(self, text: str) -> List[str]:
        """Reliable sentence tokenizer using regex, also splitting on paragraphs."""
        # Split on sentence endings with lookbehind for punctuation
        sentences = re.split(r'(?<=[.!?])\s+', text)
        # Further split on paragraph markers if needed, ensuring no empty strings
        result = []
        for s in sentences:
            parts = re.split(r'\n\n', s) # Split on explicit paragraph breaks
            result.extend([p.strip() for p in parts if p.strip()])
        return result

    def _semantic_chunk_text(self, text: str, max_chunk_size: int = 300, overlap: int = 100) -> List[str]: # Increased defaults
        """
        Robust chunking using only regex, prioritizing semantic coherence.
        - Tries to keep logical units (like paragraphs) together.
        - Preserves logical flow with overlap.
        - Ensures no chunk exceeds max size.
        """
        text = self._clean_text(text)
        # First, try to get larger logical blocks (e.g., paragraphs or groups of sentences)
        sentences = self._regex_sent_tokenize(text) # This already handles \n\n as paragraph splits

        chunks = []
        current_chunk = ""

        for i, sentence in enumerate(sentences):
            # If adding the current sentence makes the chunk too large,
            # or if it's a new paragraph and the current chunk is substantial,
            # finalize the current chunk.
            if len(current_chunk) + len(sentence) + 1 > max_chunk_size:
                if current_chunk: # Only append if the chunk has content
                    chunks.append(current_chunk)

                # Prepare for the next chunk with overlap from the *previous* finalized chunk
                # or start fresh if no previous chunk or not enough content for meaningful overlap
                if len(current_chunk) >= overlap:
                    overlap_content = current_chunk[-overlap:].strip()
                else:
                    overlap_content = current_chunk.strip() # Use full chunk if smaller than overlap

                current_chunk = (overlap_content + " " + sentence).strip()
                # Ensure the overlap doesn't make the *new* chunk too big from the start
                # This might require trimming overlap if the new sentence is very long
                if len(current_chunk) > max_chunk_size:
                    current_chunk = current_chunk[-max_chunk_size:] # Take the end part if it's too long
            else:
                # Add sentence to current chunk
                current_chunk += (" " + sentence).strip() if current_chunk else sentence.strip()

        # Add the last chunk if it exists
        if current_chunk:
            chunks.append(current_chunk)

        # Final safety check: if any chunk is still too large, split it
        final_chunks = []
        for chunk in chunks:
            if len(chunk) > max_chunk_size:
                # Simple split for oversized chunks, this might break sentences but is a fallback
                sub_chunks = [chunk[j:j+max_chunk_size] for j in range(0, len(chunk), max_chunk_size)]
                final_chunks.extend(sub_chunks)
            else:
                final_chunks.append(chunk)

        return [chunk.strip() for chunk in final_chunks if chunk.strip()]

    def populate_vector_database(self):
        """Populates ChromaDB with documents"""
        print("Populating ChromaDB with documents...")
        all_files_data = self.data_reader.read_all_files()

        if not all_files_data:
            print("⚠️ No files found to process.")
            return

        documents, metadatas, ids = [], [], []

        for file_data in all_files_data:
            chunks = self._semantic_chunk_text(file_data['content'])
            if not chunks:
                print(f"  Skipped {file_data['filename']} (no valid chunks)")
                continue

            print(f"  Processed {file_data['filename']} -> {len(chunks)} chunks")

            for i, chunk in enumerate(chunks):
                documents.append(chunk)
                metadatas.append({
                    "source": file_data['filename'],
                    "chunk_id": i,
                    "length": len(chunk)
                })
                ids.append(str(uuid.uuid4()))

        if documents:
            self._add_documents_in_batches(documents, metadatas, ids)
            print(f"🎉 Added {len(documents)} chunks to ChromaDB")
        else:
            print("⚠️ No documents were added.")

    def _add_documents_in_batches(self, documents: List[str], metadatas: List[dict], ids: List[str], batch_size: int = 100):
        """Batch addition with progress tracking"""
        total = 0
        for i in range(0, len(documents), batch_size):
            batch = {
                "documents": documents[i:i+batch_size],
                "metadatas": metadatas[i:i+batch_size],
                "ids": ids[i:i+batch_size]
            }
            try:
                self.collection.add(**batch)
                total += len(batch["documents"])
                print(f"  Added batch {i//batch_size + 1} ({len(batch['documents'])} chunks)")
            except Exception as e:
                print(f"❌ Batch {i//batch_size + 1} failed: {e}")
                raise

        print(f"✅ Successfully added {total} documents total")

def main():
    try:
        print("🚀 Starting ChromaDB setup...")
        chroma_db = ChromaVectorDatabase()
        chroma_db.populate_vector_database()
        print("\n🎉 Setup completed successfully!")
    except Exception as e:
        print(f"\n❌ Setup failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()