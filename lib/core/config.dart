import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart'; // Required for defaultTargetPlatform

class AppConfig {
  static late String _backendBaseUrl;

  // Token limit configurations
  static const int trialUserDailyTokenLimit = 10000;
  static const int subscribedUserDailyTokenLimit = 50000;
  static const bool tokenLimitsEnabled = true;
  
  // Daily reset configuration
  static const String resetTimezone = 'UTC'; // Timezone for daily resets
  static const int resetHour = 0; // Hour of day for reset (0-23)
  static const int resetMinute = 0; // Minute of hour for reset (0-59)

  // Existing openAiKey getter
  static String get openAiKey {
    const fromEnvironment = String.fromEnvironment('OPENAI_API_KEY');
    if (fromEnvironment.isNotEmpty) return fromEnvironment;
    return dotenv.env['OPENAI_API_KEY'] ?? '';
  }

  // Add this new backendBaseUrl getter
  static String get backendBaseUrl => _backendBaseUrl;

  static Future<void> initialize() async {
    if (const bool.fromEnvironment('CI_ENVIRONMENT') != true) {
      await dotenv.load(fileName: '.env');
    }

    // Conditional backend URL assignment
    if (kIsWeb) {
      _backendBaseUrl = 'http://localhost:5000'; // For web app development
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // FOR PRODUCTION: Use your main Render deployment URL
      _backendBaseUrl = 'https://ofw-admin-dashboard.onrender.com';

      // FOR LOCAL DEVELOPMENT: Uncomment the line below and comment the line above
      // _backendBaseUrl = 'http://10.0.0.93:5000';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // FOR PRODUCTION: Use your main Render deployment URL
      _backendBaseUrl = 'https://ofw-admin-dashboard.onrender.com';

      // FOR LOCAL DEVELOPMENT: Uncomment the line below and comment the line above
      // _backendBaseUrl = 'http://10.0.0.93:5000';
    } else {
      _backendBaseUrl = 'http://localhost:5000'; // Fallback
    }

    Logger('AppConfig').info('Backend Base URL set to: $_backendBaseUrl');
    
    // Validate token limit configuration
    validateTokenLimits();
  }

  /// Validates token limit configuration values
  static void validateTokenLimits() {
    if (trialUserDailyTokenLimit <= 0) {
      throw ArgumentError('Trial user daily token limit must be positive, got: $trialUserDailyTokenLimit');
    }
    
    if (subscribedUserDailyTokenLimit <= 0) {
      throw ArgumentError('Subscribed user daily token limit must be positive, got: $subscribedUserDailyTokenLimit');
    }
    
    if (subscribedUserDailyTokenLimit < trialUserDailyTokenLimit) {
      Logger('AppConfig').warning(
        'Subscribed user limit ($subscribedUserDailyTokenLimit) is less than trial user limit ($trialUserDailyTokenLimit). '
        'Consider making subscribed limits higher than trial limits.'
      );
    }
    
    Logger('AppConfig').info('Token limits validated successfully - Trial: $trialUserDailyTokenLimit, Subscribed: $subscribedUserDailyTokenLimit, Enabled: $tokenLimitsEnabled');
  }
}
