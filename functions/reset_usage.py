# Run monthly via Cloud Scheduler or a serverless function.

# reset_usage.py
import firebase_admin
from firebase_admin import firestore
from datetime import datetime, timedelta

app = firebase_admin.initialize_app()
db = firestore.client()

def reset_usage():
    users = db.collection('users').stream()
    for user in users:
        sub = user.to_dict().get('subscription', {})
        if sub.get('plan') != 'trial':
            db.collection('users').document(user.id).update({
                'subscription.gptQueriesUsed': 0,
                'subscription.videoMinutesUsed': 0,
                'subscription.lastResetDate': datetime.now()
            })

if __name__ == '__main__':
    reset_usage()