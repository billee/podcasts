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
  await dotenv.load(fileName: ".env");
  print('OPENAI_API_KEY from environment: $openAIApiKey');
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