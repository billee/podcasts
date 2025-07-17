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
  final List<String> _genders = ['Male', 'Female'];
  final List<String> _maritalStatuses = ['Married', 'Single'];
  final List<String> _educationLevels = [
    'Elementary',
    'High School',
    'University'
  ];
  bool _isLoading = true;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final List<String> _nonEditableFields = [
    'userType',
    'profileCompleted',
    'createdAt',
    'isOnline',
    'lastSeen',
    'lastLoginAt',
    'lastActiveAt',
    'isActive',
    'deviceInfo',
    'loginCount',
    'uid',
    'email',
    'preferences',
    'language',
    'subscription', // Added to non-editable fields
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          setState(() {
            _userProfile = doc.data();
            _initializeControllers(_userProfile!);
            _isLoading = false;
          });
        } else {
          final basicProfile = {
            'name': user.displayName ?? 'User',
            'email': user.email ?? '',
            'uid': user.uid,
          };
          setState(() {
            _userProfile = basicProfile;
            _initializeControllers(basicProfile);
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _userProfile = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _userProfile = null;
      });
    }
  }

  void _initializeControllers(Map<String, dynamic> profile) {
    for (var entry in profile.entries) {
      if (!_nonEditableFields.contains(entry.key)) {
        if (entry.key == 'isMarried') {
          _controllers[entry.key] = TextEditingController(
            text: entry.value?.toString() ?? 'false',
          );
        } else {
          _controllers[entry.key] = TextEditingController(
            text: entry.value?.toString() ?? '',
          );
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => _isLoading = true);

      final updateData = <String, dynamic>{};
      for (var entry in _controllers.entries) {
        if (!_nonEditableFields.contains(entry.key)) {
          updateData[entry.key] = entry.value.text;
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      await _loadUserProfile();

      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildEditableField(String label, String fieldName) {
    if (fieldName == 'gender') {
      return _buildDropdownField(
        label: label,
        value: _controllers[fieldName]?.text ?? '',
        items: _genders,
        onChanged: (value) {
          _controllers[fieldName]?.text = value ?? '';
        },
      );
    } else if (fieldName == 'isMarried') {
      final currentValue = _controllers[fieldName]?.text ?? '';
      final displayValue = currentValue == 'true'
          ? 'Married'
          : currentValue == 'false'
              ? 'Single'
              : '';

      return _buildDropdownField(
        label: label,
        value: displayValue,
        items: _maritalStatuses,
        onChanged: (value) {
          final boolValue = value == 'Married' ? 'true' : 'false';
          _controllers[fieldName]?.text = boolValue;
        },
      );
    } else if (fieldName == 'educationalAttainment') {
      return _buildDropdownField(
        label: label,
        value: _controllers[fieldName]?.text ?? '',
        items: _educationLevels,
        onChanged: (value) {
          _controllers[fieldName]?.text = value ?? '';
        },
      );
    }

    final controller = _controllers[fieldName] ??= TextEditingController();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey[700],
          labelStyle: TextStyle(color: Colors.white70),
        ),
        style: const TextStyle(color: Colors.white),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    String? dropdownValue = value.isEmpty ? null : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              value: dropdownValue,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    'Select $label',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ...items.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
              ],
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
              dropdownColor: Colors.grey[800],
              style: const TextStyle(color: Colors.white),
              icon: Icon(Icons.arrow_drop_down, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonEditableInfo(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value?.toString() ?? 'N/A',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Subscription card widget
  Widget _buildSubscriptionCard(Map<String, dynamic>? subscriptionData) {
    if (subscriptionData == null) {
      return Card(
        color: Colors.grey[800],
        margin: const EdgeInsets.only(top: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No subscription information available',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Helper function to format Firestore timestamps
    String formatTimestamp(dynamic timestamp) {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return timestamp?.toString() ?? 'N/A';
    }

    final isTrialActive = subscriptionData['isTrialActive'] ?? false;
    final plan = subscriptionData['plan']?.toString().toUpperCase() ?? 'N/A';
    final queriesUsed = subscriptionData['gptQueriesUsed']?.toString() ?? '0';
    final videoMinutesUsed =
        subscriptionData['videoMinutesUsed']?.toString() ?? '0';
    final trialStartDate = formatTimestamp(subscriptionData['trialStartDate']);
    final lastResetDate = formatTimestamp(subscriptionData['lastResetDate']);

    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.credit_card,
                  color: Colors.blue[300],
                ),
                const SizedBox(width: 10),
                Text(
                  'SUBSCRIPTION STATUS',
                  style: TextStyle(
                    color: Colors.blue[300],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSubscriptionRow('Plan:', plan),
            _buildSubscriptionRow(
                'Status:', isTrialActive ? 'ACTIVE TRIAL' : 'INACTIVE'),
            _buildSubscriptionRow('Queries Used:', '$queriesUsed'),
            _buildSubscriptionRow(
                'Video Minutes Used:', '$videoMinutesUsed min'),
            _buildSubscriptionRow('Trial Start Date:', trialStartDate),
            _buildSubscriptionRow('Last Reset Date:', lastResetDate),
          ],
        ),
      ),
    );
  }

  // Helper for subscription rows
  Widget _buildSubscriptionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userProfile == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'User not logged in or profile failed to load.',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Please log in to view your profile.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              onPressed: () {
                if (_isEditing) {
                  _saveProfile();
                } else {
                  setState(() => _isEditing = true);
                }
              },
              tooltip: _isEditing ? 'Save Changes' : 'Edit Profile',
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: _isEditing ? _buildEditView() : _buildViewOnly(),
      ),
    );
  }

  Widget _buildEditView() {
    final editableEntries = _userProfile!.entries
        .where((entry) => !_nonEditableFields.contains(entry.key))
        .toList();

    // EXCLUDE SUBSCRIPTION FROM ACCOUNT INFO
    final nonEditableEntries = _userProfile!.entries
        .where((entry) =>
            _nonEditableFields.contains(entry.key) &&
            entry.key != 'subscription')
        .toList();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: editableEntries
                .map((entry) =>
                    _buildEditableField(_formatFieldName(entry.key), entry.key))
                .toList(),
          ),

          const SizedBox(height: 24),

          // Account Information Section (without subscription)
          Text(
            'Account Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: nonEditableEntries
                .map((entry) => _buildNonEditableInfo(
                    _formatFieldName(entry.key), entry.value))
                .toList(),
          ),

          // Subscription card (separate section)
          _buildSubscriptionCard(_userProfile?['subscription']),

          const SizedBox(height: 20),

          // Save/Cancel Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _isEditing = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewOnly() {
    final editableEntries = _userProfile!.entries
        .where((entry) => !_nonEditableFields.contains(entry.key))
        .toList();

    // EXCLUDE SUBSCRIPTION FROM ACCOUNT INFO
    final nonEditableEntries = _userProfile!.entries
        .where((entry) =>
            _nonEditableFields.contains(entry.key) &&
            entry.key != 'subscription')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Information Section
        Text(
          'Profile Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: editableEntries
              .map((entry) =>
                  _buildInfoRow(_formatFieldName(entry.key), entry.value))
              .toList(),
        ),

        const SizedBox(height: 24),

        // Account Information Section (without subscription)
        Text(
          'Account Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: nonEditableEntries
              .map((entry) =>
                  _buildInfoRow(_formatFieldName(entry.key), entry.value))
              .toList(),
        ),

        // Subscription card (separate section)
        _buildSubscriptionCard(_userProfile?['subscription']),

        const SizedBox(height: 20),

        // Sign Out Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatFieldName(String fieldName) {
    return fieldName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split(' ')
        .map((word) =>
            word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ')
        .trim();
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
