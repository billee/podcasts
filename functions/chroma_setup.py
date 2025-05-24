# It deletes the whole previous records on the chromadb first.
# Populate chromadb with all the sources in data_sources directory.
# It uses "paraphrase-multilingual-MiniLM-L12-v2" as the embedding model.
# After, Test the chromedb by querying. The test_query is assumed to use the same model as above.
# Subsequent testing, you can use test_chroma.py by querying.

import os
import chromadb
import hashlib
import json
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction
from chromadb.utils import embedding_functions
from PyPDF2 import PdfReader
from tqdm import tqdm
import re # Import regex for splitting
import time # Import time for a small delay if needed

class DataProcessor:

    # EMBEDDING_MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"
    EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"

    def __init__(self):
        self.embed_fn = SentenceTransformerEmbeddingFunction(
            model_name=DataProcessor.EMBEDDING_MODEL_NAME
        )
        self.supported_types = ['.txt', '.pdf', '.json']
        # Define chunking parameters for PDFs
        self.pdf_chunk_size = 500 # Characters per chunk
        self.pdf_chunk_overlap = 100 # Overlap between chunks

    def process_directory(self, root_dir: str = "data_sources") -> Dict[str, List]:
        """Process all files in data_sources directory"""
        data = {"documents": [], "metadatas": [], "ids": []}

        for file_path in tqdm(list(Path(root_dir).rglob("*")), desc="Processing files"):
            if file_path.suffix.lower() not in self.supported_types:
                continue

            try:
                # Process file and get content(s) and metadata(s)
                contents_and_metadatas = self._process_file(file_path)

                for content, metadata in contents_and_metadatas:
                    if content and content.strip(): # Ensure content is not empty or just whitespace
                        # Generate a unique ID for each chunk
                        # Include chunk index in ID to ensure uniqueness for chunks from the same file
                        # Using a hash of file path and chunk content/index for robustness
                        chunk_id_base = f"{file_path}_{len(data['documents'])}" # Use a running index for this file's chunks
                        doc_id = hashlib.md5(f"{chunk_id_base}_{content}".encode()).hexdigest()[:12]


                        data["documents"].append(content)
                        data["metadatas"].append(metadata)
                        data["ids"].append(doc_id)
                    else:
                        print(f"Warning: Skipped empty or whitespace content from {file_path}")


            except Exception as e:
                print(f"Error processing {file_path}: {str(e)}")

        return data

    def _process_file(self, file_path: Path) -> List[Tuple[str, Dict]]:
        """Process individual files based on type, returning a list of (content, metadata) tuples"""
        base_metadata = {
            "source": str(file_path),
            "type": file_path.parent.name,
            "language": "taglish" # Assuming Taglish content
        }
        results = []

        if file_path.suffix == '.txt':
            content = file_path.read_text(encoding='utf-8')
            metadata = base_metadata.copy()
            metadata.update({"format": "text"})
            if content and content.strip():
                results.append((content.strip(), metadata))

        elif file_path.suffix == '.pdf':
            full_text = self._extract_pdf_text(file_path)
            metadata_template = base_metadata.copy()
            try:
                pdf_reader = PdfReader(file_path)
                metadata_template.update({"format": "pdf", "pages": len(pdf_reader.pages)})
            except Exception as e:
                print(f"Warning: Could not get page count for {file_path}: {e}")
                metadata_template.update({"format": "pdf", "pages": "N/A"})


            # Chunk the PDF text
            chunks = self._chunk_text(full_text, self.pdf_chunk_size, self.pdf_chunk_overlap)

            for i, chunk in enumerate(chunks):
                if chunk and chunk.strip(): # Ensure chunk is not empty or just whitespace
                    chunk_metadata = metadata_template.copy()
                    # Optional: Add chunk specific metadata, like chunk index or page number if derivable
                    # Deriving page number from chunk is complex without more advanced PDF processing
                    chunk_metadata["chunk_index"] = i
                    results.append((chunk.strip(), chunk_metadata))
                else:
                    print(f"Warning: Skipped empty or whitespace chunk {i} from {file_path}")


        elif file_path.suffix == '.json':
            # Assuming JSON contains Q&A pairs, each pair becomes a document
            try:
                json_data = json.loads(file_path.read_text())
                # Assuming JSON structure like {"question": "...", "answer": "...", "metadata": {...}}
                question = json_data.get('question', '')
                answer = json_data.get('answer', '')
                content = f"Q: {question}\nA: {answer}"

                metadata = base_metadata.copy()
                # Process metadata from JSON to ensure compatibility
                json_metadata = json_data.get('metadata', {})
                for key, value in json_metadata.items():
                    if isinstance(value, list):
                        # Convert list to a comma-separated string, or handle as needed
                        metadata[key] = ", ".join(map(str, value))
                    else:
                        metadata[key] = value
                # Ensure 'format' is also set, as in other file types
                metadata.update({"format": "json"})

                if content and content.strip():
                    results.append((content.strip(), metadata))

            except Exception as e:
                print(f"Error processing JSON file {file_path}: {e}")


        return results

    def _extract_pdf_text(self, file_path: Path) -> str:
        """Extract text from PDF files"""
        text = []
        try:
            with open(file_path, 'rb') as f:
                reader = PdfReader(f)
                for page in reader.pages:
                    # Extract text, replace multiple newlines/spaces for cleaner chunks
                    page_text = page.extract_text()
                    if page_text:
                        # Simple cleaning: replace multiple whitespace with single space
                        page_text = re.sub(r'\s+', ' ', page_text).strip()
                        text.append(page_text)
        except Exception as e:
            print(f"Error extracting text from PDF {file_path}: {e}")
            return "" # Return empty string if extraction fails
        return " ".join(text) # Join pages with space for better flow between pages

    def _chunk_text(self, text: str, chunk_size: int, chunk_overlap: int) -> List[str]:
        """Splits text into overlapping chunks."""
        if not text:
            return []

        chunks = []
        start = 0
        while start < len(text):
            end = start + chunk_size
            chunk = text[start:end]
            chunks.append(chunk)
            # Calculate the next start position, ensuring it's not beyond the text length
            next_start = start + chunk_size - chunk_overlap
            if next_start >= len(text):
                break # Stop if the next chunk would start beyond the text
            start = next_start


        return chunks


    def _generate_id(self, content: str, file_path: str, chunk_index: int) -> str:
        """Generate unique ID from content hash, file path, and chunk index"""
        # Include chunk index in the hash input
        # Using a combination of file path, chunk index, and content hash for robustness
        unique_string = f"{file_path}_{chunk_index}_{hashlib.md5(content.encode()).hexdigest()}"
        return hashlib.md5(unique_string.encode()).hexdigest()[:12]


