// lib/screens/story_screen.dart

import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/services/audio_service.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/widgets/audio_player_widget.dart';
import 'package:kapwa_companion_basic/data/app_assets.dart';
import 'package:kapwa_companion_basic/core/config.dart';
import 'package:logging/logging.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final AudioService _audioService = AudioService();
  final Logger _logger = Logger('StoryScreen');

  @override
  void initState() {
    super.initState();
    _audioService.stopAudio();
    _initializeAudioWithSubscriptionCheck();
  }

  Future<void> _initializeAudioWithSubscriptionCheck() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // No user logged in, treat as trial
        await _audioService.setCurrentAudioFiles(
          AppAssets.storyAssets,
          isTrialUser: true,
          trialLimit: AppConfig.trialUserStoryLimit,
          audioType: 'story',
        );
        return;
      }

      final subscriptionStatus = await SubscriptionService.getSubscriptionStatus(user.uid);
      final isTrialUser = subscriptionStatus == SubscriptionStatus.trial || 
                         subscriptionStatus == SubscriptionStatus.trialExpired ||
                         subscriptionStatus == SubscriptionStatus.expired;

      if (isTrialUser) {
        _logger.info('Trial user detected - limiting story access to ${AppConfig.trialUserStoryLimit} audios');
        await _audioService.setCurrentAudioFiles(
          AppAssets.storyAssets,
          isTrialUser: true,
          trialLimit: AppConfig.trialUserStoryLimit,
          audioType: 'story',
        );
      } else {
        _logger.info('Premium user detected - full story access');
        await _audioService.setCurrentAudioFiles(
          AppAssets.storyAssets,
          isTrialUser: false,
        );
      }
    } catch (e) {
      _logger.severe('Error checking subscription status: $e');
      // Fallback to trial limits on error
      await _audioService.setCurrentAudioFiles(
        AppAssets.storyAssets,
        isTrialUser: true,
        trialLimit: AppConfig.trialUserStoryLimit,
        audioType: 'story',
      );
    }
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
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        // Removed title as requested, keeping AppBar for back button
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         kToolbarHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
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
                  const SizedBox(height: 32),
                  // AudioPlayerWidget with flexible sizing
                  Expanded(
                    child: Center(
                      child: AudioPlayerWidget(),
                    ),
                  ),
                  const SizedBox(height: 16), // Reduced from 32 to save space
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
