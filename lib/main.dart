// main.dart
import 'package:flutter/material.dart';
import 'package:kapwa_companion/screens/chat_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kapwa_companion/services/suggestion_service.dart';
import 'firebase_options.dart';
import 'package:logging/logging.dart';

// const String openAIApiKey = String.fromEnvironment(
//     'OPENAI_API_KEY',
//     defaultValue: ''
// );

final Logger _logger = Logger('main');
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SuggestionService.initializeDefaultSuggestions();

  try {
    await dotenv.load(fileName: ".env");
    //print('Local .env loaded successfully.'); // Your existing print
    //print('OPENAI_API_KEY from dotenv.env: ${dotenv.env['OPENAI_API_KEY']}');
    //print('Is OPENAI_API_KEY null? ${dotenv.env['OPENAI_API_KEY'] == null}');
    //print('Type of OPENAI_API_KEY: ${dotenv.env['OPENAI_API_KEY']?.runtimeType}'); // Using ?. to safely get runtimeType
  } catch (e) {
    _logger.info(
        "Warning: .env file not found or failed to load. This is expected in CI, relying on --dart-define or environment variables. Error: $e");
  }

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
