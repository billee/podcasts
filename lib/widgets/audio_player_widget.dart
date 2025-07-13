// lib/widgets/audio_player_widget.dart

import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/services/audio_service.dart';
//import 'package:logging/logging.dart';

class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget({super.key});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  //final Logger _logger = Logger('AudioPlayerWidget');
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    // Listen to audio player state changes
    _audioService.audioPlayer.onPlayerStateChanged.listen((_) {
      if (mounted) setState(() {});
    });

    _audioService.audioPlayer.onPositionChanged.listen((_) {
      if (mounted) setState(() {});
    });

    _audioService.audioPlayer.onDurationChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _debugAudioState() {
    print('Current audio path: ${_audioService.currentAudioPath}');
    print('Audio files: ${_audioService.currentAudioFiles}');
    print('Is playing: ${_audioService.isPlaying}');
    print('Audio loading: ${_audioService.audioLoading}');
  }

  void _handleAudioTap(String audioPath) {
    _debugAudioState();

    print('Audio tap: $audioPath');

    if (_audioService.currentAudioPath == audioPath &&
        _audioService.isPlaying) {
      _audioService.pauseAudio();
    } else if (_audioService.currentAudioPath == audioPath &&
        !_audioService.isPlaying) {
      _audioService.resumeAudio();
    } else {
      _audioService.playAudio(audioPath);
    }
  }

  void _handlePlayPause() {
    if (_audioService.isPlaying) {
      _audioService.pauseAudio();
    } else if (_audioService.currentAudioPath != null) {
      _audioService.resumeAudio();
    }
  }

  void _handleStop() {
    _audioService.stopAudio();
  }

  void _handleSliderChange(double value) {
    final duration = Duration(milliseconds: value.toInt());
    _audioService.seekAudio(duration);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAudioChips(),
        if (_audioService.currentAudioPath != null) _buildAudioControls(),
      ],
    );
  }

  Widget _buildAudioChips() {
    //print('Audio loading: ${_audioService.audioLoading}');
    //print('Audio files count: ${_audioService.currentAudioFiles.length}');

    if (_audioService.audioLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
      );
    }

    if (_audioService.currentAudioFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        children: [
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _audioService.currentAudioFiles.map((audioPath) {
              final fileName = _audioService.getAudioFileName(audioPath);
              final isCurrentlyPlaying =
                  _audioService.currentAudioPath == audioPath &&
                      _audioService.isPlaying;

              return ActionChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      fileName,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                onPressed: () => _handleAudioTap(audioPath),
                backgroundColor:
                    isCurrentlyPlaying ? Colors.blue[700] : Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey[600]!),
                ),
              );
            }).toList(),
          ),
          // Refresh button
          TextButton.icon(
            onPressed: () {
              setState(() {
                _audioService.refreshCurrentAudioFiles();
              });
            },
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 16),
            label: const Text(
              'Next Audio',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Audio title
          Text(
            _audioService.getAudioFileName(_audioService.currentAudioPath!),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Progress slider
          Row(
            children: [
              Text(
                _formatDuration(_audioService.currentPosition),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value:
                      _audioService.currentPosition.inMilliseconds.toDouble(),
                  max: _audioService.totalDuration.inMilliseconds.toDouble(),
                  onChanged: _handleSliderChange,
                  activeColor: Colors.blue[600],
                  inactiveColor: Colors.grey[600],
                ),
              ),
              Text(
                _formatDuration(_audioService.totalDuration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _handleStop,
                icon: const Icon(Icons.stop, color: Colors.white70),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _handlePlayPause,
                icon: Icon(
                  _audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
