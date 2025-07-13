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
      // FOR PHYSICAL ANDROID PHONE, THIS MUST BE YOUR DEVELOPMENT MACHINE'S REAL IP
      // Based on your ipconfig, this is 10.0.0.93
      _backendBaseUrl = 'http://10.0.0.93:5000';
      // If you were using an Android EMULATOR, 10.0.2.2 would be correct:
      // _backendBaseUrl = 'http://10.0.2.2:5000';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // For iOS simulator, localhost often works. For physical iOS devices,
      // you would also need your development machine's actual local IP address.
      // If your physical iOS device is connecting to this machine:
      _backendBaseUrl = 'http://10.0.0.93:5000';
    } else {
      _backendBaseUrl = 'http://localhost:5000'; // Fallback
    }

    Logger('AppConfig').info('Backend Base URL set to: $_backendBaseUrl');
  }
}
