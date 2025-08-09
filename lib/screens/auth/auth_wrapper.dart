// lib/screens/auth/auth_wrapper.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/screens/main_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/login_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/email_verification_screen.dart';
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
  User? _currentUser;

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
            'Auth state StreamBuilder: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, data=${snapshot.data?.uid}, error=${snapshot.error}');

        // Handle errors
        if (snapshot.hasError) {
          _logger.severe('Auth stream error: ${snapshot.error}');
          return const LoginScreen();
        }

        // Handle different connection states
        if (snapshot.connectionState == ConnectionState.waiting) {
          _logger.info('Auth state: Waiting for connection. Showing splash.');
          return const SplashScreen();
        }

        // Update current user state
        _currentUser = snapshot.data;

        // Update cached auth state
        final isLoggedIn = snapshot.hasData && snapshot.data != null;
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('isLoggedIn', isLoggedIn);
          _logger.info('Updated cached auth state: isLoggedIn=$isLoggedIn');
        });

        // User is logged in
        if (isLoggedIn) {
          final user = snapshot.data!;
          _logger.info(
              'Auth state: User logged in. UID: ${user.uid}. Email: ${user.email}. EmailVerified: ${user.emailVerified}');
          
          // Double-check that user is actually authenticated
          if (user.uid.isEmpty) {
            _logger.warning('User has empty UID, treating as not authenticated');
            return const LoginScreen();
          }
          
          // Check if email is verified
          if (!user.emailVerified) {
            _logger.info('Email not verified. Navigating to EmailVerificationScreen.');
            return const EmailVerificationScreen();
          }
          
          // Email is verified, update Firestore and proceed to main screen
          _logger.info('Email verified. Updating Firestore and navigating to MainScreen.');
          
          // Update email verification status in Firestore in background
          AuthService.checkEmailVerification().catchError((e) {
            _logger.warning('Failed to update email verification status: $e');
          });
          
          // Update user activity in background, don't block navigation
          AuthService.updateUserActivity().catchError((e) {
            _logger.warning('User activity update failed: $e');
          });
          return const MainScreen();
        }

        // No user logged in
        _logger.info('Auth state: No user logged in. Navigating to LoginScreen.');
        return const LoginScreen();
      },
    );
  }

  // Add a method to manually refresh auth state
  void _refreshAuthState() {
    _logger.info('Manually refreshing auth state...');
    final currentUser = FirebaseAuth.instance.currentUser;
    _logger.info('Current user from manual check: ${currentUser?.uid}');
    
    if (currentUser != null && _currentUser?.uid != currentUser.uid) {
      _logger.info('User state changed, forcing rebuild...');
      if (mounted) {
        setState(() {
          _currentUser = currentUser;
        });
      }
    }
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
