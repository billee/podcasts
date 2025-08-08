import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:kapwa_companion_basic/services/monthly_aggregation_service.dart';
import 'package:kapwa_companion_basic/services/historical_usage_service.dart';
import 'package:kapwa_companion_basic/models/daily_token_usage.dart';

void main() {
  group('MonthlyAggregationService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      HistoricalUsageService.setFirestoreInstance(fakeFirestore);
    });

    group('performAggregationForMonth', () {
      test('should aggregate data for specific month', () async {
        // Setup: Create daily usage records for January 2024
        final users = ['user1', 'user2'];
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

        // Test: Perform aggregation for specific month
        final result = await MonthlyAggregationService.performAggregationForMonth(
          year: year,
          month: month,
        );

        // Verify: Aggregation should be successful
        expect(result['success'], isTrue);
        expect(result['year'], equals(year));
        expect(result['month'], equals(month));
        expect(result['migratedUsers'], equals(2));
        expect(result['statistics'], isNotNull);

        // Verify: Historical records should be created
        for (final userId in users) {
          final historyDocId = '${userId}_2024_01';
          final historyDoc = await fakeFirestore
              .collection('token_usage_history')
              .doc(historyDocId)
              .get();
          
          expect(historyDoc.exists, isTrue);
        }
      });

      test('should handle errors gracefully', () async {
        // Test: Perform aggregation with invalid month
        final result = await MonthlyAggregationService.performAggregationForMonth(
          year: 2024,
          month: 13, // Invalid month
        );

        // Verify: Should return success even with no data
        expect(result['success'], isTrue);
        expect(result['migratedUsers'], equals(0));
      });
    });

    group('backfillHistoricalData', () {
      test('should backfill data for multiple months', () async {
        // Setup: Create daily usage records for the last 3 months
        final now = DateTime.now();
        final users = ['user1', 'user2'];

        for (int i = 1; i <= 3; i++) {
          final targetDate = DateTime(now.year, now.month - i, 15);
          final dateString = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-15';

          for (final userId in users) {
            final dailyRecord = DailyTokenUsage(
              userId: userId,
              date: dateString,
              tokensUsed: 100 * i, // Different usage for each month
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
        }

        // Test: Backfill historical data for last 3 months
        final results = await MonthlyAggregationService.backfillHistoricalData(
          months: 3,
        );

        // Verify: Should process 3 months
        expect(results.length, equals(3));
        
        // Verify: All results should be successful
        for (final result in results) {
          expect(result['success'], isTrue);
          expect(result['migratedUsers'], equals(2));
        }
      });

      test('should handle empty data gracefully', () async {
        // Test: Backfill with no existing data
        final results = await MonthlyAggregationService.backfillHistoricalData(
          months: 2,
        );

        // Verify: Should return results even with no data
        expect(results.length, equals(2));
        
        for (final result in results) {
          expect(result['success'], isTrue);
          expect(result['migratedUsers'], equals(0));
        }
      });
    });

    group('getAggregationStatus', () {
      test('should return status for recent months', () async {
        final now = DateTime.now();
        
        // Setup: Create historical data for last month
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final userId = 'user123';
        
        final dailyRecord = DailyTokenUsage(
          userId: userId,
          date: '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}-15',
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

        // Aggregate the data first
        await MonthlyAggregationService.performAggregationForMonth(
          year: lastMonth.year,
          month: lastMonth.month,
        );

        // Test: Get aggregation status
        final status = await MonthlyAggregationService.getAggregationStatus(
          months: 2,
        );

        // Verify: Should return status for recent months
        expect(status.length, equals(2));
        
        // First entry should be the month with data
        final firstStatus = status.first;
        expect(firstStatus['year'], equals(lastMonth.year));
        expect(firstStatus['month'], equals(lastMonth.month));
        expect(firstStatus['hasData'], isTrue);
        expect(firstStatus['userCount'], equals(1));
        expect(firstStatus['totalTokens'], equals(100));
      });

      test('should indicate when no data exists', () async {
        // Test: Get status with no historical data
        final status = await MonthlyAggregationService.getAggregationStatus(
          months: 1,
        );

        // Verify: Should indicate no data
        expect(status.length, equals(1));
        expect(status.first['hasData'], isFalse);
        expect(status.first['userCount'], equals(0));
        expect(status.first['totalTokens'], equals(0));
      });
    });
  });
}