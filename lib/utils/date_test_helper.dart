import '../core/config.dart';

/// Helper class for testing date-dependent functionality
/// Allows setting override dates to test different scenarios
class DateTestHelper {
  /// Set a specific date for testing
  /// Example: DateTestHelper.setTestDate(DateTime(2025, 8, 15))
  static void setTestDate(DateTime date) {
    AppConfig.setOverrideDate(date);
  }
  
  /// Reset to use real time
  static void useRealTime() {
    AppConfig.setOverrideDate(null);
  }
  
  /// Advance the current test date by specified days
  static void advanceDays(int days) {
    final currentDate = AppConfig.overrideDate ?? DateTime.now();
    AppConfig.setOverrideDate(currentDate.add(Duration(days: days)));
  }
  
  /// Advance the current test date by specified hours
  static void advanceHours(int hours) {
    final currentDate = AppConfig.overrideDate ?? DateTime.now();
    AppConfig.setOverrideDate(currentDate.add(Duration(hours: hours)));
  }
  
  /// Get the current effective date (override or real)
  static DateTime getCurrentDate() {
    return AppConfig.currentDateTime;
  }
  
  /// Check if we're using override date
  static bool isUsingOverrideDate() {
    return AppConfig.overrideDate != null;
  }
  
  /// Get a formatted string of the current date for debugging
  static String getCurrentDateString() {
    final date = AppConfig.currentDateTime;
    final isOverride = AppConfig.overrideDate != null;
    return '${date.toString()} ${isOverride ? '(TEST)' : '(REAL)'}';
  }
}