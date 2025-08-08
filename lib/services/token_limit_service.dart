import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import '../core/config.dart';
import '../models/daily_token_usage.dart';
import '../models/token_usage_info.dart';
import 'subscription_service.dart';
import 'historical_usage_service.dart';

/// Service for managing daily token limits and usage tracking
/// Handles token limit enforcement, usage recording, and real-time monitoring
class TokenLimitService {
  static final Logger _logger = Logger('TokenLimitService');
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // For testing purposes - allow dependency injection
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }

  /// Check if user can send chat messages based on their daily token limit
  /// Returns true if user has remaining tokens, false if limit is reached
  static Future<bool> canUserChat(String userId) async {
    try {
      // Check if token limits are enabled
      if (!AppConfig.tokenLimitsEnabled) {
        return true;
      }

      final usageInfo = await getUserUsageInfo(userId);
      return !usageInfo.isLimitReached;
    } catch (e) {
      _logger.severe('Error checking if user can chat: $e');
      // On error, allow chat to prevent blocking users due to system issues
      return true;
    }
  }

  /// Get remaining tokens for the current day
  /// Returns the number of tokens remaining in the user's daily limit
  static Future<int> getRemainingTokens(String userId) async {
    try {
      final usageInfo = await getUserUsageInfo(userId);
      return usageInfo.remainingTokens;
    } catch (e) {
      _logger.severe('Error getting remaining tokens: $e');
      // On error, return a conservative estimate
      return 0;
    }
  }

  /// Record token usage for a user's message
  /// Updates the daily usage count and creates/updates the usage record
  static Future<void> recordTokenUsage(String userId, int tokenCount) async {
    try {
      if (!AppConfig.tokenLimitsEnabled || tokenCount <= 0) {
        return;
      }

      final today = _getTodayString();
      final documentId = '${userId}_$today';
      final docRef = _firestore.collection('daily_token_usage').doc(documentId);

      // Get current usage or create new record
      final doc = await docRef.get();
      
      if (doc.exists) {
        // Update existing record
        final currentUsage = DailyTokenUsage.fromFirestore(doc);
        final newTokensUsed = currentUsage.tokensUsed + tokenCount;
        
        await docRef.update({
          'tokensUsed': newTokensUsed,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        _logger.info('Updated token usage for user $userId: $tokenCount tokens added (total: $newTokensUsed)');
        
        // Update historical data for current month
        final updatedUsage = currentUsage.copyWith(
          tokensUsed: newTokensUsed,
          lastUpdated: DateTime.now(),
        );
        await HistoricalUsageService.updateCurrentMonthHistory(
          userId: userId,
          dailyUsage: updatedUsage,
        );
      } else {
        // Create new record for today
        final userType = await _getUserType(userId);
        final tokenLimit = _getTokenLimitForUserType(userType);
        final resetTime = _getNextResetTime();
        
        final newUsage = DailyTokenUsage(
          userId: userId,
          date: today,
          tokensUsed: tokenCount,
          tokenLimit: tokenLimit,
          userType: userType,
          lastUpdated: DateTime.now(),
          resetAt: resetTime,
        );
        
        await docRef.set(newUsage.toFirestore());
        
        _logger.info('Created new token usage record for user $userId: $tokenCount tokens (limit: $tokenLimit)');
        
        // Update historical data for current month
        await HistoricalUsageService.updateCurrentMonthHistory(
          userId: userId,
          dailyUsage: newUsage,
        );
      }
    } catch (e) {
      _logger.severe('Error recording token usage: $e');
      // Don't throw error to prevent blocking chat functionality
    }
  }

  /// Get comprehensive usage information for a user
  /// Returns TokenUsageInfo with current usage, limits, and status
  static Future<TokenUsageInfo> getUserUsageInfo(String userId) async {
    try {
      final today = _getTodayString();
      final documentId = '${userId}_$today';
      final doc = await _firestore.collection('daily_token_usage').doc(documentId).get();
      
      final userType = await _getUserType(userId);
      final tokenLimit = _getTokenLimitForUserType(userType);
      final resetTime = _getNextResetTime();
      
      if (doc.exists) {
        // Return existing usage info
        final usage = DailyTokenUsage.fromFirestore(doc);
        return TokenUsageInfo.fromDailyUsage(
          userId: userId,
          tokensUsed: usage.tokensUsed,
          tokenLimit: tokenLimit,
          userType: userType,
          resetTime: resetTime,
        );
      } else {
        // Return empty usage info for new day
        return TokenUsageInfo.empty(
          userId: userId,
          tokenLimit: tokenLimit,
          userType: userType,
          resetTime: resetTime,
        );
      }
    } catch (e) {
      _logger.severe('Error getting user usage info: $e');
      // Return conservative fallback
      return TokenUsageInfo.empty(
        userId: userId,
        tokenLimit: 0,
        userType: 'trial',
        resetTime: _getNextResetTime(),
      );
    }
  }

  /// Watch user usage changes in real-time
  /// Returns a stream of TokenUsageInfo updates
  static Stream<TokenUsageInfo> watchUserUsage(String userId) {
    try {
      final today = _getTodayString();
      final documentId = '${userId}_$today';
      
      return _firestore
          .collection('daily_token_usage')
          .doc(documentId)
          .snapshots()
          .asyncMap((snapshot) async {
            final userType = await _getUserType(userId);
            final tokenLimit = _getTokenLimitForUserType(userType);
            final resetTime = _getNextResetTime();
            
            if (snapshot.exists) {
              final usage = DailyTokenUsage.fromFirestore(snapshot);
              return TokenUsageInfo.fromDailyUsage(
                userId: userId,
                tokensUsed: usage.tokensUsed,
                tokenLimit: tokenLimit,
                userType: userType,
                resetTime: resetTime,
              );
            } else {
              return TokenUsageInfo.empty(
                userId: userId,
                tokenLimit: tokenLimit,
                userType: userType,
                resetTime: resetTime,
              );
            }
          });
    } catch (e) {
      _logger.severe('Error watching user usage: $e');
      // Return empty stream on error
      return Stream.empty();
    }
  }

  /// Reset daily limits for all users (called by daily reset mechanism)
  /// This method is intended to be called by a scheduled task
  /// @deprecated Use DailyResetService.performManualReset() instead
  static Future<void> resetDailyLimits() async {
    _logger.warning('resetDailyLimits() is deprecated. Use DailyResetService.performManualReset() instead.');
    
    // Import the new service dynamically to avoid circular dependencies
    try {
      // For backward compatibility, we'll implement a simple reset here
      // But recommend using the new DailyResetService for production
      final today = _getTodayString();
      final yesterday = _getYesterdayString();
      final resetTimestamp = DateTime.now().toUtc();
      
      // Query all usage records from yesterday
      final yesterdayUsage = await _firestore
          .collection('daily_token_usage')
          .where('date', isEqualTo: yesterday)
          .get();
      
      int resetCount = 0;
      
      // Process each user's usage from yesterday
      for (final doc in yesterdayUsage.docs) {
        try {
          final usage = DailyTokenUsage.fromFirestore(doc);
          
          // Create today's record with zero usage
          final userType = await _getUserType(usage.userId);
          final tokenLimit = _getTokenLimitForUserType(userType);
          final resetTime = _getNextResetTime();
          
          final todayUsage = DailyTokenUsage(
            userId: usage.userId,
            date: today,
            tokensUsed: 0,
            tokenLimit: tokenLimit,
            userType: userType,
            lastUpdated: resetTimestamp,
            resetAt: resetTime,
          );
          
          final todayDocId = '${usage.userId}_$today';
          await _firestore
              .collection('daily_token_usage')
              .doc(todayDocId)
              .set(todayUsage.toFirestore());
          
          resetCount++;
        } catch (e) {
          _logger.warning('Error resetting usage for document ${doc.id}: $e');
        }
      }
      
      _logger.info('Daily token limit reset completed: $resetCount users processed');
    } catch (e) {
      _logger.severe('Error during daily reset: $e');
    }
  }

  // Private helper methods

  /// Get user type based on subscription status
  static Future<String> _getUserType(String userId) async {
    try {
      final subscriptionStatus = await SubscriptionService.getSubscriptionStatus(userId);
      
      switch (subscriptionStatus) {
        case SubscriptionStatus.active:
        case SubscriptionStatus.cancelled: // Cancelled users keep subscribed limits until expiration
          return 'subscribed';
        case SubscriptionStatus.trial:
        case SubscriptionStatus.trialExpired:
        case SubscriptionStatus.expired:
          return 'trial';
      }
    } catch (e) {
      _logger.warning('Error determining user type for $userId: $e');
      return 'trial'; // Default to trial on error
    }
  }

  /// Get token limit based on user type
  static int _getTokenLimitForUserType(String userType) {
    switch (userType) {
      case 'subscribed':
        return AppConfig.subscribedUserDailyTokenLimit;
      case 'trial':
      default:
        return AppConfig.trialUserDailyTokenLimit;
    }
  }

  /// Get today's date string in YYYY-MM-DD format (timezone-aware)
  static String _getTodayString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get yesterday's date string in YYYY-MM-DD format (timezone-aware)
  static String _getYesterdayString() {
    final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }

  /// Get next reset time based on timezone configuration
  static DateTime _getNextResetTime() {
    final now = DateTime.now().toUtc();
    
    // Calculate next reset time in UTC
    var nextReset = DateTime.utc(
      now.year,
      now.month,
      now.day,
      AppConfig.resetHour,
      AppConfig.resetMinute,
    );

    // If the reset time for today has already passed, schedule for tomorrow
    if (nextReset.isBefore(now) || nextReset.isAtSameMomentAs(now)) {
      nextReset = nextReset.add(const Duration(days: 1));
    }

    return nextReset;
  }
}