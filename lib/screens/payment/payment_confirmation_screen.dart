import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import '../../services/payment_service.dart';
import '../../services/subscription_service.dart';
import '../../widgets/feedback_widget.dart';
import '../main_screen.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final PaymentResult paymentResult;
  final double amount;
  final String description;
  final PaymentMethod paymentMethod;

  const PaymentConfirmationScreen({
    super.key,
    required this.paymentResult,
    required this.amount,
    required this.description,
    required this.paymentMethod,
  });

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen>
    with TickerProviderStateMixin {
  static final Logger _logger = Logger('PaymentConfirmationScreen');
  
  late AnimationController _checkAnimationController;
  late Animation<double> _checkAnimation;
  bool _subscriptionActivated = false;
  bool _isActivatingSubscription = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _activateSubscription();
  }

  @override
  void dispose() {
    _checkAnimationController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _checkAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _checkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _checkAnimationController.forward();
  }

  Future<void> _activateSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isActivatingSubscription = false);
      return;
    }

    try {
      // Activate subscription if this was a subscription payment
      if (widget.paymentResult.metadata?['type'] == 'monthly_subscription') {
        final success = await SubscriptionService.subscribeToMonthlyPlan(
          user.uid,
          paymentMethod: widget.paymentMethod.name,
          transactionId: widget.paymentResult.transactionId,
        );
        
        setState(() {
          _subscriptionActivated = success;
          _isActivatingSubscription = false;
        });
        
        if (success) {
          _logger.info('Subscription activated successfully');
        } else {
          _logger.warning('Failed to activate subscription');
        }
      } else {
        setState(() => _isActivatingSubscription = false);
      }
    } catch (e) {
      _logger.severe('Error activating subscription: $e');
      setState(() => _isActivatingSubscription = false);
    }
  }

  String _getPaymentMethodDisplayName() {
    switch (widget.paymentMethod) {
      case PaymentMethod.creditCard:
        return 'Credit/Debit Card';
      case PaymentMethod.paypal:
        return 'PayPal';
      case PaymentMethod.googlePay:
        return 'Google Pay';
      case PaymentMethod.applePay:
        return 'Apple Pay';
    }
  }

  String _formatTransactionId(String? transactionId) {
    if (transactionId == null) return 'N/A';
    if (transactionId.length > 12) {
      return '${transactionId.substring(0, 4)}...${transactionId.substring(transactionId.length - 4)}';
    }
    return transactionId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Payment Confirmation'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // Success animation
            AnimatedBuilder(
              animation: _checkAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _checkAnimation.value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.green[700],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Success message
            Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            Text(
              _isActivatingSubscription
                  ? 'Activating your subscription...'
                  : _subscriptionActivated
                      ? 'Your premium subscription is now active!'
                      : 'Thank you for your payment!',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Payment details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green[700]!.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: Colors.green[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Payment Receipt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildReceiptRow('Description', widget.description),
                  _buildReceiptRow('Amount', '\$${widget.amount.toStringAsFixed(2)}'),
                  _buildReceiptRow('Payment Method', _getPaymentMethodDisplayName()),
                  _buildReceiptRow('Transaction ID', _formatTransactionId(widget.paymentResult.transactionId)),
                  _buildReceiptRow('Date', _formatDate(DateTime.now())),
                  _buildReceiptRow('Status', 'Completed'),
                  
                  if (_subscriptionActivated) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[800]?.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[800]!.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.diamond,
                                color: Colors.blue[800],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Premium Subscription Active',
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You now have access to all premium features!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action buttons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToMainScreen(),
                    icon: const Icon(Icons.home),
                    label: const Text('Continue to App'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadReceipt(),
                    icon: const Icon(Icons.download),
                    label: const Text('Download Receipt'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Support info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800]?.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Need Help?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'If you have any questions about your payment or subscription, please contact our support team.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _contactSupport(),
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Contact Support'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[800],
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

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToMainScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainScreen()),
      (route) => false,
    );
  }

  void _downloadReceipt() {
    // In a real implementation, this would generate and download a PDF receipt
    FeedbackManager.showSuccess(
      context,
      message: 'Receipt download feature coming soon!',
    );
  }

  void _contactSupport() {
    // In a real implementation, this would open support chat or email
    FeedbackManager.showInfo(
      context,
      message: 'Support contact feature coming soon!',
    );
  }
}