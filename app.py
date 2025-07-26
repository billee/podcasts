# Combined Flask App: OFW Admin Dashboard + Chat/Daily.co API
import os
import time
from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
from dotenv import load_dotenv
from openai import OpenAI
import logging
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta

# Load environment variables FIRST
load_dotenv()

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Configure logging AFTER app creation
for handler in app.logger.handlers:
    app.logger.removeHandler(handler)
handler = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
app.logger.addHandler(handler)
app.logger.setLevel(logging.INFO)

# Initialize Firebase Admin SDK
if not firebase_admin._apps:
    try:
        if os.path.exists('serviceAccountKey.json'):
            cred = credentials.Certificate('serviceAccountKey.json')
            firebase_admin.initialize_app(cred)
            app.logger.info("✅ Firebase initialized successfully")
        else:
            app.logger.error("❌ serviceAccountKey.json not found")
    except Exception as e:
        app.logger.error(f"❌ Firebase initialization error: {e}")

db = firestore.client()

# OpenAI configuration
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    app.logger.error("OPENAI_API_KEY environment variable is not set!")

# Initialize OpenAI client
openai_client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# ============================================================================
# ADMIN DASHBOARD ROUTES
# ============================================================================

@app.route('/')
def admin_dashboard():
    """Main admin dashboard page"""
    return render_template('admin_dashboard.html')

