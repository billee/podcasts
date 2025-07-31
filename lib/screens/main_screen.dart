// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/screens/chat_screen.dart';
import 'package:kapwa_companion_basic/screens/profile_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/login_screen.dart';
import 'package:kapwa_companion_basic/screens/podcast_screen.dart';
import 'package:kapwa_companion_basic/screens/story_screen.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:kapwa_companion_basic/widgets/email_verification_banner.dart';
import 'package:kapwa_companion_basic/widgets/subscription_status_indicator.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final Logger _logger = Logger('MainScreen');
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  StreamSubscription<User?>? _authStateSubscription;
  String? _currentUserId;
  String? _currentUsername;

  List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _logger.info('MainScreen initState called.');
    _initializeUserAndScreens();
    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
      _logger.info('Auth state changed in MainScreen. User: ${user?.uid}');
      _initializeUserAndScreens();

      // Email verification is now handled directly in AuthService.checkEmailVerification()
      // No need for complex monitoring service
    });
  }

  // Isolate-compatible function for fetching user profile
  static Future<Map<String, dynamic>> _fetchUserProfileIsolate(
      String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedUsername = prefs.getString('cached_username_$userId');
    if (cachedUsername != null) {
      return {'name': cachedUsername, 'fromCache': true};
    }
    final userProfile = await AuthService.getUserProfile(userId);
    final username = userProfile?['name'];
    if (username != null) {
      await prefs.setString('cached_username_$userId', username);
      if (userProfile?['preferences'] != null) {
        await prefs.setString(
          'cached_preferences_$userId',
          userProfile!['preferences'].toString(),
        );
      }
    }
    return {'name': username, 'fromCache': false, 'profile': userProfile};
  }

  Future<void> _initializeUserAndScreens() async {
    final user = FirebaseAuth.instance.currentUser;
    _logger.info('_initializeUserAndScreens called. User: ${user?.uid}');

    if (user != null) {
      _currentUserId = user.uid;
      _logger.info('User logged in. Fetching profile for UID: $_currentUserId');
      try {
        final result = await compute(_fetchUserProfileIsolate, _currentUserId!)
            .timeout(const Duration(seconds: 10));
        final username = result['name'] as String?;
        final fromCache = result['fromCache'] as bool;
        final userProfile = result['profile'];

        _logger.info(
            'DEBUG: Fetched userProfile: $userProfile, extracted username: $username, fromCache: $fromCache');

        if (mounted) {
          setState(() {
            _currentUsername = username;
            // Always refresh screens when user info changes
            _screens = [
              ChatScreen(
                userId: _currentUserId,
                username: _currentUsername,
              ),
              const PodcastScreen(),
              const StoryScreen(),
              const ProfileScreen(),
            ];
            _logger.info(
                'Screens initialized with user info for $_currentUsername');
          });
        }
      } catch (e) {
        _logger
            .severe('Error fetching username/profile for $_currentUserId: $e');

        if (mounted) {
          setState(() {
            _currentUsername = null;
            _screens = [
              ChatScreen(
                userId: _currentUserId,
                username: _currentUsername,
              ),
              const PodcastScreen(),
              const StoryScreen(),
              const ProfileScreen(),
            ];
            _logger.warning(
                'Screens initialized with partial user info due to error.');
          });
        }
      }
    } else {
      _logger.warning('No user logged in. Setting LoginScreen as fallback.');
      if (mounted) {
        setState(() {
          _screens = [
            const LoginScreen(),
          ];
        });
      }
    }
  }

  @override
  void dispose() {
    _logger.info('MainScreen dispose called. Disposing auth subscription.');
    _authStateSubscription?.cancel();
    _pageController.dispose();
    // No need to stop service anymore
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_screens.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kapwa Companion'),
        backgroundColor: Colors.grey[900],
        actions: [
          const SubscriptionStatusIndicator(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final shouldSignOut = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Mag-sign Out'),
                  content:
                      const Text('Sigurado ka bang gusto mong mag-sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Kanselahin'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Mag-sign Out'),
                    ),
                  ],
                ),
              );
              if (shouldSignOut == true) {
                try {
                  _logger.info('Sign-out confirmed. Initiating sign-out.');
                  await AuthService.signOut();
                  _logger.info(
                      'Successfully signed out. Navigating to LoginScreen.');
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  _logger.severe('Error during sign-out: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Nagkaroon ng error sa pag-sign out: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            tooltip: 'Mag-sign Out',
          ),
        ],
      ),
      body: Column(
        children: [
          const EmailVerificationBanner(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          _pageController.jumpToPage(index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'Podcast',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Story',
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
