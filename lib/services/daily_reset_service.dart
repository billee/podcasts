import 'dart:async';
import 'package:logging/logging.dart';
import '../core/config.dart';

/// Simple daily timer service that can be used for scheduling tasks
class DailyResetService {
  static final Logger _logger = Logger('DailyResetService');
  static Timer? _resetTimer;
  static bool _isRunning = false;

  /// Start the daily timer service
  static void startService() {
    if (_isRunning) {
      _logger.info('Daily timer service is already running');
      return;
    }

    _logger.info('Starting daily timer service');
    _isRunning = true;
    _scheduleNextReset();
  }

  /// Stop the daily timer service
  static void stopService() {
    if (!_isRunning) {
      _logger.info('Daily timer service is not running');
      return;
    }

    _logger.info('Stopping daily timer service');
    _resetTimer?.cancel();
    _resetTimer = null;
    _isRunning = false;
  }

  /// Check if the service is currently running
  static bool get isRunning => _isRunning;

  /// Schedule the next daily timer
  static void _scheduleNextReset() {
    try {
      final nextResetTime = _getNextResetTime();
      final now = AppConfig.currentDateTimeUtc;
      final duration = nextResetTime.difference(now);

      _logger.info(
          'Next reset scheduled for: ${nextResetTime.toIso8601String()} (in ${duration.inHours}h ${duration.inMinutes % 60}m)');

      _resetTimer = Timer(duration, () {
        _performDailyReset().then((_) {
          _scheduleNextReset();
        }).catchError((error) {
          _logger.severe('Error during scheduled tasks: $error');
          _scheduleNextReset();
        });
      });
    } catch (e) {
      _logger.severe('Error scheduling next task: $e');
      // Retry in 1 hour if there's an error
      _resetTimer = Timer(const Duration(hours: 1), () {
        _scheduleNextReset();
      });
    }
  }

  /// Get the next reset time (midnight)
  static DateTime _getNextResetTime() {
    final now = AppConfig.currentDateTime;
    DateTime nextReset = DateTime(
      now.year,
      now.month,
      now.day,
      24, // 24:00 (midnight of next day)
      0,
    );

    if (nextReset.isBefore(now) || nextReset.isAtSameMomentAs(now)) {
      nextReset = nextReset.add(const Duration(days: 1));
    }

    return nextReset.toUtc();
  }

  /// Perform any scheduled daily tasks
  static Future<void> _performDailyReset() async {
    try {
      _logger.info('Running daily tasks');
      // No tasks needed anymore
    } catch (e) {
      _logger.severe('Error in daily tasks: $e');
      throw e;
    }
  }
}
