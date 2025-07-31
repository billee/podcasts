import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/services/daily_reset_service.dart';
import 'package:kapwa_companion_basic/models/daily_token_usage.dart';

void main() {
  group('Daily Reset Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      DailyResetService.setFirestoreInstance(fakeFirestore);
      
      // Disable logging during tests
      Logger.root.level = Level.OFF;
    });

    tearDown(() {
      DailyResetService.stopService();
    });

    test('should create reset logs with proper structure', () async {
      const userId = 'test_user_1';
      
      // Simulate user activity yesterday
      final yesterday = _getYesterdayString();
      final today = _getTodayString();
      
      await fakeFirestore
          .collection('daily_token_usage')
          .doc('${userId}_$yesterday')
          .set({
        'userId': userId,
        'date': yesterday,
        'tokensUsed': 8000,
        'tokenLimit': 10000,
        'userType': 'trial',
        'lastUpdated': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
        'resetAt': Timestamp.fromDate(DateTime.now()),
      });

      // Perform daily reset
      await DailyResetService.performManualReset();

      // Verify reset log was created
      final logDoc = await fakeFirestore
          .collection('daily_reset_logs')
          .doc(today)
          .get();
      
      expect(logDoc.exists, true);
      final logData = logDoc.data()!;
      
      expect(logData['resetDate'], today);
      expect(logData['timezone'], 'UTC');
      expect(logData['resetHour'], 0);
      expect(logData['resetMinute'], 0);
      
      // Verify timestamps exist
      expect(logData['resetTimestamp'], isA<Timestamp>());
      expect(logData['nextScheduledReset'], isA<Timestamp>());
    });

    test('should handle timezone calculations correctly', () async {
      final today = _getTodayString();
      final yesterday = _getYesterdayString();
      
      // Verify dates are in YYYY-MM-DD format
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(today), true);
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(yesterday), true);
      
      // Verify yesterday is actually one day before today
      final todayDate = DateTime.parse(today);
      final yesterdayDate = DateTime.parse(yesterday);
      expect(todayDate.difference(yesterdayDate).inDays, 1);
    });
  });
}



/// Helper function to get today's date string in YYYY-MM-DD format
String _getTodayString() {
  final now = DateTime.now().toUtc();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Helper function to get yesterday's date string in YYYY-MM-DD format
String _getYesterdayString() {
  final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
  return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
}