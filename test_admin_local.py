#!/usr/bin/env python3
"""
Test script to verify the Flask admin dashboard works locally
"""

import sys
import os
sys.path.append('functions')

def test_firebase_connection():
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
        
        print("🔍 Testing Firebase connection...")
        
        # Initialize Firebase if not already done
        if not firebase_admin._apps:
            if os.path.exists('serviceAccountKey.json'):
                cred = credentials.Certificate('serviceAccountKey.json')
                firebase_admin.initialize_app(cred)
                print("✅ Firebase initialized with service account key")
            else:
                print("❌ serviceAccountKey.json not found in project root")
                return False
        
        # Test Firestore connection
        db = firestore.client()
        
        # Test collections
        users_ref = db.collection('users')
        users_count = len(list(users_ref.limit(5).stream()))
        print(f"✅ Users collection: {users_count} users found")
        
        trial_ref = db.collection('trial_history')
        trials_count = len(list(trial_ref.limit(5).stream()))
        print(f"✅ Trial history collection: {trials_count} trials found")
        
        subscription_ref = db.collection('subscriptions')
        subs_count = len(list(subscription_ref.limit(5).stream()))
        print(f"✅ Subscriptions collection: {subs_count} subscriptions found")
        
        print("\n🎉 Firebase connection successful!")
        return True
        
    except Exception as e:
        print(f"❌ Firebase connection failed: {e}")
        return False

def test_flask_import():
    try:
        print("\n🔍 Testing Flask imports...")
        from functions.admin_server import app
        print("✅ Flask app imported successfully")
        return True
    except Exception as e:
        print(f"❌ Flask import failed: {e}")
        return False

def main():
    print("🚀 Testing OFW Admin Dashboard Setup\n")
    
    # Test Firebase connection
    firebase_ok = test_firebase_connection()
    
    # Test Flask import
    flask_ok = test_flask_import()
    
    if firebase_ok and flask_ok:
        print("\n✅ All tests passed! Ready to run the admin dashboard.")
        print("\nTo start the admin dashboard:")
        print("1. cd functions")
        print("2. python admin_server.py")
        print("3. Open http://localhost:5000 in your browser")
    else:
        print("\n❌ Some tests failed. Please check the errors above.")

if __name__ == '__main__':
    main()