import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:kapwa_companion_basic/screens/subscription/subscription_screen.dart';
import 'package:logging/logging.dart';

class SubscriptionStatusWidget extends StatefulWidget {
  const SubscriptionStatusWidget({super.key});

  @override
  State<SubscriptionStatusWidget> createState() => _SubscriptionStatusWidgetState();
}

class _SubscriptionStatusWidgetState extends State<SubscriptionStatusWidget> {
  final Logger _logger = Logger('SubscriptionStatusWidget');
  SubscriptionStatus? _subscriptionStatus;
  Map<String, dynamic>? _subscriptionDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionInfo();
  }

  Future<void> _loadSubscriptionInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final status = await SubscriptionService.getSubscriptionStatus(user.uid);
      final details = await SubscriptionService.getSubscriptionDetails(user.uid);

      setState(() {
        _subscriptionStatus = status;
        _subscriptionDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      _logger.severe('Error loading subscription info: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        color: Colors.grey,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

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
                  _getStatusIcon(),
                  color: _getStatusColor(),
                ),
                const SizedBox(width: 10),
                Text(
                  'SUBSCRIPTION STATUS',
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSubscriptionInfo(),
            const SizedBox(height: 16),
            if (_shouldShowUpgradeButton()) _buildUpgradeButton(),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trial:
        return Icons.access_time;
      case SubscriptionStatus.active:
        return Icons.check_circle;
      case SubscriptionStatus.trialExpired:
      case SubscriptionStatus.expired:
        return Icons.error;
      case SubscriptionStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trial:
        return Colors.orange;
      case SubscriptionStatus.active:
        return Colors.green;
      case SubscriptionStatus.trialExpired:
      case SubscriptionStatus.expired:
        return Colors.red;
      case SubscriptionStatus.cancelled:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSubscriptionInfo() {
    if (_subscriptionDetails == null) {
      return const Text(
        'No subscription information available',
        style: TextStyle(color: Colors.white70),
      );
    }

    final details = _subscriptionDetails!;
    final status = details['status'] as String? ?? 'unknown';
    final plan = details['plan'] as String? ?? 'unknown';

    return Column(
      children: [
        _buildInfoRow('Status:', _getStatusText()),
        _buildInfoRow('Plan:', plan.toUpperCase()),
        if (_subscriptionStatus == SubscriptionStatus.trial) ...[
          _buildInfoRow('Trial Days Left:', '${details['trialDaysLeft'] ?? 0}'),
        ],
        if (_subscriptionStatus == SubscriptionStatus.active) ...[
          _buildInfoRow('Price:', '\$${details['price'] ?? 0}/month'),
          if (details['nextBillingDate'] != null)
            _buildInfoRow('Next Billing:', _formatDate(details['nextBillingDate'])),
        ],
        if (details['createdAt'] != null)
          _buildInfoRow('Member Since:', _formatDate(details['createdAt'])),
      ],
    );
  }

  String _getStatusText() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trial:
        return 'TRIAL ACTIVE';
      case SubscriptionStatus.active:
        return 'PREMIUM ACTIVE';
      case SubscriptionStatus.trialExpired:
        return 'TRIAL EXPIRED';
      case SubscriptionStatus.expired:
        return 'SUBSCRIPTION EXPIRED';
      case SubscriptionStatus.cancelled:
        return 'CANCELLED';
      default:
        return 'UNKNOWN';
    }
  }

  Widget _buildInfoRow(String label, String value) {
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

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = timestamp.toDate();
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  bool _shouldShowUpgradeButton() {
    return _subscriptionStatus == SubscriptionStatus.trial ||
           _subscriptionStatus == SubscriptionStatus.trialExpired ||
           _subscriptionStatus == SubscriptionStatus.expired;
  }

  Widget _buildUpgradeButton() {
    String buttonText;
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trial:
        buttonText = 'Upgrade to Premium';
        break;
      case SubscriptionStatus.trialExpired:
        buttonText = 'Subscribe Now';
        break;
      case SubscriptionStatus.expired:
        buttonText = 'Renew Subscription';
        break;
      default:
        buttonText = 'Subscribe';
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SubscriptionScreen(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          buttonText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}