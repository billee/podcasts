import chromadb
from firebase_functions import firestore_fn, https_fn
from firebase_admin import initialize_app, firestore

initialize_app()
client = chromadb.HttpClient(host="localhost", port=8000)
collection = client.get_or_create_collection("knowledge")

@firestore_fn.on_document_created(document="knowledge_base/{docId}")
def sync_to_chroma(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]):
    doc_data = event.data.to_dict()
    collection.add(
        ids=[event.params["docId"]],
        documents=[doc_data["content"]],
        metadatas=[{"firestore_id": event.params["docId"]}]
    )

@https_fn.on_request()
def query_chroma(req: https_fn.Request) -> https_fn.Response:
    query = req.args.get("q")
    results = collection.query(query_texts=[query], n_results=3)
    return https_fn.Response(str(results["ids"][0]))