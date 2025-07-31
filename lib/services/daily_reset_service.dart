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
      final now = DateTime.now().toUtc();
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

  /// Perform the actual daily reset operation
  static Future<void> _performDailyReset() async {
    try {
      _logger.info('Starting automated daily token limit reset');
      
      final resetTimestamp = DateTime.now().toUtc();
      final today = _getTodayString();
      final yesterday = _getYesterdayString();
      
      // Get all users who had usage yesterday
      final yesterdayQuery = await _firestore
          .collection('daily_token_usage')
          .where('date', isEqualTo: yesterday)
          .get();

      int processedUsers = 0;
      int newRecords = 0;
      int errors = 0;

      // Process each user from yesterday
      for (final doc in yesterdayQuery.docs) {
        try {
          final usage = DailyTokenUsage.fromFirestore(doc);
          await _resetUserTokens(usage.userId, today, resetTimestamp);
          processedUsers++;
          newRecords++;
        } catch (e) {
          _logger.warning('Failed to reset tokens for user in document ${doc.id}: $e');
          errors++;
        }
      }

      // Also check for any users who might have usage records from today already
      // (in case of timezone issues or manual testing)
      final todayQuery = await _firestore
          .collection('daily_token_usage')
          .where('date', isEqualTo: today)
          .get();

      for (final doc in todayQuery.docs) {
        try {
          final usage = DailyTokenUsage.fromFirestore(doc);
          // Only reset if the record is old (created before the reset time)
          if (usage.lastUpdated.isBefore(resetTimestamp.subtract(const Duration(minutes: 1)))) {
            await _resetUserTokens(usage.userId, today, resetTimestamp);
            processedUsers++;
          }
        } catch (e) {
          _logger.warning('Failed to reset existing today record for document ${doc.id}: $e');
          errors++;
        }
      }

      // Log reset completion
      _logger.info('Daily reset completed: $processedUsers users processed, $newRecords new records created, $errors errors');
      
      // Store reset metadata for monitoring
      await _storeResetMetadata(resetTimestamp, processedUsers, newRecords, errors);
      
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
      
      final documentId = '${userId}_$today';
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

  /// Store metadata about the reset operation for monitoring
  static Future<void> _storeResetMetadata(DateTime resetTimestamp, int processedUsers, int newRecords, int errors) async {
    try {
      final metadata = {
        'resetTimestamp': Timestamp.fromDate(resetTimestamp),
        'resetDate': _getTodayString(),
        'processedUsers': processedUsers,
        'newRecords': newRecords,
        'errors': errors,
        'timezone': AppConfig.resetTimezone,
        'resetHour': AppConfig.resetHour,
        'resetMinute': AppConfig.resetMinute,
        'nextScheduledReset': Timestamp.fromDate(_getNextResetTime()),
      };
      
      await _firestore
          .collection('daily_reset_logs')
          .doc(_getTodayString())
          .set(metadata);
      
      _logger.info('Reset metadata stored successfully');
    } catch (e) {
      _logger.warning('Failed to store reset metadata: $e');
      // Don't throw - this is not critical for the reset operation
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
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get yesterday's date string in YYYY-MM-DD format
  static String _getYesterdayString() {
    final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }
}