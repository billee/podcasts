// lib/main.dart
import 'package:flutter/material.dart';
import 'package:kapwa_companion/screens/main_screen.dart';
import 'package:kapwa_companion/screens/video_conference_screen.dart'; // Import VideoConferenceScreen
import 'package:kapwa_companion/services/video_conference_service.dart'; // Import the service
import 'package:logging/logging.dart'; // For logging

void main() {
  // Set up logging
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create a single instance of DirectVideoCallService here to be shared
    // This isn't the ideal pattern for larger apps (Provider, GetIt would be better)
    // but for simplicity, we'll create it once and pass it down.
    // It's crucial that it's initialized with a unique ID *before* it's used.
    // For this example, we will initialize it in ContactsScreen.
    final DirectVideoCallService _sharedVideoService = DirectVideoCallService();

    return MaterialApp(
      title: 'Kapwa Companion',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark, // Keep dark theme
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainScreen(),
        '/video-conference': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null || !args.containsKey('contactId') || !args.containsKey('isIncoming') || !args.containsKey('isVideoCall')) {
            // Handle error or navigate back if arguments are missing
            return const Scaffold(
              body: Center(child: Text('Error: Call details missing.')),
            );
          }
          return VideoConferenceScreen(
            contactId: args['contactId'] as String,
            isIncoming: args['isIncoming'] as bool,
            isVideoCall: args['isVideoCall'] as bool,
            videoCallService: _sharedVideoService, // Pass the shared service instance
          );
        },
      },
    );
  }
}
