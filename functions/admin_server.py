from flask import Flask, render_template, jsonify, request
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, firestore
import json
from datetime import datetime, timedelta
import os
import calendar

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

@app.route('/api/token-usage/monthly')
def get_monthly_token_usage():
    """Get monthly token usage statistics for all users"""
    try:
        # Get query parameters
        year = request.args.get('year', type=int)
        month = request.args.get('month', type=int)
        user_type = request.args.get('userType')
        
        # Default to current month if not specified
        if not year or not month:
            now = datetime.now()
            year = now.year
            month = now.month
        
        # Query token usage history collection
        query = db.collection('token_usage_history')
        query = query.where('year', '==', year)
        query = query.where('month', '==', month)
        
        if user_type:
            query = query.where('userType', '==', user_type)
        
        # Order by total tokens descending
        query = query.order_by('totalMonthlyTokens', direction=firestore.Query.DESCENDING)
        
        usage_docs = query.stream()
        usage_data = []
        
        total_tokens = 0
        trial_tokens = 0
        subscribed_tokens = 0
        trial_users = 0
        subscribed_users = 0
        
        for doc in usage_docs:
            data = doc.to_dict()
            usage_data.append({
                'userId': data.get('userId', ''),
                'totalTokens': data.get('totalMonthlyTokens', 0),
                'averageDailyTokens': round(data.get('averageDailyUsage', 0), 2),
                'activeDays': len([d for d in data.get('dailyUsage', {}).values() if d > 0]),
                'peakDayTokens': data.get('peakUsageTokens', 0),
                'peakDate': data.get('peakUsageDate', ''),
                'userType': data.get('userType', 'trial'),
                'monthName': calendar.month_name[month],
                'year': year
            })
            
            tokens = data.get('totalMonthlyTokens', 0)
            total_tokens += tokens
            
            if data.get('userType') == 'trial':
                trial_tokens += tokens
                trial_users += 1
            else:
                subscribed_tokens += tokens
                subscribed_users += 1
        
        # Calculate summary statistics
        total_users = len(usage_data)
        avg_tokens_per_user = round(total_tokens / total_users, 2) if total_users > 0 else 0
        
        return jsonify({
            'success': True,
            'month': month,
            'year': year,
            'monthName': calendar.month_name[month],
            'summary': {
                'totalUsers': total_users,
                'totalTokens': total_tokens,
                'averageTokensPerUser': avg_tokens_per_user,
                'trialUsers': trial_users,
                'subscribedUsers': subscribed_users,
                'trialTokens': trial_tokens,
                'subscribedTokens': subscribed_tokens
            },
            'userUsage': usage_data[:50]  # Limit to top 50 users
        })
        
    except Exception as e:
        print(f"Error in get_monthly_token_usage: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/token-usage/user/<user_id>')
def get_user_token_history(user_id):
    """Get token usage history for a specific user"""
    try:
        # Get query parameters
        months_limit = request.args.get('months', default=12, type=int)
        
        # Query user's historical usage
        query = db.collection('token_usage_history')
        query = query.where('userId', '==', user_id)
        query = query.order_by('year', direction=firestore.Query.DESCENDING)
        query = query.order_by('month', direction=firestore.Query.DESCENDING)
        query = query.limit(months_limit)
        
        history_docs = query.stream()
        history_data = []
        
        total_tokens = 0
        
        for doc in history_docs:
            data = doc.to_dict()
            month_tokens = data.get('totalMonthlyTokens', 0)
            total_tokens += month_tokens
            
            history_data.append({
                'year': data.get('year', 0),
                'month': data.get('month', 0),
                'monthName': calendar.month_name[data.get('month', 1)],
                'totalTokens': month_tokens,
                'averageDailyTokens': round(data.get('averageDailyUsage', 0), 2),
                'activeDays': len([d for d in data.get('dailyUsage', {}).values() if d > 0]),
                'peakDayTokens': data.get('peakUsageTokens', 0),
                'peakDate': data.get('peakUsageDate', ''),
                'userType': data.get('userType', 'trial'),
                'dailyBreakdown': data.get('dailyUsage', {})
            })
        
        # Calculate summary
        avg_monthly_tokens = round(total_tokens / len(history_data), 2) if history_data else 0
        peak_month = max(history_data, key=lambda x: x['totalTokens']) if history_data else None
        
        return jsonify({
            'success': True,
            'userId': user_id,
            'totalMonths': len(history_data),
            'totalTokens': total_tokens,
            'averageMonthlyTokens': avg_monthly_tokens,
            'peakMonth': f"{peak_month['monthName']} {peak_month['year']}" if peak_month else None,
            'peakMonthTokens': peak_month['totalTokens'] if peak_month else 0,
            'currentUserType': history_data[0]['userType'] if history_data else 'unknown',
            'monthlyHistory': history_data
        })
        
    except Exception as e:
        print(f"Error in get_user_token_history: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/token-usage/analytics')
def get_token_usage_analytics():
    """Get token usage analytics and insights for business decision making"""
    try:
        # Get current month data
        now = datetime.now()
        current_year = now.year
        current_month = now.month
        
        # Get previous month for comparison
        prev_month = current_month - 1 if current_month > 1 else 12
        prev_year = current_year if current_month > 1 else current_year - 1
        
        # Query current month data
        current_query = db.collection('token_usage_history')
        current_query = current_query.where('year', '==', current_year)
        current_query = current_query.where('month', '==', current_month)
        current_docs = list(current_query.stream())
        
        # Query previous month data
        prev_query = db.collection('token_usage_history')
        prev_query = prev_query.where('year', '==', prev_year)
        prev_query = prev_query.where('month', '==', prev_month)
        prev_docs = list(prev_query.stream())
        
        # Calculate current month metrics
        current_total_tokens = 0
        current_trial_tokens = 0
        current_subscribed_tokens = 0
        current_trial_users = 0
        current_subscribed_users = 0
        
        for doc in current_docs:
            data = doc.to_dict()
            tokens = data.get('totalMonthlyTokens', 0)
            current_total_tokens += tokens
            
            if data.get('userType') == 'trial':
                current_trial_tokens += tokens
                current_trial_users += 1
            else:
                current_subscribed_tokens += tokens
                current_subscribed_users += 1
        
        # Calculate previous month metrics
        prev_total_tokens = 0
        prev_trial_tokens = 0
        prev_subscribed_tokens = 0
        prev_trial_users = 0
        prev_subscribed_users = 0
        
        for doc in prev_docs:
            data = doc.to_dict()
            tokens = data.get('totalMonthlyTokens', 0)
            prev_total_tokens += tokens
            
            if data.get('userType') == 'trial':
                prev_trial_tokens += tokens
                prev_trial_users += 1
            else:
                prev_subscribed_tokens += tokens
                prev_subscribed_users += 1
        
        # Calculate growth rates
        token_growth = calculate_growth_rate(prev_total_tokens, current_total_tokens)
        user_growth = calculate_growth_rate(len(prev_docs), len(current_docs))
        trial_growth = calculate_growth_rate(prev_trial_users, current_trial_users)
        subscribed_growth = calculate_growth_rate(prev_subscribed_users, current_subscribed_users)
        
        # Calculate averages
        current_avg_per_user = round(current_total_tokens / len(current_docs), 2) if current_docs else 0
        prev_avg_per_user = round(prev_total_tokens / len(prev_docs), 2) if prev_docs else 0
        avg_growth = calculate_growth_rate(prev_avg_per_user, current_avg_per_user)
        
        # Get top users for current month
        top_users = []
        if current_docs:
            sorted_docs = sorted(current_docs, key=lambda x: x.to_dict().get('totalMonthlyTokens', 0), reverse=True)
            for doc in sorted_docs[:10]:
                data = doc.to_dict()
                top_users.append({
                    'userId': data.get('userId', ''),
                    'totalTokens': data.get('totalMonthlyTokens', 0),
                    'userType': data.get('userType', 'trial'),
                    'averageDailyTokens': round(data.get('averageDailyUsage', 0), 2)
                })
        
        # Calculate usage distribution
        usage_ranges = {
            'light': 0,    # 0-1000 tokens
            'moderate': 0, # 1001-5000 tokens
            'heavy': 0,    # 5001-15000 tokens
            'extreme': 0   # 15000+ tokens
        }
        
        for doc in current_docs:
            tokens = doc.to_dict().get('totalMonthlyTokens', 0)
            if tokens <= 1000:
                usage_ranges['light'] += 1
            elif tokens <= 5000:
                usage_ranges['moderate'] += 1
            elif tokens <= 15000:
                usage_ranges['heavy'] += 1
            else:
                usage_ranges['extreme'] += 1
        
        return jsonify({
            'success': True,
            'currentMonth': {
                'month': current_month,
                'year': current_year,
                'monthName': calendar.month_name[current_month],
                'totalTokens': current_total_tokens,
                'totalUsers': len(current_docs),
                'trialUsers': current_trial_users,
                'subscribedUsers': current_subscribed_users,
                'trialTokens': current_trial_tokens,
                'subscribedTokens': current_subscribed_tokens,
                'averagePerUser': current_avg_per_user
            },
            'previousMonth': {
                'month': prev_month,
                'year': prev_year,
                'monthName': calendar.month_name[prev_month],
                'totalTokens': prev_total_tokens,
                'totalUsers': len(prev_docs),
                'averagePerUser': prev_avg_per_user
            },
            'growth': {
                'tokenGrowth': token_growth,
                'userGrowth': user_growth,
                'trialUserGrowth': trial_growth,
                'subscribedUserGrowth': subscribed_growth,
                'averagePerUserGrowth': avg_growth
            },
            'topUsers': top_users,
            'usageDistribution': usage_ranges,
            'insights': generate_usage_insights(current_docs, prev_docs, token_growth, user_growth)
        })
        
    except Exception as e:
        print(f"Error in get_token_usage_analytics: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/token-usage/trends')
def get_token_usage_trends():
    """Get token usage trends over the last 6 months"""
    try:
        # Calculate date range for last 6 months
        now = datetime.now()
        trends_data = []
        
        for i in range(6):
            # Calculate month and year for each of the last 6 months
            target_date = now.replace(day=1) - timedelta(days=i * 30)
            target_year = target_date.year
            target_month = target_date.month
            
            # Query data for this month
            query = db.collection('token_usage_history')
            query = query.where('year', '==', target_year)
            query = query.where('month', '==', target_month)
            docs = list(query.stream())
            
            # Calculate metrics
            total_tokens = sum(doc.to_dict().get('totalMonthlyTokens', 0) for doc in docs)
            trial_tokens = sum(doc.to_dict().get('totalMonthlyTokens', 0) for doc in docs if doc.to_dict().get('userType') == 'trial')
            subscribed_tokens = sum(doc.to_dict().get('totalMonthlyTokens', 0) for doc in docs if doc.to_dict().get('userType') == 'subscribed')
            
            trends_data.append({
                'year': target_year,
                'month': target_month,
                'monthName': calendar.month_name[target_month],
                'totalTokens': total_tokens,
                'totalUsers': len(docs),
                'trialTokens': trial_tokens,
                'subscribedTokens': subscribed_tokens,
                'averagePerUser': round(total_tokens / len(docs), 2) if docs else 0
            })
        
        # Reverse to get chronological order (oldest to newest)
        trends_data.reverse()
        
        return jsonify({
            'success': True,
            'trends': trends_data,
            'totalMonths': len(trends_data)
        })
        
    except Exception as e:
        print(f"Error in get_token_usage_trends: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

def calculate_growth_rate(previous, current):
    """Calculate growth rate percentage"""
    if previous == 0:
        return 100.0 if current > 0 else 0.0
    return round(((current - previous) / previous) * 100, 2)

def generate_usage_insights(current_docs, prev_docs, token_growth, user_growth):
    """Generate business insights from usage data"""
    insights = []
    
    # Token growth insight
    if token_growth > 20:
        insights.append({
            'type': 'positive',
            'title': 'Strong Token Usage Growth',
            'message': f'Token usage increased by {token_growth}% this month, indicating high user engagement.'
        })
    elif token_growth < -10:
        insights.append({
            'type': 'warning',
            'title': 'Declining Token Usage',
            'message': f'Token usage decreased by {abs(token_growth)}% this month. Consider user engagement strategies.'
        })
    
    # User growth vs token growth
    if token_growth > user_growth + 10:
        insights.append({
            'type': 'positive',
            'title': 'Increased User Engagement',
            'message': 'Existing users are using more tokens per person, showing higher engagement.'
        })
    elif user_growth > token_growth + 10:
        insights.append({
            'type': 'info',
            'title': 'New User Acquisition',
            'message': 'Growing user base but lower per-user usage. Focus on user activation.'
        })
    
    # Heavy users analysis
    if current_docs:
        heavy_users = [doc for doc in current_docs if doc.to_dict().get('totalMonthlyTokens', 0) > 15000]
        if len(heavy_users) > len(current_docs) * 0.1:  # More than 10% are heavy users
            insights.append({
                'type': 'info',
                'title': 'High Power User Concentration',
                'message': f'{len(heavy_users)} users ({round(len(heavy_users)/len(current_docs)*100, 1)}%) are heavy users (15K+ tokens).'
            })
    
    return insights

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(debug=True, host='0.0.0.0', port=port)