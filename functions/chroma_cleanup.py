# chroma_cleanup.py
import chromadb
import shutil
import time
import os
import gc

def delete_chroma_contents():
    client = None
    try:
        # Close existing client if any
        if 'client' in locals():
            del client
            gc.collect()

        # Initialize client
        client = chromadb.PersistentClient(path="./chroma_db")

        # Delete collections
        collections = client.list_collections()
        for collection in collections:
            print(f"Deleting collection: {collection.name}")
            client.delete_collection(collection.name)

        # Force cleanup
        del client
        gc.collect()
        time.sleep(1)  # Wait for resource release

        # Manual file deletion
        if os.path.exists("./chroma_db"):
            for root, dirs, files in os.walk("./chroma_db"):
                for file in files:
                    os.chmod(os.path.join(root, file), 0o777)
                    os.unlink(os.path.join(root, file))
                for dir in dirs:
                    os.chmod(os.path.join(root, dir), 0o777)
            shutil.rmtree("./chroma_db", ignore_errors=True)

        print("ChromaDB fully reset")

    except Exception as e:
        print(f"Error: {str(e)}")
        print("Try manual deletion steps above")

if __name__ == "__main__":
    delete_chroma_contents()