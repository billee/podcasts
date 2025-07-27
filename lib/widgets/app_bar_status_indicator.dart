import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:kapwa_companion_basic/services/user_status_service.dart';
import 'package:logging/logging.dart';

class AppBarStatusIndicator extends StatefulWidget {
  const AppBarStatusIndicator({super.key});

  @override
  State<AppBarStatusIndicator> createState() => _AppBarStatusIndicatorState();
}

class _AppBarStatusIndicatorState extends State<AppBarStatusIndicator> {
  final Logger _logger = Logger('AppBarStatusIndicator');
  SubscriptionStatus? _subscriptionStatus;
  Map<String, dynamic>? _subscriptionDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatusInfo();
  }

  Future<void> _loadStatusInfo() async {
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
      _logger.severe('Error loading status info: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Trial countdown indicator
        if (_subscriptionStatus == SubscriptionStatus.trial) _buildTrialCountdown(),
        
        // Premium diamond indicator
        if (_subscriptionStatus == SubscriptionStatus.active) _buildPremiumIndicator(),
        
        // Trial expired indicator
        if (_subscriptionStatus == SubscriptionStatus.trialExpired) _buildTrialExpiredIndicator(),
        
        // Cancelled subscription indicator
        if (_subscriptionStatus == SubscriptionStatus.cancelled) _buildCancelledIndicator(),
      ],
    );
  }

  Widget _buildTrialCountdown() {
    final daysLeft = _subscriptionDetails?['trialDaysLeft'] as int? ?? 0;
    final hoursLeft = _subscriptionDetails?['trialHoursLeft'] as int? ?? 0;
    
    String timeText;
    Color indicatorColor;
    
    if (daysLeft > 0) {
      timeText = '${daysLeft}d';
      indicatorColor = daysLeft <= 1 ? Colors.red : (daysLeft <= 3 ? Colors.orange : Colors.blue);
    } else if (hoursLeft > 0) {
      timeText = '${hoursLeft}h';
      indicatorColor = Colors.red;
    } else {
      timeText = '0h';
      indicatorColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: indicatorColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            size: 16,
            color: indicatorColor,
          ),
          const SizedBox(width: 4),
          Text(
            timeText,
            style: TextStyle(
              color: indicatorColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumIndicator() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: const Icon(
          Icons.diamond,
          color: Colors.red,
          size: 24,
        ),
        onPressed: () {
          _showStatusDialog(
            title: 'Premium Subscriber',
            content: 'You are a Premium Subscriber! 💎\n\nEnjoy unlimited access to all features.',
            color: Colors.red,
          );
        },
        tooltip: 'Premium Subscriber',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildTrialExpiredIndicator() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 20,
        ),
        onPressed: () {
          _showStatusDialog(
            title: 'Trial Expired',
            content: 'Your 7-day trial has expired.\n\nUpgrade to Premium to continue using all features.',
            color: Colors.red,
          );
        },
        tooltip: 'Trial Expired',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildCancelledIndicator() {
    final willExpireAt = _subscriptionDetails?['willExpireAt'];
    String expirationText = 'Unknown';
    
    if (willExpireAt != null) {
      try {
        final date = willExpireAt.toDate();
        expirationText = '${date.day}/${date.month}/${date.year}';
      } catch (e) {
        _logger.warning('Error formatting expiration date: $e');
      }
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: const Icon(
          Icons.cancel_outlined,
          color: Colors.orange,
          size: 20,
        ),
        onPressed: () {
          _showStatusDialog(
            title: 'Subscription Cancelled',
            content: 'Your subscription has been cancelled.\n\nYou will have access until $expirationText.',
            color: Colors.orange,
          );
        },
        tooltip: 'Subscription Cancelled',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  void _showStatusDialog({
    required String title,
    required String content,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}