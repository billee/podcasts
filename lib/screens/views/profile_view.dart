// lib/screen/views/profile_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kapwa_companion_basic/widgets/subscription_status_widget.dart';
import 'package:kapwa_companion_basic/widgets/loading_state_widget.dart';
import 'package:kapwa_companion_basic/screens/subscription/subscription_management_screen.dart';

class ProfileView extends StatelessWidget {
  final bool isLoading;
  final Map<String, dynamic>? userProfile;
  final bool isEditing;
  final GlobalKey<FormState> formKey;
  final Map<String, TextEditingController> controllers;
  final List<MapEntry<String, dynamic>> editableEntries;
  final List<MapEntry<String, dynamic>> nonEditableEntries;
  final Map<String, dynamic>? subscriptionData;
  final VoidCallback onEditPressed;
  final VoidCallback onSavePressed;
  final VoidCallback onCancelPressed;
  final VoidCallback onLogoutPressed;
  final Widget Function(String, String) buildEditableField;
  final Widget Function(String, dynamic) buildInfoRow;
  final String Function(String) formatFieldName;

  const ProfileView({
    Key? key,
    required this.isLoading,
    required this.userProfile,
    required this.isEditing,
    required this.formKey,
    required this.controllers,
    required this.editableEntries,
    required this.nonEditableEntries,
    required this.subscriptionData,
    required this.onEditPressed,
    required this.onSavePressed,
    required this.onCancelPressed,
    required this.onLogoutPressed,
    required this.buildEditableField,
    required this.buildInfoRow,
    required this.formatFieldName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: LoadingStateWidget(
          message: 'Loading profile...',
          color: Colors.white,
        ),
      );
    }

