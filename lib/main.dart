// main.dart
// import 'package:firebase_core/firebase_core.dart'; // REMOVED
// import 'firebase_options.dart'; // REMOVED
import 'package:flutter/material.dart';
import 'package:kapwa_companion/screens/chat_screen.dart';
// import 'package:kapwa_companion/services/firebase_service.dart'; // REMOVED

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Removed Firebase initialization as it's no longer used for RAG core
  // If you have other Firebase features, you'll need to keep this and relevant imports.
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );
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