// lib/screens/contacts_screen.dart
import 'package:flutter/material.dart';
// import 'package:kapwa_companion_basic/models/ofw_contact.dart'; // No longer strictly needed for this simplified version
// import 'package:kapwa_companion_basic/services/contact_service.dart'; // No longer needed
import 'package:kapwa_companion_basic/services/video_conference_service.dart'; // Import the new direct call service
import 'package:kapwa_companion_basic/screens/incoming_call_screen.dart'; // Import IncomingCallScreen
import 'package:kapwa_companion_basic/screens/video_conference_screen.dart'; // ADD THIS IMPORT
import 'package:kapwa_companion_basic/models/ofw_contact.dart'; // Still needed for IncomingCallScreen
import 'package:flutter_webrtc/flutter_webrtc.dart'; // Needed for RTCSessionDescription

class ContactsScreen extends StatefulWidget {
  final DirectVideoCallService videoService;
  const ContactsScreen({
    super.key,
    required this.videoService,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // We will store contacts as a list of maps, where 'id' is the unique user ID for signaling
  List<Map<String, String>> _contacts = [];
  bool _loading = true;
  // Initialize the new direct video call service
  final DirectVideoCallService _videoService = DirectVideoCallService();
  final TextEditingController _controller = TextEditingController();

  // IMPORTANT: For testing, you need to set a unique userId for each phone.
  // In a real app, this would come from an authentication system.
  // For example, on Phone A, set 'phone1_user_id', on Phone B set 'phone2_user_id'.
  // Make sure these IDs are unique and known to each other for calling.
  // For demonstration, let's assume a static ID for now, which you should change.
  final String _currentUserId = 'user_id_2'; // <<< CHANGE THIS FOR EACH DEVICE

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _setupVideoService();
  }

  @override
  void dispose() {
    _controller.dispose();
    _videoService.dispose(); // Dispose the video service
    super.dispose();
  }

  Future<void> _loadContacts() async {
    // For now, load some dummy contacts. In a real app, you'd fetch these from a database.
    setState(() {
      _contacts = [
        {'id': 'user_id_2', 'name': 'Family Member 1', 'phone': '416-898-1292'},
        {'id': 'user_id_3', 'name': 'Family Member 2', 'phone': '098-765-4321'},
        // Add more contacts here, ensuring their 'id' matches the 'userId'
        // that another testing device will be using for its _currentUserId.
        // Make sure 'user_id_2' and 'user_id_3' are set as _currentUserId on other phones.
      ];
      _loading = false;
    });
  }

  void _setupVideoService() {
    _videoService.initialize(_currentUserId); // Initialize with the current user's ID

    // Set up callback for incoming calls
    _videoService.onIncomingCall = (callerId, callerName, isVideo, sdpOffer) {
      _showIncomingCallDialog(callerId, callerName, isVideo, sdpOffer);
    };

    // Set up callbacks for call status updates
    _videoService.onCallEnded = (partnerId) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Pop the VideoConferenceScreen if it's open
      }
      _showSnackBar('$partnerId ended the call.');
    };

    _videoService.onCallDeclined = (partnerId) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Pop the dialing screen or call screen
      }
      _showSnackBar('$partnerId declined your call.');
    };

    _videoService.onCallAccepted = (partnerId) {
      // Navigate to the video conference screen once the call is accepted
      // Remove the current VideoConferenceScreen and replace with the connected one
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoConferenceScreen(
            contactId: partnerId,
            isIncoming: false,
            isVideoCall: true, // You might want to track this separately
            videoCallService: _videoService,
          ),
        ),
      );
    };

    _videoService.onPartnerDisconnected = (disconnectedUserId) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Pop the VideoConferenceScreen if it's open
      }
      _showSnackBar('$disconnectedUserId disconnected.');
    };

    _videoService.onError = (message) {
      _showErrorDialog(message);
    };
  }

  void _showIncomingCallDialog(
      String callerId, String callerName, bool isVideo, RTCSessionDescription sdpOffer) {
    // Create a dummy OFWContact for the IncomingCallScreen
    final incomingCaller = OFWContact(
      id: callerId,
      name: callerName,
      phone: '', // Phone number not available from signaling for now
      specialization: '', // Dummy data
      profileImage: null, // No profile image
    );

    // Navigate to IncomingCallScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(
          caller: incomingCaller,
          isVideoCall: isVideo,
          sdpOffer: sdpOffer, // Pass the SDP offer
          videoCallService: _videoService, // Pass the service instance
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Contacts'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _contacts.isEmpty
          ? const Center(
        child: Text(
          'No contacts yet\nTap + to add family members',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      )
          : ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final contact = _contacts[index];
          // Do not show current user in contacts list
          if (contact['id'] == _currentUserId) {
            return const SizedBox.shrink(); // Hide current user
          }
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  contact['name']![0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text('${contact['name']!} (ID: ${contact['id']})'), // Show ID for debugging
              subtitle: Text(contact['phone']!),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () => _makeCall(contact, false), // Voice call
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam, color: Colors.blue),
                    onPressed: () => _makeCall(contact, true), // Video call
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  // Modified _addContact to take 'id', 'name', 'phone'
  void _addContact(String id, String name, String phone) {
    setState(() {
      _contacts.add({
        'id': id,
        'name': name,
        'phone': phone,
      });
    });
    print('Contact added: ID=$id, Name=$name, Phone=$phone');
  }

  // This is the core function to initiate a call
  void _makeCall(Map<String, String> contact, bool isVideo) async {
    // Navigate to a temporary screen to show "Calling..." while waiting for acceptance
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoConferenceScreen(
          contactId: contact['id']!,
          isIncoming: false,
          isVideoCall: isVideo,
          videoCallService: _videoService, // Pass the service instance
        ),
      ),
    );

    // Make the direct call using the service
    await _videoService.makeCall(contact['id']!, _currentUserId, isVideo);
    // Note: The actual navigation to the full call screen happens in
    // _videoService.onCallAccepted callback if the callee accepts.
  }

  void _showAddContactDialog() {
    final TextEditingController idController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Family Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                hintText: 'Enter unique ID (e.g., user_id_X)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Enter contact name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                hintText: 'Enter phone number (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              String contactId = idController.text.trim();
              String contactName = nameController.text.trim();
              String contactPhone = phoneController.text.trim();

              if (contactId.isNotEmpty && contactName.isNotEmpty) {
                _addContact(contactId, contactName, contactPhone);
                idController.clear();
                nameController.clear();
                phoneController.clear();
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a unique ID and name')),
                );
              }
            },
            child: const Text('Add'),
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
}