import 'package:logging/logging.dart';
import 'historical_usage_service.dart';

/// Service for handling monthly token usage aggregation
/// Provides methods for scheduled monthly data processing and migration
class MonthlyAggregationService {
  static final Logger _logger = Logger('MonthlyAggregationService');

  /// Perform monthly aggregation for the previous month
  /// This should be called at the beginning of each month (e.g., via cron job or scheduled task)
  static Future<Map<String, dynamic>> performMonthlyAggregation() async {
    try {
      final now = DateTime.now();
      final previousMonth = DateTime(now.year, now.month - 1, 1);
      final year = previousMonth.year;
      final month = previousMonth.month;

      _logger.info('Starting monthly aggregation for $year-$month');

      // Migrate all users' data for the previous month
      final migratedUsers = await HistoricalUsageService.migrateMonthlyDataForAllUsers(
        year: year,
        month: month,
      );

      // Calculate monthly statistics
      final statistics = await HistoricalUsageService.calculateMonthlyStatistics(
        year: year,
        month: month,
      );

      // Clean up old data (keep 12 months)
      final cleanedRecords = await HistoricalUsageService.cleanupOldHistoricalData(
        retentionMonths: 12,
      );

      final result = {
        'success': true,
        'year': year,
        'month': month,
        'migratedUsers': migratedUsers,
        'cleanedRecords': cleanedRecords,
        'statistics': statistics,
        'processedAt': DateTime.now().toIso8601String(),
      };

      _logger.info('Monthly aggregation completed successfully: $migratedUsers users processed');
      return result;
    } catch (e) {
      _logger.severe('Error during monthly aggregation: $e');
      return {
        'success': false,
        'error': e.toString(),
        'processedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Perform aggregation for a specific month (useful for backfilling historical data)
  static Future<Map<String, dynamic>> performAggregationForMonth({
    required int year,
    required int month,
  }) async {
    try {
      _logger.info('Starting aggregation for specific month: $year-$month');

      final migratedUsers = await HistoricalUsageService.migrateMonthlyDataForAllUsers(
        year: year,
        month: month,
      );

      final statistics = await HistoricalUsageService.calculateMonthlyStatistics(
        year: year,
        month: month,
      );

      final result = {
        'success': true,
        'year': year,
        'month': month,
        'migratedUsers': migratedUsers,
        'statistics': statistics,
        'processedAt': DateTime.now().toIso8601String(),
      };

      _logger.info('Aggregation for $year-$month completed: $migratedUsers users processed');
      return result;
    } catch (e) {
      _logger.severe('Error during aggregation for $year-$month: $e');
      return {
        'success': false,
        'error': e.toString(),
        'year': year,
        'month': month,
        'processedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Backfill historical data for the last N months
  /// Useful for initial setup or recovering missing historical data
  static Future<List<Map<String, dynamic>>> backfillHistoricalData({
    int months = 12,
  }) async {
    try {
      _logger.info('Starting historical data backfill for last $months months');

      final results = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (int i = 1; i <= months; i++) {
        final targetDate = DateTime(now.year, now.month - i, 1);
        final year = targetDate.year;
        final month = targetDate.month;

        // Skip future months
        if (targetDate.isAfter(now)) {
          continue;
        }

        _logger.info('Backfilling data for $year-$month');

        final result = await performAggregationForMonth(
          year: year,
          month: month,
        );

        results.add(result);

        // Add a small delay to avoid overwhelming the database
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _logger.info('Historical data backfill completed: ${results.length} months processed');
      return results;
    } catch (e) {
      _logger.severe('Error during historical data backfill: $e');
      return [];
    }
  }

  /// Get aggregation status for recent months
  /// Helps identify which months have been processed and which are missing
  static Future<List<Map<String, dynamic>>> getAggregationStatus({
    int months = 6,
  }) async {
    try {
      final now = DateTime.now();
      final status = <Map<String, dynamic>>[];

      for (int i = 1; i <= months; i++) {
        final targetDate = DateTime(now.year, now.month - i, 1);
        final year = targetDate.year;
        final month = targetDate.month;

        // Skip future months
        if (targetDate.isAfter(now)) {
          continue;
        }

        // Check if historical data exists for this month
        final monthlyData = await HistoricalUsageService.getMonthlyUsageForAllUsers(
          year: year,
          month: month,
        );

        final statistics = await HistoricalUsageService.calculateMonthlyStatistics(
          year: year,
          month: month,
        );

        status.add({
          'year': year,
          'month': month,
          'monthName': _getMonthName(month),
          'hasData': monthlyData.isNotEmpty,
          'userCount': monthlyData.length,
          'totalTokens': statistics['totalTokens'] ?? 0,
          'lastChecked': DateTime.now().toIso8601String(),
        });
      }

      return status;
    } catch (e) {
      _logger.severe('Error getting aggregation status: $e');
      return [];
    }
  }

  /// Helper method to get month name
  static String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}