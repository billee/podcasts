import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get openAiKey {
    const fromEnvironment = String.fromEnvironment('OPENAI_API_KEY');
    if (fromEnvironment.isNotEmpty) return fromEnvironment;
    return dotenv.env['OPENAI_API_KEY'] ?? '';
  }

  static Future<void> initialize() async {
    if (const bool.fromEnvironment('CI_ENVIRONMENT') != true) {
      await dotenv.load(fileName: '.env');
    }
  }
}