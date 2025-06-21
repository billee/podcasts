// main.dart
import 'package:flutter/material.dart';
import 'package:kapwa_companion/screens/chat_screen.dart';
import 'package:kapwa_companion/screens/contacts_screen.dart';
import 'package:kapwa_companion/screens/video_conference_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kapwa_companion/services/suggestion_service.dart';
import 'firebase_options.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('main');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SuggestionService.initializeDefaultSuggestions();

  try {
    await dotenv.load(fileName: ".env");
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
      home: const ChatScreen(), // Keep your existing home screen
      // Add the routes configuration
      routes: {
        '/chat': (context) => const ChatScreen(),
        '/contacts': (context) => const ContactsScreen(),
        '/video-conference': (context) => const VideoConferenceScreen(),
      },
      // Handle routes with arguments
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/video-conference':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => VideoConferenceScreen(
                roomId: args?['roomId'],
              ),
              settings: settings,
            );
          default:
            return null;
        }
      },
      // Add fallback for unknown routes
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Page Not Found'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Route "${settings.name}" not found',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/'),
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
