import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/services/daily_reset_service.dart';
import 'package:kapwa_companion_basic/models/daily_token_usage.dart';

void main() {
  group('DailyResetService', () {
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

    group('Service Lifecycle', () {
      test('should start and stop service correctly', () {
        expect(DailyResetService.isRunning, false);
        
        DailyResetService.startService();
        expect(DailyResetService.isRunning, true);
        
        DailyResetService.stopService();
        expect(DailyResetService.isRunning, false);
      });

      test('should not start service twice', () {
        DailyResetService.startService();
        expect(DailyResetService.isRunning, true);
        
        // Starting again should not cause issues
        DailyResetService.startService();
        expect(DailyResetService.isRunning, true);
        
        DailyResetService.stopService();
      });

      test('should handle stopping service when not running', () {
        expect(DailyResetService.isRunning, false);
        
        // Should not throw error
        DailyResetService.stopService();
        expect(DailyResetService.isRunning, false);
      });
    });

    group('Manual Reset', () {
      test('should store reset metadata after manual reset', () async {
        final today = _getTodayString();
        
        // Perform manual reset (will process zero users but should still create metadata)
        await DailyResetService.performManualReset();

        // Verify reset metadata was stored
        final metadataDoc = await fakeFirestore
            .collection('daily_reset_logs')
            .doc(today)
            .get();
        
        expect(metadataDoc.exists, true);
        final metadata = metadataDoc.data()!;
        expect(metadata['resetDate'], today);
        expect(metadata['processedUsers'], 0);
        expect(metadata['newRecords'], 0);
        expect(metadata['errors'], 0);
        expect(metadata['timezone'], 'UTC');
        expect(metadata['resetHour'], 0);
        expect(metadata['resetMinute'], 0);
      });


    });



    group('Timezone Handling', () {
      test('should use UTC for date calculations', () {
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

