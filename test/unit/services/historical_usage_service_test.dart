import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kapwa_companion_basic/services/historical_usage_service.dart';
import 'package:kapwa_companion_basic/models/daily_token_usage.dart';
import 'package:kapwa_companion_basic/models/token_usage_history.dart';

void main() {
  group('HistoricalUsageService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      HistoricalUsageService.setFirestoreInstance(fakeFirestore);
    });

    group('aggregateMonthlyUsage', () {
      test('should aggregate daily usage into monthly history', () async {
        // Setup: Create daily usage records for January 2024
        final userId = 'user123';
        final year = 2024;
        final month = 1;

        // Create daily usage records
        final dailyRecords = [
          DailyTokenUsage(
            userId: userId,
            date: '2024-01-01',
            tokensUsed: 100,
            tokenLimit: 1000,
            userType: 'trial',
            lastUpdated: DateTime.now(),
            resetAt: DateTime.now().add(const Duration(days: 1)),
          ),
          DailyTokenUsage(
            userId: userId,
            date: '2024-01-02',
            tokensUsed: 200,
            tokenLimit: 1000,
            userType: 'trial',
            lastUpdated: DateTime.now(),
            resetAt: DateTime.now().add(const Duration(days: 1)),
          ),
          DailyTokenUsage(
            userId: userId,
            date: '2024-01-03',
            tokensUsed: 150,
            tokenLimit: 1000,
            userType: 'trial',
            lastUpdated: DateTime.now(),
            resetAt: DateTime.now().add(const Duration(days: 1)),
          ),
        ];

        // Save daily records to Firestore
        for (final record in dailyRecords) {
          await fakeFirestore
              .collection('daily_token_usage')
              .doc(record.documentId)
              .set(record.toFirestore());
        }

        // Test: Aggregate monthly usage
        final result = await HistoricalUsageService.aggregateMonthlyUsage(
          userId: userId,
          year: year,
          month: month,
        );

        // Verify: Result should not be null
        expect(result, isNotNull);
        expect(result!.userId, equals(userId));
        expect(result.year, equals(year));
        expect(result.month, equals(month));
        expect(result.totalMonthlyTokens, equals(450)); // 100 + 200 + 150
        expect(result.averageDailyUsage, equals(150.0)); // 450 / 3
        expect(result.userType, equals('trial'));
        expect(result.peakUsageTokens, equals(200));
        expect(result.peakUsageDate, equals('02'));

        // Verify: Historical record should be saved to Firestore
        final historyDoc = await fakeFirestore
            .collection('token_usage_history')
            .doc(result.documentId)
            .get();
        
        expect(historyDoc.exists, isTrue);
        final savedHistory = TokenUsageHistory.fromFirestore(historyDoc);
        expect(savedHistory.totalMonthlyTokens, equals(450));
      });

      test('should return null when no daily records exist', () async {
        final result = await HistoricalUsageService.aggregateMonthlyUsage(
          userId: 'nonexistent',
          year: 2024,
          month: 1,
        );

        expect(result, isNull);
      });
    });

    group('migrateMonthlyDataForAllUsers', () {
      test('should migrate data for all users in a month', () async {
        // Setup: Create daily usage records for multiple users
        final users = ['user1', 'user2', 'user3'];
        final year = 2024;
        final month = 1;

        for (final userId in users) {
          final dailyRecord = DailyTokenUsage(
            userId: userId,
            date: '2024-01-15',
            tokensUsed: 100,
            tokenLimit: 1000,
            userType: 'trial',
            lastUpdated: DateTime.now(),
            resetAt: DateTime.now().add(const Duration(days: 1)),
          );

          await fakeFirestore
              .collection('daily_token_usage')
              .doc(dailyRecord.documentId)
              .set(dailyRecord.toFirestore());
        }

        // Test: Migrate monthly data for all users
        final migratedCount = await HistoricalUsageService.migrateMonthlyDataForAllUsers(
          year: year,
          month: month,
        );

        // Verify: All users should be migrated
        expect(migratedCount, equals(3));

        // Verify: Historical records should exist for all users
        for (final userId in users) {
          final historyDocId = '${userId}_2024_01';
          final historyDoc = await fakeFirestore
              .collection('token_usage_history')
              .doc(historyDocId)
              .get();
          
          expect(historyDoc.exists, isTrue);
        }
      });
    });

    group('getUserHistoricalUsage', () {
      test('should return user historical usage ordered by date', () async {
        final userId = 'user123';

        // Setup: Create historical records for multiple months
        final historyRecords = [
          TokenUsageHistory(
            userId: userId,
            year: 2024,
            month: 1,
            dailyUsage: {'01': 100, '02': 200},
            totalMonthlyTokens: 300,
            averageDailyUsage: 150.0,
            peakUsageDate: '02',
            peakUsageTokens: 200,
            userType: 'trial',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          TokenUsageHistory(
            userId: userId,
            year: 2024,
            month: 2,
            dailyUsage: {'01': 150, '02': 250},
            totalMonthlyTokens: 400,
            averageDailyUsage: 200.0,
            peakUsageDate: '02',
            peakUsageTokens: 250,
            userType: 'trial',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Save historical records
        for (final record in historyRecords) {
          await fakeFirestore
              .collection('token_usage_history')
              .doc(record.documentId)
              .set(record.toFirestore());
        }

        // Test: Get user historical usage
        final result = await HistoricalUsageService.getUserHistoricalUsage(
          userId: userId,
        );

        // Verify: Should return records ordered by date (most recent first)
        expect(result.length, equals(2));
        expect(result[0].month, equals(2)); // February should be first
        expect(result[1].month, equals(1)); // January should be second
      });

      test('should limit results when limitMonths is specified', () async {
        final userId = 'user123';

        // Setup: Create 3 historical records
        for (int month = 1; month <= 3; month++) {
          final record = TokenUsageHistory(
            userId: userId,
            year: 2024,
            month: month,
            dailyUsage: {'01': 100},
            totalMonthlyTokens: 100,
            averageDailyUsage: 100.0,
            peakUsageDate: '01',
            peakUsageTokens: 100,
            userType: 'trial',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await fakeFirestore
              .collection('token_usage_history')
              .doc(record.documentId)
              .set(record.toFirestore());
        }

        // Test: Get limited results
        final result = await HistoricalUsageService.getUserHistoricalUsage(
          userId: userId,
          limitMonths: 2,
        );

        // Verify: Should return only 2 records
        expect(result.length, equals(2));
      });
    });

    group('calculateMonthlyStatistics', () {
      test('should calculate correct monthly statistics', () async {
        final year = 2024;
        final month = 1;

        // Setup: Create historical records for multiple users
        final historyRecords = [
          TokenUsageHistory(
            userId: 'trial_user1',
            year: year,
            month: month,
            dailyUsage: {'01': 100, '02': 200},
            totalMonthlyTokens: 300,
            averageDailyUsage: 150.0,
            peakUsageDate: '02',
            peakUsageTokens: 200,
            userType: 'trial',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          TokenUsageHistory(
            userId: 'subscribed_user1',
            year: year,
            month: month,
            dailyUsage: {'01': 500, '02': 600},
            totalMonthlyTokens: 1100,
            averageDailyUsage: 550.0,
            peakUsageDate: '02',
            peakUsageTokens: 600,
            userType: 'subscribed',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          TokenUsageHistory(
            userId: 'trial_user2',
            year: year,
            month: month,
            dailyUsage: {'01': 50, '02': 100},
            totalMonthlyTokens: 150,
            averageDailyUsage: 75.0,
            peakUsageDate: '02',
            peakUsageTokens: 100,
            userType: 'trial',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Save historical records
        for (final record in historyRecords) {
          await fakeFirestore
              .collection('token_usage_history')
              .doc(record.documentId)
              .set(record.toFirestore());
        }

        // Test: Calculate monthly statistics
        final stats = await HistoricalUsageService.calculateMonthlyStatistics(
          year: year,
          month: month,
        );

        // Verify: Statistics should be calculated correctly
        expect(stats['totalUsers'], equals(3));
        expect(stats['totalTokens'], equals(1550)); // 300 + 1100 + 150
        expect(stats['averageTokensPerUser'], closeTo(516.67, 0.01)); // 1550 / 3
        expect(stats['trialUsers'], equals(2));
        expect(stats['subscribedUsers'], equals(1));
        expect(stats['trialTokens'], equals(450)); // 300 + 150
        expect(stats['subscribedTokens'], equals(1100));
        expect(stats['peakUsageUser'], equals('subscribed_user1'));
        expect(stats['peakUsageTokens'], equals(1100));
      });

      test('should return empty statistics when no data exists', () async {
        final stats = await HistoricalUsageService.calculateMonthlyStatistics(
          year: 2024,
          month: 1,
        );

        expect(stats['totalUsers'], equals(0));
        expect(stats['totalTokens'], equals(0));
        expect(stats['averageTokensPerUser'], equals(0.0));
      });
    });

    group('updateCurrentMonthHistory', () {
      test('should create new historical record for current month', () async {
        final userId = 'user123';
        final now = DateTime.now();
        final dailyUsage = DailyTokenUsage(
          userId: userId,
          date: '${now.year}-${now.month.toString().padLeft(2, '0')}-15',
          tokensUsed: 100,
          tokenLimit: 1000,
          userType: 'trial',
          lastUpdated: now,
          resetAt: now.add(const Duration(days: 1)),
        );

        // Test: Update current month history
        await HistoricalUsageService.updateCurrentMonthHistory(
          userId: userId,
          dailyUsage: dailyUsage,
        );

        // Verify: Historical record should be created
        final historyDocId = '${userId}_${now.year}_${now.month.toString().padLeft(2, '0')}';
        final historyDoc = await fakeFirestore
            .collection('token_usage_history')
            .doc(historyDocId)
            .get();

        expect(historyDoc.exists, isTrue);
        final history = TokenUsageHistory.fromFirestore(historyDoc);
        expect(history.totalMonthlyTokens, equals(100));
        expect(history.dailyUsage['15'], equals(100));
      });

      test('should update existing historical record for current month', () async {
        final userId = 'user123';
        final now = DateTime.now();
        final historyDocId = '${userId}_${now.year}_${now.month.toString().padLeft(2, '0')}';

        // Setup: Create existing historical record
        final existingHistory = TokenUsageHistory(
          userId: userId,
          year: now.year,
          month: now.month,
          dailyUsage: {'10': 50, '14': 75},
          totalMonthlyTokens: 125,
          averageDailyUsage: 62.5,
          peakUsageDate: '14',
          peakUsageTokens: 75,
          userType: 'trial',
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now.subtract(const Duration(days: 1)),
        );

        await fakeFirestore
            .collection('token_usage_history')
            .doc(historyDocId)
            .set(existingHistory.toFirestore());

        // Test: Update with new daily usage
        final dailyUsage = DailyTokenUsage(
          userId: userId,
          date: '${now.year}-${now.month.toString().padLeft(2, '0')}-15',
          tokensUsed: 100,
          tokenLimit: 1000,
          userType: 'trial',
          lastUpdated: now,
          resetAt: now.add(const Duration(days: 1)),
        );

        await HistoricalUsageService.updateCurrentMonthHistory(
          userId: userId,
          dailyUsage: dailyUsage,
        );

        // Verify: Historical record should be updated
        final updatedDoc = await fakeFirestore
            .collection('token_usage_history')
            .doc(historyDocId)
            .get();

        expect(updatedDoc.exists, isTrue);
        final updatedHistory = TokenUsageHistory.fromFirestore(updatedDoc);
        expect(updatedHistory.totalMonthlyTokens, equals(225)); // 50 + 75 + 100
        expect(updatedHistory.dailyUsage['15'], equals(100));
        expect(updatedHistory.peakUsageTokens, equals(100)); // New peak
        expect(updatedHistory.peakUsageDate, equals('15'));
      });
    });

    group('cleanupOldHistoricalData', () {
      test('should delete records older than retention period', () async {
        final now = DateTime.now();
        final oldYear = now.year - 2; // 2 years ago
        final recentYear = now.year;

        // Setup: Create old and recent historical records
        final oldRecord = TokenUsageHistory(
          userId: 'user123',
          year: oldYear,
          month: 1,
          dailyUsage: {'01': 100},
          totalMonthlyTokens: 100,
          averageDailyUsage: 100.0,
          peakUsageDate: '01',
          peakUsageTokens: 100,
          userType: 'trial',
          createdAt: DateTime(oldYear, 1, 1),
          updatedAt: DateTime(oldYear, 1, 1),
        );

        final recentRecord = TokenUsageHistory(
          userId: 'user123',
          year: recentYear,
          month: now.month,
          dailyUsage: {'01': 100},
          totalMonthlyTokens: 100,
          averageDailyUsage: 100.0,
          peakUsageDate: '01',
          peakUsageTokens: 100,
          userType: 'trial',
          createdAt: now,
          updatedAt: now,
        );

        await fakeFirestore
            .collection('token_usage_history')
            .doc(oldRecord.documentId)
            .set(oldRecord.toFirestore());

        await fakeFirestore
            .collection('token_usage_history')
            .doc(recentRecord.documentId)
            .set(recentRecord.toFirestore());

        // Test: Cleanup old data (keep only 12 months)
        final deletedCount = await HistoricalUsageService.cleanupOldHistoricalData(
          retentionMonths: 12,
        );

        // Verify: Old record should be deleted, recent record should remain
        expect(deletedCount, equals(1));

        final oldDoc = await fakeFirestore
            .collection('token_usage_history')
            .doc(oldRecord.documentId)
            .get();
        expect(oldDoc.exists, isFalse);

        final recentDoc = await fakeFirestore
            .collection('token_usage_history')
            .doc(recentRecord.documentId)
            .get();
        expect(recentDoc.exists, isTrue);
      });
    });
  });
}