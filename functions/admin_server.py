from flask import Flask, render_template, jsonify, request
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, firestore
import json
from datetime import datetime, timedelta
import os

app = Flask(__name__)
CORS(app)

# Initialize Firebase Admin SDK
if not firebase_admin._apps:
    try:
        # Use the service account key from project root
        cred = credentials.Certificate('../serviceAccountKey.json')
        firebase_admin.initialize_app(cred)
        print("✅ Firebase initialized successfully")
    except Exception as e:
        print(f"❌ Firebase initialization error: {e}")

db = firestore.client()

@app.route('/')
def admin_dashboard():
    return render_template('admin_dashboard.html')

@app.route('/api/users')
def get_users():
    try:
        users_data = []
        
        # Get all users from Firestore
        users_ref = db.collection('users')
        users = users_ref.stream()
        
        for user in users:
            user_data = user.to_dict()
            user_id = user.id
            email = user_data.get('email', '')
            
            # Get trial history for this user
            trial_history = None
            if email:
                trial_ref = db.collection('trial_history').document(email)
                trial_doc = trial_ref.get()
                if trial_doc.exists:
                    trial_history = trial_doc.to_dict()
            
            # Get subscription data for this user
            subscription = None
            if email:
                subscription_ref = db.collection('subscriptions').document(email)
                subscription_doc = subscription_ref.get()
                if subscription_doc.exists:
                    subscription = subscription_doc.to_dict()
            
            # Compile complete user journey data
            journey_data = {
                'user_id': user_id,
                'email': email or 'N/A',
                'username': user_data.get('username', 'N/A'),
                'registration_date': format_timestamp(user_data.get('createdAt')),
                'email_verified': user_data.get('emailVerified', False),
                'email_verification_date': format_timestamp(user_data.get('emailVerifiedAt')),
                'trial_start_date': format_timestamp(trial_history.get('trialStartDate') if trial_history else None),
                'trial_end_date': format_timestamp(trial_history.get('trialEndDate') if trial_history else None),
                'trial_status': get_trial_status(trial_history),
                'subscription_start_date': format_timestamp(subscription.get('subscriptionStartDate') if subscription else None),
                'subscription_end_date': format_timestamp(subscription.get('subscriptionEndDate') if subscription else None),
                'subscription_status': get_subscription_status(subscription),
                'cancellation_date': format_timestamp(subscription.get('willExpireAt') if subscription and subscription.get('cancelled') else None),
                'is_premium': subscription.get('isActive', False) if subscription else False,
                'last_login': format_timestamp(user_data.get('lastLoginAt')),
                'current_status': get_current_user_status(user_data, trial_history, subscription)
            }
            
            users_data.append(journey_data)
        
        # Sort by registration date (newest first)
        users_data.sort(key=lambda x: x['registration_date'] or '', reverse=True)
        
        return jsonify({
            'success': True,
            'users': users_data,
            'total_users': len(users_data)
        })
        
    except Exception as e:
        print(f"Error in get_users: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/stats')
def get_stats():
    try:
        # Get user counts
        users_ref = db.collection('users')
        all_users = list(users_ref.stream())
        total_users = len(all_users)
        
        # Count verified users
        verified_users = sum(1 for user in all_users if user.to_dict().get('emailVerified', False))
        
        # Get trial users
        trial_ref = db.collection('trial_history')
        total_trials = len(list(trial_ref.stream()))
        
        # Get active subscriptions
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        active_subscriptions = sum(1 for sub in all_subscriptions if sub.to_dict().get('isActive', False))
        
        # Get cancelled subscriptions
        cancelled_subscriptions = sum(1 for sub in all_subscriptions if sub.to_dict().get('cancelled', False))
        
        # Calculate conversion rate
        conversion_rate = round((active_subscriptions / total_trials * 100) if total_trials > 0 else 0, 2)
        
        return jsonify({
            'success': True,
            'stats': {
                'total_users': total_users,
                'verified_users': verified_users,
                'unverified_users': total_users - verified_users,
                'total_trials': total_trials,
                'active_subscriptions': active_subscriptions,
                'cancelled_subscriptions': cancelled_subscriptions,
                'conversion_rate': conversion_rate
            }
        })
        
    except Exception as e:
        print(f"Error in get_stats: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

def format_timestamp(timestamp):
    """Convert Firestore timestamp to readable format"""
    if not timestamp:
        return None
    
    try:
        if hasattr(timestamp, 'seconds'):
            # Firestore timestamp
            dt = datetime.fromtimestamp(timestamp.seconds)
        elif isinstance(timestamp, str):
            # ISO string
            dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        else:
            return str(timestamp)
        
        return dt.strftime('%Y-%m-%d %H:%M:%S')
    except Exception as e:
        print(f"Error formatting timestamp {timestamp}: {e}")
        return str(timestamp)

def get_trial_status(trial_history):
    """Determine current trial status"""
    if not trial_history:
        return 'No Trial'
    
    trial_end = trial_history.get('trialEndDate')
    if not trial_end:
        return 'Active Trial'
    
    try:
        if hasattr(trial_end, 'seconds'):
            end_date = datetime.fromtimestamp(trial_end.seconds)
        else:
            end_date = datetime.fromisoformat(str(trial_end).replace('Z', '+00:00'))
        
        if datetime.now() > end_date:
            return 'Trial Expired'
        else:
            return 'Active Trial'
    except:
        return 'Unknown'

def get_subscription_status(subscription):
    """Determine current subscription status"""
    if not subscription:
        return 'No Subscription'
    
    if subscription.get('cancelled'):
        return 'Cancelled'
    elif subscription.get('isActive'):
        return 'Active'
    else:
        return 'Inactive'

def get_current_user_status(user_data, trial_history, subscription):
    """Determine the user's current overall status"""
    if not user_data.get('emailVerified'):
        return 'Unverified'
    
    if subscription and subscription.get('isActive') and not subscription.get('cancelled'):
        return 'Premium Subscriber'
    
    if subscription and subscription.get('cancelled'):
        return 'Cancelled Subscriber'
    
    if trial_history:
        trial_status = get_trial_status(trial_history)
        if trial_status == 'Active Trial':
            return 'Trial User'
        elif trial_status == 'Trial Expired':
            return 'Trial Expired'
    
    return 'Free User'

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(debug=True, host='0.0.0.0', port=port)