import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/screens/payment/mock_payment_screen.dart';
import 'package:kapwa_companion_basic/core/config.dart';

class TermsConditionsScreen extends StatelessWidget {
  final double amount;
  final String planType;
  
  const TermsConditionsScreen({
    super.key,
    required this.amount,
    required this.planType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Terms of Service & Privacy Policy'),
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
                      'Terms of Service & Privacy Policy',
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
                    _buildSection(
                      'Subscription Terms',
                      'By subscribing to Kapwa Companion, you agree to pay the subscription fee of ${AppConfig.formattedMonthlyPrice} per month. '
                          'The subscription will automatically renew each month unless cancelled. '
                          'You can cancel your subscription at any time through your account settings.',
                    ),
                    _buildSection(
                      'Payment Processing',
                      'Your payment information will be securely processed through our payment provider. '
                          'We do not store your payment details on our servers.',
                    ),
                    _buildSection(
                      'Cancellation Policy',
                      'You can cancel your subscription at any time. Upon cancellation, you will retain access '
                          'to premium features until the end of your current billing period.',
                    ),
                    _buildSection(
                      'Refund Policy',
                      'Due to the nature of digital services, we generally do not offer refunds once a payment '
                          'has been processed. However, you may contact our support team for exceptional cases.',
                    ),
                    _buildSection(
                      'Usage Agreement',
                      'By using our service, you agree not to:\n'
                          '• Share your account credentials\n'
                          '• Use the service for any illegal purposes\n'
                          '• Attempt to reverse engineer or copy our features',
                    ),
                    _buildSection(
                      'Privacy and Data',
                      'Your privacy is important to us. We collect and process your data as described in our '
                          'Privacy Policy. We use this data to provide and improve our services.',
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'Information We Collect',
                      'We collect information you provide directly to us, such as when you create an account, '
                          'use our services, or contact us for support. This includes your email address, '
                          'usage data, and conversation history to improve our AI responses.',
                    ),
                    _buildSection(
                      'How We Use Your Information',
                      'We use the information we collect to:\n'
                          '• Provide and maintain our services\n'
                          '• Process your subscription and payments\n'
                          '• Improve our AI responses and features\n'
                          '• Send you important service updates\n'
                          '• Provide customer support',
                    ),
                    _buildSection(
                      'Data Security',
                      'We implement appropriate security measures to protect your personal information. '
                          'Your data is encrypted in transit and at rest. We use Firebase and other secure '
                          'cloud services to store and process your information.',
                    ),
                    _buildSection(
                      'Data Retention',
                      'We retain your personal information for as long as necessary to provide our services '
                          'and fulfill the purposes outlined in this policy. You can request deletion of '
                          'your account and data at any time.',
                    ),
                    _buildSection(
                      'Your Rights',
                      'You have the right to:\n'
                          '• Access your personal information\n'
                          '• Correct inaccurate information\n'
                          '• Request deletion of your data\n'
                          '• Opt out of certain communications\n'
                          '• Export your data',
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
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MockPaymentScreen(
                              amount: amount,
                              planType: planType,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'I Agree and Continue to Payment',
                        style: TextStyle(
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
