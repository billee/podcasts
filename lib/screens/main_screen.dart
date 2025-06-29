import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/screens/chat_screen.dart';
import 'package:kapwa_companion_basic/screens/contacts_screen.dart';
import 'package:kapwa_companion_basic/screens/profile_screen.dart';
import 'package:kapwa_companion_basic/services/video_conference_service.dart';
import 'package:kapwa_companion_basic/core/config.dart';

class MainScreen extends StatefulWidget {
  final DirectVideoCallService videoService;
  
  const MainScreen({
    super.key,
    required this.videoService,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ChatScreen(videoService: widget.videoService),
      ContactsScreen(videoService: widget.videoService),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
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
      ),
    );
  }
}