import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/subscription_service.dart';
import '../screens/subscription/subscription_management_screen.dart';

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
      
      if (mounted) {
        setState(() {
          _status = status;
          _subscriptionDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
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
          icon = Icons.diamond_outlined;
          color = Colors.orange;
          statusText = 'Subscription Ending';
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
          'Enjoy unlimited access to all features during your trial period.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your subscription has been cancelled but is still active until the end of your billing period.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You can reactivate your subscription at any time.',
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
        buttonText = 'Manage Subscription';
        buttonColor = Colors.blue[600]!;
        onPressed = _navigateToSubscription;
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubscriptionManagementScreen(),
      ),
    );
  }
}