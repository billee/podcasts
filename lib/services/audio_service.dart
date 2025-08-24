// lib/services/audio_service.dart

import 'package:flutter/foundation.dart'
    show kIsWeb; // Keep kIsWeb if you differentiate other logic
import 'package:audioplayers/audioplayers.dart';
import 'package:logging/logging.dart';
// You might need to import your AppAssets if you move the list there
import 'package:kapwa_companion_basic/data/app_assets.dart'; // Uncomment if using AppAssets

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final Logger _logger = Logger('AudioService');
  final AudioPlayer _audioPlayer = AudioPlayer();

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

  // Use the list from AppAssets, now named podcastAssets
  static const List<String> _podcastAssets =
      AppAssets.podcastAssets; // Renamed variable

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
      _logger.info('Loading audio files from assets (for both web and mobile)');

      // Use the predefined list for all platforms for bundled assets
      _allAudioFiles = List.from(_podcastAssets);
      _audioLoading = false;
      _refreshAudioFiles();
      _logger.info('Loaded ${_allAudioFiles.length} podcast files from assets');
    } catch (e) {
      print('ERROR in _loadAudioFiles: $e');
      _logger.severe('Error loading podcast files: $e'); // Updated log
      _audioLoading = false;
      // Fallback - empty list
      _allAudioFiles = [];
      _refreshAudioFiles();
    }
  }

  // NEW METHOD: Set current audio files to a specific list with trial user limits
  void setCurrentAudioFiles(List<String> audioFiles, {bool isTrialUser = false, int? trialLimit}) {
    _logger.info('Setting current audio files. Total available: ${audioFiles.length}, Trial user: $isTrialUser, Limit: $trialLimit');

    // Stop current audio if playing when switching audio sources
    if (_isPlaying || _currentAudioPath != null) {
      _logger
          .info('Stopping current audio before switching to new audio source');
      stopAudio();
    }

    // Apply trial user limits if applicable
    if (isTrialUser && trialLimit != null && trialLimit > 0) {
      // Always get the first N audios for trial users (no shuffling)
      _allAudioFiles = audioFiles.take(trialLimit).toList();
      _logger.info('Trial user limit applied: ${_allAudioFiles.length} audios available');
      _audioLoading = false;
      _refreshAudioFiles(shouldShuffle: false); // Don't shuffle for trial users
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
      _currentAudioFiles = _allAudioFiles.isNotEmpty
          ? _allAudioFiles.sublist(0, 1) // Show one audio file at a time
          : _allAudioFiles;
    } else {
      _currentAudioFiles = [];
    }
  }

  void refreshCurrentAudioFiles() {
    _refreshAudioFiles();
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
