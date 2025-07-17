// screens/tests/subscription_card_test_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SubscriptionCardTestScreen extends StatefulWidget {
  const SubscriptionCardTestScreen({super.key});

  @override
  State<SubscriptionCardTestScreen> createState() =>
      _SubscriptionCardTestScreenState();
}

class _SubscriptionCardTestScreenState
    extends State<SubscriptionCardTestScreen> {
  // Test cases for different subscription states
  final List<Map<String, dynamic>> _testCases = [
    {
      'name': 'Active Trial',
      'data': {
        'isTrialActive': true,
        'plan': 'trial',
        'gptQueriesUsed': 15,
        'videoMinutesUsed': 45,
        'trialStartDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 3))),
        'lastResetDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1))),
      }
    },
    {
      'name': 'Expired Trial',
      'data': {
        'isTrialActive': false,
        'plan': 'trial',
        'gptQueriesUsed': 100,
        'videoMinutesUsed': 300,
        'trialStartDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 15))),
        'lastResetDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7))),
      }
    },
    {
      'name': 'New Trial',
      'data': {
        'isTrialActive': true,
        'plan': 'trial',
        'gptQueriesUsed': 0,
        'videoMinutesUsed': 0,
        'trialStartDate': Timestamp.now(),
        'lastResetDate': Timestamp.now(),
      }
    },
    {
      'name': 'Partial Data',
      'data': {
        'plan': 'premium',
        'gptQueriesUsed': 120,
        'isTrialActive': true,
      }
    },
    {'name': 'No Data', 'data': null},
    {
      'name': 'Active Premium',
      'data': {
        'isTrialActive': false,
        'plan': 'premium',
        'gptQueriesUsed': 42,
        'videoMinutesUsed': 120,
        'subscriptionStartDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 30))),
        'lastResetDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7))),
      }
    }
  ];

  Map<String, dynamic>? _currentSubscription;
  int _currentTestCaseIndex = 0;
  int _simulatedQueries = 0;
  int _simulatedVideoMinutes = 0;
  bool _showUsageControls = true;

  @override
  void initState() {
    super.initState();
    _loadTestCase(0);
  }

  void _loadTestCase(int index) {
    setState(() {
      _currentTestCaseIndex = index;
      _currentSubscription = _testCases[index]['data'] != null
          ? Map<String, dynamic>.from(_testCases[index]['data'])
          : null;
      _simulatedQueries = 0;
      _simulatedVideoMinutes = 0;

      // Show usage controls only for trial test cases
      _showUsageControls = _currentSubscription?['plan'] == 'trial';
    });
  }

  void _simulateQuery() {
    setState(() {
      _simulatedQueries++;
      if (_currentSubscription != null) {
        final current = _currentSubscription!['gptQueriesUsed'] ?? 0;
        _currentSubscription!['gptQueriesUsed'] = current + 1;
      }
    });
  }

  void _simulateVideoUsage(int minutes) {
    setState(() {
      _simulatedVideoMinutes += minutes;
      if (_currentSubscription != null) {
        final current = _currentSubscription!['videoMinutesUsed'] ?? 0;
        _currentSubscription!['videoMinutesUsed'] = current + minutes;
      }
    });
  }

  void _resetUsage() {
    setState(() {
      if (_currentSubscription != null) {
        _currentSubscription!['gptQueriesUsed'] = 0;
        _currentSubscription!['videoMinutesUsed'] = 0;
        _currentSubscription!['lastResetDate'] = Timestamp.now();
      }
      _simulatedQueries = 0;
      _simulatedVideoMinutes = 0;
    });
  }

  void _toggleTrialStatus() {
    setState(() {
      if (_currentSubscription != null) {
        final current = _currentSubscription!['isTrialActive'] ?? false;
        _currentSubscription!['isTrialActive'] = !current;
      }
    });
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy').add_jm().format(timestamp.toDate());
    }
    return 'N/A';
  }

  Widget _buildSubscriptionCard() {
    if (_currentSubscription == null) {
      return Card(
        elevation: 4,
        margin: const EdgeInsets.all(16),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.warning_amber, size: 48, color: Colors.amber),
              SizedBox(height: 16),
              Text(
                'No Subscription Data',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Subscription information is not available',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final isTrial = _currentSubscription!['plan'] == 'trial';
    final isActive = _currentSubscription!['isTrialActive'] ?? false;
    final plan =
        _currentSubscription!['plan']?.toString().toUpperCase() ?? 'N/A';
    final queriesUsed =
        _currentSubscription!['gptQueriesUsed']?.toString() ?? '0';
    final videoMinutesUsed =
        _currentSubscription!['videoMinutesUsed']?.toString() ?? '0';
    final trialStartDate =
        _formatTimestamp(_currentSubscription!['trialStartDate']);
    final lastResetDate =
        _formatTimestamp(_currentSubscription!['lastResetDate']);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isTrial ? Icons.rocket_launch : Icons.workspace_premium,
                      color: isActive ? Colors.green : Colors.orange,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'SUBSCRIPTION STATUS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(color: Colors.grey, height: 32),

            // Plan details
            _buildDetailRow('Plan Type', plan),
            _buildDetailRow('Status', isActive ? 'Active' : 'Inactive'),
            _buildDetailRow('Queries Used', '$queriesUsed queries'),
            _buildDetailRow('Video Minutes Used', '$videoMinutesUsed minutes'),
            if (isTrial) ...[
              _buildDetailRow('Trial Start Date', trialStartDate),
              _buildDetailRow('Last Reset Date', lastResetDate),
            ] else if (_currentSubscription!['subscriptionStartDate'] != null)
              _buildDetailRow(
                  'Subscription Start',
                  _formatTimestamp(
                      _currentSubscription!['subscriptionStartDate'])),

            // Upgrade prompt for expired trials
            if (isTrial && !isActive) ...[
              const Divider(color: Colors.grey, height: 32),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your trial has ended',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upgrade to continue using premium features',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Upgrade to Premium'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Card Test'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Test case selector
            _buildTestCaseSelector(),

            // Current test case name
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
              child: Text(
                _testCases[_currentTestCaseIndex]['name'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Subscription card
            _buildSubscriptionCard(),

            // Test case description
            _buildTestCaseDescription(),

            // Interactive controls
            if (_showUsageControls) _buildUsageControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCaseSelector() {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _testCases.length,
        itemBuilder: (context, index) {
          final isSelected = index == _currentTestCaseIndex;
          return Padding(
            padding: const EdgeInsets.only(left: 8, top: 16, bottom: 16),
            child: ChoiceChip(
              label: Text(_testCases[index]['name']),
              selected: isSelected,
              selectedColor: Colors.blue[800],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
              ),
              onSelected: (selected) => _loadTestCase(index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTestCaseDescription() {
    final testCase = _testCases[_currentTestCaseIndex];
    String description = '';
    String verification = '';

    switch (testCase['name']) {
      case 'Active Trial':
        description = 'User is in an active trial period with some usage.';
        verification = 'Verify: Active status, usage tracking, dates formatted';
        break;
      case 'Expired Trial':
        description = 'Trial period has ended but usage data remains.';
        verification =
            'Verify: Inactive status, upgrade prompt, data preserved';
        break;
      case 'New Trial':
        description = 'Trial just started with no usage yet.';
        verification = 'Verify: Zero usage, current dates, active status';
        break;
      case 'Partial Data':
        description = 'Subscription data has missing fields.';
        verification = 'Verify: Graceful handling of missing data, no crashes';
        break;
      case 'No Data':
        description = 'No subscription information available.';
        verification = 'Verify: Clear message shown, no errors';
        break;
      case 'Active Premium':
        description = 'User has an active premium subscription.';
        verification = 'Verify: Premium plan shown, different date field used';
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description: $description',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Verification: $verification',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.blue[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageControls() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simulate Usage:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Query simulation
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _simulateQuery,
                  icon: const Icon(Icons.chat_bubble),
                  label: const Text('Run Query'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[50],
                    foregroundColor: Colors.green[800],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Simulated: $_simulatedQueries queries',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Video simulation
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _simulateVideoUsage(5),
                  icon: const Icon(Icons.videocam),
                  label: const Text('5 min Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[800],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _simulateVideoUsage(30),
                  icon: const Icon(Icons.video_library),
                  label: const Text('30 min Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[800],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Simulated: $_simulatedVideoMinutes min',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Management buttons
            const Text(
              'Management Actions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _resetUsage,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset Usage'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[50],
                    foregroundColor: Colors.orange[800],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _toggleTrialStatus,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Toggle Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[50],
                    foregroundColor: Colors.purple[800],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
