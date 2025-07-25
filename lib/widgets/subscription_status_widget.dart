import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
            if (_shouldShowUnsubscribeButton()) _buildUnsubscribeButton(),
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
        if (_subscriptionStatus == SubscriptionStatus.cancelled) ...[
          _buildInfoRow('Status:', 'CANCELLED - Access until end of billing period'),
          if (details['willExpireAt'] != null)
            _buildInfoRow('Access Until:', _formatDate((details['willExpireAt'] as Timestamp).toDate())),
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

  bool _shouldShowUnsubscribeButton() {
    return _subscriptionStatus == SubscriptionStatus.active;
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

  Widget _buildUnsubscribeButton() {
    final subscriptionEndDate = _subscriptionDetails?['subscriptionEndDate'] as Timestamp?;
    final endDateText = subscriptionEndDate != null 
        ? _formatDate(subscriptionEndDate.toDate())
        : 'Unknown';

    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _showUnsubscribeDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Cancel Subscription',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your subscription will remain active until $endDateText',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }



  Future<void> _showUnsubscribeDialog() async {
    final subscriptionEndDate = _subscriptionDetails?['subscriptionEndDate'] as Timestamp?;
    final endDateText = subscriptionEndDate != null 
        ? _formatDate(subscriptionEndDate.toDate())
        : 'the end of your billing period';

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel your subscription?'),
            const SizedBox(height: 16),
            Text('• You will keep access until $endDateText'),
            const Text('• No refund for the current billing period'),
            const Text('• You can resubscribe anytime'),
            const Text('• No more trial period after cancellation'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      await _cancelSubscription();
    }
  }

  Future<void> _cancelSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final success = await SubscriptionService.cancelSubscription(user.uid);
      
      if (success) {
        // Reload subscription info
        await _loadSubscriptionInfo();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription cancelled successfully. You will have access until the end of your billing period.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel subscription. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      _logger.severe('Error cancelling subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}