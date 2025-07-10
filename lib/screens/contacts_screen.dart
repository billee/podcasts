// lib/screens/contacts_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Import StreamSubscription
import 'package:flutter/services.dart'; // Import for Clipboard

import 'package:kapwa_companion_basic/models/ofw_contact.dart';
// REMOVED: import 'package:kapwa_companion_basic/screens/incoming_call_screen.dart';
// REMOVED: import 'package:kapwa_companion_basic/screens/video_conference_screen.dart';
import 'package:kapwa_companion_basic/services/contact_service.dart'; // Ensure this import is correct
// REMOVED: import 'package:kapwa_companion_basic/services/video_conference_service.dart';
import 'package:logging/logging.dart'; // Import logging

class ContactsScreen extends StatefulWidget {
  // Now receives userId and username directly
  final String? userId;
  final String? username;

  const ContactsScreen({
    super.key,
    this.userId, // Made optional as it might be null initially
    this.username, // Made optional as it might be null initially
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final Logger _logger = Logger('ContactsScreen');
  List<OFWContact> _contacts = [];
  bool _loading = true;
  // Removed DirectVideoCallService
  // late final DirectVideoCallService _videoService;
  final TextEditingController _contactIdController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _contactSpecializationController =
      TextEditingController();

  String? _currentUserId;
  StreamSubscription? _contactsSubscription;
  // Removed incoming call subscription
  // StreamSubscription? _incomingCallSubscription;

  @override
  void initState() {
    super.initState();
    _logger.info('ContactsScreen initState called.');
    // Removed videoService assignment
    // _videoService = widget.videoService;
    _getCurrentUserId();
  }

  @override
  void dispose() {
    _logger.info('ContactsScreen dispose called.');
    _contactsSubscription?.cancel();
    // Removed incoming call listener dispose
    // _incomingCallSubscription?.cancel();
    _contactIdController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactSpecializationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserId() async {
    // Use widget.userId if available, otherwise fetch from Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
      _loadContacts();
      // Removed incoming call listener
      // _listenForIncomingCalls();
    } else {
      _logger.warning('No user logged in.');
      setState(() {
        _loading = false;
      });
    }
  }

  void _loadContacts() async {
    if (_currentUserId == null) return;
    _logger.info('Loading contacts for user: $_currentUserId');
    _contactsSubscription =
        ContactServiceStream.getFamilyContactsStream(_currentUserId!).listen(
            (contacts) {
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
      _logger.info('Contacts loaded: ${_contacts.length}');
    }, onError: (e) {
      _logger.severe('Error loading contacts: $e');
      setState(() {
        _loading = false;
      });
      _showSnackBar('Error loading contacts: $e');
    });
  }

  // --- Removed all Daily.co and Firestore Invitation related methods ---
  // _listenForIncomingCalls()
  // _showIncomingCallScreen()
  // _sendCallInvitation()
  // _makeCall()

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddContactDialog,
          ),
          if (_currentUserId != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _currentUserId!));
                    _showSnackBar('Your User ID copied to clipboard!');
                  },
                  child: Tooltip(
                    message: 'Tap to copy your User ID: $_currentUserId',
                    child: Text(
                      'Your ID: ${_currentUserId!.substring(0, 6)}...',
                      style:
                          const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? const Center(
                  child: Text(
                    'No contacts yet. Add some!',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return Card(
                      color: Colors.grey[850],
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[700],
                          child: Text(
                            contact.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          contact.name,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          contact.id,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Removed call buttons
                            // IconButton(
                            //   icon: const Icon(Icons.call, color: Colors.green),
                            //   onPressed: () => _makeCall(contact, false), // Audio call
                            // ),
                            // IconButton(
                            //   icon: const Icon(Icons.videocam,
                            //       color: Colors.blue),
                            //   onPressed: () => _makeCall(contact, true), // Video call
                            // ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteContact(contact.id),
                            ),
                          ],
                        ),
                        onTap: () {
                          _showSnackBar('Tapped on ${contact.name}');
                        },
                      ),
                    );
                  },
                ),
      backgroundColor: Colors.grey[900],
    );
  }

  void _showAddContactDialog() {
    _contactIdController.clear();
    _contactNameController.clear();
    _contactPhoneController.clear();
    _contactSpecializationController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Add New Contact',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _contactIdController,
              decoration: InputDecoration(
                labelText: 'User ID',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue[700]!)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue[400]!)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contactNameController,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue[700]!)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue[400]!)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contactPhoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number (Optional)',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue[700]!)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue[400]!)),
              ),
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contactSpecializationController,
              decoration: InputDecoration(
                labelText: 'Specialization (Optional)',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue[700]!)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue[400]!)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () async {
              final contactId = _contactIdController.text.trim();
              final contactName = _contactNameController.text.trim();
              final contactPhone = _contactPhoneController.text.trim();
              final contactSpecialization =
                  _contactSpecializationController.text.trim();

              if (contactId.isNotEmpty && contactName.isNotEmpty) {
                if (_contacts.any((c) => c.id == contactId)) {
                  _showSnackBar('Contact with this User ID already exists!');
                  return;
                }

                await ContactService.addFamilyContact(
                  _currentUserId!,
                  OFWContact(
                    id: contactId,
                    name: contactName,
                    phone: contactPhone.isNotEmpty ? contactPhone : null,
                    specialization: contactSpecialization.isNotEmpty
                        ? contactSpecialization
                        : '',
                    profileImage: null,
                    lastSeen: null,
                    isOnline: false,
                    relationship: null,
                    phoneNumber: contactPhone.isNotEmpty ? contactPhone : null,
                    languages: null,
                    status: null,
                  ),
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a unique ID and name')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteContact(String contactId) async {
    if (_currentUserId == null) return;
    _logger.info('Deleting contact: $contactId');
    try {
      await ContactService.deleteFamilyContact(_currentUserId!, contactId);
      _showSnackBar('Contact deleted!');
    } catch (e) {
      _logger.severe('Error deleting contact: $e');
      _showSnackBar('Failed to delete contact: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

extension ContactServiceStream on ContactService {
  static Stream<List<OFWContact>> getFamilyContactsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('family_contacts')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OFWContact.fromMap(doc.data(), doc.id))
            .toList());
  }
}
