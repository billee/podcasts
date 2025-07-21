// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/screens/chat_screen.dart';
import 'package:kapwa_companion_basic/screens/profile_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/login_screen.dart';
import 'package:kapwa_companion_basic/screens/podcast_screen.dart';
import 'package:kapwa_companion_basic/screens/story_screen.dart';
import 'package:kapwa_companion_basic/screens/video_screen.dart';
import 'package:kapwa_companion_basic/screens/payment_screen.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:kapwa_companion_basic/screens/video_screen_web.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kapwa_companion_basic/widgets/placeholder_widget.dart';

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
  String? _dailyRoomUrl;
  bool _isFetchingRoomUrl = false;

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
    });
  }

  // NEW: Generate Daily room URL directly from userId
  String _generateDailyRoomUrl(String userId) {
    final roomName = 'kapwa-$userId';
    final dailyDomain = 'kapwa-companion-basic.daily.co';
    final roomUrl = 'https://$dailyDomain/$roomName';

    _logger.info('Generated Daily room URL: $roomUrl');
    return roomUrl;
  }

  // UPDATED: Create or get Daily room URL (fallback to backend if needed)
  Future<String?> _getDailyRoomUrl(String userId) async {
    try {
      setState(() => _isFetchingRoomUrl = true);

      // First, try to generate the URL directly
      final generatedUrl = _generateDailyRoomUrl(userId);

      // Check if we should verify with backend (optional)
      // For now, let's use the generated URL directly
      _logger.info('Using generated Daily room URL: $generatedUrl');
      return generatedUrl;

      // TODO: If you want to verify with backend, uncomment below:
      /*
      String baseUrl = kIsWeb ? 'http://localhost:5000' : 'http://10.0.2.2:5000';
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/daily-room/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final roomUrl = jsonDecode(response.body)['room_url'] as String?;
        _logger.info('Backend returned Daily room URL: $roomUrl');
        return roomUrl ?? generatedUrl; // Fallback to generated URL
      } else {
        _logger.warning('Backend failed (${response.statusCode}), using generated URL');
        return generatedUrl;
      }
      */
    } catch (e) {
      _logger
          .warning('Error with Daily room URL, using generated fallback: $e');
      // Fallback to generated URL even if backend fails
      return _generateDailyRoomUrl(userId);
    } finally {
      if (mounted) {
        setState(() => _isFetchingRoomUrl = false);
      }
    }
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
          jsonEncode(userProfile?['preferences']),
        );
      }
    }
    return {'name': username, 'fromCache': false, 'profile': userProfile};
  }

  Future<void> _initializeUserAndScreens() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      _logger.info('User logged in. Fetching profile for UID: $_currentUserId');
      try {
        final result = await compute(_fetchUserProfileIsolate, _currentUserId!);
        final username = result['name'] as String?;
        final fromCache = result['fromCache'] as bool;
        final userProfile = result['profile'];

        _logger.info(
            'DEBUG: Fetched userProfile: $userProfile, extracted username: $username, fromCache: $fromCache');

        // UPDATED: Always generate/fetch Daily room URL
        _dailyRoomUrl = await _getDailyRoomUrl(_currentUserId!);
        _logger.info('Daily room URL set to: $_dailyRoomUrl');

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
            _buildVideoScreen(),
            const ProfileScreen(),
          ];
          _logger.info(
              'Screens initialized with user info for $_currentUsername and Daily URL: $_dailyRoomUrl');
        });
      } catch (e) {
        _logger
            .severe('Error fetching username/profile for $_currentUserId: $e');

        // Even on error, try to generate Daily room URL
        _dailyRoomUrl = _generateDailyRoomUrl(_currentUserId!);

        setState(() {
          _currentUsername = null;
          _screens = [
            ChatScreen(
              userId: _currentUserId,
              username: _currentUsername,
            ),
            const PodcastScreen(),
            const StoryScreen(),
            _buildVideoScreen(),
            const ProfileScreen(),
          ];
          _logger.warning(
              'Screens initialized with partial user info due to error. Daily URL: $_dailyRoomUrl');
        });
      }
    } else {
      setState(() {
        _screens = [
          const LoginScreen(),
        ];
      });
      _logger.warning('No user logged in. Setting LoginScreen as fallback.');
    }
  }

  @override
  void dispose() {
    _logger.info('MainScreen dispose called. Disposing auth subscription.');
    _authStateSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildVideoScreen() {
    _logger.info(
        'Building video screen. Daily room URL: $_dailyRoomUrl, isFetching: $_isFetchingRoomUrl');

    if (_isFetchingRoomUrl) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading video room...'),
            ],
          ),
        ),
      );
    }

    if (_dailyRoomUrl != null && _dailyRoomUrl!.isNotEmpty) {
      if (kIsWeb) {
        return VideoScreenWeb(videoUrl: _dailyRoomUrl!);
      } else {
        return VideoScreen(roomUrl: _dailyRoomUrl);
      }
    } else {
      // Show error with retry option
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Daily room URL not available',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'User ID: ${_currentUserId ?? "Unknown"}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (_currentUserId != null) {
                    _logger.info('Retrying Daily room URL fetch...');
                    final newUrl = await _getDailyRoomUrl(_currentUserId!);
                    setState(() {
                      _dailyRoomUrl = newUrl;
                    });
                  }
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
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
          // DEBUG: Show current Daily URL in debug mode
          if (_dailyRoomUrl != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Debug Info'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User ID: ${_currentUserId ?? "Unknown"}'),
                        const SizedBox(height: 8),
                        Text('Daily Room URL: $_dailyRoomUrl'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.upgrade),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaymentScreen(),
                ),
              );
            },
            tooltip: 'Upgrade',
          ),
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
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
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
            icon: Icon(Icons.videocam),
            label: 'Video',
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
