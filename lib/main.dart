// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/screens/auth/auth_wrapper.dart';
import 'package:kapwa_companion_basic/core/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set Firebase Auth persistence to LOCAL
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    Logger('main').info('Firebase Auth persistence set to LOCAL');
  } catch (e) {
    Logger('main').severe('Error setting Firebase Auth persistence: $e');
  }

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
