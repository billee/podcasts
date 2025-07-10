import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:logging/logging.dart'; // Ensure this import is present
import 'package:kapwa_companion_basic/screens/auth/auth_wrapper.dart';
import 'package:kapwa_companion_basic/core/config.dart'; // Make sure this import is present for AppConfig

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- MODIFIED LOGGING CONFIGURATION ---
  Logger.root.level = Level.ALL; // Ensure this is set to ALL or INFO
  Logger.root.onRecord.listen((record) {
    // Change debugPrint to print
    print(
        '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
    if (record.error != null) {
      print('  Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('  StackTrace: ${record.stackTrace}');
    }
  });
  // --- END MODIFIED LOGGING CONFIGURATION ---

  // Initialize environment configuration
  await AppConfig.initialize(); // Ensure AppConfig is initialized before runApp
  debugPrint(
      'Environment loaded successfully'); // This debugPrint will also now appear

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kapwa Companion Basic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      // THIS IS THE CRUCIAL CHANGE:
      // Set AuthWrapper as the home, so it can decide which screen to show.
      home: const AuthWrapper(),
    );
  }
}
