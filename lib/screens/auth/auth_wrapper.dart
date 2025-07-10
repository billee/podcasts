import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/screens/main_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/login_screen.dart';
import 'package:kapwa_companion_basic/services/auth_service.dart';
import 'package:logging/logging.dart'; // Import logging

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({
    super.key,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final Logger _logger = Logger('AuthWrapper'); // Add logger

  @override
  void initState() {
    super.initState();
    _logger.info('AuthWrapper initState called.');
    WidgetsBinding.instance.addObserver(this);
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        _logger.info(
            'Auth state StreamBuilder: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, data=${snapshot.data?.uid}');

        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          _logger.info(
              'Auth state: ConnectionState.waiting. Showing CircularProgressIndicator.');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          _logger.info(
              'Auth state: User logged in. UID: ${snapshot.data!.uid}. Navigating to MainScreen.');
          AuthService.updateUserActivity();
          return const MainScreen();
        }

        // User is not logged in
        _logger
            .info('Auth state: No user logged in. Navigating to LoginScreen.');
        return const LoginScreen();
      },
    );
  }
}
