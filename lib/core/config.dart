import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart'; // Required for defaultTargetPlatform

class AppConfig {
  static late String _backendBaseUrl;

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
      // FOR PRODUCTION: Use your Render deployment URL
      _backendBaseUrl = 'https://backend-kapwa.onrender.com';

      // FOR LOCAL DEVELOPMENT: Uncomment the line below and comment the line above
      // _backendBaseUrl = 'http://10.0.0.93:5000';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // FOR PRODUCTION: Use your Render deployment URL
      _backendBaseUrl = 'https://backend-kapwa.onrender.com';

      // FOR LOCAL DEVELOPMENT: Uncomment the line below and comment the line above
      // _backendBaseUrl = 'http://10.0.0.93:5000';
    } else {
      _backendBaseUrl = 'http://localhost:5000'; // Fallback
    }

    Logger('AppConfig').info('Backend Base URL set to: $_backendBaseUrl');
  }
}
