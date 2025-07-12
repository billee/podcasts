// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/screens/auth/auth_wrapper.dart';
import 'package:kapwa_companion_basic/core/config.dart';
import 'package:kapwa_companion_basic/services/audio_service.dart'; // Import AudioService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  Logger('main').info('Firebase initialized successfully.');

  // Set Firebase Auth persistence to LOCAL
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    Logger('main').info('Firebase Auth persistence set to LOCAL');
  } catch (e) {
    Logger('main').severe('Error setting Firebase Auth persistence: $e');
  }

  // Initialize logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print(
        '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
    if (record.error != null) {
      print('  Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('  StackTrace: ${record.stackTrace}');
    }
  });

  await AppConfig.initialize();
  debugPrint('Environment loaded successfully');

  // Initialize AudioService here, before runApp
  // Since AudioService is a singleton, this ensures it's initialized once.
  await AudioService().initialize();
  Logger('main').info('AudioService initialized successfully.');

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
      home: AuthWrapper(), // Your existing auth wrapper
    );
  }
}
