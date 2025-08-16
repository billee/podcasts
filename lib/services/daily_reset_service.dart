import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import '../core/config.dart';
import '../models/daily_token_usage.dart';
import 'subscription_service.dart';

/// Service for managing automated daily token limit resets
/// Handles timezone-aware reset scheduling and database updates
class DailyResetService {
  static final Logger _logger = Logger('DailyResetService');
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Timer? _resetTimer;
  static bool _isRunning = false;

  // For testing purposes - allow dependency injection
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }

  /// Start the daily reset service
  /// Schedules the next reset and sets up recurring timer
  static void startService() {
    if (_isRunning) {
      _logger.info('Daily reset service is already running');
      return;
    }

    _logger.info('Starting daily reset service');
    _isRunning = true;
    _scheduleNextReset();
  }

  /// Stop the daily reset service
  /// Cancels any scheduled resets
  static void stopService() {
    if (!_isRunning) {
      _logger.info('Daily reset service is not running');
      return;
    }

    _logger.info('Stopping daily reset service');
    _resetTimer?.cancel();
    _resetTimer = null;
    _isRunning = false;
  }

  /// Check if the service is currently running
  static bool get isRunning => _isRunning;

  /// Schedule the next daily reset based on timezone configuration
  static void _scheduleNextReset() {
    try {
      final nextResetTime = _getNextResetTime();
      final now = AppConfig.currentDateTimeUtc;
      final duration = nextResetTime.difference(now);

      _logger.info('Next reset scheduled for: ${nextResetTime.toIso8601String()} (in ${duration.inHours}h ${duration.inMinutes % 60}m)');

      _resetTimer = Timer(duration, () {
        _performDailyReset().then((_) {
          // Schedule the next reset after this one completes
          _scheduleNextReset();
        }).catchError((error) {
          _logger.severe('Error during scheduled reset: $error');
          // Still schedule the next reset even if this one failed
          _scheduleNextReset();
        });
      });
    } catch (e) {
      _logger.severe('Error scheduling next reset: $e');
      // Retry scheduling in 1 hour if there's an error
      _resetTimer = Timer(const Duration(hours: 1), () {
        _scheduleNextReset();
      });
    }
  }

  /// Get the next reset time based on timezone configuration
  /// Reset happens at 24:00 (midnight) in the user's local timezone
  static DateTime _getNextResetTime() {
    final now = AppConfig.currentDateTime; // Use local time instead of UTC
    
    // Calculate next reset time in local timezone (24:00 = midnight)
    DateTime nextReset = DateTime(
      now.year,
      now.month,
      now.day,
      24, // 24:00 military time (midnight of next day)
      0,  // 0 minutes
    );
    
    // If we're already past midnight today, the next reset is tomorrow at 24:00
    // Note: DateTime(year, month, day, 24, 0) automatically becomes next day at 00:00
    if (nextReset.isBefore(now) || nextReset.isAtSameMomentAs(now)) {
      nextReset = nextReset.add(const Duration(days: 1));
    }
    
    // Convert to UTC for storage in Firestore
    return nextReset.toUtc();
  }

  /// Perform the actual daily reset operation
  static Future<void> _performDailyReset() async {
    try {
      _logger.info('Starting automated daily token limit reset');
      
      final resetTimestamp = AppConfig.currentDateTimeUtc;
      final today = _getTodayString();
      
      // Get all token usage documents (now one per user)
      final allUsageQuery = await _firestore
          .collection('daily_token_usage')
          .get();

      int processedUsers = 0;
      int newRecords = 0;
      int errors = 0;

      // Process each user's document
      for (final doc in allUsageQuery.docs) {
        try {
          final usage = DailyTokenUsage.fromFirestore(doc);
          
          // Only reset if the document is from a previous day
          if (usage.date != today) {
            await _resetUserTokens(usage.userId, today, resetTimestamp);
            processedUsers++;
            newRecords++;
            _logger.fine('Reset user ${usage.userId} from ${usage.date} to $today');
          } else {
            _logger.fine('User ${usage.userId} already has today\'s record, skipping');
          }
        } catch (e) {
          _logger.warning('Failed to reset tokens for user in document ${doc.id}: $e');
          errors++;
        }
      }

      // Log reset completion
      _logger.info('Daily reset completed: $processedUsers users processed, $newRecords new records created, $errors errors');
      
      // Reset metadata logging removed - no longer needed
      
    } catch (e) {
      _logger.severe('Critical error during daily reset: $e');
      throw e;
    }
  }

  /// Reset tokens for a specific user
  static Future<void> _resetUserTokens(String userId, String today, DateTime resetTimestamp) async {
    try {
      // Get current user type and token limit
      final userType = await _getUserType(userId);
      final tokenLimit = _getTokenLimitForUserType(userType);
      final nextResetTime = _getNextResetTime();
      
      // Create new daily usage record with zero tokens
      final newUsage = DailyTokenUsage(
        userId: userId,
        date: today,
        tokensUsed: 0,
        tokenLimit: tokenLimit,
        userType: userType,
        lastUpdated: resetTimestamp,
        resetAt: nextResetTime,
      );
      
      final documentId = userId; // Use userId as document ID
      await _firestore
          .collection('daily_token_usage')
          .doc(documentId)
          .set(newUsage.toFirestore(), SetOptions(merge: false));
      
      _logger.fine('Reset tokens for user $userId: limit=$tokenLimit, type=$userType');
    } catch (e) {
      _logger.warning('Error resetting tokens for user $userId: $e');
      throw e;
    }
  }



  /// Manual reset trigger for testing or emergency use
  static Future<void> performManualReset() async {
    _logger.info('Performing manual daily reset');
    await _performDailyReset();
  }

  /// Get user type based on subscription status
  static Future<String> _getUserType(String userId) async {
    try {
      final subscriptionStatus = await SubscriptionService.getSubscriptionStatus(userId);
      
      switch (subscriptionStatus) {
        case SubscriptionStatus.active:
        case SubscriptionStatus.cancelled:
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

  /// Get today's date string in YYYY-MM-DD format
  static String _getTodayString() {
    final now = AppConfig.currentDateTime; // Use local time instead of UTC
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get yesterday's date string in YYYY-MM-DD format
  static String _getYesterdayString() {
    final yesterday = AppConfig.currentDateTime.subtract(const Duration(days: 1)); // Use local time instead of UTC
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }
}