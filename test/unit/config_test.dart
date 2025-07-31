import 'package:flutter_test/flutter_test.dart';
import 'package:kapwa_companion_basic/core/config.dart';

void main() {
  group('AppConfig Token Limits', () {
    test('should have valid token limit constants', () {
      // Test that constants are defined with expected values
      expect(AppConfig.trialUserDailyTokenLimit, equals(10000));
      expect(AppConfig.subscribedUserDailyTokenLimit, equals(50000));
      expect(AppConfig.tokenLimitsEnabled, equals(true));
    });

    test('should validate token limits successfully with valid values', () {
      // This should not throw any exceptions
      expect(() => AppConfig.validateTokenLimits(), returnsNormally);
    });

    test('should have subscribed limit greater than or equal to trial limit', () {
      expect(AppConfig.subscribedUserDailyTokenLimit, 
             greaterThanOrEqualTo(AppConfig.trialUserDailyTokenLimit));
    });

    test('should have positive token limits', () {
      expect(AppConfig.trialUserDailyTokenLimit, greaterThan(0));
      expect(AppConfig.subscribedUserDailyTokenLimit, greaterThan(0));
    });
  });
}