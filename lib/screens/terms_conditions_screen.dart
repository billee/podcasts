import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapwa_companion_basic/screens/payment/mock_payment_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/auth_wrapper.dart';
import 'package:kapwa_companion_basic/services/terms_acceptance_service.dart';
import 'package:kapwa_companion_basic/core/config.dart';
import 'package:logging/logging.dart';

class TermsConditionsScreen extends StatefulWidget {
  final double? amount;
  final String? planType;
  final String? userId; // For initial terms acceptance
  final VoidCallback? onAccepted; // For initial terms acceptance
  
  const TermsConditionsScreen({
    super.key,
    this.amount,
    this.planType,
    this.userId,
    this.onAccepted,
  });

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  static final Logger _logger = Logger('TermsConditionsScreen');
  bool _isAccepting = false;

  bool get _isInitialAcceptance => widget.userId != null && widget.onAccepted != null;
  bool get _isPaymentFlow => widget.amount != null && widget.planType != null;

  Future<void> _acceptTerms() async {
    if (!_isInitialAcceptance) return;

    setState(() {
      _isAccepting = true;
    });

    try {
      await TermsAcceptanceService.acceptTerms(widget.userId!);
      _logger.info('Terms accepted successfully for user: ${widget.userId}');
      widget.onAccepted!();
    } catch (e) {
      _logger.severe('Error accepting terms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting terms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  void _continueToPayment() {
    if (!_isPaymentFlow) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MockPaymentScreen(
          amount: widget.amount!,
          planType: widget.planType!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _logger.info('TermsConditionsScreen build - userId: ${widget.userId}, amount: ${widget.amount}, planType: ${widget.planType}');
    _logger.info('_isInitialAcceptance: $_isInitialAcceptance, _isPaymentFlow: $_isPaymentFlow');
    
    // If neither flow is detected, this is an error - go back to login
    if (!_isInitialAcceptance && !_isPaymentFlow) {
      _logger.severe('TermsConditionsScreen called without proper parameters - redirecting to login');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
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
                      'Target Audience',
                      'This application is specifically designed for Overseas Filipino Workers (OFWs) to assist with their unique needs. If you are not an OFW, you may find the features and services to be of limited use.',
                    ),
                    _buildSection(
                      'Subscription Terms',
                      'By subscribing to Kapwa Companion, you agree to pay the subscription fee of ${AppConfig.formattedMonthlyPrice} per month. '
                          'The subscription will automatically renew each month unless cancelled. '
                          'You can cancel your subscription at any time through your Profile page.',
                    ),
                    _buildSection(
                      'Payment Processing',
                      'Your payment information will be securely processed through our payment provider(Stripe). '
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
                          'has been processed. You have to cancel and wait for the end of the subscription to expire.',
                    ),
                    _buildSection(
                      'Usage Agreement',
                      'By using our service, you agree not to:\n'
                          '• Share your account credentials\n'
                          '• Use the service for any illegal purposes\n'
                          '• Violation of these terms will result in non-renewal of your subscription.',
                    ),
                    _buildSection(
                      'Privacy and Data',
                      'Your privacy is important to us. We do not collect or save your personal data in our database. We only store a summary of conversations for context, and only collect violation data for security purposes.',
                    ),
                    _buildSection(
                      'User Behavior',
                      'To ensure a helpful and safe community for everyone, we have a zero-tolerance policy for certain behaviors. '
                          'We take these violations very seriously, and if you trigger any of the following flags three times, your account will be permanently banned and you will not be able to renew your subscription:\n\n'
                          '• **Abuse/Hate:** Engaging in hateful or abusive language. Violations are flagged with [FLAG:ABUSE].'
                          '• **Sexual Content:** Discussing inappropriate sexual content. Violations are flagged with [FLAG:SEXUAL].'
                          '• **Self-Harm:** Conversing about self-harm. Violations are flagged with [FLAG:MENTAL_HEALTH].'
                          '• **Scams:** Discussing fraudulent activities. Violations are flagged with [FLAG:SCAM].',
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
                      'We do not collect and process your personal data. We only collect your email address when you create an account and violation data if any flag is triggered.',
                    ),
                    _buildSection(
                      'How We Use Your Information',
                      'We use the limited information we collect to:\n'
                          '• Provide and maintain our services\n'
                          '• Process your subscription and payments\n'
                          '• Protect our community from harmful behavior.',
                    ),
                    _buildSection(
                      'Data Security',
                      'We implement appropriate security measures to protect your personal information. '
                          'Your data is encrypted in transit and at rest. We use Firebase and other secure '
                          'cloud services to store and process your information.',
                    ),
                    _buildSection(
                      'Data Retention',
                      'We retain your email address even after you cancel your subscription or are banned from the app to prevent future violations. All other data, including credit card information, is completely erased.',
                    ),
                    _buildSection(
                      'Community Support and Protection',
                      'This app is designed to be a safe space for OFWs. We are committed to protecting our community from harmful content and behavior. By using our service, you agree to help us maintain a positive and supportive environment for all users.',
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
                      onPressed: _isAccepting ? null : (_isInitialAcceptance ? _acceptTerms : _continueToPayment),
                      child: _isAccepting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isInitialAcceptance 
                                  ? 'I Accept the Terms and Conditions'
                                  : 'I Agree and Continue to Payment',
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
