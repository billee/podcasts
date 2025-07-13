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
    // Removed _initializeAudioService() call, as it's handled in main.dart
    // The player listeners are already set up in AudioService's initialize method
    _audioService.audioPlayer.onPlayerComplete.listen((_) {
      _logger.info('Audio player completed playback in PodcastScreen.');
      setState(() {
        _audioService.stopAudio();
      });
    });
    _logger.info('PodcastScreen initialized and listeners set up.');
  }

  @override
  void dispose() {
    _logger
        .info('PodcastScreen dispose called. AudioService NOT disposed here.');
    // Removed _audioService.dispose() call, as it's handled globally in main.dart
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
            // No need to pass audioService, as AudioPlayerWidget will get the singleton
            AudioPlayerWidget(),
          ],
        ),
      ),
    );
  }
}
