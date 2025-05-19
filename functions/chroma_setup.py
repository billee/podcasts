import os
import chromadb
import hashlib
import json
from pathlib import Path
from typing import List, Dict, Optional
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction
from PyPDF2 import PdfReader
from tqdm import tqdm

class DataProcessor:
    def __init__(self):
        self.embed_fn = SentenceTransformerEmbeddingFunction(
            model_name="all-MiniLM-L6-v2"
        )
        self.supported_types = ['.txt', '.pdf', '.json']

    def process_directory(self, root_dir: str = "data_sources") -> Dict[str, List]:
        """Process all files in data_sources directory"""
        data = {"documents": [], "metadatas": [], "ids": []}

        for file_path in tqdm(list(Path(root_dir).rglob("*")), desc="Processing files"):
            if file_path.suffix.lower() not in self.supported_types:
                continue

            try:
                content, metadata = self._process_file(file_path)
                if content:
                    doc_id = self._generate_id(content, str(file_path))
                    data["documents"].append(content)
                    data["metadatas"].append(metadata)
                    data["ids"].append(doc_id)
            except Exception as e:
                print(f"Error processing {file_path}: {str(e)}")

        return data

    def _process_file(self, file_path: Path) -> (Optional[str], Dict):
        """Process individual files based on type"""
        metadata = {
            "source": str(file_path),
            "type": file_path.parent.name,
            "language": "taglish"
        }

        if file_path.suffix == '.txt':
            content = file_path.read_text(encoding='utf-8')
            metadata.update({"format": "text"})

        elif file_path.suffix == '.pdf':
            content = self._extract_pdf_text(file_path)
            metadata.update({"format": "pdf", "pages": len(PdfReader(file_path).pages)})

        elif file_path.suffix == '.json':
            json_data = json.loads(file_path.read_text())
            content = f"Q: {json_data.get('question', '')}\nA: {json_data.get('answer', '')}"

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

        return content.strip(), metadata

    def _extract_pdf_text(self, file_path: Path) -> str:
        """Extract text from PDF files"""
        text = []
        with open(file_path, 'rb') as f:
            reader = PdfReader(f)
            for page in reader.pages:
                text.append(page.extract_text())
        return "\n".join(text)

    def _generate_id(self, content: str, file_path: str) -> str:
        """Generate unique ID from content hash"""
        return hashlib.md5(f"{content}{file_path}".encode()).hexdigest()[:12]

def setup_chroma():
    client = chromadb.PersistentClient(path="./chroma_db")
    processor = DataProcessor()

    # Get or create collection
    collection = client.get_or_create_collection(
        name="ofw_knowledge",
        embedding_function=processor.embed_fn,
        metadata={"hnsw:space": "cosine"}
    )

    # Process data and upsert documents
    data = processor.process_directory()

    if data["documents"]:
        collection.upsert(
            documents=data["documents"],
            metadatas=data["metadatas"],
            ids=data["ids"]
        )
        print(f"\nSuccessfully loaded {len(data['ids'])} documents")

    else:
        print("No documents found in data_sources directory")

if __name__ == "__main__":
    setup_chroma()