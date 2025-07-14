// lib/screens/podcast_screen.dart

import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/widgets/audio_player_widget.dart';
import 'package:kapwa_companion_basic/services/audio_service.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/data/app_assets.dart';

class PodcastScreen extends StatefulWidget {
  // Removed audioService parameter as it will get the singleton directly
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
    _logger
        .info('PodcastScreen dispose called. AudioService NOT disposed here.');
    // IMPORTANT: Removed _audioService.dispose() call.
    // AudioService is a global singleton, its lifecycle is managed by main.dart.
    _audioService.stopAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Podcast'),
        backgroundColor: Colors.grey[900],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 16),
            const Text(
              'Podcast content will go here.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            // AudioPlayerWidget will get the singleton AudioService instance directly
            AudioPlayerWidget(),
          ],
        ),
      ),
    );
  }
}
