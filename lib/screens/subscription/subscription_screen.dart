import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:kapwa_companion_basic/screens/main_screen.dart';
import 'package:kapwa_companion_basic/screens/terms_conditions_screen.dart';
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
      final details = await SubscriptionService.getSubscriptionDetails(
        user.uid,
      );

      _logger.info(
        'Loaded subscription - Status: ${status.name}, Details: $details',
      );

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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  _getSubtitle(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Subscription Plan Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[800]!, width: 1),
                ),
                child: Column(
                  children: [
                    // Price row including the plan name
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.diamond,
                              color: Colors.blue[800],
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Premium Monthly',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '\$3',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            Text(
                              '/mo',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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

              const SizedBox(height: 16),

              // Subscribe Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const TermsConditionsScreen(),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Subscribe Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Terms and conditions
              Text(
                'By subscribing, you agree to our Terms of Service and Privacy Policy.',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),

              // Trial info (if applicable)
              if (_subscriptionStatus == SubscriptionStatus.trial &&
                  _subscriptionDetails != null)
                _buildTrialInfo(),
            ],
          ),
        ),
      ),
    );
  }

  String _getSubtitle() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trialExpired:
      case SubscriptionStatus.expired:
        return 'Subscribe to continue using premium features';
      case SubscriptionStatus.trial:
        final daysLeft = _subscriptionDetails?['trialDaysLeft'] as int? ?? 0;
        if (daysLeft <= 1) {
          return 'Your trial ends soon. Subscribe now to continue.';
        }
        return 'Upgrade now to unlock all premium features';
      default:
        return 'Unlock all premium features with our monthly subscription';
    }
  }

  Widget _buildFeatureItem(String feature) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, color: Colors.green[400], size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            feature,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
          Icon(Icons.access_time, color: Colors.orange[800], size: 24),
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
            style: TextStyle(color: Colors.orange[600], fontSize: 14),
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
