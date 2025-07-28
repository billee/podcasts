import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import '../services/payment_service.dart';
import '../services/subscription_service.dart';
import 'payment/payment_method_selection_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static final Logger _logger = Logger('PaymentScreen');
  
  bool _isLoading = false;
  List<PaymentMethod> _availablePaymentMethods = [];
  PaymentMethod? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _loadAvailablePaymentMethods();
  }

  Future<void> _loadAvailablePaymentMethods() async {
    try {
      setState(() => _isLoading = true);
      
      final methods = await PaymentService.getAvailablePaymentMethods();
      
      setState(() {
        _availablePaymentMethods = methods;
        _selectedPaymentMethod = methods.isNotEmpty ? methods.first : null;
        _isLoading = false;
      });
    } catch (e) {
      _logger.severe('Error loading payment methods: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading payment methods: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to payment method selection screen
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentMethodSelectionScreen(
          amount: PaymentService.monthlySubscriptionPrice,
          description: 'Premium Monthly Subscription',
          metadata: {
            'type': 'monthly_subscription',
            'userId': user.uid,
          },
        ),
      ),
    );

    // If payment was successful, close this screen
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  String _getPaymentMethodDisplayName(PaymentMethod method) {
    switch (method) {
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

  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.creditCard:
        return Icons.credit_card;
      case PaymentMethod.paypal:
        return Icons.account_balance_wallet;
      case PaymentMethod.googlePay:
        return Icons.payment;
      case PaymentMethod.applePay:
        return Icons.apple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Upgrade to Premium'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Subscription details
                  Card(
                    color: Colors.grey[800],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Premium Subscription',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '\$3.00 / month',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Features included:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• Unlimited access to all features',
                                  style: TextStyle(color: Colors.white70)),
                              Text('• Premium content and suggestions',
                                  style: TextStyle(color: Colors.white70)),
                              Text('• Priority customer support',
                                  style: TextStyle(color: Colors.white70)),
                              Text('• No ads',
                                  style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Payment method selection
                  if (_availablePaymentMethods.isNotEmpty) ...[
                    const Text(
                      'Select Payment Method',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    ..._availablePaymentMethods.map((method) => Card(
                      color: _selectedPaymentMethod == method 
                          ? Colors.blue[800] 
                          : Colors.grey[800],
                      child: ListTile(
                        leading: Icon(
                          _getPaymentMethodIcon(method),
                          color: Colors.white,
                        ),
                        title: Text(
                          _getPaymentMethodDisplayName(method),
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: Radio<PaymentMethod>(
                          value: method,
                          groupValue: _selectedPaymentMethod,
                          onChanged: (PaymentMethod? value) {
                            setState(() {
                              _selectedPaymentMethod = value;
                            });
                          },
                          activeColor: Colors.blue,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedPaymentMethod = method;
                          });
                        },
                      ),
                    )).toList(),
                    
                    const SizedBox(height: 32),
                  ],
                  
                  // Payment button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Choose Payment Method',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // No payment methods available message
                  if (_availablePaymentMethods.isEmpty)
                    Card(
                      color: Colors.orange[800],
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.white,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No Payment Methods Available',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Please check your device settings and try again.',
                              style: TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Terms and security info
                  const Text(
                    'By subscribing, you agree to our Terms of Service and Privacy Policy. Your payment information is processed securely and we never store your payment details.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}
