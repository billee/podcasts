import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Logger _logger = Logger('ProfileScreen');
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _logger.info('ProfileScreen initState called.');
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    _logger.info('Attempting to load user profile...');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _logger.info('Firebase currentUser found: UID = ${user.uid}');
        // Try to get profile from Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          _logger.info('User profile found in Firestore for UID: ${user.uid}');
          setState(() {
            _userProfile = doc.data();
            _isLoading = false;
          });
        } else {
          _logger.warning(
              'User profile NOT found in Firestore for UID: ${user.uid}. Falling back to basic Firebase Auth info.');
          // Fallback to basic Firebase Auth info
          setState(() {
            _userProfile = {
              'name': user.displayName ?? 'User',
              'email': user.email ?? '',
              'uid': user.uid, // Add UID for debugging
            };
            _isLoading = false;
          });
        }
      } else {
        _logger.warning(
            'No Firebase currentUser found. User is not authenticated.');
        setState(() {
          _userProfile = null; // Ensure profile is null if not logged in
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.severe('Error loading user profile: $e');
      setState(() {
        _isLoading = false;
        _userProfile = null; // Clear profile on error
      });
    }
  }

  Future<void> _signOut() async {
    _logger.info('Attempting to sign out...');
    try {
      await FirebaseAuth.instance.signOut();
      _logger.info('User signed out successfully.');
      // Navigation is handled by AuthWrapper
    } catch (e) {
      _logger.severe('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userProfile == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'User not logged in or profile failed to load.',
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Please log in to view your profile.',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Profile Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.blue[800],
                              child: Text(
                                (_userProfile!['name']?.toString() ?? 'U')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _userProfile!['name']?.toString() ??
                                  'Unknown User',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _userProfile!['email']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                            if (_userProfile!['uid'] !=
                                null) // Display UID for debugging
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'UID: ${_userProfile!['uid']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Show available profile information
                      if (_userProfile!.isNotEmpty) ...[
                        _buildInfoCard(
                          'Profile Information',
                          _userProfile!.entries
                              .where((entry) =>
                                  entry.key != 'name' &&
                                  entry.key != 'email' &&
                                  entry.key != 'uid')
                              .map((entry) => _buildInfoRow(
                                  _formatFieldName(entry.key), entry.value))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Sign Out Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _signOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout),
                              SizedBox(width: 8),
                              Text(
                                'Sign Out',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _formatFieldName(String fieldName) {
    // Convert camelCase to readable format
    return fieldName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split(' ')
        .map((word) =>
            word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ')
        .trim();
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value is bool ? (value ? 'Yes' : 'No') : value.toString(),
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
