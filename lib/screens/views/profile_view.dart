// lib/screen/views/profile_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final VoidCallback? onAdminPressed;
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
    this.onAdminPressed,
    required this.buildEditableField,
    required this.buildInfoRow,
    required this.formatFieldName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
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
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: onEditPressed,
            tooltip: isEditing ? 'Save Changes' : 'Edit Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: onLogoutPressed,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: isEditing ? _buildEditView() : _buildViewOnly(),
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
          Column(
            children: editableEntries
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
          Column(
            children: nonEditableEntries
                .map<Widget>((entry) => _buildNonEditableInfo(
                    formatFieldName(entry.key), entry.value))
                .toList(),
          ),
          _buildSubscriptionCard(subscriptionData),
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

  Widget _buildViewOnly() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              .map<Widget>((entry) =>
                  buildInfoRow(formatFieldName(entry.key), entry.value))
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
        Column(
          children: nonEditableEntries
              .map<Widget>((entry) =>
                  buildInfoRow(formatFieldName(entry.key), entry.value))
              .toList(),
        ),
        _buildSubscriptionCard(subscriptionData),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: onLogoutPressed,
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
        
        // Admin button (for testing/debugging)
        if (onAdminPressed != null) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onAdminPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.admin_panel_settings),
                  SizedBox(width: 8),
                  Text(
                    'User Management',
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
}