    if (userProfile == null) {
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: isEditing ? _buildEditView() : _buildViewOnly(context),
        ),
      ),
    );
  }

  Widget _buildEditView() {
    return Form(
      key: formKey,
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
          
          // Show only clean editable fields (exclude unwanted metadata)
          Column(
            children: _getCleanEditableFields()
                .map<Widget>((entry) =>
                    buildEditableField(formatFieldName(entry.key), entry.key))
                .toList(),
          ),
          
          const SizedBox(height: 24),
          Text(
            'Account Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 12),
          
          // Show only essential non-editable fields
          Column(
            children: _getNonEditableFieldsForEditMode()
                .map<Widget>((entry) =>
                    _buildInfoRowWithDateFormatting(formatFieldName(entry.key), entry.value, fieldKey: entry.key))
                .toList(),
          ),
          
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onCancelPressed,
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
                  onPressed: onSavePressed,
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

  Widget _buildViewOnly(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Profile Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            IconButton(
              icon: Icon(isEditing ? Icons.save : Icons.edit),
              onPressed: onEditPressed,
              tooltip: isEditing ? 'Save Changes' : 'Edit Profile',
              color: Colors.blue[800],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: _getLogicallyOrderedFields()
              .map<Widget>((entry) =>
                  _buildInfoRowWithDateFormatting(formatFieldName(entry.key), entry.value, fieldKey: entry.key))
              .toList(),
        ),

        const SizedBox(height: 12),

        _buildSubscriptionSection(context),



      ],
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
            style: const TextStyle(
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildSubscriptionSection(BuildContext context) {
    final subscription = userProfile?['subscription'] as Map<String, dynamic>?;
    final isTrialActive = subscription?['isTrialActive'] ?? false;
    
    // Calculate trial information
    String trialInfo = 'No trial information available';
    if (subscription != null && isTrialActive) {
      final trialStartDate = subscription['trialStartDate'];
      final trialEndDate = subscription['trialEndDate'];
      
      if (trialStartDate != null && trialEndDate != null) {
        final startDate = (trialStartDate as Timestamp).toDate();
        final endDate = (trialEndDate as Timestamp).toDate();
        final now = DateTime.now();
        final daysLeft = endDate.difference(now).inDays;
        
        trialInfo = '''Trial started: ${_formatDate(startDate)}
Trial ends: ${_formatDate(endDate)}
Days remaining: ${daysLeft > 0 ? daysLeft : 0} days''';
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Trial Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            trialInfo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Subscribe logic
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionManagementScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Subscribe',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  List<MapEntry<String, dynamic>> _getCleanEditableFields() {
    // Fields that should NOT be shown in edit mode
    final excludedFields = [
      'metadata', 'isOnline', 'language', 'isActive', 'lastUpdated', 
      'createdAt', 'preferences', 'profileCompleted', 'loginCount', 
      'deviceInfo', 'lastActiveAt', 'emailVerified', 'lastLoginAt', 
      'emailVerifiedAt', 'userType', 'hasRealEmail', 'subscription', 'uid', 'email'
    ];
    
    return editableEntries
        .where((entry) => !excludedFields.contains(entry.key))
        .toList();
  }

  List<MapEntry<String, dynamic>> _getNonEditableFieldsForEditMode() {
    if (userProfile == null) return [];
    
    // Only show essential account fields: uid and email
    final allowedFields = ['uid', 'email'];
    
    return userProfile!.entries
        .where((entry) => allowedFields.contains(entry.key))
        .toList();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Enhanced date field detection method
  bool _isDateField(String label, String? fieldKey, dynamic value) {
    // First check value type - this is the most reliable
    if (value is Timestamp || value is DateTime) {
      return true;
    }
    
    // Check if string looks like a date
    if (value is String) {
      try {
        DateTime.parse(value);
        return true;
      } catch (e) {
        // Not a valid date string, continue with other checks
      }
    }
    
    // List of known date field keys
    final dateFieldKeys = [
      'createdAt', 'created_at', 'created',
      'emailVerified', 'email_verified', 'emailVerifiedAt',
      'lastUpdated', 'last_updated', 'updatedAt',
      'lastActiveAt', 'last_active_at',
      'lastLoginAt', 'last_login_at', 'lastLogin'
    ];
    
    // Check field key directly
    if (fieldKey != null && dateFieldKeys.contains(fieldKey)) {
      return true;
    }
    
    // Check label text patterns (be more specific)
    final labelLower = label.toLowerCase();
    
    // Exact matches first
    if (labelLower == 'created at' || labelLower == 'email verified' || labelLower == 'last updated') {
      return true;
    }
    
    // Pattern matches
    final datePatterns = ['created', 'verified', 'updated'];
    for (final pattern in datePatterns) {
      if (labelLower.contains(pattern)) {
        return true;
      }
    }
    
    return false;
  }
  
  List<MapEntry<String, dynamic>> _getLogicallyOrderedFields() {
    if (userProfile == null) return [];
    
    // Define the logical order of fields to display
    final fieldOrder = [
      // Personal Information
      'name', 'email', 'age', 'gender',
      // Location & Work
      'workLocation', 'occupation', 'educationalAttainment',
      // Personal Status
      'isMarried', 'hasChildren',
      // Account Information
      'uid', 'emailVerified'
    ];
    
    // Get all available fields and remove unwanted ones
    final availableFields = userProfile!.entries
        .where((entry) => !['metadata', 'preferences', 'profileCompleted', 'deviceInfo', 'hasRealEmail', 'subscription', 'lastUpdated', 'lastActiveAt', 'lastLoginAt', 'createdAt'].contains(entry.key))
        .toList();
    
    // Create a map for quick lookup
    final fieldMap = Map.fromEntries(availableFields);
    
    // Return fields in logical order, only including fields that exist
    final orderedFields = <MapEntry<String, dynamic>>[];
    final addedFields = <String>{};
    
    // Add fields in the specified order
    for (final fieldName in fieldOrder) {
      if (fieldMap.containsKey(fieldName) && !addedFields.contains(fieldName)) {
        orderedFields.add(MapEntry(fieldName, fieldMap[fieldName]));
        addedFields.add(fieldName);
      }
    }
    
    // Add any remaining fields that weren't in our order list
    for (final entry in availableFields) {
      if (!addedFields.contains(entry.key)) {
        orderedFields.add(entry);
      }
    }
    
    return orderedFields;
  }

  Widget _buildInfoRowWithDateFormatting(String label, dynamic value, {String? fieldKey}) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    // Format specific fields with user-friendly dates
    String displayValue;
    
    // Enhanced date field detection - be more aggressive about detecting date fields
    bool isDateField = _isDateField(label, fieldKey, value);
        
    if (isDateField) {
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

  void _showCancelSubscriptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: const Text(
            'Cancel Subscription',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to cancel your subscription? You will lose access to premium features.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep Subscription'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Add actual cancellation logic here
              },
              child: const Text(
                'Cancel Subscription',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }



}
