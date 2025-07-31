import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:kapwa_companion_basic/models/daily_token_usage.dart';
import 'package:kapwa_companion_basic/models/token_usage_history.dart';

void main() {
  group('DailyTokenUsage Model Tests', () {
    test('should create DailyTokenUsage from constructor', () {
      final now = DateTime.now();
      final resetTime = DateTime(now.year, now.month, now.day + 1);
      
      final usage = DailyTokenUsage(
        userId: 'user123',
        date: '2024-01-15',
        tokensUsed: 1500,
        tokenLimit: 10000,
        userType: 'trial',
        lastUpdated: now,
        resetAt: resetTime,
      );

      expect(usage.userId, equals('user123'));
      expect(usage.date, equals('2024-01-15'));
      expect(usage.tokensUsed, equals(1500));
      expect(usage.tokenLimit, equals(10000));
      expect(usage.userType, equals('trial'));
      expect(usage.remainingTokens, equals(8500));
      expect(usage.usagePercentage, equals(0.15));
      expect(usage.isLimitReached, isFalse);
      expect(usage.isWarningThreshold, isFalse);
    });

    test('should calculate correct document ID', () {
      final usage = DailyTokenUsage(
        userId: 'user123',
        date: '2024-01-15',
        tokensUsed: 1500,
        tokenLimit: 10000,
        userType: 'trial',
        lastUpdated: DateTime.now(),
        resetAt: DateTime.now(),
      );

      expect(usage.documentId, equals('user123_2024-01-15'));
    });

    test('should detect limit reached', () {
      final usage = DailyTokenUsage(
        userId: 'user123',
        date: '2024-01-15',
        tokensUsed: 10000,
        tokenLimit: 10000,
        userType: 'trial',
        lastUpdated: DateTime.now(),
        resetAt: DateTime.now(),
      );

      expect(usage.isLimitReached, isTrue);
      expect(usage.remainingTokens, equals(0));
    });

    test('should detect warning threshold', () {
      final usage = DailyTokenUsage(
        userId: 'user123',
        date: '2024-01-15',
        tokensUsed: 9500,
        tokenLimit: 10000,
        userType: 'trial',
        lastUpdated: DateTime.now(),
        resetAt: DateTime.now(),
      );

      expect(usage.isWarningThreshold, isTrue);
      expect(usage.usagePercentage, equals(0.95));
    });

    test('should convert to and from Firestore', () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.now();
      
      final originalUsage = DailyTokenUsage(
        userId: 'user123',
        date: '2024-01-15',
        tokensUsed: 1500,
        tokenLimit: 10000,
        userType: 'trial',
        lastUpdated: now,
        resetAt: now,
      );

      // Convert to Firestore format
      final firestoreData = originalUsage.toFirestore();
      
      // Save to fake Firestore
      await firestore
          .collection('daily_token_usage')
          .doc(originalUsage.documentId)
          .set(firestoreData);

      // Retrieve from fake Firestore
      final doc = await firestore
          .collection('daily_token_usage')
          .doc(originalUsage.documentId)
          .get();

      // Convert back to model
      final retrievedUsage = DailyTokenUsage.fromFirestore(doc);

      expect(retrievedUsage.userId, equals(originalUsage.userId));
      expect(retrievedUsage.date, equals(originalUsage.date));
      expect(retrievedUsage.tokensUsed, equals(originalUsage.tokensUsed));
      expect(retrievedUsage.tokenLimit, equals(originalUsage.tokenLimit));
      expect(retrievedUsage.userType, equals(originalUsage.userType));
    });
  });

  group('TokenUsageHistory Model Tests', () {
    test('should create TokenUsageHistory from constructor', () {
      final now = DateTime.now();
      final dailyUsage = {'01': 100, '02': 200, '03': 150};
      
      final history = TokenUsageHistory(
        userId: 'user123',
        year: 2024,
        month: 1,
        dailyUsage: dailyUsage,
        totalMonthlyTokens: 450,
        averageDailyUsage: 150.0,
        peakUsageDate: '02',
        peakUsageTokens: 200,
        userType: 'trial',
        createdAt: now,
        updatedAt: now,
      );

      expect(history.userId, equals('user123'));
      expect(history.year, equals(2024));
      expect(history.month, equals(1));
      expect(history.totalMonthlyTokens, equals(450));
      expect(history.monthName, equals('January'));
      expect(history.displayPeriod, equals('January 2024'));
      expect(history.activeDays, equals(3));
    });

    test('should calculate correct document ID', () {
      final history = TokenUsageHistory(
        userId: 'user123',
        year: 2024,
        month: 1,
        dailyUsage: {},
        totalMonthlyTokens: 0,
        averageDailyUsage: 0.0,
        peakUsageDate: '01',
        peakUsageTokens: 0,
        userType: 'trial',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(history.documentId, equals('user123_2024_01'));
    });

    test('should create from daily records', () {
      final dailyRecords = [
        {'date': '2024-01-01', 'tokensUsed': 100},
        {'date': '2024-01-02', 'tokensUsed': 250},
        {'date': '2024-01-03', 'tokensUsed': 150},
      ];

      final history = TokenUsageHistory.fromDailyRecords(
        userId: 'user123',
        year: 2024,
        month: 1,
        dailyRecords: dailyRecords,
        userType: 'trial',
      );

      expect(history.totalMonthlyTokens, equals(500));
      expect(history.averageDailyUsage, equals(500 / 3));
      expect(history.peakUsageTokens, equals(250));
      expect(history.peakUsageDate, equals('02'));
      expect(history.dailyUsage['01'], equals(100));
      expect(history.dailyUsage['02'], equals(250));
      expect(history.dailyUsage['03'], equals(150));
    });

    test('should convert to and from Firestore', () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.now();
      
      final originalHistory = TokenUsageHistory(
        userId: 'user123',
        year: 2024,
        month: 1,
        dailyUsage: {'01': 100, '02': 200},
        totalMonthlyTokens: 300,
        averageDailyUsage: 150.0,
        peakUsageDate: '02',
        peakUsageTokens: 200,
        userType: 'trial',
        createdAt: now,
        updatedAt: now,
      );

      // Convert to Firestore format
      final firestoreData = originalHistory.toFirestore();
      
      // Save to fake Firestore
      await firestore
          .collection('token_usage_history')
          .doc(originalHistory.documentId)
          .set(firestoreData);

      // Retrieve from fake Firestore
      final doc = await firestore
          .collection('token_usage_history')
          .doc(originalHistory.documentId)
          .get();

      // Convert back to model
      final retrievedHistory = TokenUsageHistory.fromFirestore(doc);

      expect(retrievedHistory.userId, equals(originalHistory.userId));
      expect(retrievedHistory.year, equals(originalHistory.year));
      expect(retrievedHistory.month, equals(originalHistory.month));
      expect(retrievedHistory.totalMonthlyTokens, equals(originalHistory.totalMonthlyTokens));
      expect(retrievedHistory.userType, equals(originalHistory.userType));
    });
  });
}