// lib/screens/video_conference_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for Clipboard
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kapwa_companion/services/video_conference_service.dart'; // Import the new direct call service
//import 'package:logging/logging.dart'; // Uncomment if you use logging within this file

class VideoConferenceScreen extends StatefulWidget {
  // We no longer need roomId, but rather the contactId (the user we're calling/connected to)
  final String contactId;
  final bool isIncoming; // true if it's an incoming call being accepted, false if it's an outgoing call
  final bool isVideoCall; // True for video, false for audio only
  final DirectVideoCallService videoCallService; // The service instance

  const VideoConferenceScreen({
    super.key,
    required this.contactId,
    required this.isIncoming,
    required this.isVideoCall,
    required this.videoCallService, // Receive the service instance
  });

  @override
  State<VideoConferenceScreen> createState() => _VideoConferenceScreenState();
}

class _VideoConferenceScreenState extends State<VideoConferenceScreen> {
  //final Logger _logger = Logger('VideoConferenceScreen'); // Uncomment if using logger

  // Use the passed service instance
  late final DirectVideoCallService _videoService; // Marked as late final

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  String _connectionStatus = 'Connecting...';
  // Note: _isInCall and _isConnecting states will primarily be driven by _connectionStatus
  // from the service callbacks.

  @override
  void initState() {
    super.initState();
    _videoService = widget.videoCallService; // Assign the passed service instance

    _initializeRenderers();
    _setupVideoServiceCallbacks();

    // Initial status based on whether it's an outgoing or incoming call
    if (!widget.isIncoming) {
      _connectionStatus = 'Calling ${widget.contactId}...';
    } else {
      _connectionStatus = 'Connecting to ${widget.contactId}...';
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
        _connectionStatus = isConnected ? 'Connected with ${widget.contactId}' : 'Connecting...';
      });
      // If connected, ensure the speaker is on for the remote audio
      if (isConnected && !_videoService.isSpeakerOn) {
        _videoService.toggleSpeaker(); // Ensure speaker is on when connected
      }
    };

    _videoService.onError = (error) {
      _showErrorDialog(error);
      setState(() {
        _connectionStatus = 'Disconnected: $error';
      });
    };

    // The following callbacks are already handled in contacts_screen,
    // which pops this screen. But having them here as a fallback or for logging
    // might be useful in complex scenarios. For direct calls, usually the
    // contacts_screen handles the popping logic on call end/decline.
    _videoService.onCallEnded = (partnerId) {
      _showSnackBar('$partnerId ended the call.');
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Pop this screen if partner ends
      }
    };

    _videoService.onCallDeclined = (partnerId) {
      _showSnackBar('$partnerId declined your call.');
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Pop this screen if call declined
      }
    };

    _videoService.onPartnerDisconnected = (disconnectedUserId) {
      _showSnackBar('$disconnectedUserId disconnected.');
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Pop this screen if partner disconnects
      }
    };
  }

  // This function is now only about ending the current active call.
  Future<void> _endCall() async {
    await _videoService.endCall();
    // After ending the call, we navigate back to the previous screen (ContactsScreen).
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
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
    // Check if the current context has a ScaffoldMessenger
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Call with ${widget.contactId}'), // Show partner's ID
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // No back button during active call
      ),
      body: _buildCallInterface(), // Always show the call interface
    );
  }

  Widget _buildCallInterface() {
    return Stack(
      children: [
        // Remote video (full screen) - Only show if video call and remote stream available
        widget.isVideoCall && _remoteRenderer.srcObject != null
            ? RTCVideoView(_remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            : Container(
          color: Colors.grey[800],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.isVideoCall ? Icons.person : Icons.call, size: 80, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  _connectionStatus, // Show actual connection status
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (!widget.isVideoCall) // Show voice call icon if it's a voice call
                  const Icon(Icons.mic, size: 40, color: Colors.white54),
              ],
            ),
          ),
        ),

        // Local video (picture-in-picture) - Only show if video call
        if (widget.isVideoCall)
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

        // Connection status overlay (e.g., "Connecting...", "Calling...")
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
                if (_connectionStatus.contains('Connecting') || _connectionStatus.contains('Calling'))
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                if (_connectionStatus.contains('Connecting') || _connectionStatus.contains('Calling'))
                  const SizedBox(width: 8),
                Text(
                  _connectionStatus,
                  style: const TextStyle(color: Colors.white),
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
                onPressed: () => setState(() => _videoService.toggleMute()), // Update UI on toggle
                backgroundColor: _videoService.isMuted ? Colors.red : Colors.grey[700],
              ),
              // Only show video toggle if it's a video call
              if (widget.isVideoCall)
                _buildControlButton(
                  icon: _videoService.isVideoOff ? Icons.videocam_off : Icons.videocam,
                  onPressed: () => setState(() => _videoService.toggleVideo()), // Update UI on toggle
                  backgroundColor: _videoService.isVideoOff ? Colors.red : Colors.grey[700],
                ),
              // Only show switch camera if it's a video call
              if (widget.isVideoCall)
                _buildControlButton(
                  icon: Icons.switch_camera,
                  onPressed: _videoService.switchCamera,
                  backgroundColor: Colors.grey[700],
                ),
              _buildControlButton(
                icon: _videoService.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                onPressed: () => setState(() => _videoService.toggleSpeaker()), // Update UI on toggle
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
    // Only dispose renderers here. The _videoService is managed externally
    // (in ContactsScreen) and will be disposed there.
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }
}