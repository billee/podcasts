// lib/screens/video_conference_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kapwa_companion/services/video_conference_service.dart';
//import 'package:logging/logging.dart';

class VideoConferenceScreen extends StatefulWidget {
  final String? roomId;

  const VideoConferenceScreen({super.key, this.roomId});

  @override
  State<VideoConferenceScreen> createState() => _VideoConferenceScreenState();
}

class _VideoConferenceScreenState extends State<VideoConferenceScreen> {
  //final Logger _logger = Logger('VideoConferenceScreen');
  final SimpleVideoService _videoService = SimpleVideoService();
  final TextEditingController _roomIdController = TextEditingController();

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isInCall = false;
  bool _isConnecting = false;
  String _connectionStatus = 'Disconnected';
  final List<String> _participants = [];

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _setupVideoServiceCallbacks();

    if (widget.roomId != null) {
      _roomIdController.text = widget.roomId!;
    }
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupVideoServiceCallbacks() {
    _videoService.onLocalStream = (stream) {
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };

    _videoService.onRemoteStream = (stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
      });
    };

    _videoService.onConnectionStateChanged = (isConnected) {
      setState(() {
        _connectionStatus = isConnected ? 'Connected' : 'Connecting...';
        _isInCall = isConnected;
        _isConnecting = !isConnected && _isInCall;
      });
    };

    _videoService.onError = (error) {
      _showErrorDialog(error);
      setState(() {
        _isConnecting = false;
      });
    };

    _videoService.onParticipantJoined = (participant) {
      setState(() {
        _participants.add(participant['participantId'] as String);
      });
      _showSnackBar('${participant['participantId']} joined the call');
    };

    _videoService.onParticipantLeft = (participantId) {
      setState(() {
        _participants.remove(participantId);
      });
      _showSnackBar('$participantId left the call');
    };
  }

  Future<void> _createRoom() async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Creating room...';
    });

    await _videoService.createRoom();
    _roomIdController.text = _videoService.currentRoomId ?? '';
    await _videoService.startCall();
  }

  Future<void> _joinRoom() async {
    final roomId = _roomIdController.text.trim();
    if (roomId.isEmpty) {
      _showErrorDialog('Please enter a room ID');
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Joining room...';
    });

    await _videoService.joinRoom(roomId);
    await _videoService.startCall();
  }

  Future<void> _endCall() async {
    await _videoService.endCall();
    setState(() {
      _isInCall = false;
      _isConnecting = false;
      _connectionStatus = 'Disconnected';
      _participants.clear();
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    });
  }

  void _copyRoomId() {
    if (_videoService.currentRoomId != null) {
      Clipboard.setData(ClipboardData(text: _videoService.currentRoomId!));
      _showSnackBar('Room ID copied to clipboard');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Video Conference'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          if (_isInCall && _videoService.currentRoomId != null)
            IconButton(
              onPressed: _copyRoomId,
              icon: const Icon(Icons.copy),
              tooltip: 'Copy Room ID',
            ),
        ],
      ),
      body: _isInCall || _isConnecting
          ? _buildCallInterface()
          : _buildJoinInterface(),
    );
  }

  Widget _buildJoinInterface() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_call,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 32),
          const Text(
            'Video Conference',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Connect with OFW counselors and support groups',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _roomIdController,
            decoration: InputDecoration(
              labelText: 'Room ID (optional)',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'Enter room ID to join existing room',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createRoom,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Room'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _joinRoom,
                  icon: const Icon(Icons.login),
                  label: const Text('Join Room'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Status: $_connectionStatus',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildCallInterface() {
    return Stack(
      children: [
        // Remote video (full screen)
        _remoteRenderer.srcObject != null
            ? RTCVideoView(_remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            : Container(
                color: Colors.grey[800],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person, size: 80, color: Colors.white54),
                      SizedBox(height: 16),
                      Text(
                        'Waiting for participant...',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

        // Local video (picture-in-picture)
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _localRenderer.srcObject != null
                  ? RTCVideoView(_localRenderer, mirror: true)
                  : Container(
                      color: Colors.grey[700],
                      child:
                          const Icon(Icons.videocam_off, color: Colors.white54),
                    ),
            ),
          ),
        ),

        // Connection status
        if (_isConnecting)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _connectionStatus,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        // Room ID display
        if (_videoService.currentRoomId != null)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.room, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Room: ${_videoService.currentRoomId}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

        // Control buttons
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _videoService.isMuted ? Icons.mic_off : Icons.mic,
                onPressed: _videoService.toggleMute,
                backgroundColor:
                    _videoService.isMuted ? Colors.red : Colors.grey[700],
              ),
              _buildControlButton(
                icon: _videoService.isVideoOff
                    ? Icons.videocam_off
                    : Icons.videocam,
                onPressed: _videoService.toggleVideo,
                backgroundColor:
                    _videoService.isVideoOff ? Colors.red : Colors.grey[700],
              ),
              _buildControlButton(
                icon: Icons.switch_camera,
                onPressed: _videoService.switchCamera,
                backgroundColor: Colors.grey[700],
              ),
              _buildControlButton(
                icon: _videoService.isSpeakerOn
                    ? Icons.volume_up
                    : Icons.volume_off,
                onPressed: _videoService.toggleSpeaker,
                backgroundColor: Colors.grey[700],
              ),
              _buildControlButton(
                icon: Icons.call_end,
                onPressed: _endCall,
                backgroundColor: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[700],
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        iconSize: 28,
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _roomIdController.dispose();
    super.dispose();
  }
}
