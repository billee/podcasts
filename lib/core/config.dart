import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart'; // Required for defaultTargetPlatform

class AppConfig {
  static late String _backendBaseUrl;

  // Token limit configurations
  // Token limit configurations - Updated for REAL token usage (input + output)
  // Real usage includes system prompts, conversation history, user input, and LLM responses
  static const int trialUserDailyTokenLimit = 10000;    // ~10-20 conversation exchanges
  static const int subscribedUserDailyTokenLimit = 100000;  // ~100-200 conversation exchanges
  static const bool tokenLimitsEnabled = true;
  
  // Daily reset configuration
  // Reset happens at 24:00 (midnight) in user's local timezone
  
  // Date configuration for testing
  static DateTime? _overrideDate; // For testing purposes - when null, uses real DateTime.now()
  
  /// Get the current date/time - uses override date if set, otherwise real DateTime.now()
  static DateTime get currentDateTime {
    return _overrideDate ?? DateTime.now();
  }
  
  /// Get the current date/time in UTC - uses override date if set, otherwise real DateTime.now().toUtc()
  static DateTime get currentDateTimeUtc {
    return _overrideDate?.toUtc() ?? DateTime.now().toUtc();
  }
  
  /// Set override date for testing (null to use real time)
  static void setOverrideDate(DateTime? date) {
    _overrideDate = date;
    Logger('AppConfig').info('Override date set to: ${date?.toString() ?? 'null (using real time)'}');
  }
  
  /// Get current override date (null if using real time)
  static DateTime? get overrideDate => _overrideDate;

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
    
    // Initialize with real time by default (today)
    //_overrideDate = null;
    
    ////////// tomorrow
    _overrideDate = DateTime.now().add(Duration(days: 5));

    ///////// Initialize with 2 months from now for testing
    //_overrideDate = DateTime.now().add(Duration(days: 60));

    ///////// Specific date
    //_overrideDate = DateTime(2025, 10, 15);

    Logger('AppConfig').info('Date configuration initialized - using real time by default');
    
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
