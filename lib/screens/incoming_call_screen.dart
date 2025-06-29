// lib/screens/incoming_call_screen.dart
import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/models/ofw_contact.dart'; // Ensure this model exists
import 'package:kapwa_companion_basic/screens/video_conference_screen.dart'; // Import VideoConferenceScreen
import 'package:kapwa_companion_basic/services/video_conference_service.dart'; // Import the new service
import 'package:flutter_webrtc/flutter_webrtc.dart'; // For RTCSessionDescription

class IncomingCallScreen extends StatelessWidget {
  final OFWContact caller;
  final bool isVideoCall;
  final RTCSessionDescription sdpOffer; // The SDP offer from the caller
  final DirectVideoCallService videoCallService; // The video service instance

  const IncomingCallScreen({
    super.key,
    required this.caller,
    required this.isVideoCall,
    required this.sdpOffer,
    required this.videoCallService, // Pass the service here
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient or caller's photo
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue[900]!, Colors.black],
              ),
            ),
          ),

          // Caller info
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 80,
                  backgroundImage: caller.profileImage != null
                      ? NetworkImage(caller.profileImage!)
                      : null,
                  child: caller.profileImage == null
                      ? Text(caller.name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 40, color: Colors.white))
                      : null,
                ),
                const SizedBox(height: 24),
                Text(
                  caller.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVideoCall ? 'Incoming video call...' : 'Incoming call...',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  caller.specialization.isNotEmpty ? caller.specialization : 'Unknown', // Display specialization if available
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Call control buttons
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline button
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _declineCall(context),
                    icon: const Icon(Icons.call_end, color: Colors.white),
                    iconSize: 35,
                    padding: const EdgeInsets.all(20),
                  ),
                ),

                // Accept button
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _acceptCall(context),
                    icon: Icon(
                      isVideoCall ? Icons.videocam : Icons.call,
                      color: Colors.white,
                    ),
                    iconSize: 35,
                    padding: const EdgeInsets.all(20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _acceptCall(BuildContext context) async {
    // Call the service method to accept the incoming call
    await videoCallService.acceptIncomingCall(sdpOffer, isVideoCall);

    // Navigate to the VideoConferenceScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VideoConferenceScreen(
          contactId: caller.id, // The ID of the person we are connecting with
          isIncoming: true, // We are accepting an incoming call
          isVideoCall: isVideoCall,
          videoCallService: videoCallService, // Pass the service instance
        ),
      ),
    );
  }

  void _declineCall(BuildContext context) {
    videoCallService.declineCall(); // Call the service method to decline
    Navigator.pop(context); // Pop this screen
  }
}
