// lib/services/video_conference_service.dart

import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:logging/logging.dart';

// You will need to replace this with your deployed signaling server URL
// For example: 'https://your-signaling-server.render.com/'
const String _SIGNALING_SERVER_URL = 'http://localhost:3000'; // Placeholder, replace this!

class DirectVideoCallService {
  final Logger _logger = Logger('DirectVideoCallService');

  IO.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  String? _currentUserId; // The ID of the currently logged-in user
  String? _targetUserId; // The ID of the user being called or who called us

  // Callbacks for UI updates
  Function(MediaStream?)? onLocalStream;
  Function(MediaStream?)? onRemoteStream;
  Function(bool)? onConnectionStateChanged;
  Function(String, String, bool, RTCSessionDescription)? onIncomingCall; // Added sdpOffer
  Function(String)? onError;
  Function(String)? onCallEnded;
  Function(String)? onCallDeclined;
  Function(String)? onCallAccepted; // For the caller
  Function(String)? onPartnerDisconnected;

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true; // Default to speaker on for calls
  bool _isIncomingCall = false; // To differentiate caller/callee roles

  // Getters for UI to know current states
  bool get isMuted => _isMuted;
  bool get isVideoOff => _isVideoOff;
  bool get isSpeakerOn => _isSpeakerOn;
  String? get currentCallPartnerId => _targetUserId;

