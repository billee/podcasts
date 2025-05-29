// main.dart
import 'package:flutter/material.dart';
import 'package:kapwa_companion/screens/chat_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kapwa_companion/services/suggestion_service.dart';
import 'firebase_options.dart';



const String openAIApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: ''
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SuggestionService.initializeDefaultSuggestions();

  try {
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