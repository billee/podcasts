// lib/screens/podcast_screen.dart

import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/widgets/audio_player_widget.dart';
import 'package:kapwa_companion_basic/services/audio_service.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/data/app_assets.dart';
import 'package:kapwa_companion_basic/core/config.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  final Logger _logger = Logger('PodcastScreen');
  // Obtain the singleton AudioService instance. It's initialized in main.dart.
  final AudioService _audioService = AudioService();
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _logger.info('PodcastScreen initState called.');
    _audioService.stopAudio();
    _initializeAudioWithSubscriptionCheck();
  }

  Future<void> _initializeAudioWithSubscriptionCheck() async {
    try {
      setState(() {
        _isInitializing = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // No user logged in, treat as trial
        await _audioService.setCurrentAudioFiles(
          AppAssets.podcastAssets,
          isTrialUser: true,
          trialLimit: AppConfig.trialUserPodcastLimit,
          audioType: 'podcast',
        );
        setState(() {
          _isInitializing = false;
        });
        return;
      }

      final subscriptionStatus =
          await SubscriptionService.getSubscriptionStatus(user.uid);
      final isTrialUser = subscriptionStatus == SubscriptionStatus.trial ||
          subscriptionStatus == SubscriptionStatus.trialExpired ||
          subscriptionStatus == SubscriptionStatus.expired;

      if (isTrialUser) {
        _logger.info(
            'Trial user detected - limiting podcast access to ${AppConfig.trialUserPodcastLimit} audios');
        await _audioService.setCurrentAudioFiles(
          AppAssets.podcastAssets,
          isTrialUser: true,
          trialLimit: AppConfig.trialUserPodcastLimit,
          audioType: 'podcast',
        );
      } else {
        _logger.info('Premium user detected - full podcast access');
        await _audioService.setCurrentAudioFiles(
          AppAssets.podcastAssets,
          isTrialUser: false,
        );
      }

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      _logger.severe('Error checking subscription status: $e');
      // Fallback to trial limits on error
      await _audioService.setCurrentAudioFiles(
        AppAssets.podcastAssets,
        isTrialUser: true,
        trialLimit: AppConfig.trialUserPodcastLimit,
        audioType: 'podcast',
      );
      setState(() {
        _isInitializing = false;
      });
    }
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
          // Show loading indicator while initializing, then AudioPlayerWidget
          Expanded(
            child: Center(
              child: _isInitializing
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white70),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading podcasts...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    )
                  : AudioPlayerWidget(),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
