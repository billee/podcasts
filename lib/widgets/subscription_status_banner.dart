import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:kapwa_companion_basic/screens/payment_screen.dart';
import 'package:kapwa_companion_basic/widgets/loading_state_widget.dart';
import 'package:logging/logging.dart';

class SubscriptionStatusBanner extends StatefulWidget {
  const SubscriptionStatusBanner({super.key});

  @override
  State<SubscriptionStatusBanner> createState() => _SubscriptionStatusBannerState();
}

class _SubscriptionStatusBannerState extends State<SubscriptionStatusBanner> {
  final Logger _logger = Logger('SubscriptionStatusBanner');
  SubscriptionStatus? _subscriptionStatus;
  Map<String, dynamic>? _subscriptionDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
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

      _logger.info('Subscription status loaded: ${status.name}');
    } catch (e) {
      _logger.severe('Error loading subscription status: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.5), width: 2),
        ),
        child: const Row(
          children: [
            LoadingStateWidget(
              type: LoadingType.dots,
              size: 6,
              showMessage: false,
              color: Colors.grey,
            ),
            SizedBox(width: 12),
            Text(
              'Loading status...',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Don't show banner if user doesn't have email verified
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      return const SizedBox.shrink();
    }

    return _buildStatusBanner();
  }

  Widget _buildStatusBanner() {
    // No subscription banners for trial users
    // if (_subscriptionStatus == SubscriptionStatus.trial) {
    //   return _buildTrialBanner();
    // }
    
    return const SizedBox.shrink();
  }

  Widget _buildSubscribedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.5), width: 2),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Premium Subscriber',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Icon(
            Icons.star,
            color: Colors.green[700],
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTrialBanner() {
    final daysLeft = _subscriptionDetails?['trialDaysLeft'] as int? ?? 0;
    final hoursLeft = _subscriptionDetails?['trialHoursLeft'] as int? ?? 0;
    
    String timeLeftText;
    if (daysLeft > 0) {
      timeLeftText = 'Trial: $daysLeft Day${daysLeft == 1 ? '' : 's'} Left';
    } else if (hoursLeft > 0) {
      timeLeftText = 'Trial: $hoursLeft Hour${hoursLeft == 1 ? '' : 's'} Left';
    } else {
      timeLeftText = 'Trial: Ending Soon';
    }

    Color bannerColor = daysLeft <= 1 ? Colors.red : (daysLeft <= 3 ? Colors.orange : Colors.blue);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Text(
              timeLeftText,
              style: TextStyle(
                color: bannerColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          if (daysLeft <= 3)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaymentScreen(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: bannerColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}