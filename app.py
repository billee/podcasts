# Combined Flask App: OFW Admin Dashboard + Chat/Daily.co API
# 
# Main production app.py file for the OFW admin dashboard and chat API
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
# Initialize UUID for mock payment IDs
import uuid
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
        # Try to use service account key file first (for local development)
        if os.path.exists('serviceAccountKey.json'):
            cred = credentials.Certificate('serviceAccountKey.json')
            firebase_admin.initialize_app(cred)
            app.logger.info("✅ Firebase initialized successfully from file")
        else:
            # Use environment variable (for production deployment)
            firebase_key_json = os.getenv('FIREBASE_SERVICE_ACCOUNT_KEY')
            if firebase_key_json:
                import json
                firebase_key_dict = json.loads(firebase_key_json)
                cred = credentials.Certificate(firebase_key_dict)
                firebase_admin.initialize_app(cred)
                app.logger.info("✅ Firebase initialized successfully from environment variable")
            else:
                app.logger.error("❌ Neither serviceAccountKey.json file nor FIREBASE_SERVICE_ACCOUNT_KEY environment variable found")
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

# ============================================================================
# PAYMENT ROUTES
# ============================================================================

@app.route('/create-payment-intent', methods=['POST'])
def create_payment_intent():
    """Create a mock payment intent"""
    try:
        data = request.get_json()
        app.logger.info(f"Received mock payment request: {data}")
        
        # Get amount and metadata from request
        amount = data.get('amount', 0)
        metadata = data.get('metadata', {})
        
        # Generate a mock payment ID
        payment_id = str(uuid.uuid4())
        
        # Update subscription status in Firestore immediately for mock payment
        user_id = metadata.get('userId')
        if user_id:
            db.collection('subscriptions').document(user_id).set({
                'status': 'active',
                'paymentId': payment_id,
                'updatedAt': firestore.SERVER_TIMESTAMP,
                'amount': amount,
                'currency': data.get('currency', 'usd').lower(),
                'expiresAt': datetime.now() + timedelta(days=30)
            })
            app.logger.info(f"Updated subscription for user {user_id}")

        return jsonify({
            'payment_intent_id': payment_id,
            'amount': amount,
            'status': 'succeeded'
        })

    except Exception as e:
        app.logger.error(f"Error processing mock payment: {str(e)}")
        return jsonify({'error': str(e)}), 403

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
            
            # Get subscription data for this user by UID only
            subscription = None
            subscription_ref = db.collection('subscriptions').document(user_id)
            subscription_doc = subscription_ref.get()
            if subscription_doc.exists:
                subscription = subscription_doc.to_dict()
                app.logger.info(f"✅ Found subscription for user {user_id}")
            else:
                app.logger.info(f"❌ No subscription found for user {user_id}")
            
            # Get total monthly tokens from total_usage_history
            # Inside your user loop
            user_id = user.id

            # Get current month/year
            current_month = datetime.utcnow().month
            current_year = datetime.utcnow().year

            usage_query = db.collection('token_usage_history') \
                .where('userId', '==', user_id) \
                .where('month', '==', current_month) \
                .where('year', '==', current_year) \
                .limit(1)

            usage_docs = list(usage_query.stream())
            total_tokens = 0

            # # Add more debugging:
            # print(f"Checking token usage for user {user_id} in collection {usage_ref.parent.id}")
            # usage_doc = usage_ref.get()
            # print(f"Document exists: {usage_doc.exists}")
            if usage_docs:
                usage_data = usage_docs[0].to_dict()
                total_tokens = usage_data.get('totalMonthlyTokens', 0)
                app.logger.info(f"Found token usage for user {user_id}: {total_tokens} tokens")
            else:
                app.logger.info(f"No token usage found for user {user_id} for {current_month}/{current_year}")
            
            # Calculate days remaining for trial
            days_remaining = get_trial_days_remaining(trial_history)
            
            # Compile complete user journey data
            journey_data = {
                'user_id': user_id,
                'email': email or 'N/A',
                'uid': user_id,
                'registration_date': format_timestamp(user_data.get('createdAt')),
                'email_verified': user_data.get('emailVerified', False),
                'email_verification_date': format_timestamp(user_data.get('emailVerifiedAt')),
                'trial_start_date': format_timestamp(trial_history.get('trialStartDate') if trial_history else None),
                'trial_end_date': format_timestamp(trial_history.get('trialEndDate') if trial_history else None),
                'trial_days_remaining': days_remaining,
                'trial_status': get_trial_status(trial_history),
                'subscription_start_date': format_timestamp(subscription.get('startDate') if subscription else None),
                'subscription_end_date': format_timestamp(subscription.get('subscriptionEndDate') if subscription else None),
                'subscription_status': get_subscription_status(subscription),
                'cancellation_date': format_timestamp(subscription.get('willExpireAt') if subscription and subscription.get('cancelled') else None),
                'is_premium': subscription.get('status') == 'active' if subscription else False,
                'last_login': format_timestamp(user_data.get('lastLoginAt')),
                'current_status': get_current_user_status(user_data, trial_history, subscription),
                'total_monthly_tokens': total_tokens  # Added this field
            }
            
            users_data.append(journey_data)
            
            # Debug: log the first user's data to see what fields are being sent
            if len(users_data) == 1:
                app.logger.info(f"First user data fields: {list(journey_data.keys())}")
                app.logger.info(f"UID field value: {journey_data.get('uid')}")
                app.logger.info(f"Username field (should not exist): {journey_data.get('username', 'NOT_FOUND')}")
                app.logger.info(f"Total monthly tokens: {journey_data.get('total_monthly_tokens')}")

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
        
        # Debug: log subscription data
        app.logger.info(f"aaaaaa: {all_subscriptions}")
        print("nnnnnnnnnnnnnnnnnnnnnnn")
        app.logger.info(f"Total subscription documents: {len(all_subscriptions)}")
        
        for i, sub in enumerate(all_subscriptions):
            sub_data = sub.to_dict()
            app.logger.info(f"Subscription {i+1}: status={sub_data.get('status')}, isActive={sub_data.get('isActive')}, cancelled={sub_data.get('cancelled')}")
            print(f"Subscription data: {sub_data}")
        
        active_subscriptions = sum(1 for sub in all_subscriptions if sub.to_dict().get('status') == 'active')
        app.logger.info(f"Active subscriptions count: {active_subscriptions}")
        print(f"Active count: {active_subscriptions}")
        
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
# KPI DASHBOARD AND BUSINESS ANALYTICS ROUTES
# ============================================================================