def setup_chroma():

    processor = DataProcessor()
    print(processor)

    CHROMA_COLLECTION_NAME = "ofw_knowledge"
    # EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"
    EMBEDDING_MODEL_NAME =DataProcessor.EMBEDDING_MODEL_NAME

    # Use a persistent client to store data on disk
    client = chromadb.PersistentClient(path="./chroma_db")
    sentence_transformer_ef = embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name=EMBEDDING_MODEL_NAME
    )

    try:
        print(f"Attempting to delete collection '{CHROMA_COLLECTION_NAME}' for a clean re-index...")
        client.delete_collection(name=CHROMA_COLLECTION_NAME)
        print(f"Successfully deleted collection '{CHROMA_COLLECTION_NAME}'.")

        # Give ChromaDB a moment to process the deletion
        time.sleep(1)
    except Exception as e:
        print(f"Could not delete collection (maybe it didn't exist?): {e}")


    try:
        print(f"Creating collection '{CHROMA_COLLECTION_NAME}'...")
        collection = client.create_collection(
            name=CHROMA_COLLECTION_NAME,
            embedding_function= sentence_transformer_ef,
            metadata={"hnsw:space": "cosine"} # Using cosine similarity
        )
        print(f"Collection '{CHROMA_COLLECTION_NAME}' created/obtained.")

    except Exception as e:
        print(f"FATAL ERROR: Could not create collection '{CHROMA_COLLECTION_NAME}': {e}")
        return # Exit if collection cannot be created/obtained


    # print('................................')
    # exit()

    # Process data and upsert documents (chunks)
    print("Processing data sources and generating chunks...")
    data = processor.process_directory()

    if data["documents"]:
        print(f"Adding {len(data['ids'])} document chunks to ChromaDB...")
        # Add documents in batches if there are many
        batch_size = 100
        for i in tqdm(range(0, len(data["ids"]), batch_size), desc="Adding chunks to ChromaDB"):
            batch_ids = data["ids"][i:i+batch_size]
            batch_documents = data["documents"][i:i+batch_size]
            batch_metadatas = data["metadatas"][i:i+batch_size]
            collection.upsert(
                documents=batch_documents,
                metadatas=batch_metadatas,
                ids=batch_ids
            )

        print(f"\nSuccessfully loaded {len(data['ids'])} document chunks into ChromaDB.")
        current_count = collection.count()
        print(f"Current collection count: {current_count} documents.")

        # --- Post-Indexing Query Test ---
        print("\n--- Running Post-Indexing Query Test ---")
        test_query = "balikbayan box pro tips?" # A direct question from the PDF
        try:
            test_results = collection.query(
                query_texts=[test_query],
                n_results=5, # Get top 5 results for the test
                include=['documents', 'distances', 'metadatas']
            )

            print(f"Test Query: '{test_query}'")
            print("Test Query Results:")
            if test_results and test_results.get('documents') and test_results['documents'][0]:
                for i in range(len(test_results['documents'][0])):
                    print(f"  Result {i+1}:::::::::::::::::::::::::::::::::::::::::::::")
                    print(f"    Content: {test_results['documents'][0][i][:200]}...") # Print first 200 chars
                    print(f"    Score: {1 - test_results['distances'][0][i]:.4f}") # Print similarity score
                    print(f"    Metadata: {test_results['metadatas'][0][i]}")
            else:
                print("  No documents retrieved for the test query.")
        except Exception as e:
            print(f"Error during post-indexing test query: {e}")

        print("--- End of Post-Indexing Query Test ---\n")


    else:
        print("No documents found in data_sources directory after processing.")

if __name__ == "__main__":
    setup_chroma()
