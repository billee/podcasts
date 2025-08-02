import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/screens/payment/payment_screen.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
        backgroundColor: Colors.grey[900],
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
                      'Terms and Conditions',
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
                      'By subscribing to Kapwa Companion, you agree to pay the subscription fee of \$3.00 per month. '
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
                            builder: (context) => const PaymentScreen(),
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
