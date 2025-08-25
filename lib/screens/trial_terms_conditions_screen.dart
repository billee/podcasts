import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapwa_companion_basic/screens/payment/mock_payment_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/auth_wrapper.dart';
import 'package:kapwa_companion_basic/services/terms_acceptance_service.dart';
import 'package:kapwa_companion_basic/core/config.dart';
import 'package:logging/logging.dart';

class TrialTermsConditionsScreen extends StatefulWidget {
  final double? amount;
  final String? planType;
  final String? userId; // For initial terms acceptance
  final VoidCallback? onAccepted; // For initial terms acceptance
  
  const TrialTermsConditionsScreen({
    super.key,
    this.amount,
    this.planType,
    this.userId,
    this.onAccepted,
  });

  @override
  State<TrialTermsConditionsScreen> createState() => _TrialTermsConditionsScreenState();
}

class _TrialTermsConditionsScreenState extends State<TrialTermsConditionsScreen> {
  static final Logger _logger = Logger('TrialTermsConditionsScreen');
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
    _logger.info('TrialTermsConditionsScreen build - userId: ${widget.userId}, amount: ${widget.amount}, planType: ${widget.planType}');
    _logger.info('_isInitialAcceptance: $_isInitialAcceptance, _isPaymentFlow: $_isPaymentFlow');
    
    // If neither flow is detected, this is an error - go back to login
    if (!_isInitialAcceptance && !_isPaymentFlow) {
      _logger.severe('TrialTermsConditionsScreen called without proper parameters - redirecting to login');
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
                      'Trial Period',
                      'New users receive a 7-day free trial period to explore the app features. '
                          'During your trial, you have access to:\n'
                          '• 10,000 AI chat tokens per day\n'
                          '• First ${AppConfig.trialUserPodcastLimit} podcast episodes\n'
                          '• First ${AppConfig.trialUserStoryLimit} story audios\n\n'
                          'Your trial will expire automatically after 7 days, and you can choose to subscribe to continue using premium features.',
                    ),
                    _buildSection(
                      'AI Companion Disclaimer',
                      '**IMPORTANT: This is an AI companion, not a human advisor.**\n\n'
                          'Please understand that:\n'
                          '• The AI companion can make mistakes and provide incorrect information\n'
                          '• Do NOT fully trust AI advice for important decisions\n'
                          '• This app is for companionship and casual conversation only\n'
                          '• Do NOT seek advice on financial, political, health, or marital topics\n'
                          '• Do NOT get emotionally attached to the AI - it is not a real person\n'
                          '• Always consult qualified professionals for serious matters\n\n'
                          'Use this app responsibly and remember it\'s just a tool for friendly conversation.',
                    ),
                    _buildSection(
                      'Service Features',
                      'Kapwa Companion provides AI-powered companionship, stories, and podcast content specifically designed for OFWs. '
                          'Features may be updated or modified to improve user experience. '
                          'All content is generated by AI and should be treated as entertainment, not professional advice.',
                    ),
                    _buildSection(
                      'Usage Agreement',
                      'By using our service, you agree not to:\n'
                          '• Share your account credentials\n'
                          '• Use the service for any illegal purposes\n'
                          '• Violation of these terms will result in termination of your trial period.',
                    ),
                    _buildSection(
                      'Privacy and Data',
                      'Your privacy is important to us. We do not collect or save your personal data in our database. We only store a summary of conversations for context, and only collect violation data for security purposes.',
                    ),
                    _buildSection(
                      'User Behavior',
                      'To ensure a helpful and safe community for everyone, we have a zero-tolerance policy for certain behaviors. '
                          'We take these violations very seriously, and if you trigger any of the following flags three times, your account will be permanently banned:\n\n'
                          '• **Abuse/Hate:** Engaging in hateful or abusive language. Violations are flagged with [FLAG:ABUSE]\n'
                          '• **Sexual Content:** Discussing inappropriate sexual content. Violations are flagged with [FLAG:SEXUAL]\n'
                          '• **Self-Harm:** Conversing about self-harm. Violations are flagged with [FLAG:MENTAL_HEALTH]\n'
                          '• **Scams:** Discussing fraudulent activities. Violations are flagged with [FLAG:SCAM]',
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
                      'Data Security',
                      'We implement appropriate security measures to protect your personal information. '
                          'Your data is encrypted in transit and at rest. We use Firebase and other secure '
                          'cloud services to store and process your information.',
                    ),
                    _buildSection(
                      'Data Retention',
                      'We retain your email address even after your trial expires or if you are banned from the app to prevent future violations. '
                          'Conversation summaries are kept for context purposes but contain no personal information.',
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
