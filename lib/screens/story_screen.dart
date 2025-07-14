// lib/screens/story_screen.dart

import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/services/audio_service.dart';
import 'package:kapwa_companion_basic/widgets/audio_player_widget.dart';
import 'package:kapwa_companion_basic/data/app_assets.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    _audioService.stopAudio();
    _audioService.setCurrentAudioFiles(AppAssets.storyAssets);
  }

  @override
  void dispose() {
    _audioService.stopAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Story',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 32),
          Icon(
            Icons.book,
            size: 80,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 16),
          const Text(
            'Mga Kuwento',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Listen to inspiring stories',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 32),
          // Centered AudioPlayerWidget
          Expanded(
            child: Center(
              child: AudioPlayerWidget(),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
