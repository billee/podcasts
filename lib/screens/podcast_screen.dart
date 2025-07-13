// lib/screens/podcast_screen.dart

import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/widgets/audio_player_widget.dart';
import 'package:kapwa_companion_basic/services/audio_service.dart';
import 'package:logging/logging.dart';

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
    // IMPORTANT: Removed _initializeAudioService() call, as it's handled globally in main.dart
    // Player listeners should ideally be set up once in AudioService's initialize method
    // and not repeatedly here. If any specific PodcastScreen UI depends on player completion,
    // you might listen to _audioService.audioPlayer.onPlayerComplete, but the stop logic
    // should be handled within AudioService itself for consistency.
    _audioService.audioPlayer.onPlayerComplete.listen((_) {
      _logger
          .info('Audio player completed playback in PodcastScreen listener.');
      // You might want to update local UI state if needed, but not stop the global service.
    });
    _logger.info('PodcastScreen initialized and listeners (if any) set up.');
  }

  @override
  void dispose() {
    _logger
        .info('PodcastScreen dispose called. AudioService NOT disposed here.');
    // IMPORTANT: Removed _audioService.dispose() call.
    // AudioService is a global singleton, its lifecycle is managed by main.dart.
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
