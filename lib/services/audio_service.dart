// lib/services/audio_service.dart

import 'package:flutter/foundation.dart'
    show kIsWeb; // Keep kIsWeb if you differentiate other logic
import 'package:audioplayers/audioplayers.dart';
import 'package:logging/logging.dart';
// You might need to import your AppAssets if you move the list there
import 'package:kapwa_companion_basic/data/app_assets.dart'; // Uncomment if using AppAssets
import 'package:kapwa_companion_basic/services/daily_audio_selection_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final Logger _logger = Logger('AudioService');
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Add index to track current position in the daily selection
  int _currentAudioIndex = 0;

  List<String> _allAudioFiles = [];
  List<String> _currentAudioFiles = [];
  bool _audioLoading = true;

  // Audio state
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _currentAudioPath;

  // Getters
  List<String> get currentAudioFiles => _currentAudioFiles;
  bool get audioLoading => _audioLoading;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  String? get currentAudioPath => _currentAudioPath;
  AudioPlayer get audioPlayer => _audioPlayer;

  // Audio files are now set by individual screens (podcast/story) via setCurrentAudioFiles

  Future<void> initialize() async {
    _logger.info('Initializing AudioService...');

    // Set up audio player listeners
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration;
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _currentPosition = Duration.zero;
      _isPlaying = false;
    });

    await _loadAudioFiles();
  }

  Future<void> _loadAudioFiles() async {
    try {
      _audioLoading = true;
      _logger.info(
          'AudioService initialized - audio files will be set by individual screens');

      // Don't load any specific audio files here - let the screens set them
      _allAudioFiles = [];
      _audioLoading = false;
      _refreshAudioFiles();
      _logger
          .info('AudioService ready - waiting for screen to set audio files');
    } catch (e) {
      print('ERROR in _loadAudioFiles: $e');
      _logger.severe('Error initializing audio service: $e');
      _audioLoading = false;
      // Fallback - empty list
      _allAudioFiles = [];
      _refreshAudioFiles();
    }
  }

  // NEW METHOD: Set current audio files to a specific list with trial user limits
  Future<void> setCurrentAudioFiles(List<String> audioFiles,
      {bool isTrialUser = false, int? trialLimit, String? audioType}) async {
    _logger.info(
        'Setting current audio files. Total available: ${audioFiles.length}, Trial user: $isTrialUser, Limit: $trialLimit');

    // Stop current audio if playing when switching audio sources
    if (_isPlaying || _currentAudioPath != null) {
      _logger
          .info('Stopping current audio before switching to new audio source');
      stopAudio();
    }

    // Apply trial user limits if applicable
    if (isTrialUser &&
        trialLimit != null &&
        trialLimit > 0 &&
        audioType != null) {
      try {
        // Get daily random selection for trial users
        final dailySelection =
            await DailyAudioSelectionService.getDailyRandomSelection(
          allAudioFiles: audioFiles,
          audioType: audioType,
          selectionLimit: trialLimit,
        );

        _allAudioFiles = dailySelection;
        _logger.info(
            'Trial user daily random selection applied: ${_allAudioFiles.length} audios available for $audioType');
        _audioLoading = false;
        _refreshAudioFiles(
            shouldShuffle: false); // Don't shuffle the daily selection
      } catch (e) {
        _logger.severe(
            'Error getting daily selection, falling back to first N audios: $e');
        // Fallback to original behavior if daily selection fails
        _allAudioFiles = audioFiles.take(trialLimit).toList();
        _logger.info(
            'Fallback: Trial user limit applied: ${_allAudioFiles.length} audios available');
        _audioLoading = false;
        _refreshAudioFiles(shouldShuffle: false);
      }
    } else {
      _allAudioFiles = List.from(audioFiles);
      _logger.info('Full access: ${_allAudioFiles.length} audios available');
      _audioLoading = false;
      _refreshAudioFiles(shouldShuffle: true); // Shuffle for premium users
    }
  }

  void _refreshAudioFiles({bool shouldShuffle = true}) {
    if (_allAudioFiles.isNotEmpty) {
      if (shouldShuffle) {
        _allAudioFiles.shuffle();
      }
      // Reset index when refreshing
      _currentAudioIndex = 0;
      _currentAudioFiles = _allAudioFiles.isNotEmpty
          ? _allAudioFiles.sublist(0, 1) // Show one audio file at a time
          : _allAudioFiles;
    } else {
      _currentAudioFiles = [];
      _currentAudioIndex = 0;
    }
  }

  void refreshCurrentAudioFiles() {
    if (_allAudioFiles.isNotEmpty) {
      // Cycle to the next audio in the daily selection
      _currentAudioIndex = (_currentAudioIndex + 1) % _allAudioFiles.length;
      _currentAudioFiles = [_allAudioFiles[_currentAudioIndex]];
      _logger.info(
          'Cycled to next audio: ${_currentAudioFiles.first} (index: $_currentAudioIndex/${_allAudioFiles.length})');
    }
  }

  Future<void> playAudio(String filePath) async {
    try {
      _logger.info('Playing audio: $filePath');
      _currentAudioPath = filePath;

      // Stop current audio if playing
      if (_isPlaying) {
        await _audioPlayer.stop();
      }

      // For bundled assets (which filePath now represents), always use AssetSource
      final assetPath = filePath.replaceFirst('assets/',
          ''); // Remove 'assets/' prefix if AssetSource expects path relative to assets/
      await _audioPlayer.play(AssetSource(assetPath));

      // If you still have scenarios for playing local device files (e.g., downloaded files),
      // you would need separate logic here, perhaps based on the `filePath` format.
      // But for bundled assets, AssetSource is the way.
    } catch (e) {
      _logger.severe('Error playing audio: $e'); // Updated log
    }
  }

  Future<void> pauseAudio() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      _logger.severe('Error pausing audio: $e'); // Updated log
    }
  }

  Future<void> resumeAudio() async {
    try {
      await _audioPlayer.resume();
    } catch (e) {
      _logger.severe('Error resuming audio: $e'); // Updated log
    }
  }

  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
      _currentPosition = Duration.zero;
      _currentAudioPath = null;
      _isPlaying = false;
    } catch (e) {
      _logger.severe('Error stopping audio: $e'); // Updated log
    }
  }

  Future<void> seekAudio(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      _logger.severe('Error seeking audio: $e'); // Updated log
    }
  }

  String getAudioFileName(String filePath) {
    // This logic is now unified for all platforms, as filePath will always be an asset path.
    // Asset paths use forward slashes.
    String fileName = filePath.split('/').last;

    return fileName
        .replaceAll('.wav', '')
        .replaceAll('.mp3', '')
        .replaceAll('.ogg', '')
        .replaceAll('.aac', '')
        .replaceAll('.m4a', '');
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