  // ICE (Interactive Connectivity Establishment) servers configuration
  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'}, // Google STUN server
      // You can add TURN servers here for better NAT traversal, especially for production
      // {'urls': 'turn:YOUR_TURN_SERVER_IP:PORT', 'username': 'YOUR_USERNAME', 'credential': 'YOUR_PASSWORD'},
    ],
  };

  // Initialize the service: connect to signaling server and set user ID
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    _logger.info('Initializing DirectVideoCallService for user: $_currentUserId');

    _socket = IO.io(
      _SIGNALING_SERVER_URL,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'userId': _currentUserId})
          .enableForceNew()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      _logger.info('Connected to signaling server.');
      onConnectionStateChanged?.call(false); // Indicate connecting
    });

    _socket!.on('ready', (data) {
      _logger.info('Signaling server ready. User ID: ${data['userId']}');
    });

    _socket!.on('connect_error', (data) {
      _logger.severe('Signaling server connection error: $data');
      onError?.call('Signaling server connection error: $data');
      onConnectionStateChanged?.call(false);
    });

    _socket!.on('disconnect', (_) {
      _logger.info('Disconnected from signaling server.');
      _closePeerConnection(); // Clean up WebRTC connection
      onConnectionStateChanged?.call(false);
      onCallEnded?.call('Disconnected from server'); // Notify UI call ended
    });

    _socket!.on('error', (data) {
      _logger.severe('Signaling error from server: $data');
      onError?.call('Signaling error: ${data['message']}');
    });

    // --- Direct Call Specific Events ---
    _socket!.on('incoming-direct-call', (data) {
      _logger.info('Incoming direct call from: ${data['callerId']}');
      _isIncomingCall = true;
      _targetUserId = data['callerId']; // Set target to caller ID
      if (onIncomingCall != null) {
        // Pass the SDP offer directly to the UI/handler
        final sdpOffer = RTCSessionDescription(data['sdpOffer']['sdp'], data['sdpOffer']['type']);
        onIncomingCall!(data['callerId'], data['callerName'], data['isVideo'], sdpOffer);
      }
    });

    _socket!.on('offer', (data) async {
      _logger.info('Received SDP Offer from: ${data['fromUserId']}');
      await _handleOffer(data['sdpOffer']);
    });

    _socket!.on('answer', (data) async {
      _logger.info('Received SDP Answer from: ${data['fromUserId']}');
      await _handleAnswer(data['sdpAnswer']);
    });

    _socket!.on('candidate', (data) async {
      _logger.info('Received ICE Candidate from: ${data['fromUserId']}');
      await _handleCandidate(data['candidate']);
    });

    _socket!.on('call-accepted-by-callee', (data) async {
      _logger.info('Call accepted by callee: ${data['calleeId']}');
      onCallAccepted?.call(data['calleeId']);
      // Handle the initial SDP answer from the callee to finalize connection
      final sdpAnswer = RTCSessionDescription(data['sdpAnswer']['sdp'], data['sdpAnswer']['type']);
      await _peerConnection!.setRemoteDescription(sdpAnswer);
      onConnectionStateChanged?.call(true); // Call is now truly connected
    });

    _socket!.on('call-declined-by-callee', (data) {
      _logger.info('Call declined by callee: ${data['calleeId']}');
      _closePeerConnection();
      onCallDeclined?.call(data['calleeId']);
    });

    _socket!.on('call-ended', (data) {
      _logger.info('Call ended by: ${data['fromUserId']}');
      _closePeerConnection();
      onCallEnded?.call(data['fromUserId']);
    });

    _socket!.on('partner-disconnected', (data) {
      _logger.info('Partner disconnected: ${data['disconnectedUserId']}');
      _closePeerConnection();
      onPartnerDisconnected?.call(data['disconnectedUserId']);
    });

    _socket!.on('audio-toggle', (data) {
        _logger.info('Remote audio toggle from ${data['fromUserId']}: isMuted = ${data['isMuted']}');
        // This is mainly for UI feedback or if you want to explicitly show remote muted status
    });

    _socket!.on('video-toggle', (data) {
        _logger.info('Remote video toggle from ${data['fromUserId']}: isVideoOff = ${data['isVideoOff']}');
        // This is mainly for UI feedback or if you want to explicitly show remote video status
    });
  }

  // --- Outgoing Call (Caller) ---
  // Initiate a direct call to a target user
  Future<void> makeCall(String targetUserId, String callerName, bool isVideo) async {
    _logger.info('Making direct call to $targetUserId, isVideo: $isVideo');
    _isIncomingCall = false;
    _targetUserId = targetUserId;

    if (_currentUserId == null) {
      onError?.call('User ID not set. Cannot make call.');
      return;
    }

    await _createPeerConnection();
    await _getUserMedia(isVideo);

    // Create an SDP Offer
    final offer = await _peerConnection!.createOffer(_offerAnswerConstraints());
    await _peerConnection!.setLocalDescription(offer);

    // Send the offer to the signaling server
    _socket!.emit('make-direct-call', {
      'toUserId': targetUserId,
      'callerId': _currentUserId,
      'callerName': callerName,
      'isVideo': isVideo,
      'sdpOffer': offer.toMap(), // Convert SDP to map for sending
    });

    onConnectionStateChanged?.call(false); // Indicate connecting
  }

  // --- Incoming Call (Callee) ---
  // Accept an incoming call
  Future<void> acceptIncomingCall(RTCSessionDescription sdpOffer, bool isVideo) async {
    _logger.info('Accepting incoming call from $_targetUserId');
    _isIncomingCall = true;

    if (_targetUserId == null) {
      onError?.call('No target user ID for incoming call.');
      return;
    }

    await _createPeerConnection();
    await _getUserMedia(isVideo); // Get local media based on call type

    await _peerConnection!.setRemoteDescription(sdpOffer);

    // Create an SDP Answer
    final answer = await _peerConnection!.createAnswer(_offerAnswerConstraints());
    await _peerConnection!.setLocalDescription(answer);

    // Send the answer to the signaling server
    _socket!.emit('accept-call', {
      'toUserId': _targetUserId, // Send back to the caller
      'calleeId': _currentUserId,
      'sdpAnswer': answer.toMap(), // Convert SDP to map for sending
    });

    onConnectionStateChanged?.call(true); // Call is now active for callee
  }

  // Decline an incoming call
  void declineCall() {
    if (_targetUserId != null && _currentUserId != null) {
      _logger.info('Declining call from $_targetUserId');
      _socket!.emit('decline-call', {
        'toUserId': _targetUserId,
        'calleeId': _currentUserId,
      });
    }
    _closePeerConnection();
  }

  // End the current call
  Future<void> endCall() async {
    _logger.info('Ending call with $_targetUserId');
    if (_targetUserId != null && _currentUserId != null) {
      _socket!.emit('end-call', {
        'toUserId': _targetUserId,
        'fromUserId': _currentUserId,
      });
    }
    _closePeerConnection();
  }

  // --- WebRTC Core Logic ---

  Future<void> _createPeerConnection() async {
    _logger.info('Creating peer connection...');
    _peerConnection = await createPeerConnection(_iceServers);

    _peerConnection!.onIceCandidate = (candidate) {
      _logger.info('Sending ICE candidate to $_targetUserId');
      if (_targetUserId != null && _currentUserId != null) {
        _socket!.emit('candidate', {
          'toUserId': _targetUserId,
          'fromUserId': _currentUserId,
          'candidate': candidate.toMap(),
        });
      }
    };

    _peerConnection!.onAddStream = (stream) {
      _logger.info('Remote stream added.');
      _remoteStream = stream;
      onRemoteStream?.call(stream);
    };

    _peerConnection!.onIceConnectionState = (state) {
      _logger.info('ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        _logger.info('WebRTC connection established!');
        if (!_isIncomingCall) { // For caller, connection is established here
            onConnectionStateChanged?.call(true);
        }
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
                 state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _logger.warning('WebRTC connection failed or disconnected: $state');
        onError?.call('WebRTC connection error: $state');
        _closePeerConnection();
        onConnectionStateChanged?.call(false);
      }
    };

    _peerConnection!.onSignalingState = (state) {
      _logger.info('Signaling state: $state');
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(event.streams[0]);
      } else if (event.track.kind == 'audio') {
        // Handle remote audio track if needed
      }
    };
  }

  Future<void> _getUserMedia(bool isVideo) async {
    _logger.info('Getting user media (video: $isVideo)');
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideo
          ? {'facingMode': 'user', 'width': 640, 'height': 480}
          : false, // Only request video if isVideo is true
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      onLocalStream?.call(_localStream!);

      // Add tracks to peer connection
      for (var track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    } catch (e) {
      _logger.severe('Error getting user media: $e');
      onError?.call('Failed to get camera/microphone access: $e');
      _closePeerConnection();
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> sdpOfferMap) async {
    if (_peerConnection == null) {
      // This case should ideally not happen if incoming-direct-call creates it
      _logger.warning('Peer connection not created for handling offer.');
      return;
    }
    final RTCSessionDescription sdpOffer = RTCSessionDescription(
      sdpOfferMap['sdp'],
      sdpOfferMap['type'],
    );
    await _peerConnection!.setRemoteDescription(sdpOffer);
    _logger.info('Remote description (offer) set.');
  }


  Future<void> _handleAnswer(Map<String, dynamic> sdpAnswerMap) async {
    if (_peerConnection == null) return;
    final RTCSessionDescription sdpAnswer = RTCSessionDescription(
      sdpAnswerMap['sdp'],
      sdpAnswerMap['type'],
    );
    await _peerConnection!.setRemoteDescription(sdpAnswer);
    _logger.info('Remote description (answer) set.');
  }

  Future<void> _handleCandidate(Map<String, dynamic> candidateMap) async {
    if (_peerConnection == null) return;
    final RTCIceCandidate candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );
    await _peerConnection!.addCandidate(candidate);
    _logger.info('ICE candidate added.');
  }

  // --- Media Controls ---

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
    }
    // Notify the other user via signaling server
    if (_targetUserId != null && _currentUserId != null) {
      _socket!.emit('audio-toggle', {
        'toUserId': _targetUserId,
        'fromUserId': _currentUserId,
        'isMuted': _isMuted,
      });
    }
    _logger.info('Audio toggled: $_isMuted');
  }

  void toggleVideo() {
    _isVideoOff = !_isVideoOff;
    if (_localStream != null) {
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = !_isVideoOff;
      });
    }
    // Notify the other user via signaling server
    if (_targetUserId != null && _currentUserId != null) {
      _socket!.emit('video-toggle', {
        'toUserId': _targetUserId,
        'fromUserId': _currentUserId,
        'isVideoOff': _isVideoOff,
      });
    }
    _logger.info('Video toggled: $_isVideoOff');
  }

  void switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
      _logger.info('Camera switched.');
    }
  }

  // Note: Speaker control is typically handled by the platform's audio routing.
  // WebRTC itself doesn't directly expose speaker on/off toggles in this way,
  // but you can influence it via audio session management in native code or
  // by setting output type for Android/iOS.
  // For simplicity, we'll just track the state in the app.
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    // Implement native platform specific code to toggle speaker here if needed.
    // Example (pseudo-code for Android/iOS - not part of WebRTC Flutter directly):
    // if (Platform.isAndroid || Platform.isIOS) {
    //   if (_isSpeakerOn) {
    //     WebRTC.setSpeakerphoneOn(true);
    //   } else {
    //     WebRTC.setSpeakerphoneOn(false);
    //   }
    // }
    _logger.info('Speaker toggled: $_isSpeakerOn');
  }

  // --- Cleanup ---

  Future<void> _closePeerConnection() async {
    _logger.info('Closing peer connection and streams.');
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.dispose());
      await _localStream!.dispose();
      _localStream = null;
      onLocalStream?.call(null); // Now this will work
    }
    if (_remoteStream != null) {
      _remoteStream!.getTracks().forEach((track) => track.dispose());
      await _remoteStream!.dispose();
      _remoteStream = null;
      onRemoteStream?.call(null); // Now this will work
    }
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }
    _targetUserId = null;
    _isIncomingCall = false;
    _isMuted = false;
    _isVideoOff = false;
    onConnectionStateChanged?.call(false);
  }

  void dispose() {
    _logger.info('Disposing DirectVideoCallService.');
    _closePeerConnection();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // Helper method for offer/answer constraints
  Map<String, dynamic> _offerAnswerConstraints() {
    return {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };
  }
}
