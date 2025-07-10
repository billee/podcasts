import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';

class AppConfig {
  // Existing openAiKey getter
  static String get openAiKey {
    const fromEnvironment = String.fromEnvironment('OPENAI_API_KEY');
    if (fromEnvironment.isNotEmpty) return fromEnvironment;
    return dotenv.env['OPENAI_API_KEY'] ?? '';
  }

  // Add this new backendBaseUrl getter
  static String backendBaseUrl = 'http://localhost:5000';

  static Future<void> initialize() async {
    if (const bool.fromEnvironment('CI_ENVIRONMENT') != true) {
      await dotenv.load(fileName: '.env');
    }
  }
}
