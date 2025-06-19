// lib/services/audio_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';
import 'package:logging/logging.dart';

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

  static const String _audioSourcesPath = './audio_sources';

  // Predefined audio assets for web
  static const List<String> _audioAssets = [
    'assets/audio_sources/alone_abroad.wav',
    'assets/audio_sources/beyond_remittances.wav',
    'assets/audio_sources/essential_mental_health.wav',
  ];

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

      if (kIsWeb) {
        // Web platform: use predefined assets
        _logger.info('Running on web - using predefined audio assets');
        _allAudioFiles = List.from(_audioAssets);
        _audioLoading = false;
        _refreshAudioFiles();
        _logger.info('Loaded ${_allAudioFiles.length} audio files from assets');
        return;
      }

      // Desktop platform: use file system
      _logger.info('Running on desktop - scanning file system');
      print('=== AudioService Debug ===');
      print('Current working directory: ${Directory.current.path}');
      print('Looking for: $_audioSourcesPath');

      final directory = Directory(_audioSourcesPath);
      final absolutePath = directory.absolute.path;
      print('Absolute path: $absolutePath');
      print('Directory exists: ${await directory.exists()}');

      if (!await directory.exists()) {
        _logger.warning(
            'Audio sources directory does not exist: $_audioSourcesPath');

        final altPath1 = Directory('./audio_sources');
        final altPath2 = Directory('audio_sources');
        print(
            'Alt path 1 (./audio_sources) exists: ${await altPath1.exists()}');
        print('Alt path 2 (audio_sources) exists: ${await altPath2.exists()}');

        _audioLoading = false;
        return;
      }

      print('Directory found! Listing contents...');

      final List<String> audioFiles = [];
      await for (final entity in directory.list()) {
        print('Found entity: ${entity.path} (type: ${entity.runtimeType})');

        if (entity is File) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final extension = fileName.toLowerCase().split('.').last;

          print('File: $fileName, Extension: $extension');

          // Support common audio formats
          if (['wav', 'mp3', 'ogg', 'aac', 'm4a'].contains(extension)) {
            audioFiles.add(entity.path);
            print('✓ Added audio file: $fileName');
          } else {
            print('✗ Skipping non-audio file: $fileName');
          }
        }
      }

      _allAudioFiles = audioFiles;
      _audioLoading = false;
      _refreshAudioFiles();

      print('Final result: ${_allAudioFiles.length} audio files loaded');
      print('Current audio files: $_currentAudioFiles');
      print('=== End Debug ===');
    } catch (e) {
      print('ERROR in _loadAudioFiles: $e');
      _logger.severe('Error loading audio files: $e');
      _audioLoading = false;
      // Fallback - empty list
      _allAudioFiles = [];
      _refreshAudioFiles();
    }
  }

  void _refreshAudioFiles() {
    if (_allAudioFiles.isNotEmpty) {
      _allAudioFiles.shuffle();
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

      if (kIsWeb) {
        // Web: use AssetSource
        final assetPath = filePath.replaceFirst('assets/', '');
        await _audioPlayer.play(AssetSource(assetPath));
      } else {
        // Desktop: use DeviceFileSource
        await _audioPlayer.play(DeviceFileSource(filePath));
      }
    } catch (e) {
      _logger.severe('Error playing audio: $e');
    }
  }

  Future<void> pauseAudio() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      _logger.severe('Error pausing audio: $e');
    }
  }

  Future<void> resumeAudio() async {
    try {
      await _audioPlayer.resume();
    } catch (e) {
      _logger.severe('Error resuming audio: $e');
    }
  }

  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
      _currentPosition = Duration.zero;
      _currentAudioPath = null;
    } catch (e) {
      _logger.severe('Error stopping audio: $e');
    }
  }

  Future<void> seekAudio(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      _logger.severe('Error seeking audio: $e');
    }
  }

  String getAudioFileName(String filePath) {
    String fileName;
    if (kIsWeb) {
      fileName = filePath.split('/').last;
    } else {
      fileName = filePath.split(Platform.pathSeparator).last;
    }

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
