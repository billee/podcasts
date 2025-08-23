import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:kapwa_companion_basic/widgets/loading_state_widget.dart';
import 'package:kapwa_companion_basic/widgets/feedback_widget.dart';
import 'package:kapwa_companion_basic/widgets/subscription_confirmation_dialog.dart';
import 'package:kapwa_companion_basic/screens/subscription/subscription_screen.dart';
import 'package:kapwa_companion_basic/screens/payment/mock_payment_screen.dart';
import 'package:logging/logging.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> {
  final Logger _logger = Logger('SubscriptionManagementScreen');
  SubscriptionStatus? _subscriptionStatus;
  Map<String, dynamic>? _subscriptionDetails;
  bool _isLoading = true;
  bool _isProcessing = false;

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
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Subscription Management'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: LoadingStateWidget(
                message: 'Loading subscription details...',
                color: Colors.white,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSubscriptionInfo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCurrentPlanCard(),
                    const SizedBox(height: 24),
                    _buildPlanDetailsCard(),
                    const SizedBox(height: 24),
                    _buildAvailablePlansCard(),
                    const SizedBox(height: 24),
                    _buildManagementActionsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentPlanCard() {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Current Plan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _getCurrentPlanName(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getCurrentPlanDescription(),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDetailsCard() {
    if (_subscriptionDetails == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plan Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRows(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRows() {
    final details = _subscriptionDetails!;
    List<Widget> rows = [];

    // Status
    rows.add(_buildDetailRow('Status', _getStatusText()));

    // Plan type
    final plan = details['plan'] as String? ?? 'unknown';
    rows.add(_buildDetailRow('Plan Type', plan.toUpperCase()));

    // Trial specific details
    if (_subscriptionStatus == SubscriptionStatus.trial) {
      final daysLeft = details['trialDaysLeft'] as int? ?? 0;
      final hoursLeft = details['trialHoursLeft'] as int? ?? 0;
      
      if (daysLeft > 0) {
        rows.add(_buildDetailRow('Trial Days Remaining', '$daysLeft days'));
      } else if (hoursLeft > 0) {
        rows.add(_buildDetailRow('Trial Time Remaining', '$hoursLeft hours'));
      } else {
        rows.add(_buildDetailRow('Trial Status', 'Ending very soon'));
      }
      
      if (details['trialEndDate'] != null) {
        rows.add(_buildDetailRow('Trial End Date', _formatDate(details['trialEndDate'])));
      }
    }

    // Active subscription details
    if (_subscriptionStatus == SubscriptionStatus.active) {
      final price = details['price'] as double? ?? 0.0;
      rows.add(_buildDetailRow('Monthly Price', '\$${price.toStringAsFixed(2)}'));
      
      if (details['nextBillingDate'] != null) {
        rows.add(_buildDetailRow('Next Billing Date', _formatDate(details['nextBillingDate'])));
      }
      
      if (details['lastPaymentDate'] != null) {
        rows.add(_buildDetailRow('Last Payment', _formatDate(details['lastPaymentDate'])));
      }
    }

    // Cancelled subscription details
    if (_subscriptionStatus == SubscriptionStatus.cancelled) {
      if (details['willExpireAt'] != null) {
        rows.add(_buildDetailRow('Access Until', _formatDate(details['willExpireAt'])));
      }
      
      if (details['cancelledAt'] != null) {
        rows.add(_buildDetailRow('Cancelled On', _formatDate(details['cancelledAt'])));
      }
    }

    // Member since
    if (details['createdAt'] != null) {
      rows.add(_buildDetailRow('Member Since', _formatDate(details['createdAt'])));
    }

    return Column(children: rows);
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8), 
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2, 
              overflow: TextOverflow.ellipsis, 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailablePlansCard() {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Plans',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildPremiumPlanOption(),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumPlanOption() {
    final isCurrentPlan = _subscriptionStatus == SubscriptionStatus.active;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlan ? Colors.green : Colors.blue[800]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              Text(
                'Premium Monthly',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (isCurrentPlan)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'CURRENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$3.00',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '/month',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Features included:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ..._buildFeatureList([
            'More AI Chat tokens',
            'More Stories',
            'More Podcast Content',
          ]),
        ],
      ),
    );
  }

  List<Widget> _buildFeatureList(List<String> features) {
    return features.map((feature) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[400],
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            feature,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    )).toList();
  }

  Widget _buildManagementActionsCard() {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Subscription',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    List<Widget> buttons = [];

    // Upgrade/Subscribe button
    if (_shouldShowUpgradeButton()) {
      buttons.add(_buildUpgradeButton());
      buttons.add(const SizedBox(height: 12));
    }

    // Cancel subscription button
    if (_shouldShowCancelButton()) {
      buttons.add(_buildCancelButton());
      buttons.add(const SizedBox(height: 12));
    }

    // Reactivate button for cancelled subscriptions
    if (_subscriptionStatus == SubscriptionStatus.cancelled) {
      buttons.add(_buildReactivateButton());
      buttons.add(const SizedBox(height: 12));
    }

    return Column(children: buttons);
  }

  Widget _buildUpgradeButton() {
    String buttonText;
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trial:
        buttonText = 'Upgrade to Premium';
        break;
      case SubscriptionStatus.trialExpired:
        buttonText = 'Subscribe to Premium';
        break;
      case SubscriptionStatus.expired:
        buttonText = 'Renew Subscription';
        break;
      default:
        buttonText = 'Subscribe to Premium';
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _handleUpgrade,
        icon: const Icon(Icons.upgrade),
        label: Text(buttonText),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isProcessing ? null : _showCancelConfirmationDialog,
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Cancel Subscription'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildReactivateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _handleReactivate,
        icon: const Icon(Icons.refresh),
        label: const Text('Reactivate Subscription'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStatusColor()),
      ),
      child: Text(
        _getStatusText(),
        style: TextStyle(
          color: _getStatusColor(),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // Helper methods
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

  String _getCurrentPlanName() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trial:
        return 'Free Trial';
      case SubscriptionStatus.active:
        return 'Premium Monthly';
      case SubscriptionStatus.trialExpired:
        return 'Trial Expired';
      case SubscriptionStatus.expired:
        return 'Subscription Expired';
      case SubscriptionStatus.cancelled:
        return 'Premium Monthly (Cancelled)';
      default:
        return 'No Active Plan';
    }
  }

  String _getCurrentPlanDescription() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trial:
        final daysLeft = _subscriptionDetails?['trialDaysLeft'] as int? ?? 0;
        if (daysLeft > 1) {
          return '$daysLeft days remaining in your free trial';
        } else if (daysLeft == 1) {
          return 'Last day of your free trial';
        } else {
          return 'Trial ending very soon';
        }
      case SubscriptionStatus.active:
        return 'Full access to all premium features';
      case SubscriptionStatus.trialExpired:
        return 'Your 7-day trial has ended';
      case SubscriptionStatus.expired:
        return 'Your subscription has expired';
      case SubscriptionStatus.cancelled:
        return 'Cancelled - Access until end of billing period';
      default:
        return 'No active subscription';
    }
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
        return 'INACTIVE';
    }
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

  bool _shouldShowCancelButton() {
    return _subscriptionStatus == SubscriptionStatus.active;
  }

  // Action handlers
  Future<void> _handleUpgrade() async {
    // Go directly to payment screen instead of subscription screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MockPaymentScreen(
          amount: 3.00,
          planType: 'monthly',
        ),
      ),
    ).then((_) {
      // Refresh subscription info when returning from payment screen
      _loadSubscriptionInfo();
    });
  }

  Future<void> _showCancelConfirmationDialog() async {
    final subscriptionEndDate = _subscriptionDetails?['subscriptionEndDate'];
    final endDateText = subscriptionEndDate != null 
        ? _formatDate(subscriptionEndDate)
        : 'the end of your billing period';

    await SubscriptionConfirmationDialog.showCancellationDialog(
      context: context,
      endDate: endDateText,
      onConfirm: _handleCancelSubscription,
    );
  }

  Future<void> _handleCancelSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final success = await SubscriptionService.cancelSubscription(user.uid);
      
      if (success) {
        await _loadSubscriptionInfo();
        
        if (mounted) {
          FeedbackManager.showSuccess(
            context,
            message: 'Subscription cancelled successfully. You will have access until the end of your billing period.',
            duration: const Duration(seconds: 4),
          );
        }
      } else {
        if (mounted) {
          FeedbackManager.showError(
            context,
            message: 'Failed to cancel subscription. Please try again.',
          );
        }
      }
    } catch (e) {
      _logger.severe('Error cancelling subscription: $e');
      if (mounted) {
        FeedbackManager.showError(
          context,
          message: 'Error: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleReactivate() async {
    // Go directly to payment screen for reactivation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MockPaymentScreen(
          amount: 3.00,
          planType: 'monthly',
        ),
      ),
    ).then((_) {
      _loadSubscriptionInfo();
    });
  }
}