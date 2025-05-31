import firebase_admin
from firebase_admin import credentials, firestore
from typing import List, Dict
import os

class FirestoreManager:
    def __init__(self, credentials_path: str = None):
        if not firebase_admin._apps:
            cred_path = credentials_path or os.getenv('FIREBASE_CREDENTIALS_PATH', 'C:/Users/sanme/AndroidStudioProjects/kapwa_companion/serviceAccountKey.json')
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)

        self.db = firestore.client()
        self.suggestions_collection = 'ofw_suggestions'

    def clear_existing_suggestions(self):
        """Remove all existing suggestions from Firestore"""
        try:
            # Get all documents in the collection
            docs = self.db.collection(self.suggestions_collection).stream()

            # Delete each document
            batch = self.db.batch()
            count = 0

            for doc in docs:
                batch.delete(doc.reference)
                count += 1

                # Commit batch every 500 operations (Firestore limit)
                if count % 500 == 0:
                    batch.commit()
                    batch = self.db.batch()

            # Commit remaining operations
            if count % 500 != 0:
                batch.commit()

            print(f"Cleared {count} existing suggestions from Firestore")

        except Exception as e:
            print(f"Error clearing existing suggestions: {e}")

    def batch_add_suggestions(self, suggestions: List[Dict]):
        """Add multiple suggestions to Firestore in batches"""
        try:
            batch = self.db.batch()
            count = 0

            for suggestion in suggestions:
                doc_ref = self.db.collection(self.suggestions_collection).document()
                batch.set(doc_ref, suggestion)
                count += 1

                # Commit batch every 500 operations
                if count % 500 == 0:
                    batch.commit()
                    batch = self.db.batch()

            # Commit remaining operations
            if count % 500 != 0:
                batch.commit()

            print(f"Added {count} new suggestions to Firestore")

        except Exception as e:
            print(f"Error adding suggestions to Firestore: {e}")

    def get_suggestions_count(self) -> int:
        """Get total count of suggestions in Firestore"""
        try:
            docs = self.db.collection(self.suggestions_collection).stream()
            return len(list(docs))
        except Exception as e:
            print(f"Error getting suggestions count: {e}")
            return 0