// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/screens/auth/auth_wrapper.dart';
import 'package:kapwa_companion_basic/core/config.dart';
import 'package:kapwa_companion_basic/services/audio_service.dart';

void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint(
      '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}',
    );
    if (record.error != null) {
      debugPrint('  Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('  StackTrace: ${record.stackTrace}');
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupLogging();
  final logger = Logger('main');

  try {
    // Initialize Firebase
    logger.info('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.info('Firebase initialized successfully.');

    // Set Firebase Auth persistence
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      logger.info('Firebase Auth persistence set to LOCAL');
    } catch (e) {
      logger.severe('Error setting Firebase Auth persistence: $e');
    }

    // Initialize app configuration
    logger.info('Loading environment configuration...');
    await AppConfig.initialize();
    debugPrint('Environment loaded successfully');
    logger.info('Environment loaded successfully');

    // Initialize AudioService with error handling
    logger.info('Initializing AudioService...');
    try {
      await AudioService().initialize();
      logger.info('AudioService initialized successfully.');
    } catch (e, s) {
      logger.warning('AudioService initialization failed: $e', e, s);
    }

    runApp(const MyApp());
  } catch (e, s) {
    logger.severe('CRITICAL INITIALIZATION ERROR: $e', e, s);
    runApp(ErrorFallbackApp(error: e, stackTrace: s));
  }
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
      home: const AuthWrapper(),
    );
  }
}

class ErrorFallbackApp extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;

  const ErrorFallbackApp({
    super.key,
    required this.error,
    this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'App Initialization Failed',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    // Add restart logic here if needed
                  },
                  child: const Text('Restart App'),
                ),
                if (stackTrace != null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Stack Trace:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(stackTrace.toString()),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
