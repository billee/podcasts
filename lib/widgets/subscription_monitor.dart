import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:kapwa_companion_basic/screens/subscription/subscription_screen.dart';
import 'package:kapwa_companion_basic/core/config.dart';
import 'package:logging/logging.dart';

class SubscriptionMonitor extends StatefulWidget {
  final Widget child;
  
  const SubscriptionMonitor({
    super.key,
    required this.child,
  });

  @override
  State<SubscriptionMonitor> createState() => _SubscriptionMonitorState();
}

class _SubscriptionMonitorState extends State<SubscriptionMonitor> {
  final Logger _logger = Logger('SubscriptionMonitor');
  SubscriptionStatus? _subscriptionStatus;
  Map<String, dynamic>? _subscriptionDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
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

      _logger.info('Subscription status: ${status.name}');
    } catch (e) {
      _logger.severe('Error checking subscription status: $e');
      // If there's an error, assume trial is active for new users
      setState(() {
        _subscriptionStatus = SubscriptionStatus.trial;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show subscription screen if trial expired or no active subscription
    if (_subscriptionStatus == SubscriptionStatus.trialExpired ||
        _subscriptionStatus == SubscriptionStatus.expired) {
      return const SubscriptionScreen();
    }

    // Show main app with subscription banner if needed
    return Column(
      children: [
        if (_shouldShowSubscriptionBanner()) _buildSubscriptionBanner(),
        Expanded(child: widget.child),
      ],
    );
  }

  bool _shouldShowSubscriptionBanner() {
    // No subscription banner for trial users
    // if (_subscriptionStatus == SubscriptionStatus.trial && _subscriptionDetails != null) {
    //   final daysLeft = _subscriptionDetails!['trialDaysLeft'] as int? ?? 0;
    //   return daysLeft <= 3; // Show banner when 3 days or less remaining
    // }
    return false;
  }

  Widget _buildSubscriptionBanner() {
    final daysLeft = _subscriptionDetails!['trialDaysLeft'] as int? ?? 0;
    final hoursLeft = _subscriptionDetails!['trialHoursLeft'] as int? ?? 0;
    
    String timeLeftText;
    if (daysLeft > 0) {
      timeLeftText = '$daysLeft day${daysLeft == 1 ? '' : 's'} left';
    } else if (hoursLeft > 0) {
      timeLeftText = '$hoursLeft hour${hoursLeft == 1 ? '' : 's'} left';
    } else {
      timeLeftText = 'Trial ending soon';
    }

    Color bannerColor = daysLeft <= 1 ? Colors.red : Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor.withOpacity(0.5), width: 2),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: bannerColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trial Period: $timeLeftText',
                  style: TextStyle(
                    color: bannerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Subscribe now for just \$${AppConfig.monthlySubscriptionPrice.toStringAsFixed(0)}/month to continue using all features',
                  style: TextStyle(
                    color: bannerColor.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: bannerColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Subscribe',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}