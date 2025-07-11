// lib/screens/auth/auth_wrapper.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/screens/main_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/login_screen.dart';
import 'package:kapwa_companion_basic/services/auth_service.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/services.dart'
    show BackgroundIsolateBinaryMessenger, RootIsolateToken;

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final Logger _logger = Logger('AuthWrapper');
  bool _isCheckingAuth = true;
  bool _isInitiallyLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _logger.info(
        'AuthWrapper initState called. Platform: ${kIsWeb ? "Web" : "Mobile"}');
    WidgetsBinding.instance.addObserver(this);
    _checkInitialAuthState();
  }

  // Isolate-compatible function for auth check
  static Future<Map<String, dynamic>> _checkAuthIsolate(
      RootIsolateToken token) async {
    // Initialize the binary messenger for the isolate
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    User? currentUser;
    int maxRetries = kIsWeb ? 5 : 2; // Reduced retries for mobile
    for (int i = 0; i < maxRetries; i++) {
      currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) break;
      await Future.delayed(const Duration(seconds: 1));
    }
    return {
      'isLoggedIn': isLoggedIn,
      'user': currentUser,
    };
  }

  Future<void> _checkInitialAuthState() async {
    try {
      // Pass the root isolate token to the compute function
      final result =
          await compute(_checkAuthIsolate, RootIsolateToken.instance!);
      _isInitiallyLoggedIn = result['isLoggedIn'] as bool;
      final currentUser = result['user'] as User?;
      _logger.info('Cached auth state: isLoggedIn=$_isInitiallyLoggedIn');

      final prefs = await SharedPreferences.getInstance();
      if (currentUser != null) {
        _logger.info('Initial check: User logged in. UID: ${currentUser.uid}');
        await prefs.setBool('isLoggedIn', true);
        await AuthService.updateUserActivity();
      } else {
        _logger.info('Initial check: No user logged in.');
        await prefs.setBool('isLoggedIn', false);
        if (kIsWeb && _isInitiallyLoggedIn) {
          _logger.warning(
              'No user found despite cached login. Possible localStorage issue or incognito mode.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Please use a regular browser window to stay logged in.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      _logger.severe('Error checking initial auth state: $e');
      final prefs = await SharedPreferences.getInstance();
      _isInitiallyLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _logger.info('AuthWrapper dispose called.');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _logger.info('App lifecycle state changed: $state');
    switch (state) {
      case AppLifecycleState.resumed:
        AuthService.updateUserActivity();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        AuthService.setUserOffline();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      _logger.info('Still checking auth state. Showing SplashScreen.');
      return const SplashScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        _logger.info(
            'Auth state StreamBuilder: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, data=${snapshot.data?.uid}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          _logger
              .info('Auth state: ConnectionState.waiting. Using cached state.');
          return _isInitiallyLoggedIn
              ? const MainScreen()
              : const SplashScreen();
        }

        SharedPreferences.getInstance().then((prefs) {
          bool isLoggedIn = snapshot.hasData && snapshot.data != null;
          prefs.setBool('isLoggedIn', isLoggedIn);
          _logger.info('Updated cached auth state: isLoggedIn=$isLoggedIn');
        });

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          _logger.info(
              'Auth state: User logged in. UID: ${snapshot.data!.uid}. Navigating to MainScreen.');
          AuthService.updateUserActivity();
          return const MainScreen();
        }

        _logger
            .info('Auth state: No user logged in. Navigating to LoginScreen.');
        return const LoginScreen();
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.blue[800],
            ),
            const SizedBox(height: 16),
            Text(
              'Kapwa Companion',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
