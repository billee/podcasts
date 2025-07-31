import 'package:flutter_test/flutter_test.dart';
import 'package:kapwa_companion_basic/core/config.dart';

void main() {
  group('AppConfig Feature Toggle', () {
    test('should have tokenLimitsEnabled flag', () {
      // Test that the feature toggle exists and is accessible
      expect(AppConfig.tokenLimitsEnabled, isA<bool>());
      expect(AppConfig.tokenLimitsEnabled, equals(true));
    });

    test('should allow feature to be disabled by changing the flag', () {
      // This test verifies the flag exists and can be used for feature toggling
      // In actual usage, the owner would change this const value in config.dart
      const bool featureEnabled = AppConfig.tokenLimitsEnabled;
      
      if (featureEnabled) {
        // Feature is enabled, token limits should be enforced
        expect(AppConfig.trialUserDailyTokenLimit, greaterThan(0));
        expect(AppConfig.subscribedUserDailyTokenLimit, greaterThan(0));
      } else {
        // Feature is disabled, but limits still exist for when it's re-enabled
        expect(AppConfig.trialUserDailyTokenLimit, isA<int>());
        expect(AppConfig.subscribedUserDailyTokenLimit, isA<int>());
      }
    });
  });
}