import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/subscription_service.dart';
import '../screens/subscription/subscription_management_screen.dart';
import 'subscription_status_indicator.dart';
import '../core/config.dart';

/// Widget that displays subscription information in the profile screen
/// Shows trial status for trial users and subscription status for subscribers
class ProfileSubscriptionSection extends StatefulWidget {
  const ProfileSubscriptionSection({super.key});

  @override
  State<ProfileSubscriptionSection> createState() => _ProfileSubscriptionSectionState();
}

class _ProfileSubscriptionSectionState extends State<ProfileSubscriptionSection> {
  SubscriptionStatus? _status;
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
      
      // Debug logging
      print('DEBUG ProfileSubscriptionSection: Status = ${status.name}');
      print('DEBUG ProfileSubscriptionSection: Details = $details');
      
      if (mounted) {
        setState(() {
          _status = status;
          _subscriptionDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('DEBUG ProfileSubscriptionSection: Error = $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Subscription Status',
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
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          _getStatusTitle(),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusIcon(),
              const SizedBox(height: 12),
              _buildStatusInfo(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildActionButton(),
      ],
    );
  }

  String _getStatusTitle() {
    if (_status == null) return 'Subscription Status';
    
    switch (_status!) {
      case SubscriptionStatus.trial:
        return 'Trial Status';
      case SubscriptionStatus.active:
      case SubscriptionStatus.cancelled:
        return 'Subscription Status';
      case SubscriptionStatus.expired:
      case SubscriptionStatus.trialExpired:
        return 'Account Status';
    }
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;
    String statusText;

    if (_status == null) {
      icon = Icons.help_outline;
      color = Colors.grey;
      statusText = 'Unknown Status';
    } else {
      switch (_status!) {
        case SubscriptionStatus.trial:
          icon = Icons.schedule;
          color = Colors.orange;
          statusText = 'Trial Active';
          break;
        case SubscriptionStatus.active:
          icon = Icons.diamond;
          color = Colors.green;
          statusText = 'Premium Subscriber';
          break;
        case SubscriptionStatus.cancelled:
          icon = Icons.cancel;
          color = Colors.orange;
          statusText = 'Subscription Cancelled';
          break;
        case SubscriptionStatus.expired:
        case SubscriptionStatus.trialExpired:
          icon = Icons.block;
          color = Colors.red;
          statusText = 'Expired';
          break;
      }
    }

    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(width: 12),
        Text(
          statusText,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusInfo() {
    if (_status == null || _subscriptionDetails == null) {
      return const Text(
        'Unable to load subscription information',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
      );
    }

    switch (_status!) {
      case SubscriptionStatus.trial:
        return _buildTrialInfo();
      case SubscriptionStatus.active:
        return _buildActiveSubscriptionInfo();
      case SubscriptionStatus.cancelled:
        return _buildCancelledSubscriptionInfo();
      case SubscriptionStatus.expired:
      case SubscriptionStatus.trialExpired:
        return _buildExpiredInfo();
    }
  }

  Widget _buildTrialInfo() {
    final trialDaysLeft = _subscriptionDetails?['trialDaysLeft'] ?? 0;
    final trialHoursLeft = _subscriptionDetails?['trialHoursLeft'] ?? 0;
    
    String timeRemaining;
    if (trialDaysLeft > 0) {
      timeRemaining = '$trialDaysLeft day${trialDaysLeft == 1 ? '' : 's'} remaining';
    } else if (trialHoursLeft > 0) {
      timeRemaining = '$trialHoursLeft hour${trialHoursLeft == 1 ? '' : 's'} remaining';
    } else {
      timeRemaining = 'Trial expired';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          timeRemaining,
          style: TextStyle(
            color: trialDaysLeft <= 1 ? Colors.red[300] : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enjoy access to all features during your trial period.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (trialDaysLeft <= 2) ...[
          const SizedBox(height: 8),
          Text(
            '⚠️ Your trial is ending soon. Subscribe to continue using premium features.',
            style: TextStyle(
              color: Colors.orange[300],
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActiveSubscriptionInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You have full access to all premium features.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Thank you for supporting Kapwa Companion!',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelledSubscriptionInfo() {
    // Use willExpireAt field for cancelled subscriptions
    final willExpireAt = _subscriptionDetails?['willExpireAt'];
    String expirationText = 'the end of your billing period';
    
    if (willExpireAt != null) {
      try {
        DateTime endDate;
        if (willExpireAt is DateTime) {
          endDate = willExpireAt;
        } else if (willExpireAt.runtimeType.toString().contains('Timestamp')) {
          // Handle Firestore Timestamp
          endDate = willExpireAt.toDate();
        } else {
          // Try parsing as string
          endDate = DateTime.parse(willExpireAt.toString());
        }
        // Format as "Sept 3, 2025"
        const monthNames = [
          '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'
        ];
        final monthName = monthNames[endDate.month];
        expirationText = '$monthName ${endDate.day}, ${endDate.year}';
      } catch (e) {
        print('DEBUG: Error parsing willExpireAt: $e, value: $willExpireAt, type: ${willExpireAt.runtimeType}');
        expirationText = 'the end of your billing period';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your subscription is cancelled and will expire on $expirationText.',
          style: TextStyle(
            color: Colors.orange[300],
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You can reactivate your subscription at any time before it expires.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildExpiredInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your access to premium features has expired.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Subscribe to regain access to all premium features and continue your journey with Kapwa Companion.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    if (_status == null) {
      return const SizedBox.shrink();
    }

    String buttonText;
    Color buttonColor;
    VoidCallback? onPressed;

    switch (_status!) {
      case SubscriptionStatus.trial:
        buttonText = 'Subscribe Now';
        buttonColor = Colors.green[600]!;
        onPressed = _navigateToSubscription;
        break;
      case SubscriptionStatus.active:
        buttonText = 'Cancel Subscription';
        buttonColor = Colors.red[600]!;
        onPressed = _showCancelSubscriptionDialog;
        break;
      case SubscriptionStatus.cancelled:
        buttonText = 'Reactivate Subscription';
        buttonColor = Colors.green[600]!;
        onPressed = _navigateToSubscription;
        break;
      case SubscriptionStatus.expired:
      case SubscriptionStatus.trialExpired:
        buttonText = 'Subscribe';
        buttonColor = Colors.green[600]!;
        onPressed = _navigateToSubscription;
        break;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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

  void _navigateToSubscription() {
    // For cancelled subscriptions, we need to handle reactivation differently
    if (_status == SubscriptionStatus.cancelled) {
      _handleReactivateSubscription();
    } else {
      // For other statuses (trial, expired), go to subscription management
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SubscriptionManagementScreen(),
        ),
      );
    }
  }

  Future<void> _handleReactivateSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if subscription is still within the valid period (not expired)
    final willExpireAt = _subscriptionDetails?['willExpireAt'];
    final now = AppConfig.currentDateTime;
    bool isStillValid = false;

    if (willExpireAt != null) {
      try {
        DateTime expirationDate;
        if (willExpireAt.runtimeType.toString().contains('Timestamp')) {
          expirationDate = willExpireAt.toDate();
        } else if (willExpireAt is DateTime) {
          expirationDate = willExpireAt;
        } else {
          expirationDate = DateTime.parse(willExpireAt.toString());
        }
        isStillValid = now.isBefore(expirationDate);
      } catch (e) {
        print('Error parsing expiration date: $e');
        isStillValid = false;
      }
    }

    if (isStillValid) {
      // Case 1: Cancelled but not expired - just reactivate
      await _reactivateCancelledSubscription();
    } else {
      // Case 2: Expired - go through payment process
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SubscriptionManagementScreen(),
        ),
      );
    }
  }

  Future<void> _reactivateCancelledSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Reactivate the subscription by changing status back to 'active'
      await SubscriptionService.reactivateSubscription(user.uid);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Reload subscription info
      await _loadSubscriptionInfo();

      // Trigger refresh of SubscriptionStatusIndicator immediately
      subscriptionIndicatorKey.currentState?.refreshStatus();
      print('DEBUG: Subscription reactivated - forcing UI refresh');
      print('DEBUG: New status should be active');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription reactivated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reactivating subscription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCancelSubscriptionDialog() {
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
            'Are you sure you want to cancel your subscription? You will lose access to premium features at the end of your billing period.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep Subscription'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _cancelSubscription();
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

  Future<void> _cancelSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Cancel the subscription
      await SubscriptionService.cancelSubscription(user.uid);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Reload subscription info
      await _loadSubscriptionInfo();

      // Trigger refresh of SubscriptionStatusIndicator immediately
      subscriptionIndicatorKey.currentState?.refreshStatus();
      print('DEBUG: Subscription cancelled - forcing UI refresh');
      print('DEBUG: New status should be cancelled');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling subscription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}