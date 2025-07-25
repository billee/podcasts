import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:logging/logging.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final Logger _logger = Logger('AdminDashboard');
  List<UserJourney> _userJourneys = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUserJourneys();
  }

  Future<void> _loadUserJourneys() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userJourneys = <UserJourney>[];
      
      // Get all users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;
        
        // Get trial history
        final trialSnapshot = await FirebaseFirestore.instance
            .collection('trial_history')
            .where('userId', isEqualTo: userId)
            .get();

        // Get subscription data
        final subscriptionSnapshot = await FirebaseFirestore.instance
            .collection('subscriptions')
            .doc(userId)
            .get();

        // Get current subscription status
        SubscriptionStatus currentStatus = SubscriptionStatus.expired;
        try {
          currentStatus = await SubscriptionService.getSubscriptionStatus(userId);
        } catch (e) {
          _logger.warning('Error getting status for user $userId: $e');
        }

        final journey = UserJourney(
          userId: userId,
          email: userData['email'] ?? 'Unknown',
          name: userData['name'] ?? 'Unknown',
          username: userData['username'] ?? 'Unknown',
          registrationDate: userData['createdAt'] as Timestamp?,
          emailVerified: userData['emailVerified'] ?? false,
          emailVerifiedAt: userData['emailVerifiedAt'] as Timestamp?,
          trialData: trialSnapshot.docs.isNotEmpty ? trialSnapshot.docs.first.data() : null,
          subscriptionData: subscriptionSnapshot.exists ? subscriptionSnapshot.data() : null,
          currentStatus: currentStatus,
        );

        userJourneys.add(journey);
      }

      setState(() {
        _userJourneys = userJourneys;
        _isLoading = false;
      });

      _logger.info('Loaded ${userJourneys.length} user journeys');
    } catch (e) {
      _logger.severe('Error loading user journeys: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<UserJourney> get _filteredJourneys {
    if (_searchQuery.isEmpty) return _userJourneys;
    
    return _userJourneys.where((journey) {
      return journey.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             journey.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             journey.username.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserJourneys,
            tooltip: 'Refresh Data',
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
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by email, name, or username...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[800],
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          
          // Stats Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildStatCard('Total Users', _userJourneys.length.toString(), Colors.blue),
                const SizedBox(width: 8),
                _buildStatCard('Active Trials', _userJourneys.where((j) => j.currentStatus == SubscriptionStatus.trial).length.toString(), Colors.orange),
                const SizedBox(width: 8),
                _buildStatCard('Subscribers', _userJourneys.where((j) => j.currentStatus == SubscriptionStatus.active).length.toString(), Colors.green),
                const SizedBox(width: 8),
                _buildStatCard('Cancelled', _userJourneys.where((j) => j.currentStatus == SubscriptionStatus.cancelled).length.toString(), Colors.red),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // User Journey Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildUserJourneyTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: Colors.grey[800],
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserJourneyTable() {
    if (_filteredJourneys.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: MaterialStateProperty.all(Colors.grey[800]),
          dataRowColor: MaterialStateProperty.all(Colors.grey[850]),
          columns: const [
            DataColumn(label: Text('User Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Registration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Email Verified', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Trial Started', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Trial Ends', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Subscription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Current Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
          rows: _filteredJourneys.map((journey) => _buildUserRow(journey)).toList(),
        ),
      ),
    );
  }

  DataRow _buildUserRow(UserJourney journey) {
    return DataRow(
      cells: [
        // User Info
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(journey.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(journey.email, style: const TextStyle(color: Colors.blue, fontSize: 12)),
              Text('@${journey.username}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
        
        // Registration
        DataCell(
          Text(
            _formatDateTime(journey.registrationDate),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        
        // Email Verified
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                journey.emailVerified ? Icons.check_circle : Icons.cancel,
                color: journey.emailVerified ? Colors.green : Colors.red,
                size: 16,
              ),
              if (journey.emailVerifiedAt != null)
                Text(
                  _formatDateTime(journey.emailVerifiedAt),
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
            ],
          ),
        ),
        
        // Trial Started
        DataCell(
          Text(
            journey.trialData != null 
                ? _formatDateTime(journey.trialData!['trialStartDate'])
                : 'No Trial',
            style: TextStyle(
              color: journey.trialData != null ? Colors.orange : Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
        
        // Trial Ends
        DataCell(
          Text(
            journey.trialData != null 
                ? _formatDateTime(journey.trialData!['trialEndDate'])
                : 'N/A',
            style: TextStyle(
              color: journey.trialData != null ? Colors.orange : Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
        
        // Subscription
        DataCell(
          journey.subscriptionData != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      journey.subscriptionData!['plan']?.toString().toUpperCase() ?? 'N/A',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    if (journey.subscriptionData!['subscriptionStartDate'] != null)
                      Text(
                        'Started: ${_formatDateTime(journey.subscriptionData!['subscriptionStartDate'])}',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    if (journey.subscriptionData!['subscriptionEndDate'] != null)
                      Text(
                        'Ends: ${_formatDateTime(journey.subscriptionData!['subscriptionEndDate'])}',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    if (journey.subscriptionData!['cancelledAt'] != null)
                      Text(
                        'Cancelled: ${_formatDateTime(journey.subscriptionData!['cancelledAt'])}',
                        style: const TextStyle(color: Colors.red, fontSize: 10),
                      ),
                  ],
                )
              : const Text('No Subscription', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        
        // Current Status
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(journey.currentStatus).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getStatusColor(journey.currentStatus)),
            ),
            child: Text(
              _getStatusText(journey.currentStatus),
              style: TextStyle(
                color: _getStatusColor(journey.currentStatus),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
        
        // Actions
        DataCell(
          IconButton(
            icon: const Icon(Icons.info, color: Colors.blue, size: 20),
            onPressed: () => _showUserDetails(journey),
            tooltip: 'View Details',
          ),
        ),
      ],
    );
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = timestamp.toDate();
      }
      return '${date.day}/${date.month}/${date.year}\n${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Color _getStatusColor(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.trial:
        return Colors.orange;
      case SubscriptionStatus.active:
        return Colors.green;
      case SubscriptionStatus.cancelled:
        return Colors.yellow;
      case SubscriptionStatus.trialExpired:
      case SubscriptionStatus.expired:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.trial:
        return 'TRIAL';
      case SubscriptionStatus.active:
        return 'ACTIVE';
      case SubscriptionStatus.cancelled:
        return 'CANCELLED';
      case SubscriptionStatus.trialExpired:
        return 'TRIAL EXPIRED';
      case SubscriptionStatus.expired:
        return 'EXPIRED';
      default:
        return 'UNKNOWN';
    }
  }

  void _showUserDetails(UserJourney journey) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details: ${journey.name}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Email: ${journey.email}'),
              Text('Username: ${journey.username}'),
              Text('User ID: ${journey.userId}'),
              const SizedBox(height: 16),
              const Text('Timeline:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('1. Registered: ${_formatDateTime(journey.registrationDate)}'),
              if (journey.emailVerifiedAt != null)
                Text('2. Email Verified: ${_formatDateTime(journey.emailVerifiedAt)}'),
              if (journey.trialData != null) ...[
                Text('3. Trial Started: ${_formatDateTime(journey.trialData!['trialStartDate'])}'),
                Text('4. Trial Ends: ${_formatDateTime(journey.trialData!['trialEndDate'])}'),
              ],
              if (journey.subscriptionData != null) ...[
                if (journey.subscriptionData!['subscriptionStartDate'] != null)
                  Text('5. Subscribed: ${_formatDateTime(journey.subscriptionData!['subscriptionStartDate'])}'),
                if (journey.subscriptionData!['cancelledAt'] != null)
                  Text('6. Cancelled: ${_formatDateTime(journey.subscriptionData!['cancelledAt'])}'),
              ],
              const SizedBox(height: 16),
              Text('Current Status: ${_getStatusText(journey.currentStatus)}', 
                   style: TextStyle(color: _getStatusColor(journey.currentStatus), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class UserJourney {
  final String userId;
  final String email;
  final String name;
  final String username;
  final Timestamp? registrationDate;
  final bool emailVerified;
  final Timestamp? emailVerifiedAt;
  final Map<String, dynamic>? trialData;
  final Map<String, dynamic>? subscriptionData;
  final SubscriptionStatus currentStatus;

  UserJourney({
    required this.userId,
    required this.email,
    required this.name,
    required this.username,
    required this.registrationDate,
    required this.emailVerified,
    required this.emailVerifiedAt,
    required this.trialData,
    required this.subscriptionData,
    required this.currentStatus,
  });
}