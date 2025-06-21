// lib/screens/contacts_screen.dart
import 'package:flutter/material.dart';
import 'package:kapwa_companion/models/ofw_contact.dart';
import 'package:kapwa_companion/services/contact_service.dart';
import 'package:kapwa_companion/services/video_conference_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // Use only one _contacts declaration - using Map for simplicity
  List<Map<String, String>> _contacts = [];
  bool _loading = true;
  final SimpleVideoService _videoService = SimpleVideoService();
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _setupVideoService();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    // For now, we'll load empty contacts since we're using Map instead of OFWContact
    // You can modify this later to load actual OFWContact data
    setState(() {
      _contacts = []; // Start with empty list
      _loading = false;
    });
  }

  void _setupVideoService() {
    _videoService.onIncomingCall = (callerId, callerName, isVideo) {
      _showIncomingCallDialog(callerId, callerName, isVideo);
    };

    _videoService.initialize('current_user_id');
  }

  void _showIncomingCallDialog(
      String callerId, String callerName, bool isVideo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Incoming ${isVideo ? 'Video' : 'Voice'} Call'),
        content: Text('$callerName is calling you'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _videoService.declineCall();
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _videoService.acceptCall();
              // Navigate to call screen
            },
            child: const Text('Accept'),
          ),
        ],
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
      body: _contacts.isEmpty
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
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        contact['name']![0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(contact['name']!),
                    subtitle: Text(contact['phone']!),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => _makeCall(contact, false),
                        ),
                        IconButton(
                          icon: const Icon(Icons.videocam, color: Colors.blue),
                          onPressed: () => _makeCall(contact, true),
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

  // Single _addContact method
  void _addContact(String contactInfo) {
    setState(() {
      _contacts.add({
        'name': 'Contact ${_contacts.length + 1}',
        'phone': contactInfo,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    });
    print('Contact added: $contactInfo');
  }

  void _makeCall(Map<String, String> contact, bool isVideo) {
    _videoService.makeCall(contact['id']!, contact['name']!, isVideo);

    Navigator.pushNamed(
      context,
      '/video-conference',
      arguments: {
        'contactName': contact['name'],
        'isVideo': isVideo,
      },
    );
  }

  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Family Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Enter phone number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            const Text('Scan QR code or enter phone number'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              String contactInfo = _controller.text.trim();

              if (contactInfo.isNotEmpty) {
                _addContact(contactInfo);
                _controller.clear();
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a phone number')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
