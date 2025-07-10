// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/screens/chat_screen.dart';
import 'package:kapwa_companion_basic/screens/contacts_screen.dart';
import 'package:kapwa_companion_basic/screens/profile_screen.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/services/auth_service.dart'; // Import AuthService

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final Logger _logger = Logger('MainScreen');
  int _currentIndex = 0;

  StreamSubscription<User?>? _authStateSubscription;

  // State variables to hold current user's ID and username
  String? _currentUserId;
  String? _currentUsername;

  // --- MODIFICATION START ---
  // Change from 'late final' to a regular list, initialized as empty.
  List<Widget> _screens = [];
  // --- MODIFICATION END ---

  @override
  void initState() {
    super.initState();
    _logger.info('MainScreen initState called.');
    _initializeUserAndScreens(); // Call new initialization method

    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
      _logger.info('Auth state changed in MainScreen. User: ${user?.uid}');
      // Re-initialize screens when auth state changes (e.g., user logs in/out)
      // Only re-initialize if the user state has truly changed in a meaningful way
      // that affects _currentUserId or _currentUsername.
      // This listener might trigger multiple times on startup, so _initializeUserAndScreens
      // will handle setting _screens.
      _initializeUserAndScreens();
    });
  }

  Future<void> _initializeUserAndScreens() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      _logger.info('User logged in. Fetching profile for UID: $_currentUserId');
      try {
        final userProfile = await AuthService.getUserProfile(_currentUserId!);
        // --- MODIFICATION START ---
        // Change 'username' to 'name' to match your Firestore document
        final username = userProfile?['name'] as String?;
        // --- MODIFICATION END ---

        _logger.info(
            'DEBUG: Fetched userProfile: $userProfile, extracted username: $username');

        setState(() {
          _currentUsername = username;
          _screens = [
            ChatScreen(
              userId: _currentUserId,
              username: _currentUsername, // This will now receive 'bill tan'
            ),
            ContactsScreen(
              userId: _currentUserId,
              username: _currentUsername,
            ),
            const ProfileScreen(),
          ];
          _logger.info(
              'Screens initialized with user info for $_currentUsername.');
        });
      } catch (e) {
        _logger
            .severe('Error fetching username/profile for $_currentUserId: $e');
        setState(() {
          _currentUsername = null;
          _screens = [
            ChatScreen(
              userId: _currentUserId,
              username: _currentUsername,
            ),
            ContactsScreen(
              userId: _currentUserId,
              username: _currentUsername,
            ),
            const ProfileScreen(),
          ];
          _logger.warning(
              'Screens initialized with partial user info due to error.');
        });
      }
    } else {
      // ... (rest of _initializeUserAndScreens for logged out users) ...
    }
  }

  @override
  void dispose() {
    _logger.info('MainScreen dispose called. Disposing auth subscription.');
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator until _screens is initialized with at least one screen
    // This check ensures _screens is not empty before accessing _screens[_currentIndex]
    if (_screens.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        backgroundColor: Colors.grey[900],
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey[500],
      ),
    );
  }
}
