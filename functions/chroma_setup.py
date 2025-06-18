"""
ChromaDB Setup with Improved Chunking
- Token-based chunking instead of character-based
- Better sentence splitting for Filipino/English mixed content
- Sentence-level overlap (no broken words/sentences)
- Robust error handling and progress tracking
"""

import chromadb
from chromadb.utils import embedding_functions
import os
import uuid
import re
import tiktoken
from typing import List, Dict, Any
from scoring_utils import print_score_analysis

# Import our custom module for data reading
from data_source_reader import DataSourceReader

class ChromaVectorDatabase:
    def __init__(self, db_path: str = "./chroma_db", collection_name: str = "ofw_knowledge"):
        # Updated to use multilingual model as discussed
        # self.EMBEDDING_MODEL_NAME = "intfloat/multilingual-e5-base"
        self.EMBEDDING_MODEL_NAME = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"
        self.CHROMA_DB_PATH = db_path
        self.CHROMA_COLLECTION_NAME = collection_name
        self.client = None
        self.collection = None
        self.data_reader = DataSourceReader()

        # Chunking parameters - using tokens instead of characters
        self.MAX_TOKENS_PER_CHUNK = 400  # Optimal for most embedding models
        self.OVERLAP_TOKENS = 50  # Meaningful overlap without too much redundancy

        # Initialize tokenizer for accurate token counting
        try:
            self.tokenizer = tiktoken.get_encoding("cl100k_base")  # GPT-4 tokenizer
        except Exception as e:
            print(f"⚠️ Warning: Could not load tokenizer, falling back to character estimation: {e}")
            self.tokenizer = None

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
            print(f"✅ ChromaDB collection '{self.CHROMA_COLLECTION_NAME}' initialized with {self.EMBEDDING_MODEL_NAME}")
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

    def _count_tokens(self, text: str) -> int:
        """Count actual tokens in text"""
        if self.tokenizer:
            return len(self.tokenizer.encode(text))
        else:
            # Fallback: rough estimation (4 characters ≈ 1 token)
            return len(text) // 4

    def _clean_text(self, text: str) -> str:
        """Enhanced text cleaning for Filipino/English mixed content"""
        # Normalize whitespace
        text = re.sub(r'\s+', ' ', text)

        # Remove citation numbers but preserve other brackets
        text = re.sub(r'\[\d+\]', '', text)

        # Fix common OCR/encoding issues
        text = re.sub(r'â€™', "'", text)  # Fix apostrophes
        text = re.sub(r'â€œ|â€', '"', text)  # Fix quotes

        # Normalize Filipino punctuation
        text = re.sub(r'\.{3,}', '...', text)  # Multiple dots to ellipsis

        return text.strip()

    def _improved_sentence_split(self, text: str) -> List[str]:
        """
        Better sentence splitting for Filipino/English mixed content
        Handles common abbreviations and mixed language patterns
        """
        # Protect common abbreviations from being split
        abbreviations = [
            'Mr', 'Mrs', 'Ms', 'Dr', 'Prof', 'Sr', 'Jr', 'Inc', 'Ltd', 'Corp',
            'vs', 'etc', 'i.e', 'e.g', 'a.m', 'p.m', 'Ph.D', 'M.D',
            'Gov', 'Sen', 'Rep', 'Pres', 'VP', 'CEO', 'CFO'
        ]

        # Temporarily replace abbreviations
        for abbr in abbreviations:
            text = re.sub(f'\\b{abbr}\\.', f'{abbr}<DOT>', text, flags=re.IGNORECASE)

        # Split on sentence endings followed by whitespace and capital letter
        # This handles most English and Filipino sentence patterns
        sentences = re.split(r'(?<=[.!?])\s+(?=[A-Z])', text)

        # Also split on paragraph breaks (double newlines)
        result = []
        for sentence in sentences:
            # Split on explicit paragraph breaks
            parts = re.split(r'\n\s*\n', sentence)
            for part in parts:
                if part.strip():
                    # Restore abbreviation dots
                    part = part.replace('<DOT>', '.')
                    result.append(part.strip())

        return result

    def _smart_chunk_text(self, text: str) -> List[str]:
        text = self._clean_text(text)
        sentences = self._improved_sentence_split(text)

        if not sentences:
            return []

        chunks = []
        current_sentences = []
        current_tokens = 0

        for sentence in sentences:
            sentence_tokens = self._count_tokens(sentence)

            # Skip extremely long sentences that exceed max chunk size
            if sentence_tokens > self.MAX_TOKENS_PER_CHUNK:
                print(f"⚠️ Breaking down long sentence ({sentence_tokens} tokens): {sentence[:100]}...")
            
                # Add current chunk if it has content
                if current_sentences:
                    chunk_text = ' '.join(current_sentences)
                    chunks.append(chunk_text)
                    current_sentences = []
                    current_tokens = 0
                
                # Break down the long sentence and add as separate chunks
                long_sentence_parts = self._handle_long_sentence(sentence, self.MAX_TOKENS_PER_CHUNK)
                for part in long_sentence_parts:
                    if part.strip():
                        chunks.append(part.strip())

                continue

            # If adding this sentence would exceed the limit, finalize current chunk
            if current_tokens + sentence_tokens > self.MAX_TOKENS_PER_CHUNK and current_sentences:
                # Create chunk from current sentences
                chunk_text = ' '.join(current_sentences)
                chunks.append(chunk_text)

                # Create overlap using complete sentences from the end
                overlap_sentences = []
                overlap_tokens = 0

                # Take sentences from the end for overlap (reverse order, then reverse back)
                for sent in reversed(current_sentences):
                    sent_tokens = self._count_tokens(sent)
                    if overlap_tokens + sent_tokens <= self.OVERLAP_TOKENS:
                        overlap_sentences.insert(0, sent)  # Insert at beginning to maintain order
                        overlap_tokens += sent_tokens
                    else:
                        break

                # Start new chunk with overlap + current sentence
                current_sentences = overlap_sentences + [sentence]
                current_tokens = overlap_tokens + sentence_tokens
            else:
                # Add sentence to current chunk
                current_sentences.append(sentence)
                current_tokens += sentence_tokens

        # Add the final chunk if it has content
        if current_sentences:
            chunk_text = ' '.join(current_sentences)
            chunks.append(chunk_text)

        return [chunk for chunk in chunks if chunk.strip()]

    def populate_vector_database(self):
        """Populates ChromaDB with documents using improved chunking"""
        print("🚀 Starting ChromaDB population with improved chunking...")
        print(f"📊 Chunking parameters: {self.MAX_TOKENS_PER_CHUNK} max tokens, {self.OVERLAP_TOKENS} overlap tokens")

        all_files_data = self.data_reader.read_all_files()

        if not all_files_data:
            print("⚠️ No files found to process.")
            return

        documents, metadatas, ids = [], [], []
        total_chunks = 0

        for file_data in all_files_data:
            print(f"📄 Processing: {file_data['filename']}")

            chunks = self._smart_chunk_text(file_data['content'])
            if not chunks:
                print(f"  ⚠️ Skipped {file_data['filename']} (no valid chunks created)")
                continue

            print(f"  ✅ Generated {len(chunks)} chunks")
            total_chunks += len(chunks)

            for i, chunk in enumerate(chunks):
                documents.append(chunk)
                metadatas.append({
                    "source": file_data['filename'],
                    "chunk_id": i,
                    "token_count": self._count_tokens(chunk),
                    "char_length": len(chunk)
                })
                ids.append(str(uuid.uuid4()))

        if documents:
            print(f"\n📊 Total chunks to add: {len(documents)}")
            self._add_documents_in_batches(documents, metadatas, ids)
            print(f"🎉 Successfully populated ChromaDB with {len(documents)} chunks from {len(all_files_data)} files")

            # Print final statistics
            total_tokens = sum(meta['token_count'] for meta in metadatas)
            avg_tokens = total_tokens / len(documents)
            print(f"📈 Statistics: {total_tokens:,} total tokens, {avg_tokens:.0f} avg tokens per chunk")
        else:
            print("⚠️ No documents were added to ChromaDB.")

    def _add_documents_in_batches(self, documents: List[str], metadatas: List[dict], ids: List[str], batch_size: int = 100):
        """Add documents to ChromaDB in batches with progress tracking"""
        total_added = 0
        total_batches = (len(documents) + batch_size - 1) // batch_size

        print(f"📦 Adding documents in {total_batches} batches of {batch_size}...")

        for i in range(0, len(documents), batch_size):
            batch_num = i // batch_size + 1
            batch_docs = documents[i:i+batch_size]
            batch_metas = metadatas[i:i+batch_size]
            batch_ids = ids[i:i+batch_size]

            try:
                self.collection.add(
                    documents=batch_docs,
                    metadatas=batch_metas,
                    ids=batch_ids
                )
                total_added += len(batch_docs)
                print(f"  ✅ Batch {batch_num}/{total_batches}: Added {len(batch_docs)} chunks")

            except Exception as e:
                print(f"  ❌ Batch {batch_num}/{total_batches} failed: {e}")
                # Continue with other batches instead of failing completely
                continue

        print(f"✅ Successfully added {total_added}/{len(documents)} documents to ChromaDB")

        if total_added < len(documents):
            print(f"⚠️ Warning: {len(documents) - total_added} documents failed to add")

    def get_collection_stats(self):
        """Get statistics about the current collection"""
        try:
            count = self.collection.count()
            print(f"📊 Collection '{self.CHROMA_COLLECTION_NAME}' contains {count} documents")
            return count
        except Exception as e:
            print(f"❌ Error getting collection stats: {e}")
            return 0

    def test_query_with_scoring(self, query: str = "test query", n_results: int = 5):
        """Test the collection with a sample query and display scoring analysis"""
        try:
            results = self.collection.query(
                query_texts=[query],
                n_results=n_results,
                include=['documents', 'distances', 'metadatas']
            )

            print(f"\nTesting query: '{query}'")
            print_score_analysis(results, score_threshold=0.15, max_display=3)

        except Exception as e:
            print(f"Error during test query: {e}")


    def _handle_long_sentence(self, sentence: str, max_tokens: int) -> List[str]:
        sentence_tokens = self._count_tokens(sentence)
        
        if sentence_tokens <= max_tokens:
            return [sentence]
        
        # Split on common breakpoints
        parts = []
        
        # Try splitting on semicolons, colons, or long dashes first
        for delimiter in [';', ':', ' - ', ' – ']:
            if delimiter in sentence:
                temp_parts = sentence.split(delimiter)
                if len(temp_parts) > 1:
                    for i, part in enumerate(temp_parts):
                        if i > 0:  # Add delimiter back except for first part
                            part = delimiter + part
                        if self._count_tokens(part.strip()) <= max_tokens:
                            parts.append(part.strip())
                        else:
                            # Still too long, split further
                            parts.extend(self._split_by_clauses(part.strip(), max_tokens))
                    return [p for p in parts if p.strip()]
        
        # Fallback: split by clauses/commas
        return self._split_by_clauses(sentence, max_tokens)

    def _split_by_clauses(self, text: str, max_tokens: int) -> List[str]:
        """Split text by clauses and commas as last resort"""
        parts = []
        current_part = ""
        
        # Split on commas but try to maintain meaning
        clauses = text.split(',')
        
        for clause in clauses:
            test_part = current_part + (',' if current_part else '') + clause
            if self._count_tokens(test_part) <= max_tokens:
                current_part = test_part
            else:
                if current_part:
                    parts.append(current_part.strip())
                current_part = clause.strip()
        
        if current_part:
            parts.append(current_part.strip())
        
        return parts






def main():
    """Main function to run the ChromaDB setup"""
    try:
        print("🚀 Starting improved ChromaDB setup for Kapwa Companion...")
        print("=" * 60)

        # Initialize the database
        chroma_db = ChromaVectorDatabase()

        # Show current collection stats
        current_count = chroma_db.get_collection_stats()

        if current_count > 0:
            response = input(f"\n⚠️ Collection already contains {current_count} documents. Clear and rebuild? (y/N): ").strip().lower()
            if response in ['y', 'yes']:
                chroma_db.clear_vector_database()
            else:
                print("Keeping existing collection. Exiting...")
                return

        # Populate the database
        print("\n" + "=" * 60)
        chroma_db.populate_vector_database()

        # Final stats
        print("\n" + "=" * 60)
        final_count = chroma_db.get_collection_stats()
        print(f"🎉 Setup completed successfully! Final document count: {final_count}")

    except KeyboardInterrupt:
        print("\n⚠️ Setup interrupted by user.")
    except Exception as e:
        print(f"\n❌ Setup failed with error: {e}")
        import traceback
        traceback.print_exc()
        print("\n💡 Check your data files and try again.")

if __name__ == "__main__":
    main()