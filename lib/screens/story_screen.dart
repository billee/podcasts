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
    // Set the story audio files when the screen initializes
    // This will automatically stop any playing podcast audio
    _audioService.stopAudio();
    _audioService.setCurrentAudioFiles(AppAssets.storyAssets);
  }

  @override
  void dispose() {
    // Reset to podcast assets when leaving the story screen
    // This will automatically stop any playing story audio
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
          // Main content area
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                ],
              ),
            ),
          ),
          // Audio player widget at the bottom
          Container(
            color: Colors.grey[850],
            child: const AudioPlayerWidget(),
          ),
        ],
      ),
    );
  }
}
