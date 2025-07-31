import 'package:flutter_test/flutter_test.dart';
import 'package:kapwa_companion_basic/models/token_usage_info.dart';

void main() {
  group('TokenUsageInfo', () {
    test('creates from daily usage correctly', () {
      final resetTime = DateTime.now().add(const Duration(days: 1));
      
      final usageInfo = TokenUsageInfo.fromDailyUsage(
        userId: 'test_user',
        tokensUsed: 3000,
        tokenLimit: 10000,
        userType: 'trial',
        resetTime: resetTime,
      );

      expect(usageInfo.userId, equals('test_user'));
      expect(usageInfo.tokensUsed, equals(3000));
      expect(usageInfo.tokenLimit, equals(10000));
      expect(usageInfo.remainingTokens, equals(7000));
      expect(usageInfo.userType, equals('trial'));
      expect(usageInfo.usagePercentage, equals(0.3));
      expect(usageInfo.isLimitReached, isFalse);
      expect(usageInfo.isWarningThreshold, isFalse);
      expect(usageInfo.resetTime, equals(resetTime));
    });

    test('creates empty usage info correctly', () {
      final resetTime = DateTime.now().add(const Duration(days: 1));
      
      final usageInfo = TokenUsageInfo.empty(
        userId: 'test_user',
        tokenLimit: 10000,
        userType: 'trial',
        resetTime: resetTime,
      );

      expect(usageInfo.tokensUsed, equals(0));
      expect(usageInfo.remainingTokens, equals(10000));
      expect(usageInfo.usagePercentage, equals(0.0));
      expect(usageInfo.isLimitReached, isFalse);
      expect(usageInfo.isWarningThreshold, isFalse);
    });

    test('detects warning threshold correctly', () {
      final resetTime = DateTime.now().add(const Duration(days: 1));
      
      final usageInfo = TokenUsageInfo.fromDailyUsage(
        userId: 'test_user',
        tokensUsed: 9500,
        tokenLimit: 10000,
        userType: 'trial',
        resetTime: resetTime,
      );

      expect(usageInfo.isWarningThreshold, isTrue);
      expect(usageInfo.usagePercentage, equals(0.95));
    });

    test('detects limit reached correctly', () {
      final resetTime = DateTime.now().add(const Duration(days: 1));
      
      final usageInfo = TokenUsageInfo.fromDailyUsage(
        userId: 'test_user',
        tokensUsed: 10000,
        tokenLimit: 10000,
        userType: 'trial',
        resetTime: resetTime,
      );

      expect(usageInfo.isLimitReached, isTrue);
      expect(usageInfo.remainingTokens, equals(0));
    });

    test('handles over-limit usage correctly', () {
      final resetTime = DateTime.now().add(const Duration(days: 1));
      
      final usageInfo = TokenUsageInfo.fromDailyUsage(
        userId: 'test_user',
        tokensUsed: 12000,
        tokenLimit: 10000,
        userType: 'trial',
        resetTime: resetTime,
      );

      expect(usageInfo.isLimitReached, isTrue);
      expect(usageInfo.remainingTokens, equals(0)); // Clamped to 0
      expect(usageInfo.usagePercentage, equals(1.2));
    });

    test('copyWith works correctly', () {
      final resetTime = DateTime.now().add(const Duration(days: 1));
      
      final original = TokenUsageInfo.fromDailyUsage(
        userId: 'test_user',
        tokensUsed: 3000,
        tokenLimit: 10000,
        userType: 'trial',
        resetTime: resetTime,
      );

      final updated = original.copyWith(tokensUsed: 5000);

      expect(updated.tokensUsed, equals(5000));
      expect(updated.userId, equals(original.userId));
      expect(updated.tokenLimit, equals(original.tokenLimit));
      expect(updated.remainingTokens, equals(5000)); // Should be recalculated
    });

    test('equality and hashCode work correctly', () {
      final resetTime = DateTime.now().add(const Duration(days: 1));
      
      final usage1 = TokenUsageInfo.fromDailyUsage(
        userId: 'test_user',
        tokensUsed: 3000,
        tokenLimit: 10000,
        userType: 'trial',
        resetTime: resetTime,
      );

      final usage2 = TokenUsageInfo.fromDailyUsage(
        userId: 'test_user',
        tokensUsed: 3000,
        tokenLimit: 10000,
        userType: 'trial',
        resetTime: resetTime,
      );

      expect(usage1, equals(usage2));
      expect(usage1.hashCode, equals(usage2.hashCode));
    });
  });
}