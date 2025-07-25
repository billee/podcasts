import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:kapwa_companion_basic/screens/main_screen.dart';
import 'package:logging/logging.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final Logger _logger = Logger('SubscriptionScreen');
  bool _isLoading = false;
  SubscriptionStatus? _subscriptionStatus;
  Map<String, dynamic>? _subscriptionDetails;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionInfo();
  }

  Future<void> _loadSubscriptionInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final status = await SubscriptionService.getSubscriptionStatus(user.uid);
      final details = await SubscriptionService.getSubscriptionDetails(user.uid);

      _logger.info('Loaded subscription - Status: ${status.name}, Details: $details');

      setState(() {
        _subscriptionStatus = status;
        _subscriptionDetails = details;
      });
    } catch (e) {
      _logger.severe('Error loading subscription info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // Premium Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[800]?.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star,
                size: 60,
                color: Colors.blue[800],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              _getTitle(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Subtitle
            Text(
              _getSubtitle(),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Subscription Plan Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[800]!, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.diamond,
                        color: Colors.blue[800],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Premium Monthly',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$3',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      Text(
                        '/month',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Features
                  Column(
                    children: [
                      _buildFeatureItem('Unlimited AI Chat'),
                      _buildFeatureItem('Access to All Stories'),
                      _buildFeatureItem('Premium Podcast Content'),
                      _buildFeatureItem('Priority Support'),
                      _buildFeatureItem('No Ads'),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Subscribe Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Subscribe Now',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Terms and conditions
            Text(
              'By subscribing, you agree to our Terms of Service and Privacy Policy. Subscription automatically renews monthly.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Trial info (if applicable)
            if (_subscriptionStatus == SubscriptionStatus.trial && _subscriptionDetails != null)
              _buildTrialInfo(),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trialExpired:
        return 'Trial Period Ended';
      case SubscriptionStatus.expired:
        return 'Subscription Expired';
      case SubscriptionStatus.trial:
        final daysLeft = _subscriptionDetails?['trialDaysLeft'] as int? ?? 0;
        if (daysLeft <= 1) {
          return 'Trial Ending Soon';
        }
        return 'Upgrade to Premium';
      default:
        return 'Get Premium Access';
    }
  }

  String _getSubtitle() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trialExpired:
        return 'Your 7-day trial has ended. Subscribe to continue using all features.';
      case SubscriptionStatus.expired:
        return 'Your subscription has expired. Renew to continue using premium features.';
      case SubscriptionStatus.trial:
        final daysLeft = _subscriptionDetails?['trialDaysLeft'] as int? ?? 0;
        if (daysLeft <= 1) {
          return 'Your trial ends soon. Subscribe now to avoid interruption.';
        }
        return 'Upgrade now to unlock all premium features.';
      default:
        return 'Unlock all premium features with our monthly subscription.';
    }
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            feature,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialInfo() {
    final daysLeft = _subscriptionDetails!['trialDaysLeft'] as int? ?? 0;
    final hoursLeft = _subscriptionDetails!['trialHoursLeft'] as int? ?? 0;
    
    String timeLeftText;
    if (daysLeft > 0) {
      timeLeftText = '$daysLeft day${daysLeft == 1 ? '' : 's'} remaining';
    } else if (hoursLeft > 0) {
      timeLeftText = '$hoursLeft hour${hoursLeft == 1 ? '' : 's'} remaining';
    } else {
      timeLeftText = 'Trial ending very soon';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.access_time,
            color: Colors.orange[800],
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            'Trial Status',
            style: TextStyle(
              color: Colors.orange[800],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeLeftText,
            style: TextStyle(
              color: Colors.orange[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // In a real app, you would integrate with a payment processor here
      // For now, we'll simulate a successful payment
      await _simulatePayment();
    } catch (e) {
      _logger.severe('Error during subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _simulatePayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'User not authenticated';

    // Simulate payment processing delay
    await Future.delayed(const Duration(seconds: 2));

    // For demo purposes, we'll simulate a successful payment
    // In a real app, you would integrate with Stripe, PayPal, etc.
    final success = await SubscriptionService.subscribeToMonthlyPlan(
      user.uid,
      paymentMethod: 'demo_payment',
      transactionId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription successful! Welcome to Premium!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to main screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } else {
      throw 'Payment processing failed';
    }
  }
}