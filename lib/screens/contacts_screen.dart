// lib/screens/contacts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Import StreamSubscription
import 'package:flutter/services.dart'; // Import for Clipboard

import 'package:kapwa_companion_basic/models/ofw_contact.dart';
import 'package:kapwa_companion_basic/screens/incoming_call_screen.dart';
import 'package:kapwa_companion_basic/screens/video_conference_screen.dart';
import 'package:kapwa_companion_basic/services/contact_service.dart';
import 'package:kapwa_companion_basic/services/video_conference_service.dart';


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
  List<OFWContact> _contacts = []; // Change to use OFWContact model directly
  bool _loading = true;
  // Use the passed video service instance
  late final DirectVideoCallService _videoService;
  final TextEditingController _contactIdController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _contactSpecializationController = TextEditingController();


  String? _currentUserId; // Will be set from Firebase Auth

  // Firestore listener subscription
  StreamSubscription? _contactsSubscription;

  @override
  void initState() {
    super.initState();
    _videoService = widget.videoService; // Assign the passed service
    _initializeUserAndContacts();
    _setupVideoService();
  }

  Future<void> _initializeUserAndContacts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      _videoService.initialize(_currentUserId!); // Initialize video service with current user's ID
      _listenToContacts(); // Start listening to contacts
      _updateOnlineStatus(true); // Set user online when app starts
    } else {
      _showErrorDialog('User not logged in. Cannot load contacts.');
      setState(() {
        _loading = false;
      });
    }
  }

  void _listenToContacts() {
    if (_currentUserId == null) return;

    // Use a stream to listen for real-time updates to contacts
    _contactsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId!)
        .collection('family_contacts')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _contacts = snapshot.docs
            .map((doc) => OFWContact.fromMap(doc.data(), doc.id))
            .where((contact) => contact.id != _currentUserId) // Don't show self in contacts
            .toList();
        _loading = false;
      });
    }, onError: (error) {
      _showErrorDialog('Error loading contacts: $error');
      setState(() {
        _loading = false;
      });
    });
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    if (_currentUserId != null) {
      await ContactService.updateOnlineStatus(_currentUserId!, isOnline);
    }
  }

  @override
  void dispose() {
    _contactsSubscription?.cancel(); // Cancel the Firestore subscription
    _contactIdController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactSpecializationController.dispose();
    _updateOnlineStatus(false); // Set user offline when app disposes
    _videoService.dispose(); // Dispose the video service
    super.dispose();
  }

  void _setupVideoService() {
    // _videoService.initialize is now called in _initializeUserAndContacts
    // Set up callback for incoming calls
    _videoService.onIncomingCall = (callerId, callerName, isVideo, sdpOffer) {
      // Find the contact in our local list or create a dummy one for display
      OFWContact? callerContact = _contacts.firstWhere(
            (contact) => contact.id == callerId,
        orElse: () => OFWContact(
          id: callerId,
          name: callerName.isNotEmpty ? callerName : 'Unknown Caller',
          phone: '', // Phone number might not be available from signaling
          specialization: '', // Specialization not available from signaling
        ),
      );
      _showIncomingCallDialog(callerContact, isVideo, sdpOffer);
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
            isVideoCall: true, // This should ideally come from the initial makeCall
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
      OFWContact caller, bool isVideo, RTCSessionDescription sdpOffer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(
          caller: caller,
          isVideoCall: isVideo,
          sdpOffer: sdpOffer, // Pass the SDP offer
          videoCallService: _videoService, // Pass the service instance
        ),
      ),
    );
  }

  // New method to copy user ID
  void _copyUserIdToClipboard() {
    if (_currentUserId != null) {
      Clipboard.setData(ClipboardData(text: _currentUserId!));
      _showSnackBar('Your User ID copied to clipboard!');
    } else {
      _showSnackBar('User ID not available yet.');
    }
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
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No contacts yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row( // Wrap in a Row for the ID and copy button
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Your User ID: ${_currentUserId ?? 'Loading...'}', // Display current user ID
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_currentUserId != null) // Only show copy button if ID is available
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                    onPressed: _copyUserIdToClipboard,
                    tooltip: 'Copy your User ID',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddContactDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Family Member'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row( // Wrap in a Row for the ID and copy button
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Your User ID: ${_currentUserId ?? 'Loading...'}', // Display current user ID
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_currentUserId != null) // Only show copy button if ID is available
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                    onPressed: _copyUserIdToClipboard,
                    tooltip: 'Copy your User ID',
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: contact.isOnline ? Colors.green : Colors.blueGrey,
                      child: Text(
                        contact.name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text('${contact.name} (ID: ${contact.id})'), // Show ID for debugging
                    subtitle: Text(
                        '${contact.phone}\n${contact.specialization.isNotEmpty ? contact.specialization : 'N/A'}'
                    ),
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
          ),
        ],
      ),
      floatingActionButton: _contacts.isNotEmpty
          ? FloatingActionButton(
        onPressed: _showAddContactDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      )
          : null, // Only show FAB if contacts list is not empty for 'Add Family Member' button
    );
  }

  Future<void> _addContact(OFWContact contact) async {
    if (_currentUserId == null) {
      _showErrorDialog('User not authenticated. Cannot add contact.');
      return;
    }
    try {
      await ContactService.addFamilyContact(_currentUserId!, contact);
      _showSnackBar('Contact added successfully!');
    } catch (e) {
      _showErrorDialog('Failed to add contact: $e');
    }
  }

  void _makeCall(OFWContact contact, bool isVideo) async {
    if (_currentUserId == null) {
      _showErrorDialog('User not authenticated. Cannot make call.');
      return;
    }
    // Navigate to a temporary screen to show "Calling..." while waiting for acceptance
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoConferenceScreen(
          contactId: contact.id,
          isIncoming: false,
          isVideoCall: isVideo,
          videoCallService: _videoService, // Pass the service instance
        ),
      ),
    );

    // Make the direct call using the service
    await _videoService.makeCall(contact.id, contact.name, isVideo);
    // Note: The actual navigation to the full call screen happens in
    // _videoService.onCallAccepted callback if the callee accepts.
  }

  void _showAddContactDialog() {
    _contactIdController.clear();
    _contactNameController.clear();
    _contactPhoneController.clear();
    _contactSpecializationController.clear();


    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Family Member'),
        content: SingleChildScrollView( // Added SingleChildScrollView
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _contactIdController,
                decoration: const InputDecoration(
                  hintText: 'Enter unique ID (e.g., user_id_X)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contactNameController,
                decoration: const InputDecoration(
                  hintText: 'Enter contact name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contactPhoneController,
                decoration: const InputDecoration(
                  hintText: 'Enter phone number (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contactSpecializationController,
                decoration: const InputDecoration(
                  hintText: 'Enter specialization (e.g., OFW, Doctor)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              String contactId = _contactIdController.text.trim();
              String contactName = _contactNameController.text.trim();
              String contactPhone = _contactPhoneController.text.trim();
              String contactSpecialization = _contactSpecializationController.text.trim();


              if (contactId.isNotEmpty && contactName.isNotEmpty) {
                _addContact(OFWContact(
                  id: contactId,
                  name: contactName,
                  phone: contactPhone, // Use 'phone' field as defined in OFWContact
                  specialization: contactSpecialization,
                  profileImage: null,
                  lastSeen: null,
                  isOnline: false, // Default to false, will be updated by other user's presence
                  // Provide values for new fields, or null if not explicitly entered
                  relationship: null,
                  phoneNumber: contactPhone, // Use 'phoneNumber' for consistency with contact_service expectations
                  languages: null,
                  status: null,
                ));
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
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
}
