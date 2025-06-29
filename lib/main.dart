import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:kapwa_companion/screens/main_screen.dart';
import 'package:kapwa_companion/screens/auth/auth_wrapper.dart'; // We'll create this next
import 'package:kapwa_companion/services/video_conference_service.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion/screens/auth/login_screen.dart';

void main() async {
  // Mobile-specific initialization
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure logger for mobile
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('MOBILE [${record.level.name}]: ${record.message}');
  });

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');

    await dotenv.load(fileName: '.env'); // Store in assets for mobile
    debugPrint('Environment loaded successfully');
    debugPrint('API Key: ${dotenv.env['OPENAI_API_KEY']?.substring(0, 5)}...'); // First 5 chars only
    
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Initialization error: $e');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Initialization Failed\nPlease restart the app',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final videoService = DirectVideoCallService();
    return MaterialApp(
      title: 'Kapwa Companion Basic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true, // Enable Material 3 for mobile
      ),
      //home: MainScreen(videoService: videoService),
      home: AuthWrapper(videoService: videoService),
      // initialRoute: '/',
      // routes: {
      //   '/': (context) => MainScreen(videoService: videoService),
      //   '/video-conference': (context) {
      //     final args = ModalRoute.of(context)?.settings.arguments 
      //         as Map<String, dynamic>? ?? {};
              
      //     return VideoConferenceScreen(
      //       contactId: args['contactId'] ?? 'default_contact',
      //       isIncoming: args['isIncoming'] ?? false,
      //       isVideoCall: args['isVideoCall'] ?? true,
      //       videoCallService: videoService,
      //     );
      //   },
      // },
    );
  }
}