@app.route('/api/analytics/revenue')
def get_revenue_analytics():
    """Get revenue analytics including MRR, ARPU, and revenue trends"""
    try:
        # Get all subscriptions
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        
        # Calculate MRR (Monthly Recurring Revenue)
        active_subscriptions = [sub for sub in all_subscriptions if sub.to_dict().get('status') == 'active']
        mrr = len(active_subscriptions) * 3.0  # $3/month per subscription
        
        # Calculate ARPU (Average Revenue Per User)
        users_ref = db.collection('users')
        total_users = len(list(users_ref.stream()))
        arpu = mrr / total_users if total_users > 0 else 0
        
        # Calculate revenue trends (last 6 months)
        revenue_trends = calculate_revenue_trends(all_subscriptions)
        
        # Calculate total revenue to date
        total_revenue = calculate_total_revenue(all_subscriptions)
        
        # Calculate revenue growth rate
        revenue_growth_rate = calculate_revenue_growth_rate(revenue_trends)
        
        return jsonify({
            'success': True,
            'revenue_analytics': {
                'mrr': round(mrr, 2),
                'arpu': round(arpu, 2),
                'total_revenue': round(total_revenue, 2),
                'revenue_growth_rate': round(revenue_growth_rate, 2),
                'active_subscriptions': len(active_subscriptions),
                'revenue_trends': revenue_trends
            }
        })
        
    except Exception as e:
        app.logger.error(f"Error in get_revenue_analytics: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/analytics/conversion')
def get_conversion_funnel():
    """Get conversion funnel analysis (registration → trial → subscription)"""
    try:
        # Get all users
        users_ref = db.collection('users')
        all_users = list(users_ref.stream())
        total_registrations = len(all_users)
        
        # Count verified users
        verified_users = [user for user in all_users if user.to_dict().get('emailVerified', False)]
        total_verified = len(verified_users)
        
        # Get trial users
        trial_ref = db.collection('trial_history')
        all_trials = list(trial_ref.stream())
        total_trials = len(all_trials)
        
        # Get active subscriptions
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        total_subscriptions = len([sub for sub in all_subscriptions if sub.to_dict().get('status') == 'active'])
        
        # Calculate conversion rates
        verification_rate = (total_verified / total_registrations * 100) if total_registrations > 0 else 0
        trial_conversion_rate = (total_trials / total_verified * 100) if total_verified > 0 else 0
        subscription_conversion_rate = (total_subscriptions / total_trials * 100) if total_trials > 0 else 0
        overall_conversion_rate = (total_subscriptions / total_registrations * 100) if total_registrations > 0 else 0
        
        return jsonify({
            'success': True,
            'conversion_funnel': {
                'total_registrations': total_registrations,
                'total_verified': total_verified,
                'total_trials': total_trials,
                'total_subscriptions': total_subscriptions,
                'verification_rate': round(verification_rate, 2),
                'trial_conversion_rate': round(trial_conversion_rate, 2),
                'subscription_conversion_rate': round(subscription_conversion_rate, 2),
                'overall_conversion_rate': round(overall_conversion_rate, 2)
            }
        })
        
    except Exception as e:
        app.logger.error(f"Error in get_conversion_funnel: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/analytics/retention')
def get_retention_analytics():
    """Get user retention and churn rate calculations"""
    try:
        # Get all users with their data
        users_ref = db.collection('users')
        all_users = list(users_ref.stream())
        
        # Calculate retention metrics
        retention_metrics = calculate_retention_metrics(all_users)
        
        # Calculate churn rate
        churn_metrics = calculate_churn_metrics()
        
        return jsonify({
            'success': True,
            'retention_analytics': {
                **retention_metrics,
                **churn_metrics
            }
        })
        
    except Exception as e:
        app.logger.error(f"Error in get_retention_analytics: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/analytics/subscription-health')
def get_subscription_health():
    """Get subscription growth and health metrics"""
    try:
        # Get all subscriptions
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        
        # Calculate subscription health metrics
        health_metrics = calculate_subscription_health_metrics(all_subscriptions)
        
        # Calculate subscription growth trends
        growth_trends = calculate_subscription_growth_trends(all_subscriptions)
        
        return jsonify({
            'success': True,
            'subscription_health': {
                **health_metrics,
                'growth_trends': growth_trends
            }
        })
        
    except Exception as e:
        app.logger.error(f"Error in get_subscription_health: {e}")
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
        {"role": "system", "content": "Summarize conversations in 1-2 sentences focusing on emotional state and key topics only."},
        {"role": "user", "content": f"""Summarize this conversation in 1-2 sentences:
{f"Previous: {previous_summary_content}" if previous_summary_content and previous_summary_content != "No sufficient conversation to summarize." else ""}
Current: {conversation_text}
Focus only on emotional state and main topics discussed."""}
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
        # Handle Firestore DatetimeWithNanoseconds (most common)
        if hasattr(timestamp, 'timestamp'):
            dt = timestamp.replace(tzinfo=None)  # Remove timezone info
        elif hasattr(timestamp, 'seconds') and hasattr(timestamp, 'nanoseconds'):
            # Firestore timestamp object
            dt = datetime.fromtimestamp(timestamp.seconds + timestamp.nanoseconds / 1e9)
        elif hasattr(timestamp, 'seconds'):
            # Simple timestamp with seconds only
            dt = datetime.fromtimestamp(timestamp.seconds)
        elif isinstance(timestamp, str):
            # Handle string representation of Timestamp object
            if 'Timestamp(' in timestamp and 'seconds=' in timestamp:
                # Parse string like "Timestamp(seconds=1753482044, nanoseconds=992000000)"
                import re
                seconds_match = re.search(r'seconds=(\d+)', timestamp)
                nanoseconds_match = re.search(r'nanoseconds=(\d+)', timestamp)
                
                if seconds_match:
                    seconds = int(seconds_match.group(1))
                    nanoseconds = int(nanoseconds_match.group(1)) if nanoseconds_match else 0
                    dt = datetime.fromtimestamp(seconds + nanoseconds / 1e9)
                else:
                    app.logger.warning(f"Could not parse Timestamp string: {timestamp}")
                    return "Parse Error"
            else:
                # ISO string
                dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00')).replace(tzinfo=None)
        elif isinstance(timestamp, datetime):
            # Already a datetime object
            dt = timestamp.replace(tzinfo=None) if timestamp.tzinfo else timestamp
        else:
            app.logger.warning(f"Unknown timestamp format: {timestamp} ({type(timestamp)})")
            return str(timestamp)
        
        return dt.strftime('%Y-%m-%d %H:%M:%S')
    except Exception as e:
        app.logger.error(f"Error formatting timestamp {timestamp}: {e}")
        return "Format Error"

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
    email = user_data.get('email', '')
    
    if not user_data.get('emailVerified'):
        return 'Unverified'
    
    # Check if user has an active subscription (status: "active")
    if subscription and subscription.get('status') == 'active':
        return 'Pro'
    
    # Also check for legacy isActive field as fallback
    if subscription and subscription.get('isActive') and not subscription.get('cancelled'):
        return 'Pro'
    
    # Check for cancelled subscription
    if subscription and subscription.get('cancelled'):
        return 'Cancelled Subscriber'
    
    # Check trial status
    if trial_history:
        trial_status = get_trial_status(trial_history)
        if trial_status == 'Active Trial':
            return 'Trial User'
        elif trial_status == 'Trial Expired':
            return 'Trial Expired'
    
    return 'Free User'

# ============================================================================
# ADVANCED ANALYTICS ROUTES (Task 10.2)
# ============================================================================

@app.route('/api/analytics/cohort')
def get_cohort_analysis():
    """Get cohort analysis for user retention tracking"""
    try:
        # Get all users with their registration and activity data
        users_ref = db.collection('users')
        all_users = list(users_ref.stream())
        
        # Calculate cohort analysis
        cohort_data = calculate_cohort_analysis(all_users)
        
        return jsonify({
            'success': True,
            'cohort_analysis': cohort_data
        })
        
    except Exception as e:
        app.logger.error(f"Error in get_cohort_analysis: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/analytics/geographic')
def get_geographic_distribution():
    """Get geographic distribution analysis for OFW markets"""
    try:
        # Get all users and analyze their geographic data
        users_ref = db.collection('users')
        all_users = list(users_ref.stream())
        
        # Calculate geographic distribution
        geographic_data = calculate_geographic_distribution(all_users)
        
        return jsonify({
            'success': True,
            'geographic_distribution': geographic_data
        })
        
    except Exception as e:
        app.logger.error(f"Error in get_geographic_distribution: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/analytics/user-behavior')
def get_user_behavior_analytics():
    """Get user behavior and engagement analytics"""
    try:
        # Get user behavior data from multiple collections
        users_ref = db.collection('users')
        all_users = list(users_ref.stream())
        
        # Get trial and subscription data for behavior analysis
        trial_ref = db.collection('trial_history')
        all_trials = list(trial_ref.stream())
        
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        
        # Calculate user behavior metrics
        behavior_data = calculate_user_behavior_analytics(all_users, all_trials, all_subscriptions)
        
        return jsonify({
            'success': True,
            'user_behavior': behavior_data
        })
        
    except Exception as e:
        app.logger.error(f"Error in get_user_behavior_analytics: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/analytics/payment-analysis')
def get_payment_analysis():
    """Get payment success rate and failure analysis"""
    try:
        # Get subscription and payment data
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        
        # Calculate payment analysis metrics
        payment_data = calculate_payment_analysis(all_subscriptions)
        
        return jsonify({
            'success': True,
            'payment_analysis': payment_data
        })
        
    except Exception as e:
        app.logger.error(f"Error in get_payment_analysis: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# ============================================================================
# ALERTING AND MONITORING SYSTEM ROUTES (Task 10.3)
# ============================================================================

@app.route('/api/monitoring/alerts')
def get_business_alerts():
    """Get critical business alerts (churn, payment failures, etc.)"""
    try:
        alerts = generate_business_alerts()
        
        return jsonify({
            'success': True,
            'alerts': alerts
        })
        
    except Exception as e:
        app.logger.error(f"Error in get_business_alerts: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/monitoring/performance')
def get_performance_metrics():
    """Get performance monitoring and error tracking data"""
    try:
        performance_data = calculate_performance_metrics()
        
        return jsonify({
            'success': True,
            'performance': performance_data
        })
        
    except Exception as e:
        app.logger.error(f"Error in get_performance_metrics: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/monitoring/reports')
def get_automated_reports():
    """Get automated reporting and trend analysis"""
    try:
        reports = generate_automated_reports()
        
        return jsonify({
            'success': True,
            'reports': reports
        })
        
    except Exception as e:
        app.logger.error(f"Error in get_automated_reports: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/export/data')
def export_data():
    """Export data for detailed analysis"""
    try:
        export_type = request.args.get('type', 'users')  # users, subscriptions, analytics
        format_type = request.args.get('format', 'csv')  # csv, json
        
        if export_type == 'users':
            data = export_users_data(format_type)
        elif export_type == 'subscriptions':
            data = export_subscriptions_data(format_type)
        elif export_type == 'analytics':
            data = export_analytics_data(format_type)
        else:
            return jsonify({
                'success': False,
                'error': 'Invalid export type'
            }), 400
        
        return data
        
    except Exception as e:
        app.logger.error(f"Error in export_data: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# ============================================================================
# ALERTING AND MONITORING SYSTEM HELPER FUNCTIONS (Task 10.3)
# ============================================================================

def generate_business_alerts():
    """Generate critical business alerts"""
    try:
        alerts = []
        
        # Get current data
        users_ref = db.collection('users')
        all_users = list(users_ref.stream())
        
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        
        trial_ref = db.collection('trial_history')
        all_trials = list(trial_ref.stream())
        
        # Alert 1: High Churn Rate
        churn_metrics = calculate_churn_metrics()
        if churn_metrics['monthly_churn_rate'] > 15:  # Alert if monthly churn > 15%
            alerts.append({
                'type': 'critical',
                'category': 'churn',
                'title': 'High Churn Rate Alert',
                'message': f"Monthly churn rate is {churn_metrics['monthly_churn_rate']}% (threshold: 15%)",
                'value': churn_metrics['monthly_churn_rate'],
                'threshold': 15,
                'timestamp': datetime.now().isoformat(),
                'action': 'Review user feedback and improve retention strategies'
            })
        
        # Alert 2: Payment Failures
        payment_data = calculate_payment_analysis(all_subscriptions)
        if payment_data['failure_rate'] > 10:  # Alert if payment failure rate > 10%
            alerts.append({
                'type': 'warning',
                'category': 'payment',
                'title': 'High Payment Failure Rate',
                'message': f"Payment failure rate is {payment_data['failure_rate']}% (threshold: 10%)",
                'value': payment_data['failure_rate'],
                'threshold': 10,
                'timestamp': datetime.now().isoformat(),
                'action': 'Check payment processor status and user payment methods'
            })
        
        # Alert 3: Low Trial Conversion
        if all_trials and all_subscriptions:
            active_subscriptions = len([sub for sub in all_subscriptions if sub.to_dict().get('isActive')])
            conversion_rate = (active_subscriptions / len(all_trials)) * 100
            
            if conversion_rate < 20:  # Alert if trial conversion < 20%
                alerts.append({
                    'type': 'warning',
                    'category': 'conversion',
                    'title': 'Low Trial Conversion Rate',
                    'message': f"Trial to subscription conversion is {conversion_rate:.1f}% (threshold: 20%)",
                    'value': round(conversion_rate, 1),
                    'threshold': 20,
                    'timestamp': datetime.now().isoformat(),
                    'action': 'Review trial experience and onboarding process'
                })
        
        # Alert 4: High Unverified User Rate
        if all_users:
            unverified_users = len([user for user in all_users if not user.to_dict().get('emailVerified')])
            unverified_rate = (unverified_users / len(all_users)) * 100
            
            if unverified_rate > 30:  # Alert if unverified rate > 30%
                alerts.append({
                    'type': 'info',
                    'category': 'verification',
                    'title': 'High Unverified User Rate',
                    'message': f"Unverified user rate is {unverified_rate:.1f}% (threshold: 30%)",
                    'value': round(unverified_rate, 1),
                    'threshold': 30,
                    'timestamp': datetime.now().isoformat(),
                    'action': 'Improve email verification flow and reminders'
                })
        
        return {
            'total_alerts': len(alerts),
            'critical_alerts': len([a for a in alerts if a['type'] == 'critical']),
            'warning_alerts': len([a for a in alerts if a['type'] == 'warning']),
            'info_alerts': len([a for a in alerts if a['type'] == 'info']),
            'alerts': alerts,
            'last_updated': datetime.now().isoformat()
        }
        
    except Exception as e:
        app.logger.error(f"Error generating business alerts: {e}")
        return {
            'total_alerts': 0,
            'critical_alerts': 0,
            'warning_alerts': 0,
            'info_alerts': 0,
            'alerts': [],
            'last_updated': datetime.now().isoformat()
        }

def calculate_performance_metrics():
    """Calculate performance monitoring metrics"""
    try:
        # Simulated performance metrics (in a real app, these would come from monitoring tools)
        now = datetime.now()
        
        # Response time metrics
        response_times = {
            'api_average_response_time': 245,  # ms
            'database_query_time': 89,  # ms
            'authentication_time': 156,  # ms
            'payment_processing_time': 1234  # ms
        }
        
        # Error tracking
        error_metrics = {
            'total_errors_24h': calculate_simulated_errors(),
            'error_rate_percentage': calculate_simulated_error_rate(),
            'critical_errors': 2,
            'warning_errors': 8,
            'info_errors': 15
        }
        
        # System health
        system_health = {
            'uptime_percentage': 99.8,
            'cpu_usage': 45.2,
            'memory_usage': 67.8,
            'disk_usage': 34.1,
            'active_connections': 127
        }
        
        # User activity metrics
        user_activity = calculate_user_activity_metrics()
        
        return {
            'response_times': response_times,
            'error_metrics': error_metrics,
            'system_health': system_health,
            'user_activity': user_activity,
            'last_updated': now.isoformat(),
            'status': determine_system_status(response_times, error_metrics, system_health)
        }
        
    except Exception as e:
        app.logger.error(f"Error calculating performance metrics: {e}")
        return {
            'response_times': {},
            'error_metrics': {},
            'system_health': {},
            'user_activity': {},
            'last_updated': datetime.now().isoformat(),
            'status': 'unknown'
        }

def generate_automated_reports():
    """Generate automated reports and trend analysis"""
    try:
        # Get data for reports
        users_ref = db.collection('users')
        all_users = list(users_ref.stream())
        
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        
        trial_ref = db.collection('trial_history')
        all_trials = list(trial_ref.stream())
        
        # Daily Summary Report
        daily_report = generate_daily_summary_report(all_users, all_subscriptions, all_trials)
        
        # Weekly Trend Report
        weekly_report = generate_weekly_trend_report(all_users, all_subscriptions)
        
        # Monthly Business Report
        monthly_report = generate_monthly_business_report(all_subscriptions)
        
        return {
            'daily_summary': daily_report,
            'weekly_trends': weekly_report,
            'monthly_business': monthly_report,
            'generated_at': datetime.now().isoformat()
        }
        
    except Exception as e:
        app.logger.error(f"Error generating automated reports: {e}")
        return {
            'daily_summary': {},
            'weekly_trends': {},
            'monthly_business': {},
            'generated_at': datetime.now().isoformat()
        }

def export_users_data(format_type):
    """Export users data for analysis"""
    try:
        users_ref = db.collection('users')
        all_users = list(users_ref.stream())
        
        # Prepare user data for export
        export_data = []
        for user_doc in all_users:
            user_data = user_doc.to_dict()
            export_data.append({
                'user_id': user_doc.id,
                'email': user_data.get('email', ''),
                'username': user_data.get('username', ''),
                'email_verified': user_data.get('emailVerified', False),
                'created_at': format_timestamp(user_data.get('createdAt')),
                'last_login': format_timestamp(user_data.get('lastLoginAt')),
                'email_verified_at': format_timestamp(user_data.get('emailVerifiedAt'))
            })
        
        if format_type == 'csv':
            return generate_csv_response(export_data, 'users_export')
        else:
            return jsonify({
                'success': True,
                'data': export_data,
                'count': len(export_data),
                'exported_at': datetime.now().isoformat()
            })
            
    except Exception as e:
        app.logger.error(f"Error exporting users data: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

def export_subscriptions_data(format_type):
    """Export subscriptions data for analysis"""
    try:
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        
        # Prepare subscription data for export
        export_data = []
        for sub_doc in all_subscriptions:
            sub_data = sub_doc.to_dict()
            export_data.append({
                'subscription_id': sub_doc.id,
                'email': sub_data.get('email', ''),
                'is_active': sub_data.get('status') == 'active',
                'cancelled': sub_data.get('cancelled', False),
                'subscription_start': format_timestamp(sub_data.get('startDate')),
                'subscription_end': format_timestamp(sub_data.get('subscriptionEndDate')),
                'will_expire_at': format_timestamp(sub_data.get('willExpireAt')),
                'monthly_fee': 3.0
            })
        
        if format_type == 'csv':
            return generate_csv_response(export_data, 'subscriptions_export')
        else:
            return jsonify({
                'success': True,
                'data': export_data,
                'count': len(export_data),
                'exported_at': datetime.now().isoformat()
            })
            
    except Exception as e:
        app.logger.error(f"Error exporting subscriptions data: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

def export_analytics_data(format_type):
    """Export analytics summary data"""
    try:
        # Get analytics data
        users_ref = db.collection('users')
        all_users = list(users_ref.stream())
        
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        
        # Calculate key metrics
        total_users = len(all_users)
        verified_users = len([u for u in all_users if u.to_dict().get('emailVerified')])
        active_subscriptions = len([s for s in all_subscriptions if s.to_dict().get('isActive')])
        
        revenue_trends = calculate_revenue_trends(all_subscriptions)
        churn_metrics = calculate_churn_metrics()
        
        export_data = {
            'summary': {
                'total_users': total_users,
                'verified_users': verified_users,
                'active_subscriptions': active_subscriptions,
                'monthly_churn_rate': churn_metrics['monthly_churn_rate'],
                'mrr': active_subscriptions * 3.0
            },
            'revenue_trends': revenue_trends,
            'exported_at': datetime.now().isoformat()
        }
        
        if format_type == 'csv':
            # For CSV, flatten the summary data
            csv_data = [export_data['summary']]
            return generate_csv_response(csv_data, 'analytics_export')
        else:
            return jsonify({
                'success': True,
                'data': export_data,
                'exported_at': datetime.now().isoformat()
            })
            
    except Exception as e:
        app.logger.error(f"Error exporting analytics data: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# Helper functions for monitoring system

def calculate_simulated_error_rate():
    """Simulate error rate calculation"""
    import random
    return round(random.uniform(1.0, 8.0), 1)

def calculate_simulated_errors():
    """Simulate error count calculation"""
    import random
    return random.randint(15, 45)

def calculate_user_activity_metrics():
    """Calculate user activity metrics"""
    try:
        users_ref = db.collection('users')
        all_users = list(users_ref.stream())
        
        now = datetime.now()
        active_today = 0
        active_week = 0
        
        for user_doc in all_users:
            user_data = user_doc.to_dict()
            last_login = user_data.get('lastLoginAt')
            
            if last_login:
                if hasattr(last_login, 'seconds'):
                    login_dt = datetime.fromtimestamp(last_login.seconds)
                else:
                    login_dt = datetime.fromisoformat(str(last_login).replace('Z', '+00:00')).replace(tzinfo=None)
                
                days_since_login = (now - login_dt).days
                
                if days_since_login == 0:
                    active_today += 1
                if days_since_login <= 7:
                    active_week += 1
        
        return {
            'daily_active_users': active_today,
            'weekly_active_users': active_week,
            'total_registered_users': len(all_users)
        }
        
    except Exception as e:
        app.logger.error(f"Error calculating user activity metrics: {e}")
        return {
            'daily_active_users': 0,
            'weekly_active_users': 0,
            'total_registered_users': 0
        }

def determine_system_status(response_times, error_metrics, system_health):
    """Determine overall system status"""
    if (response_times.get('api_average_response_time', 0) > 500 or 
        error_metrics.get('error_rate_percentage', 0) > 10 or
        system_health.get('uptime_percentage', 100) < 99):
        return 'critical'
    elif (response_times.get('api_average_response_time', 0) > 300 or 
          error_metrics.get('error_rate_percentage', 0) > 5):
        return 'warning'
    else:
        return 'healthy'

def generate_daily_summary_report(users, subscriptions, trials):
    """Generate daily summary report"""
    today = datetime.now().date()
    
    # Count today's activities
    new_users_today = 0
    new_subscriptions_today = 0
    
    for user_doc in users:
        user_data = user_doc.to_dict()
        created_at = user_data.get('createdAt')
        if created_at:
            if hasattr(created_at, 'seconds'):
                created_date = datetime.fromtimestamp(created_at.seconds).date()
            else:
                created_date = datetime.fromisoformat(str(created_at).replace('Z', '+00:00')).date()
            
            if created_date == today:
                new_users_today += 1
    
    for sub_doc in subscriptions:
        sub_data = sub_doc.to_dict()
        start_date = sub_data.get('startDate')
        if start_date:
            if hasattr(start_date, 'seconds'):
                start_date_obj = datetime.fromtimestamp(start_date.seconds).date()
            else:
                start_date_obj = datetime.fromisoformat(str(start_date).replace('Z', '+00:00')).date()
            
            if start_date_obj == today:
                new_subscriptions_today += 1
    
    return {
        'date': today.isoformat(),
        'new_users': new_users_today,
        'new_subscriptions': new_subscriptions_today,
        'total_users': len(users),
        'active_subscriptions': len([s for s in subscriptions if s.to_dict().get('isActive')]),
        'daily_revenue': new_subscriptions_today * 3.0
    }

def generate_weekly_trend_report(users, subscriptions):
    """Generate weekly trend report"""
    weekly_data = []
    now = datetime.now()
    
    for i in range(7):
        day = now - timedelta(days=i)
        day_date = day.date()
        
        daily_users = 0
        daily_subscriptions = 0
        
        # Count users for this day
        for user_doc in users:
            user_data = user_doc.to_dict()
            created_at = user_data.get('createdAt')
            if created_at:
                if hasattr(created_at, 'seconds'):
                    created_date = datetime.fromtimestamp(created_at.seconds).date()
                else:
                    created_date = datetime.fromisoformat(str(created_at).replace('Z', '+00:00')).date()
                
                if created_date == day_date:
                    daily_users += 1
        
        # Count subscriptions for this day
        for sub_doc in subscriptions:
            sub_data = sub_doc.to_dict()
            start_date = sub_data.get('startDate')
            if start_date:
                if hasattr(start_date, 'seconds'):
                    start_date_obj = datetime.fromtimestamp(start_date.seconds).date()
                else:
                    start_date_obj = datetime.fromisoformat(str(start_date).replace('Z', '+00:00')).date()
                
                if start_date_obj == day_date:
                    daily_subscriptions += 1
        
        weekly_data.append({
            'date': day_date.isoformat(),
            'new_users': daily_users,
            'new_subscriptions': daily_subscriptions,
            'revenue': daily_subscriptions * 3.0
        })
    
    return list(reversed(weekly_data))

def generate_monthly_business_report(subscriptions):
    """Generate monthly business report"""
    now = datetime.now()
    current_month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    
    monthly_revenue = 0
    monthly_new_subscriptions = 0
    monthly_cancellations = 0
    
    for sub_doc in subscriptions:
        sub_data = sub_doc.to_dict()
        
        # Check for new subscriptions this month
        start_date = sub_data.get('startDate')
        if start_date:
            if hasattr(start_date, 'seconds'):
                start_dt = datetime.fromtimestamp(start_date.seconds)
            else:
                start_dt = datetime.fromisoformat(str(start_date).replace('Z', '+00:00')).replace(tzinfo=None)
            
            if start_dt >= current_month_start:
                monthly_new_subscriptions += 1
                monthly_revenue += 3.0
        
        # Check for cancellations this month
        if sub_data.get('cancelled'):
            expire_date = sub_data.get('willExpireAt')
            if expire_date:
                if hasattr(expire_date, 'seconds'):
                    expire_dt = datetime.fromtimestamp(expire_date.seconds)
                else:
                    expire_dt = datetime.fromisoformat(str(expire_date).replace('Z', '+00:00')).replace(tzinfo=None)
                
                if expire_dt >= current_month_start:
                    monthly_cancellations += 1
    
    return {
        'month': current_month_start.strftime('%Y-%m'),
        'new_subscriptions': monthly_new_subscriptions,
        'cancellations': monthly_cancellations,
        'net_growth': monthly_new_subscriptions - monthly_cancellations,
        'revenue': monthly_revenue,
        'active_subscriptions': len([s for s in subscriptions if s.to_dict().get('isActive')])
    }

def generate_csv_response(data, filename):
    """Generate CSV response for data export"""
    try:
        import csv
        import io
        from flask import make_response
        
        if not data:
            return jsonify({'success': False, 'error': 'No data to export'}), 400
        
        output = io.StringIO()
        
        # Get field names from first record
        fieldnames = data[0].keys()
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        
        writer.writeheader()
        for row in data:
            writer.writerow(row)
        
        output.seek(0)
        
        response = make_response(output.getvalue())
        response.headers['Content-Type'] = 'text/csv'
        response.headers['Content-Disposition'] = f'attachment; filename={filename}_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv'
        
        return response
        
    except Exception as e:
        app.logger.error(f"Error generating CSV response: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

# ============================================================================
# ADVANCED ANALYTICS HELPER FUNCTIONS (Task 10.2)
# ============================================================================

def calculate_cohort_analysis(users):
    """Calculate cohort analysis for user retention tracking"""
    try:
        cohorts = {}
        now = datetime.now()
        
        # Group users by registration month (cohort)
        for user_doc in users:
            user_data = user_doc.to_dict()
            created_at = user_data.get('createdAt')
            
            if not created_at:
                continue
                
            # Parse registration date
            if hasattr(created_at, 'seconds'):
                reg_date = datetime.fromtimestamp(created_at.seconds)
            else:
                reg_date = datetime.fromisoformat(str(created_at).replace('Z', '+00:00')).replace(tzinfo=None)
            
            cohort_month = reg_date.strftime('%Y-%m')
            
            if cohort_month not in cohorts:
                cohorts[cohort_month] = {
                    'total_users': 0,
                    'users': [],
                    'retention_periods': {}
                }
            
            cohorts[cohort_month]['total_users'] += 1
            cohorts[cohort_month]['users'].append({
                'user_id': user_doc.id,
                'registration_date': reg_date,
                'last_login': user_data.get('lastLoginAt'),
                'email_verified': user_data.get('emailVerified', False)
            })
        
        # Calculate retention rates for each cohort
        cohort_analysis = []
        for cohort_month, cohort_data in cohorts.items():
            if cohort_data['total_users'] == 0:
                continue
                
            cohort_date = datetime.strptime(cohort_month, '%Y-%m')
            
            # Calculate retention for different periods (1, 7, 30, 90 days)
            retention_1_day = 0
            retention_7_day = 0
            retention_30_day = 0
            retention_90_day = 0
            
            for user in cohort_data['users']:
                last_login = user.get('last_login')
                if not last_login:
                    continue
                    
                # Parse last login date
                if hasattr(last_login, 'seconds'):
                    login_date = datetime.fromtimestamp(last_login.seconds)
                else:
                    login_date = datetime.fromisoformat(str(last_login).replace('Z', '+00:00')).replace(tzinfo=None)
                
                reg_date = user['registration_date']
                days_since_reg = (login_date - reg_date).days
                
                if days_since_reg >= 1:
                    retention_1_day += 1
                if days_since_reg >= 7:
                    retention_7_day += 1
                if days_since_reg >= 30:
                    retention_30_day += 1
                if days_since_reg >= 90:
                    retention_90_day += 1
            
            total_users = cohort_data['total_users']
            cohort_analysis.append({
                'cohort_month': cohort_month,
                'total_users': total_users,
                'retention_1_day': round((retention_1_day / total_users) * 100, 2),
                'retention_7_day': round((retention_7_day / total_users) * 100, 2),
                'retention_30_day': round((retention_30_day / total_users) * 100, 2),
                'retention_90_day': round((retention_90_day / total_users) * 100, 2),
                'months_since_launch': (now.year - cohort_date.year) * 12 + (now.month - cohort_date.month)
            })
        
        # Sort by cohort month
        cohort_analysis.sort(key=lambda x: x['cohort_month'])
        
        return {
            'cohorts': cohort_analysis,
            'total_cohorts': len(cohort_analysis),
            'average_retention_1_day': round(sum(c['retention_1_day'] for c in cohort_analysis) / len(cohort_analysis), 2) if cohort_analysis else 0,
            'average_retention_7_day': round(sum(c['retention_7_day'] for c in cohort_analysis) / len(cohort_analysis), 2) if cohort_analysis else 0,
            'average_retention_30_day': round(sum(c['retention_30_day'] for c in cohort_analysis) / len(cohort_analysis), 2) if cohort_analysis else 0,
            'average_retention_90_day': round(sum(c['retention_90_day'] for c in cohort_analysis) / len(cohort_analysis), 2) if cohort_analysis else 0
        }
        
    except Exception as e:
        app.logger.error(f"Error calculating cohort analysis: {e}")
        return {
            'cohorts': [],
            'total_cohorts': 0,
            'average_retention_1_day': 0,
            'average_retention_7_day': 0,
            'average_retention_30_day': 0,
            'average_retention_90_day': 0
        }

def calculate_geographic_distribution(users):
    """Calculate geographic distribution analysis for OFW markets"""
    try:
        # Common OFW destination countries
        ofw_countries = {
            'Saudi Arabia': {'users': 0, 'verified': 0, 'subscribed': 0},
            'United Arab Emirates': {'users': 0, 'verified': 0, 'subscribed': 0},
            'Qatar': {'users': 0, 'verified': 0, 'subscribed': 0},
            'Kuwait': {'users': 0, 'verified': 0, 'subscribed': 0},
            'Hong Kong': {'users': 0, 'verified': 0, 'subscribed': 0},
            'Singapore': {'users': 0, 'verified': 0, 'subscribed': 0},
            'Taiwan': {'users': 0, 'verified': 0, 'subscribed': 0},
            'Japan': {'users': 0, 'verified': 0, 'subscribed': 0},
            'South Korea': {'users': 0, 'verified': 0, 'subscribed': 0},
            'Malaysia': {'users': 0, 'verified': 0, 'subscribed': 0},
            'Italy': {'users': 0, 'verified': 0, 'subscribed': 0},
            'United Kingdom': {'users': 0, 'verified': 0, 'subscribed': 0},
            'Canada': {'users': 0, 'verified': 0, 'subscribed': 0},
            'United States': {'users': 0, 'verified': 0, 'subscribed': 0},
            'Australia': {'users': 0, 'verified': 0, 'subscribed': 0},
            'Other': {'users': 0, 'verified': 0, 'subscribed': 0}
        }
        
        # Get subscription data for cross-referencing
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        subscribed_emails = set()
        for sub_doc in all_subscriptions:
            sub_data = sub_doc.to_dict()
            if sub_data.get('isActive'):
                subscribed_emails.add(sub_data.get('email', ''))
        
        # Analyze user geographic data
        total_users = 0
        for user_doc in users:
            user_data = user_doc.to_dict()
            email = user_data.get('email', '')
            total_users += 1
            
            # Extract country from email domain or user profile
            country = extract_country_from_user_data(user_data)
            
            if country not in ofw_countries:
                country = 'Other'
            
            ofw_countries[country]['users'] += 1
            
            if user_data.get('emailVerified'):
                ofw_countries[country]['verified'] += 1
            
            if email in subscribed_emails:
                ofw_countries[country]['subscribed'] += 1
        
        # Calculate percentages and conversion rates
        geographic_analysis = []
        for country, data in ofw_countries.items():
            if data['users'] > 0:
                verification_rate = (data['verified'] / data['users']) * 100
                subscription_rate = (data['subscribed'] / data['users']) * 100
                market_share = (data['users'] / total_users) * 100
                
                geographic_analysis.append({
                    'country': country,
                    'total_users': data['users'],
                    'verified_users': data['verified'],
                    'subscribed_users': data['subscribed'],
                    'market_share': round(market_share, 2),
                    'verification_rate': round(verification_rate, 2),
                    'subscription_rate': round(subscription_rate, 2),
                    'revenue_potential': round(data['subscribed'] * 3.0, 2)  # $3/month per subscription
                })
        
        # Sort by market share (descending)
        geographic_analysis.sort(key=lambda x: x['market_share'], reverse=True)
        
        # Calculate top markets summary
        top_5_markets = geographic_analysis[:5]
        top_5_users = sum(market['total_users'] for market in top_5_markets)
        top_5_revenue = sum(market['revenue_potential'] for market in top_5_markets)
        
        return {
            'countries': geographic_analysis,
            'total_countries': len([c for c in geographic_analysis if c['total_users'] > 0]),
            'top_5_markets': top_5_markets,
            'top_5_market_share': round((top_5_users / total_users) * 100, 2) if total_users > 0 else 0,
            'top_5_revenue': top_5_revenue,
            'geographic_diversity_index': calculate_diversity_index(geographic_analysis)
        }
        
    except Exception as e:
        app.logger.error(f"Error calculating geographic distribution: {e}")
        return {
            'countries': [],
            'total_countries': 0,
            'top_5_markets': [],
            'top_5_market_share': 0,
            'top_5_revenue': 0,
            'geographic_diversity_index': 0
        }

def extract_country_from_user_data(user_data):
    """Extract country information from user data"""
    # This is a simplified implementation
    # In a real app, you might have actual location data or IP geolocation
    email = user_data.get('email', '').lower()
    
    # Common email domains by country for OFWs
    domain_country_map = {
        'gmail.com': 'Other',  # Generic
        'yahoo.com': 'Other',  # Generic
        'hotmail.com': 'Other',  # Generic
        # Add more specific mappings as needed
    }
    
    # Extract domain
    if '@' in email:
        domain = email.split('@')[1]
        return domain_country_map.get(domain, 'Other')
    
    return 'Other'

def calculate_diversity_index(geographic_data):
    """Calculate geographic diversity index (higher = more diverse)"""
    try:
        total_users = sum(country['total_users'] for country in geographic_data)
        if total_users == 0:
            return 0
        
        # Calculate Herfindahl-Hirschman Index (HHI) and convert to diversity
        hhi = sum((country['total_users'] / total_users) ** 2 for country in geographic_data)
        diversity_index = (1 - hhi) * 100  # Convert to percentage
        
        return round(diversity_index, 2)
    except:
        return 0

def calculate_user_behavior_analytics(users, trials, subscriptions):
    """Calculate user behavior and engagement analytics"""
    try:
        total_users = len(users)
        if total_users == 0:
            return {}
        
        # Analyze user journey patterns
        journey_patterns = {
            'quick_converters': 0,  # Trial to subscription within 3 days
            'trial_completers': 0,  # Used full trial period
            'trial_abandoners': 0,  # Abandoned trial early
            'email_verifiers': 0,   # Verified email quickly (within 24h)
            'delayed_verifiers': 0, # Verified email after 24h
            'never_verified': 0     # Never verified email
        }
        
        # Create lookup dictionaries
        trial_lookup = {}
        for trial_doc in trials:
            trial_data = trial_doc.to_dict()
            user_id = trial_data.get('userId')
            if user_id:
                trial_lookup[user_id] = trial_data
        
        subscription_lookup = {}
        for sub_doc in subscriptions:
            sub_data = sub_doc.to_dict()
            email = sub_data.get('email')
            if email:
                subscription_lookup[email] = sub_data
        
        # Analyze each user's behavior
        engagement_scores = []
        session_patterns = {
            'single_session': 0,    # Only logged in once
            'regular_user': 0,      # Multiple logins
            'power_user': 0,        # Very active
            'inactive_user': 0      # Registered but never logged in
        }
        
        for user_doc in users:
            user_data = user_doc.to_dict()
            user_id = user_doc.id
            email = user_data.get('email', '')
            
            # Analyze email verification behavior
            created_at = user_data.get('createdAt')
            verified_at = user_data.get('emailVerifiedAt')
            
            if not user_data.get('emailVerified'):
                journey_patterns['never_verified'] += 1
            elif created_at and verified_at:
                # Calculate verification time
                if hasattr(created_at, 'seconds'):
                    created_dt = datetime.fromtimestamp(created_at.seconds)
                else:
                    created_dt = datetime.fromisoformat(str(created_at).replace('Z', '+00:00')).replace(tzinfo=None)
                
                if hasattr(verified_at, 'seconds'):
                    verified_dt = datetime.fromtimestamp(verified_at.seconds)
                else:
                    verified_dt = datetime.fromisoformat(str(verified_at).replace('Z', '+00:00')).replace(tzinfo=None)
                
                verification_hours = (verified_dt - created_dt).total_seconds() / 3600
                
                if verification_hours <= 24:
                    journey_patterns['email_verifiers'] += 1
                else:
                    journey_patterns['delayed_verifiers'] += 1
            
            # Analyze trial behavior
            trial_data = trial_lookup.get(user_id)
            subscription_data = subscription_lookup.get(email)
            
            if trial_data and subscription_data:
                trial_start = trial_data.get('trialStartDate')
                sub_start = subscription_data.get('startDate')
                
                if trial_start and sub_start:
                    # Parse dates
                    if hasattr(trial_start, 'seconds'):
                        trial_dt = datetime.fromtimestamp(trial_start.seconds)
                    else:
                        trial_dt = datetime.fromisoformat(str(trial_start).replace('Z', '+00:00')).replace(tzinfo=None)
                    
                    if hasattr(sub_start, 'seconds'):
                        sub_dt = datetime.fromtimestamp(sub_start.seconds)
                    else:
                        sub_dt = datetime.fromisoformat(str(sub_start).replace('Z', '+00:00')).replace(tzinfo=None)
                    
                    conversion_days = (sub_dt - trial_dt).days
                    
                    if conversion_days <= 3:
                        journey_patterns['quick_converters'] += 1
                    elif conversion_days >= 6:  # Used most of trial
                        journey_patterns['trial_completers'] += 1
                    else:
                        journey_patterns['trial_abandoners'] += 1
            
            # Analyze session patterns
            last_login = user_data.get('lastLoginAt')
            if not last_login:
                session_patterns['inactive_user'] += 1
            else:
                # This is simplified - in a real app you'd have more session data
                session_patterns['regular_user'] += 1
            
            # Calculate engagement score (0-100)
            engagement_score = calculate_user_engagement_score(user_data, trial_data, subscription_data)
            engagement_scores.append(engagement_score)
        
        # Calculate averages and insights
        avg_engagement = sum(engagement_scores) / len(engagement_scores) if engagement_scores else 0
        
        # User lifecycle insights
        lifecycle_analysis = {
            'activation_rate': round((journey_patterns['email_verifiers'] + journey_patterns['delayed_verifiers']) / total_users * 100, 2),
            'quick_verification_rate': round(journey_patterns['email_verifiers'] / total_users * 100, 2),
            'trial_completion_rate': round(journey_patterns['trial_completers'] / len(trials) * 100, 2) if trials else 0,
            'quick_conversion_rate': round(journey_patterns['quick_converters'] / len(trials) * 100, 2) if trials else 0
        }
        
        return {
            'journey_patterns': journey_patterns,
            'session_patterns': session_patterns,
            'lifecycle_analysis': lifecycle_analysis,
            'engagement_metrics': {
                'average_engagement_score': round(avg_engagement, 2),
                'high_engagement_users': len([s for s in engagement_scores if s >= 70]),
                'low_engagement_users': len([s for s in engagement_scores if s <= 30]),
                'engagement_distribution': calculate_engagement_distribution(engagement_scores)
            },
            'behavioral_insights': generate_behavioral_insights(journey_patterns, session_patterns, lifecycle_analysis)
        }
        
    except Exception as e:
        app.logger.error(f"Error calculating user behavior analytics: {e}")
        return {}

def calculate_user_engagement_score(user_data, trial_data, subscription_data):
    """Calculate engagement score for a user (0-100)"""
    score = 0
    
    # Email verification (20 points)
    if user_data.get('emailVerified'):
        score += 20
    
    # Trial usage (30 points)
    if trial_data:
        score += 30
    
    # Subscription (40 points)
    if subscription_data and subscription_data.get('isActive'):
        score += 40
    
    # Recent activity (10 points)
    last_login = user_data.get('lastLoginAt')
    if last_login:
        if hasattr(last_login, 'seconds'):
            login_dt = datetime.fromtimestamp(last_login.seconds)
        else:
            login_dt = datetime.fromisoformat(str(last_login).replace('Z', '+00:00')).replace(tzinfo=None)
        
        days_since_login = (datetime.now() - login_dt).days
        if days_since_login <= 7:
            score += 10
        elif days_since_login <= 30:
            score += 5
    
    return min(score, 100)

def calculate_engagement_distribution(scores):
    """Calculate distribution of engagement scores"""
    if not scores:
        return {}
    
    high = len([s for s in scores if s >= 70])
    medium = len([s for s in scores if 30 <= s < 70])
    low = len([s for s in scores if s < 30])
    total = len(scores)
    
    return {
        'high_engagement': round(high / total * 100, 2),
        'medium_engagement': round(medium / total * 100, 2),
        'low_engagement': round(low / total * 100, 2)
    }

def generate_behavioral_insights(journey_patterns, session_patterns, lifecycle_analysis):
    """Generate actionable behavioral insights"""
    insights = []
    
    # Email verification insights
    if lifecycle_analysis['quick_verification_rate'] < 50:
        insights.append("Consider improving email verification flow - many users delay verification")
    
    # Trial conversion insights
    if lifecycle_analysis['quick_conversion_rate'] > 30:
        insights.append("High quick conversion rate suggests strong product-market fit")
    elif lifecycle_analysis['trial_completion_rate'] < 40:
        insights.append("Many users abandon trials early - consider onboarding improvements")
    
    # User activation insights
    if lifecycle_analysis['activation_rate'] < 70:
        insights.append("Low activation rate - focus on improving initial user experience")
    
    return insights

def calculate_payment_analysis(subscriptions):
    """Calculate payment success rate and failure analysis"""
    try:
        if not subscriptions:
            return {
                'total_payment_attempts': 0,
                'successful_payments': 0,
                'failed_payments': 0,
                'success_rate': 0,
                'failure_rate': 0,
                'payment_methods': {},
                'failure_reasons': {},
                'recovery_rate': 0,
                'monthly_trends': []
            }
        
        # Analyze subscription payment data
        total_subscriptions = len(subscriptions)
        active_subscriptions = 0
        cancelled_subscriptions = 0
        payment_failures = 0
        
        # Payment method analysis (simulated data - in real app this would come from payment processor)
        payment_methods = {
            'credit_card': {'attempts': 0, 'successes': 0, 'failures': 0},
            'paypal': {'attempts': 0, 'successes': 0, 'failures': 0},
            'google_pay': {'attempts': 0, 'successes': 0, 'failures': 0},
            'apple_pay': {'attempts': 0, 'successes': 0, 'failures': 0}
        }
        
        # Failure reason analysis (simulated)
        failure_reasons = {
            'insufficient_funds': 0,
            'expired_card': 0,
            'declined_card': 0,
            'network_error': 0,
            'authentication_failed': 0,
            'other': 0
        }
        
        monthly_payment_data = {}
        
        for sub_doc in subscriptions:
            sub_data = sub_doc.to_dict()
            
            if sub_data.get('isActive'):
                active_subscriptions += 1
            
            if sub_data.get('cancelled'):
                cancelled_subscriptions += 1
                # Simulate payment failure as potential cause
                if not sub_data.get('isActive'):
                    payment_failures += 1
            
            # Analyze monthly payment trends
            start_date = sub_data.get('startDate')
            if start_date:
                if hasattr(start_date, 'seconds'):
                    start_dt = datetime.fromtimestamp(start_date.seconds)
                else:
                    start_dt = datetime.fromisoformat(str(start_date).replace('Z', '+00:00')).replace(tzinfo=None)
                
                month_key = start_dt.strftime('%Y-%m')
                if month_key not in monthly_payment_data:
                    monthly_payment_data[month_key] = {
                        'attempts': 0,
                        'successes': 0,
                        'failures': 0,
                        'revenue': 0
                    }
                
                monthly_payment_data[month_key]['attempts'] += 1
                if sub_data.get('isActive') or not sub_data.get('cancelled'):
                    monthly_payment_data[month_key]['successes'] += 1
                    monthly_payment_data[month_key]['revenue'] += 3.0
                else:
                    monthly_payment_data[month_key]['failures'] += 1
            
            # Simulate payment method distribution
            import random
            method = random.choice(['credit_card', 'paypal', 'google_pay', 'apple_pay'])
            payment_methods[method]['attempts'] += 1
            
            if sub_data.get('isActive'):
                payment_methods[method]['successes'] += 1
            else:
                payment_methods[method]['failures'] += 1
                # Simulate failure reason
                reason = random.choice(list(failure_reasons.keys()))
                failure_reasons[reason] += 1
        
        # Calculate success rates
        total_attempts = total_subscriptions
        successful_payments = active_subscriptions
        failed_payments = payment_failures
        
        success_rate = (successful_payments / total_attempts * 100) if total_attempts > 0 else 0
        failure_rate = (failed_payments / total_attempts * 100) if total_attempts > 0 else 0
        
        # Calculate payment method success rates
        for method, data in payment_methods.items():
            if data['attempts'] > 0:
                data['success_rate'] = round((data['successes'] / data['attempts']) * 100, 2)
            else:
                data['success_rate'] = 0
        
        # Calculate recovery rate (users who resubscribed after cancellation)
        recovery_rate = 0  # This would require more complex tracking in a real app
        
        # Prepare monthly trends
        monthly_trends = []
        for month, data in sorted(monthly_payment_data.items()):
            monthly_trends.append({
                'month': month,
                'attempts': data['attempts'],
                'successes': data['successes'],
                'failures': data['failures'],
                'success_rate': round((data['successes'] / data['attempts']) * 100, 2) if data['attempts'] > 0 else 0,
                'revenue': data['revenue']
            })
        
        return {
            'total_payment_attempts': total_attempts,
            'successful_payments': successful_payments,
            'failed_payments': failed_payments,
            'success_rate': round(success_rate, 2),
            'failure_rate': round(failure_rate, 2),
            'payment_methods': payment_methods,
            'failure_reasons': failure_reasons,
            'recovery_rate': round(recovery_rate, 2),
            'monthly_trends': monthly_trends[-6:],  # Last 6 months
            'insights': generate_payment_insights(success_rate, failure_rate, payment_methods, failure_reasons)
        }
        
    except Exception as e:
        app.logger.error(f"Error calculating payment analysis: {e}")
        return {
            'total_payment_attempts': 0,
            'successful_payments': 0,
            'failed_payments': 0,
            'success_rate': 0,
            'failure_rate': 0,
            'payment_methods': {},
            'failure_reasons': {},
            'recovery_rate': 0,
            'monthly_trends': []
        }

def generate_payment_insights(success_rate, failure_rate, payment_methods, failure_reasons):
    """Generate actionable payment insights"""
    insights = []
    
    # Success rate insights
    if success_rate < 85:
        insights.append("Payment success rate is below industry standard (85%) - investigate payment flow issues")
    elif success_rate > 95:
        insights.append("Excellent payment success rate - current payment flow is working well")
    
    # Payment method insights
    best_method = max(payment_methods.items(), key=lambda x: x[1]['success_rate']) if payment_methods else None
    if best_method and best_method[1]['success_rate'] > 90:
        insights.append(f"{best_method[0].replace('_', ' ').title()} has the highest success rate - consider promoting it")
    
    # Failure reason insights
    if failure_reasons:
        top_failure = max(failure_reasons.items(), key=lambda x: x[1])
        if top_failure[1] > 0:
            insights.append(f"Most common failure reason: {top_failure[0].replace('_', ' ')} - focus on addressing this issue")
    
    return insights

# ============================================================================
# BUSINESS ANALYTICS HELPER FUNCTIONS
# ============================================================================

def calculate_revenue_trends(subscriptions):
    """Calculate revenue trends for the last 6 months"""
    try:
        now = datetime.now()
        trends = []
        
        for i in range(6):
            # Calculate month start and end
            month_date = now - timedelta(days=30 * i)
            month_start = month_date.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            
            if month_date.month == 12:
                next_month = month_date.replace(year=month_date.year + 1, month=1, day=1)
            else:
                next_month = month_date.replace(month=month_date.month + 1, day=1)
            
            month_end = next_month - timedelta(seconds=1)
            
            # Count active subscriptions in this month
            active_in_month = 0
            for sub_doc in subscriptions:
                sub_data = sub_doc.to_dict()
                if not sub_data.get('isActive'):
                    continue
                
                start_date = sub_data.get('startDate')
                if start_date:
                    if hasattr(start_date, 'seconds'):
                        start_dt = datetime.fromtimestamp(start_date.seconds)
                    else:
                        start_dt = datetime.fromisoformat(str(start_date).replace('Z', '+00:00')).replace(tzinfo=None)
                    
                    if start_dt <= month_end:
                        active_in_month += 1
            
            revenue = active_in_month * 3.0  # $3 per subscription
            trends.append({
                'month': month_date.strftime('%Y-%m'),
                'revenue': revenue,
                'active_subscriptions': active_in_month
            })
        
        return list(reversed(trends))  # Return chronological order
        
    except Exception as e:
        app.logger.error(f"Error calculating revenue trends: {e}")
        return []

def calculate_retention_metrics(users):
    """Calculate user retention metrics"""
    try:
        now = datetime.now()
        total_users = len(users)
        
        if total_users == 0:
            return {
                'retention_7_day': 0,
                'retention_30_day': 0,
                'retention_90_day': 0
            }
        
        # Calculate retention based on last login
        retention_7_day = 0
        retention_30_day = 0
        retention_90_day = 0
        
        for user_doc in users:
            user_data = user_doc.to_dict()
            last_login = user_data.get('lastLoginAt')
            
            if last_login:
                if hasattr(last_login, 'seconds'):
                    login_dt = datetime.fromtimestamp(last_login.seconds)
                else:
                    login_dt = datetime.fromisoformat(str(last_login).replace('Z', '+00:00')).replace(tzinfo=None)
                
                days_since_login = (now - login_dt).days
                
                if days_since_login <= 7:
                    retention_7_day += 1
                if days_since_login <= 30:
                    retention_30_day += 1
                if days_since_login <= 90:
                    retention_90_day += 1
        
        return {
            'retention_7_day': round((retention_7_day / total_users) * 100, 2),
            'retention_30_day': round((retention_30_day / total_users) * 100, 2),
            'retention_90_day': round((retention_90_day / total_users) * 100, 2)
        }
        
    except Exception as e:
        app.logger.error(f"Error calculating retention metrics: {e}")
        return {
            'retention_7_day': 0,
            'retention_30_day': 0,
            'retention_90_day': 0
        }

def calculate_churn_metrics():
    """Calculate churn rate metrics"""
    try:
        # Get subscription data
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        
        if not all_subscriptions:
            return {
                'overall_churn_rate': 0,
                'monthly_churn_rate': 0
            }
        
        total_subscriptions = len(all_subscriptions)
        cancelled_subscriptions = sum(1 for sub in all_subscriptions if sub.to_dict().get('cancelled', False))
        
        # Calculate overall churn rate
        overall_churn_rate = (cancelled_subscriptions / total_subscriptions) * 100 if total_subscriptions > 0 else 0
        
        # Calculate monthly churn rate (simplified)
        now = datetime.now()
        current_month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        
        monthly_cancellations = 0
        active_at_month_start = 0
        
        for sub_doc in all_subscriptions:
            sub_data = sub_doc.to_dict()
            
            # Check if subscription was active at start of month
            start_date = sub_data.get('startDate')
            if start_date:
                if hasattr(start_date, 'seconds'):
                    start_dt = datetime.fromtimestamp(start_date.seconds)
                else:
                    start_dt = datetime.fromisoformat(str(start_date).replace('Z', '+00:00')).replace(tzinfo=None)
                
                if start_dt < current_month_start:
                    active_at_month_start += 1
                    
                    # Check if cancelled this month
                    if sub_data.get('cancelled'):
                        will_expire = sub_data.get('willExpireAt')
                        if will_expire:
                            if hasattr(will_expire, 'seconds'):
                                expire_dt = datetime.fromtimestamp(will_expire.seconds)
                            else:
                                expire_dt = datetime.fromisoformat(str(will_expire).replace('Z', '+00:00')).replace(tzinfo=None)
                            
                            if expire_dt >= current_month_start:
                                monthly_cancellations += 1
        
        monthly_churn_rate = (monthly_cancellations / active_at_month_start) * 100 if active_at_month_start > 0 else 0
        
        return {
            'overall_churn_rate': round(overall_churn_rate, 2),
            'monthly_churn_rate': round(monthly_churn_rate, 2)
        }
        
    except Exception as e:
        app.logger.error(f"Error calculating churn metrics: {e}")
        return {
            'overall_churn_rate': 0,
            'monthly_churn_rate': 0
        }

def calculate_subscription_health_metrics(subscriptions):
    """Calculate subscription health metrics"""
    try:
        if not subscriptions:
            return {
                'health_score': 0,
                'average_duration_months': 0,
                'customer_lifetime_value': 0
            }
        
        active_subscriptions = [sub for sub in subscriptions if sub.to_dict().get('status') == 'active']
        total_subscriptions = len(subscriptions)
        active_count = len(active_subscriptions)
        
        # Calculate health score (percentage of active subscriptions)
        health_score = (active_count / total_subscriptions) * 100 if total_subscriptions > 0 else 0
        
        # Calculate average subscription duration
        total_duration_months = 0
        duration_count = 0
        
        for sub_doc in subscriptions:
            sub_data = sub_doc.to_dict()
            start_date = sub_data.get('startDate')
            end_date = sub_data.get('subscriptionEndDate') or sub_data.get('willExpireAt')
            
            if start_date:
                if hasattr(start_date, 'seconds'):
                    start_dt = datetime.fromtimestamp(start_date.seconds)
                else:
                    start_dt = datetime.fromisoformat(str(start_date).replace('Z', '+00:00')).replace(tzinfo=None)
                
                if end_date:
                    if hasattr(end_date, 'seconds'):
                        end_dt = datetime.fromtimestamp(end_date.seconds)
                    else:
                        end_dt = datetime.fromisoformat(str(end_date).replace('Z', '+00:00')).replace(tzinfo=None)
                else:
                    end_dt = datetime.now()  # Still active
                
                duration_months = (end_dt - start_dt).days / 30.44  # Average days per month
                total_duration_months += duration_months
                duration_count += 1
        
        average_duration_months = total_duration_months / duration_count if duration_count > 0 else 0
        
        # Calculate Customer Lifetime Value (CLV)
        customer_lifetime_value = average_duration_months * 3.0  # $3/month
        
        return {
            'health_score': round(health_score, 2),
            'average_duration_months': round(average_duration_months, 2),
            'customer_lifetime_value': round(customer_lifetime_value, 2)
        }
        
    except Exception as e:
        app.logger.error(f"Error calculating subscription health metrics: {e}")
        return {
            'health_score': 0,
            'average_duration_months': 0,
            'customer_lifetime_value': 0
        }

def calculate_subscription_growth_trends(subscriptions):
    """Calculate subscription growth trends"""
    try:
        now = datetime.now()
        trends = []
        
        for i in range(6):
            # Calculate month start and end
            month_date = now - timedelta(days=30 * i)
            month_start = month_date.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            
            if month_date.month == 12:
                next_month = month_date.replace(year=month_date.year + 1, month=1, day=1)
            else:
                next_month = month_date.replace(month=month_date.month + 1, day=1)
            
            month_end = next_month - timedelta(seconds=1)
            
            # Count new subscriptions in this month
            new_subscriptions = 0
            cancelled_subscriptions = 0
            
            for sub_doc in subscriptions:
                sub_data = sub_doc.to_dict()
                
                # Check for new subscriptions
                start_date = sub_data.get('startDate')
                if start_date:
                    if hasattr(start_date, 'seconds'):
                        start_dt = datetime.fromtimestamp(start_date.seconds)
                    else:
                        start_dt = datetime.fromisoformat(str(start_date).replace('Z', '+00:00')).replace(tzinfo=None)
                    
                    if month_start <= start_dt <= month_end:
                        new_subscriptions += 1
                
                # Check for cancellations
                if sub_data.get('cancelled'):
                    expire_date = sub_data.get('willExpireAt')
                    if expire_date:
                        if hasattr(expire_date, 'seconds'):
                            expire_dt = datetime.fromtimestamp(expire_date.seconds)
                        else:
                            expire_dt = datetime.fromisoformat(str(expire_date).replace('Z', '+00:00')).replace(tzinfo=None)
                        
                        if month_start <= expire_dt <= month_end:
                            cancelled_subscriptions += 1
            
            net_growth = new_subscriptions - cancelled_subscriptions
            
            trends.append({
                'month': month_date.strftime('%Y-%m'),
                'new_subscriptions': new_subscriptions,
                'cancelled_subscriptions': cancelled_subscriptions,
                'net_growth': net_growth
            })
        
        return list(reversed(trends))  # Return chronological order
        
    except Exception as e:
        app.logger.error(f"Error calculating subscription growth trends: {e}")
        return []

def calculate_revenue_growth_rate(revenue_trends):
    """Calculate revenue growth rate from trends"""
    try:
        if len(revenue_trends) < 2:
            return 0
        
        # Compare current month to previous month
        current_revenue = revenue_trends[-1]['revenue']
        previous_revenue = revenue_trends[-2]['revenue']
        
        if previous_revenue == 0:
            return 0
        
        growth_rate = ((current_revenue - previous_revenue) / previous_revenue) * 100
        return growth_rate
        
    except Exception as e:
        app.logger.error(f"Error calculating revenue growth rate: {e}")
        return 0

def calculate_total_revenue(subscriptions):
    """Calculate total revenue to date"""
    try:
        total_revenue = 0
        now = datetime.now()
        
        for sub_doc in subscriptions:
            sub_data = sub_doc.to_dict()
            start_date = sub_data.get('startDate')
            end_date = sub_data.get('subscriptionEndDate')
            
            if not start_date:
                continue
            
            # Parse start date
            if hasattr(start_date, 'seconds'):
                start_dt = datetime.fromtimestamp(start_date.seconds)
            else:
                start_dt = datetime.fromisoformat(str(start_date).replace('Z', '+00:00')).replace(tzinfo=None)
            
            # Determine end date
            if end_date:
                if hasattr(end_date, 'seconds'):
                    end_dt = datetime.fromtimestamp(end_date.seconds)
                else:
                    end_dt = datetime.fromisoformat(str(end_date).replace('Z', '+00:00')).replace(tzinfo=None)
            else:
                end_dt = now  # Still active
            
            # Calculate months of subscription
            months_active = max(0, (end_dt.year - start_dt.year) * 12 + end_dt.month - start_dt.month)
            if months_active == 0 and (end_dt - start_dt).days > 0:
                months_active = 1  # At least partial month
            
            total_revenue += months_active * 3.0
        
        return total_revenue
        
    except Exception as e:
        app.logger.error(f"Error calculating total revenue: {e}")
        return 0

def calculate_revenue_growth_rate(revenue_trends):
    """Calculate month-over-month revenue growth rate"""
    try:
        if len(revenue_trends) < 2:
            return 0
        
        current_revenue = revenue_trends[-1]['revenue']
        previous_revenue = revenue_trends[-2]['revenue']
        
        if previous_revenue == 0:
            return 100 if current_revenue > 0 else 0
        
        growth_rate = ((current_revenue - previous_revenue) / previous_revenue) * 100
        return growth_rate
        
    except Exception as e:
        app.logger.error(f"Error calculating revenue growth rate: {e}")
        return 0

def calculate_retention_metrics(users):
    """Calculate user retention metrics"""
    try:
        now = datetime.now()
        
        # Calculate 7-day retention
        week_ago = now - timedelta(days=7)
        users_week_ago = []
        users_still_active = []
        
        for user_doc in users:
            user_data = user_data = user_doc.to_dict()
            created_at = user_data.get('createdAt')
            last_login = user_data.get('lastLoginAt')
            
            if not created_at:
                continue
            
            # Parse creation date
            if hasattr(created_at, 'seconds'):
                created_dt = datetime.fromtimestamp(created_at.seconds)
            else:
                created_dt = datetime.fromisoformat(str(created_at).replace('Z', '+00:00')).replace(tzinfo=None)
            
            # Users who registered a week ago
            if created_dt <= week_ago:
                users_week_ago.append(user_doc.id)
                
                # Check if they're still active (logged in within last 7 days)
                if last_login:
                    if hasattr(last_login, 'seconds'):
                        last_login_dt = datetime.fromtimestamp(last_login.seconds)
                    else:
                        last_login_dt = datetime.fromisoformat(str(last_login).replace('Z', '+00:00')).replace(tzinfo=None)
                    
                    if last_login_dt >= week_ago:
                        users_still_active.append(user_doc.id)
        
        # Calculate 30-day retention
        month_ago = now - timedelta(days=30)
        users_month_ago = []
        users_still_active_month = []
        
        for user_doc in users:
            user_data = user_doc.to_dict()
            created_at = user_data.get('createdAt')
            last_login = user_data.get('lastLoginAt')
            
            if not created_at:
                continue
            
            # Parse creation date
            if hasattr(created_at, 'seconds'):
                created_dt = datetime.fromtimestamp(created_at.seconds)
            else:
                created_dt = datetime.fromisoformat(str(created_at).replace('Z', '+00:00')).replace(tzinfo=None)
            
            # Users who registered a month ago
            if created_dt <= month_ago:
                users_month_ago.append(user_doc.id)
                
                # Check if they're still active (logged in within last 30 days)
                if last_login:
                    if hasattr(last_login, 'seconds'):
                        last_login_dt = datetime.fromtimestamp(last_login.seconds)
                    else:
                        last_login_dt = datetime.fromisoformat(str(last_login).replace('Z', '+00:00')).replace(tzinfo=None)
                    
                    if last_login_dt >= month_ago:
                        users_still_active_month.append(user_doc.id)
        
        # Calculate retention rates
        retention_7_day = (len(users_still_active) / len(users_week_ago) * 100) if len(users_week_ago) > 0 else 0
        retention_30_day = (len(users_still_active_month) / len(users_month_ago) * 100) if len(users_month_ago) > 0 else 0
        
        return {
            'retention_7_day': round(retention_7_day, 2),
            'retention_30_day': round(retention_30_day, 2),
            'users_week_ago': len(users_week_ago),
            'users_still_active_week': len(users_still_active),
            'users_month_ago': len(users_month_ago),
            'users_still_active_month': len(users_still_active_month)
        }
        
    except Exception as e:
        app.logger.error(f"Error calculating retention metrics: {e}")
        return {
            'retention_7_day': 0,
            'retention_30_day': 0,
            'users_week_ago': 0,
            'users_still_active_week': 0,
            'users_month_ago': 0,
            'users_still_active_month': 0
        }

def calculate_churn_metrics():
    """Calculate churn rate metrics"""
    try:
        # Get cancelled subscriptions
        subscription_ref = db.collection('subscriptions')
        all_subscriptions = list(subscription_ref.stream())
        
        total_subscriptions = len(all_subscriptions)
        cancelled_subscriptions = len([sub for sub in all_subscriptions if sub.to_dict().get('cancelled', False)])
        active_subscriptions = len([sub for sub in all_subscriptions if sub.to_dict().get('status') == 'active'])
        
        # Calculate churn rate
        churn_rate = (cancelled_subscriptions / total_subscriptions * 100) if total_subscriptions > 0 else 0
        
        # Calculate monthly churn (subscriptions cancelled in last 30 days)
        now = datetime.now()
        month_ago = now - timedelta(days=30)
        recent_cancellations = 0
        
        for sub_doc in all_subscriptions:
            sub_data = sub_doc.to_dict()
            if sub_data.get('cancelled'):
                will_expire_at = sub_data.get('willExpireAt')
                if will_expire_at:
                    if hasattr(will_expire_at, 'seconds'):
                        expire_dt = datetime.fromtimestamp(will_expire_at.seconds)
                    else:
                        expire_dt = datetime.fromisoformat(str(will_expire_at).replace('Z', '+00:00')).replace(tzinfo=None)
                    
                    if expire_dt >= month_ago:
                        recent_cancellations += 1
        
        monthly_churn_rate = (recent_cancellations / active_subscriptions * 100) if active_subscriptions > 0 else 0
        
        return {
            'overall_churn_rate': round(churn_rate, 2),
            'monthly_churn_rate': round(monthly_churn_rate, 2),
            'total_cancellations': cancelled_subscriptions,
            'recent_cancellations': recent_cancellations
        }
        
    except Exception as e:
        app.logger.error(f"Error calculating churn metrics: {e}")
        return {
            'overall_churn_rate': 0,
            'monthly_churn_rate': 0,
            'total_cancellations': 0,
            'recent_cancellations': 0
        }

def calculate_subscription_health_metrics(subscriptions):
    """Calculate subscription growth and health metrics"""
    try:
        total_subscriptions = len(subscriptions)
        active_subscriptions = len([sub for sub in subscriptions if sub.to_dict().get('status') == 'active'])
        cancelled_subscriptions = len([sub for sub in subscriptions if sub.to_dict().get('cancelled', False)])
        
        # Calculate subscription health score (0-100)
        if total_subscriptions == 0:
            health_score = 0
        else:
            active_ratio = active_subscriptions / total_subscriptions
            health_score = active_ratio * 100
        
        # Calculate average subscription duration
        avg_duration = calculate_average_subscription_duration(subscriptions)
        
        # Calculate customer lifetime value (CLV)
        clv = avg_duration * 3.0  # $3/month * average months
        
        return {
            'total_subscriptions': total_subscriptions,
            'active_subscriptions': active_subscriptions,
            'cancelled_subscriptions': cancelled_subscriptions,
            'health_score': round(health_score, 2),
            'average_duration_months': round(avg_duration, 2),
            'customer_lifetime_value': round(clv, 2)
        }
        
    except Exception as e:
        app.logger.error(f"Error calculating subscription health metrics: {e}")
        return {
            'total_subscriptions': 0,
            'active_subscriptions': 0,
            'cancelled_subscriptions': 0,
            'health_score': 0,
            'average_duration_months': 0,
            'customer_lifetime_value': 0
        }

def calculate_average_subscription_duration(subscriptions):
    """Calculate average subscription duration in months"""
    try:
        total_duration = 0
        count = 0
        now = datetime.now()
        
        for sub_doc in subscriptions:
            sub_data = sub_doc.to_dict()
            start_date = sub_data.get('startDate')
            
            if not start_date:
                continue
            
            # Parse start date
            if hasattr(start_date, 'seconds'):
                start_dt = datetime.fromtimestamp(start_date.seconds)
            else:
                start_dt = datetime.fromisoformat(str(start_date).replace('Z', '+00:00')).replace(tzinfo=None)
            
            # Determine end date
            if sub_data.get('cancelled'):
                end_date = sub_data.get('willExpireAt')
                if end_date:
                    if hasattr(end_date, 'seconds'):
                        end_dt = datetime.fromtimestamp(end_date.seconds)
                    else:
                        end_dt = datetime.fromisoformat(str(end_date).replace('Z', '+00:00')).replace(tzinfo=None)
                else:
                    end_dt = now
            else:
                end_dt = now  # Still active
            
            # Calculate duration in months
            duration_months = (end_dt.year - start_dt.year) * 12 + end_dt.month - start_dt.month
            if duration_months <= 0:
                duration_months = 1  # At least 1 month
            
            total_duration += duration_months
            count += 1
        
        return total_duration / count if count > 0 else 0
        
    except Exception as e:
        app.logger.error(f"Error calculating average subscription duration: {e}")
        return 0

def calculate_subscription_growth_trends(subscriptions):
    """Calculate subscription growth trends over last 6 months"""
    try:
        now = datetime.now()
        trends = []
        
        for i in range(6):
            # Calculate month start and end
            month_date = now - timedelta(days=30 * i)
            month_start = month_date.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            
            if month_date.month == 12:
                next_month = month_date.replace(year=month_date.year + 1, month=1, day=1)
            else:
                next_month = month_date.replace(month=month_date.month + 1, day=1)
            
            month_end = next_month - timedelta(seconds=1)
            
            # Count new subscriptions in this month
            new_subscriptions = 0
            cancelled_in_month = 0
            
            for sub_doc in subscriptions:
                sub_data = sub_doc.to_dict()
                
                # Check for new subscriptions
                start_date = sub_data.get('startDate')
                if start_date:
                    if hasattr(start_date, 'seconds'):
                        start_dt = datetime.fromtimestamp(start_date.seconds)
                    else:
                        start_dt = datetime.fromisoformat(str(start_date).replace('Z', '+00:00')).replace(tzinfo=None)
                    
                    if month_start <= start_dt <= month_end:
                        new_subscriptions += 1
                
                # Check for cancellations
                if sub_data.get('cancelled'):
                    expire_date = sub_data.get('willExpireAt')
                    if expire_date:
                        if hasattr(expire_date, 'seconds'):
                            expire_dt = datetime.fromtimestamp(expire_date.seconds)
                        else:
                            expire_dt = datetime.fromisoformat(str(expire_date).replace('Z', '+00:00')).replace(tzinfo=None)
                        
                        if month_start <= expire_dt <= month_end:
                            cancelled_in_month += 1
            
            net_growth = new_subscriptions - cancelled_in_month
            
            trends.append({
                'month': month_date.strftime('%Y-%m'),
                'new_subscriptions': new_subscriptions,
                'cancelled_subscriptions': cancelled_in_month,
                'net_growth': net_growth
            })
        
        return list(reversed(trends))  # Return chronological order
        
    except Exception as e:
        app.logger.error(f"Error calculating subscription growth trends: {e}")
        return []

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)