@app.route('/api/users')
def get_users():
    """Get all users with their journey data"""
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
            
            # First try by userId (this is how it's actually stored)
            trial_query = db.collection('trial_history').where('userId', '==', user_id).limit(1)
            trial_results = list(trial_query.stream())
            if trial_results:
                trial_history = trial_results[0].to_dict()
                app.logger.info(f"Found trial history by userId for {email}: {trial_history}")
            elif email:
                # Fallback: try by email as document ID
                trial_ref = db.collection('trial_history').document(email)
                trial_doc = trial_ref.get()
                if trial_doc.exists:
                    trial_history = trial_doc.to_dict()
                    app.logger.info(f"Found trial history by email for {email}: {trial_history}")
                else:
                    app.logger.info(f"No trial history found for user {user_id} / {email}")
            
            # Get subscription data for this user
            subscription = None
            if email:
                subscription_ref = db.collection('subscriptions').document(email)
                subscription_doc = subscription_ref.get()
                if subscription_doc.exists:
                    subscription = subscription_doc.to_dict()
            
            # Calculate days remaining for trial
            days_remaining = get_trial_days_remaining(trial_history)
            
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
                'trial_days_remaining': days_remaining,
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
        app.logger.error(f"Error in get_users: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/stats')
def get_stats():
    """Get dashboard statistics"""
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
        app.logger.error(f"Error in get_stats: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# ============================================================================
# CHAT AND AI ROUTES (from your existing app.py)
# ============================================================================

def call_openai_llm(messages_for_llm):
    try:
        start_time = time.time()
        chat_completion = openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages_for_llm,
            temperature=0.7,
            max_tokens=500,
        )
        llm_response = chat_completion.choices[0].message.content
        end_time = time.time()
        app.logger.info(f"OpenAI LLM call took {end_time - start_time:.2f} seconds.")
        return llm_response
    except Exception as e:
        app.logger.error(f"Error calling OpenAI LLM: {e}")
        return f"Error: Failed to get response from AI. Details: {e}"



@app.route('/chat', methods=['POST'])
def chat():
    data = request.json
    messages = data.get('messages')
    if not messages:
        return jsonify({"error": "No messages provided"}), 400

    openai_messages = []
    for msg in messages:
        role = msg.get('role')
        content = msg.get('content')
        if role and content:
            openai_messages.append({"role": role, "content": content})

    if not openai_messages:
        return jsonify({"error": "No valid messages for LLM"}), 400

    llm_response = call_openai_llm(openai_messages)
    return jsonify({"response": llm_response})

@app.route('/health')
def health_check():
    return jsonify({"status": "healthy", "message": "Flask app is running"})

@app.route('/debug/trials')
def debug_trials():
    """Debug endpoint to see all trial history data"""
    try:
        trials = []
        trial_ref = db.collection('trial_history')
        for trial_doc in trial_ref.stream():
            trial_data = trial_doc.to_dict()
            trial_data['document_id'] = trial_doc.id
            trials.append(trial_data)
        
        return jsonify({
            'success': True,
            'trials': trials,
            'count': len(trials)
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/summarize_chat', methods=['POST'])
def summarize_chat():
    data = request.json
    messages = data.get('messages')
    print(f"\nMessages: \n{messages}\n")
    
    if not messages:
        return jsonify({"error": "No messages provided for summarization"}), 400

    previous_summary_content = None
    conversation_messages_for_llm = []
    
    for msg in messages:
        if msg.get('role') == 'system' and "Continuing from our last conversation:" in msg.get('content', ''):
            previous_summary_content = msg['content'].replace("Continuing from our last conversation: ", "").strip()
        else:
            role = msg.get('role')
            content = msg.get('content')
            sender_name = msg.get('senderName', 'Participant')
            if role and content:
                if role == 'user':
                    conversation_messages_for_llm.append({"role": "user", "content": f"{sender_name}: {content}"})
                elif role == 'assistant':
                    conversation_messages_for_llm.append({"role": "assistant", "content": content})

    conversation_text = ""
    for msg in conversation_messages_for_llm:
        if msg['role'] == 'user':
            conversation_text += f"User: {msg['content']}\n"
        elif msg['role'] == 'assistant':
            conversation_text += f"Assistant: {msg['content']}\n"

    summary_prompt_messages = [
        {"role": "system", "content": "You are a highly skilled summarization AI. Your primary goal is to create a single, comprehensive, and concise summary of a conversation. **The final summary MUST be a single, continuous paragraph without line breaks or bullet points.**"},
        {"role": "user", "content": f"""Please create a comprehensive summary of this conversation:
{f"Previous summary: {previous_summary_content}" if previous_summary_content and previous_summary_content != "No sufficient conversation to summarize." else ""}
Current conversation:
{conversation_text}
Create a single paragraph summary that captures all the key points, topics discussed, and important details from {'both the previous summary and ' if previous_summary_content else ''}the current conversation."""}
    ]

    if not previous_summary_content and not conversation_messages_for_llm:
        return jsonify({"summary": "No sufficient conversation to summarize."})

    summary = call_openai_llm(summary_prompt_messages)
    summary = summary.replace('\n', ' ').strip()
    
    print("\n--- LLM RETURNED CUMULATIVE SUMMARY (CLEANED) ---")
    print(f"Summary: {summary}")
    print("--------------------------------------------------")
    
    return jsonify({"summary": summary})



# ============================================================================
# HELPER FUNCTIONS FOR ADMIN DASHBOARD
# ============================================================================

def format_timestamp(timestamp):
    """Convert Firestore timestamp to readable format"""
    if not timestamp:
        return None
    
    try:
        # Handle Firestore DatetimeWithNanoseconds
        if hasattr(timestamp, 'timestamp'):
            dt = timestamp.replace(tzinfo=None)  # Remove timezone info
        elif hasattr(timestamp, 'seconds'):
            # Firestore timestamp
            dt = datetime.fromtimestamp(timestamp.seconds)
        elif isinstance(timestamp, str):
            # ISO string
            dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00')).replace(tzinfo=None)
        else:
            return str(timestamp)
        
        return dt.strftime('%Y-%m-%d %H:%M:%S')
    except Exception as e:
        app.logger.error(f"Error formatting timestamp {timestamp}: {e}")
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

def get_trial_days_remaining(trial_history):
    """Calculate days remaining in trial"""
    if not trial_history:
        return 'N/A'
    
    trial_end = trial_history.get('trialEndDate')
    if not trial_end:
        return 'N/A'
    
    try:
        # Handle Firestore DatetimeWithNanoseconds
        if hasattr(trial_end, 'timestamp'):
            end_date = trial_end.replace(tzinfo=None)  # Remove timezone info
        elif hasattr(trial_end, 'seconds'):
            end_date = datetime.fromtimestamp(trial_end.seconds)
        else:
            end_date = datetime.fromisoformat(str(trial_end).replace('Z', '+00:00')).replace(tzinfo=None)
        
        now = datetime.now()  # This is timezone-naive
        if now > end_date:
            return 'Expired'
        else:
            days_left = (end_date - now).days
            hours_left = (end_date - now).seconds // 3600
            if days_left == 0 and hours_left > 0:
                return f"{hours_left}h left"
            return f"{days_left} days"
    except Exception as e:
        app.logger.error(f"Error calculating trial days remaining: {e}")
        return 'Error'

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
    app.run(host='0.0.0.0', port=port, debug=False)