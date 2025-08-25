import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/screens/payment/mock_payment_screen.dart';
import 'package:kapwa_companion_basic/core/config.dart';
import 'package:logging/logging.dart';

class SubscriptionTermsConditionsScreen extends StatefulWidget {
  final double amount;
  final String planType;
  
  const SubscriptionTermsConditionsScreen({
    super.key,
    required this.amount,
    required this.planType,
  });

  @override
  State<SubscriptionTermsConditionsScreen> createState() => _SubscriptionTermsConditionsScreenState();
}

class _SubscriptionTermsConditionsScreenState extends State<SubscriptionTermsConditionsScreen> {
  static final Logger _logger = Logger('SubscriptionTermsConditionsScreen');

  void _continueToPayment() {
    _logger.info('User agreed to subscription terms, proceeding to payment');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MockPaymentScreen(
          amount: widget.amount,
          planType: widget.planType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _logger.info('SubscriptionTermsConditionsScreen build - amount: ${widget.amount}, planType: ${widget.planType}');
    
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Subscription Terms'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subscription Terms & Conditions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Last updated: August 2, 2025',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Subscription Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[800]?.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[800]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Subscription Summary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Plan:',
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                widget.planType.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Monthly Price:',
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                '\$${widget.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildSection(
                      'Billing Terms',
                      'By subscribing, you authorize us to charge your payment method \$${widget.amount.toStringAsFixed(2)} monthly. '
                          'Your subscription will automatically renew each month on the same date unless cancelled. '
                          'You will be charged immediately upon confirmation.',
                    ),
                    _buildSection(
                      'Payment Processing',
                      'Your payment will be securely processed through our payment provider. '
                          'We do not store your payment details on our servers. '
                          'All transactions are encrypted and secure.',
                    ),
                    _buildSection(
                      'Cancellation Policy',
                      'You can cancel your subscription at any time through your Profile page. '
                          'Upon cancellation, you will retain access to premium features until the end of your current billing period. '
                          'No partial refunds will be provided for unused portions of your subscription.',
                    ),
                    _buildSection(
                      'Refund Policy',
                      'Due to the nature of digital services, we generally do not offer refunds once a payment '
                          'has been processed. You must cancel your subscription to prevent future charges. '
                          'In exceptional circumstances, refunds may be considered on a case-by-case basis.',
                    ),
                    _buildSection(
                      'Service Availability',
                      'We strive to provide continuous service availability. However, we do not guarantee '
                          'uninterrupted access and may perform maintenance that temporarily affects service availability. '
                          'No refunds will be provided for temporary service interruptions.',
                    ),
                    _buildSection(
                      'Changes to Pricing',
                      'We reserve the right to change subscription pricing with 30 days advance notice. '
                          'Existing subscribers will be notified of any price changes and can choose to cancel '
                          'before the new pricing takes effect.',
                    ),
                    _buildSection(
                      'Account Termination',
                      'We reserve the right to terminate accounts that violate our terms of service. '
                          'In case of account termination for policy violations, no refunds will be provided.',
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[800]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _continueToPayment,
                      child: Text(
                        'I Agree and Continue to Payment (\$${widget.amount.toStringAsFixed(2)})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}