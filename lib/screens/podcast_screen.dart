// lib/screens/podcast_screen.dart

import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/widgets/audio_player_widget.dart';
import 'package:kapwa_companion_basic/services/audio_service.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/data/app_assets.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  final Logger _logger = Logger('PodcastScreen');
  // Obtain the singleton AudioService instance. It's initialized in main.dart.
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    _logger.info('PodcastScreen initState called.');
    _audioService.stopAudio();
    _audioService.setCurrentAudioFiles(AppAssets.podcastAssets);
  }

  @override
  void dispose() {
    _logger.info('PodcastScreen dispose called.');
    _audioService.stopAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        // Removed title as requested, keeping AppBar for back button
      ),
      body: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.mic, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 16),
          const Text(
            'Podcast',
            style: TextStyle(fontSize: 18),
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
