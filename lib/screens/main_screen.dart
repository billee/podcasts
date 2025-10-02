// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/screens/podcast_screen.dart';
import 'package:logging/logging.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  final Logger _logger = Logger('MainScreen');
  final String _anonymousUserId = 'anonymous_user';

  @override
  void initState() {
    super.initState();
    _logger.info('MainScreen initialized');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Podcasts'),
        backgroundColor: Colors.grey[900],
      ),
      body: PodcastScreen(userId: _anonymousUserId),
    );
  }
}
