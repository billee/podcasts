import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/screens/views/profile_view.dart';
import 'package:kapwa_companion_basic/screens/admin/user_management_screen.dart';
import 'package:kapwa_companion_basic/widgets/feedback_widget.dart';

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
  final List<String> _booleanOptions = ['Yes', 'No'];
  bool _isLoading = true;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final List<String> _nonEditableFields = [
    'uid',
    'email',
    'emailVerified',
    'createdAt',
    'lastActiveAt',
    'lastLoginAt',
    'hasRealEmail',
    'subscription',
    // Removed unwanted metadata fields as requested
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
        if (entry.key == 'isMarried' || entry.key == 'hasChildren') {
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
          // Convert boolean string values back to actual booleans
          if (entry.key == 'isMarried' || entry.key == 'hasChildren') {
            updateData[entry.key] = entry.value.text == 'true';
          } else {
            updateData[entry.key] = entry.value.text;
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      await _loadUserProfile();

      setState(() => _isEditing = false);

      if (mounted) {
        FeedbackManager.showSuccess(
          context,
          message: 'Profile updated successfully!',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        FeedbackManager.showError(
          context,
          message: 'Error saving profile: ${e.toString()}',
          duration: const Duration(seconds: 2),
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
    } else if (fieldName == 'hasChildren') {
      final currentValue = _controllers[fieldName]?.text ?? '';
      final displayValue = currentValue == 'true'
          ? 'Yes'
          : currentValue == 'false'
              ? 'No'
              : '';

      return _buildDropdownField(
        label: label,
        value: displayValue,
        items: _booleanOptions,
        onChanged: (value) {
          final boolValue = value == 'Yes' ? 'true' : 'false';
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

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    // Format specific fields with user-friendly dates
    String displayValue;
    if (label.toLowerCase().contains('created at') || 
        label.toLowerCase().contains('last active') || 
        label.toLowerCase().contains('last login') ||
        label.toLowerCase().contains('email verified')) {
      displayValue = _formatUserFriendlyDate(value);
    } else if (value is bool) {
      displayValue = value ? 'Yes' : 'No';
    } else {
      displayValue = value.toString();
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
              displayValue,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
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

  String _formatUserFriendlyDate(dynamic value) {
    if (value == null) return 'N/A';
    
    try {
      DateTime date;
      if (value is Timestamp) {
        date = value.toDate();
      } else if (value is String) {
        date = DateTime.parse(value);
      } else if (value is DateTime) {
        date = value;
      } else {
        return value.toString();
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return value.toString();
    }
  }



  @override
  Widget build(BuildContext context) {
    final editableEntries = _userProfile?.entries
            .where((entry) =>
                !_nonEditableFields.contains(entry.key) &&
                entry.key != 'subscription')
            .toList() ??
        [];

    final nonEditableEntries = _userProfile?.entries
            .where((entry) =>
                _nonEditableFields.contains(entry.key) &&
                entry.key != 'subscription')
            .toList() ??
        [];

    return ProfileView(
      isLoading: _isLoading,
      userProfile: _userProfile,
      isEditing: _isEditing,
      formKey: _formKey,
      controllers: _controllers,
      editableEntries: editableEntries,
      nonEditableEntries: nonEditableEntries,
      subscriptionData: _userProfile?['subscription'],
      onEditPressed: () {
        if (_isEditing) {
          _saveProfile();
        } else {
          setState(() => _isEditing = true);
        }
      },
      onSavePressed: _saveProfile,
      onCancelPressed: () => setState(() => _isEditing = false),
      onLogoutPressed: () async {
        await FirebaseAuth.instance.signOut();
      },
      buildEditableField: _buildEditableField,
      buildInfoRow: _buildInfoRow,
      formatFieldName: _formatFieldName,

    );
  }
}
