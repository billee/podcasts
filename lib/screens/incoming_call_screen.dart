// lib/screens/incoming_call_screen.dart
class IncomingCallScreen extends StatelessWidget {
  final OFWContact caller;
  final bool isVideoCall;

  const IncomingCallScreen({
    required this.caller,
    required this.isVideoCall,
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
                          style: TextStyle(fontSize: 40))
                      : null,
                ),
                SizedBox(height: 24),
                Text(
                  caller.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  isVideoCall ? 'Incoming video call...' : 'Incoming call...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  caller.specialization,
                  style: TextStyle(
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
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _declineCall(context),
                    icon: Icon(Icons.call_end, color: Colors.white),
                    iconSize: 35,
                    padding: EdgeInsets.all(20),
                  ),
                ),

                // Accept button
                Container(
                  decoration: BoxDecoration(
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
                    padding: EdgeInsets.all(20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _acceptCall(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VideoConferenceScreen(
          contactId: caller.id,
          isIncoming: true,
        ),
      ),
    );
  }

  void _declineCall(BuildContext context) {
    // Handle call decline
    Navigator.pop(context);
  }
}
