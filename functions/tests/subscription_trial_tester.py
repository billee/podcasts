import sys
import os
from datetime import datetime, timedelta, timezone

try:
    from google.cloud import firestore
    from google.oauth2 import service_account
except ImportError as e:
    print(f"CRITICAL ERROR: Missing required packages - {str(e)}")
    print("Please install them using:")
    print("  pip install google-cloud-firestore google-auth")
    sys.exit(1)

# Configuration
SERVICE_ACCOUNT_FILE = os.path.join(os.path.dirname(__file__), "../../serviceAccountKey.json")
print(SERVICE_ACCOUNT_FILE)
USER_ID = "zAAplGG3BGZClSXuj7o9tOiJ3U62"

# exit()

def get_firestore_client():
    try:
        if not os.path.exists(SERVICE_ACCOUNT_FILE):
            raise FileNotFoundError(f"Service account file not found at {SERVICE_ACCOUNT_FILE}")
            
        credentials = service_account.Credentials.from_service_account_file(
            SERVICE_ACCOUNT_FILE
        )
        return firestore.Client(credentials=credentials)
    except Exception as e:
        print(f"🔥 Firestore connection failed: {str(e)}")
        print("Please verify:")
        print(f"1. File exists at: {SERVICE_ACCOUNT_FILE}")
        print("2. File has valid JSON format")
        print("3. Service account has Firestore read permissions")
        sys.exit(1)

def get_subscription_status(db, user_id):
    try:
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            return {"error": f"User {user_id} not found in Firestore"}
        
        user_data = user_doc.to_dict()
        
        # Check if subscription exists
        if 'subscription' not in user_data:
            return {"error": "No subscription data found for user"}
            
        subscription = user_data['subscription']
        
        # Extract data with validation
        plan = subscription.get('plan', 'N/A')
        is_trial_active = subscription.get('isTrialActive', False)
        trial_start = subscription.get('trialStartDate')
        last_reset = subscription.get('lastResetDate')
        queries_used = subscription.get('gptQueriesUsed', 0)
        video_minutes_used = subscription.get('videoMinutesUsed', 0)
        
        # Calculate days remaining
        days_remaining = "N/A"
        if trial_start:
            # Handle Firestore timestamp conversion
            if hasattr(trial_start, 'timestamp'):  # Native datetime
                trial_start_date = trial_start
            else:  # Firestore Timestamp
                trial_start_date = trial_start.to_datetime()
            
            # Ensure timezone awareness
            if trial_start_date.tzinfo is None:
                trial_start_date = trial_start_date.replace(tzinfo=timezone.utc)
            
            trial_end = trial_start_date + timedelta(days=7)
            now = datetime.now(timezone.utc)
            days_remaining = max(0, (trial_end - now).days)
        
        # Format dates
        def format_date(dt):
            if not dt:
                return "N/A"
            if hasattr(dt, 'timestamp'):  # Already datetime
                return dt.strftime("%b %d, %Y %I:%M %p %Z")
            return dt.to_datetime().strftime("%b %d, %Y %I:%M %p %Z")
        
        return {
            "Plan": plan.upper(),
            "Status": "ACTIVE" if is_trial_active else "EXPIRED",
            "Days Remaining": days_remaining,
            "Queries Used": queries_used,
            "Video Minutes Used": video_minutes_used,
            "Trial Start Date": format_date(trial_start),
            "Last Reset Date": format_date(last_reset)
        }
    except Exception as e:
        return {"error": f"Data processing error: {str(e)}"}

def print_status(status):
    if 'error' in status:
        print(f"\n❌ ERROR: {status['error']}")
        return
    
    print("\n" + "="*55)
    print("✅ SUBSCRIPTION STATUS SUMMARY".center(55))
    print("="*55)
    
    headers = ["PLAN", "STATUS", "DAYS LEFT", "QUERIES", "VIDEO MIN", "TRIAL START", "LAST RESET"]
    values = [
        status["Plan"],
        status["Status"],
        str(status["Days Remaining"]),
        str(status["Queries Used"]),
        str(status["Video Minutes Used"]),
        status["Trial Start Date"],
        status["Last Reset Date"]
    ]
    
    # Print table
    print(" | ".join(f"{h:<10}" for h in headers))
    print("-"*55)
    print(" | ".join(f"{v:<10}" for v in values))
    print("="*55)

if __name__ == "__main__":
    print("\n🔍 Fetching subscription status...")
    print(f"User ID: {USER_ID}")
    print(f"Service Account: {SERVICE_ACCOUNT_FILE}")
    
    try:
        db = get_firestore_client()
        print("🔑 Successfully connected to Firestore")
        
        status = get_subscription_status(db, USER_ID)
        print_status(status)
        
    except Exception as e:
        print(f"🔥 Unhandled error: {str(e)}")
        import traceback
        traceback.print_exc()