// lib/services/simple_video_service.dart
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SimpleVideoService {
  static final SimpleVideoService _instance = SimpleVideoService._internal();
  factory SimpleVideoService() => _instance;
  SimpleVideoService._internal();

  IO.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _currentCallId;

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = false;
  bool _isFrontCamera = true;

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(String, String, bool)?
      onIncomingCall; // callerId, callerName, isVideo
  Function()? onCallEnded;

  Function(bool)? onConnectionStateChanged;
  Function(String)? onError;
  Function(Map<String, dynamic>)?
      onParticipantJoined; // Pass a map with participantId as String
  Function(String)? onParticipantLeft;

  bool get isMuted => _isMuted;
  bool get isVideoOff => _isVideoOff;
  bool get isSpeakerOn => _isSpeakerOn;
  String? get currentRoomId => _currentCallId;

  // Simple server URL - you can use a free service like Socket.IO
  //static const String _serverUrl = 'https://your-simple-server.herokuapp.com';
  static const String _serverUrl = 'http://10.0.0.93:3000';

  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });

    // Emit to other participant
    _socket?.emit('audio-toggle', {'isMuted': _isMuted});
  }

  void toggleVideo() {
    _isVideoOff = !_isVideoOff;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !_isVideoOff;
    });

    // Emit to other participant
    _socket?.emit('video-toggle', {'isVideoOff': _isVideoOff});
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    // Note: Speaker control is platform-specific and may need platform channels
    // For web, this is handled by the browser's audio routing
    print('Speaker ${_isSpeakerOn ? 'enabled' : 'disabled'}');
  }

  Future<void> switchCamera() async {
    try {
      _isFrontCamera = !_isFrontCamera;

      // Stop current stream
      _localStream?.getTracks().forEach((track) => track.stop());

      // Get new stream with opposite camera
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': _isFrontCamera ? 'user' : 'environment'}
      });

      // Apply current mute/video settings to new stream
      _localStream?.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });

      _localStream?.getVideoTracks().forEach((track) {
        track.enabled = !_isVideoOff;
      });

      // Update UI
      onLocalStream?.call(_localStream!);

      print('Camera switched to ${_isFrontCamera ? 'front' : 'back'}');
    } catch (e) {
      onError?.call('Failed to switch camera: $e');
      print('Camera switch error: $e');
    }
  }

  Future<void> initialize(String userId) async {
    _socket = IO.io(_serverUrl, {
      'transports': ['websocket'],
      'query': {'userId': userId}
    });

    _socket!.on('connect', (_) {
      print('Connected to server');
      onConnectionStateChanged?.call(true);
    });

    _socket!.on('incoming-call', (data) {
      _currentCallId = data['callerId'];
      onIncomingCall?.call(
          data['callerId'], data['callerName'], data['isVideo']);
    });

    _socket!.on('call-accepted', (_) {
      // When the other person accepts, treat them as "joined"
      onParticipantJoined?.call({
        'participantId': _currentCallId ?? 'remote-user', // Return as String
        'name': 'Remote User'
      });
    });

    _socket!.on('call-ended', (_) {
      onParticipantLeft?.call(_currentCallId ?? 'remote-user');
      onCallEnded?.call();
      _cleanup();
    });

    _socket!.on('disconnect', (_) {
      onConnectionStateChanged?.call(false);
    });

    _socket!.on('audio-toggle', (data) {
      print('Remote participant ${data['isMuted'] ? 'muted' : 'unmuted'}');
    });

    _socket!.on('video-toggle', (data) {
      print(
          'Remote participant ${data['isVideoOff'] ? 'turned off' : 'turned on'} video');
    });

    _socket!.connect();
  }

  Future<void> createRoom() async {
    await _setupLocalStream();
    _currentCallId = DateTime.now().millisecondsSinceEpoch.toString();
    print('Ready to make/receive calls');
  }

  Future<void> startCall() async {
    await _setupLocalStream();
    print('Call started - waiting for connection');
  }

  // Add joinRoom method (for accepting/joining a call)
  Future<void> joinRoom(String roomId) async {
    _currentCallId = roomId;
    await acceptCall();
  }

  // Make a simple call like WhatsApp
  Future<void> makeCall(
      String contactId, String contactName, bool isVideo) async {
    _currentCallId = contactId;
    _socket!.emit('make-call',
        {'to': contactId, 'callerName': contactName, 'isVideo': isVideo});
  }

  // Accept incoming call
  Future<void> acceptCall() async {
    _socket!.emit('accept-call');
    await _setupLocalStream();
  }

  // Decline call
  void declineCall() {
    _socket!.emit('decline-call');
    _currentCallId = null;
  }

  Future<void> endCall() async {
    _socket!.emit('end-call');
    await _cleanup();
  }

  Future<void> _setupLocalStream() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user' // Start with front camera
        }
      });

      // Reset state
      _isMuted = false;
      _isVideoOff = false;
      _isFrontCamera = true;

      onLocalStream?.call(_localStream!);
    } catch (e) {
      onError?.call('Failed to get media: $e');
    }
  }

  Future<void> _cleanup() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;
    await _peerConnection?.close();
    _peerConnection = null;
    _currentCallId = null;

    // Reset state
    _isMuted = false;
    _isVideoOff = false;
    _isSpeakerOn = false;
    _isFrontCamera = true;
  }
}
