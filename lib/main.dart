// main.dart
import 'package:flutter/material.dart';
import 'package:kapwa_companion/screens/chat_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const String openAIApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: ''
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ONLY attempt to load .env if it's expected to be present (e.g., local dev).
  // In CI, where .env is not committed and not an asset, this block might be skipped
  // or gracefully fail without error.
  // The String.fromEnvironment() variables will then pick up values from --dart-define.
  try {
    // This will only succeed if .env is present.
    // If you plan to NEVER commit .env, you can even remove flutter_dotenv dependency
    // and this whole try-catch. But for local dev, it's useful.
    await dotenv.load(fileName: ".env");
    print("Local .env loaded successfully."); // For local debugging
  } catch (e) {
    print("Warning: .env file not found or failed to load. This is expected in CI, relying on --dart-define or environment variables. Error: $e");
  }

  // Verify that the keys are being read
  print('OPENAI_API_KEY (from env/dart-define): $openAIApiKey');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kapwa Companion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}