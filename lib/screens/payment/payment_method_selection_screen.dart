import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import '../../services/payment_service.dart';
import '../../widgets/loading_state_widget.dart';
import '../../widgets/feedback_widget.dart';
import 'payment_form_screen.dart';

class PaymentMethodSelectionScreen extends StatefulWidget {
  final double amount;
  final String description;
  final Map<String, dynamic>? metadata;

  const PaymentMethodSelectionScreen({
    super.key,
    required this.amount,
    required this.description,
    this.metadata,
  });

  @override
  State<PaymentMethodSelectionScreen> createState() => _PaymentMethodSelectionScreenState();
}

class _PaymentMethodSelectionScreenState extends State<PaymentMethodSelectionScreen> {
  static final Logger _logger = Logger('PaymentMethodSelectionScreen');
  
  bool _isLoading = true;
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
        FeedbackManager.showError(
          context,
          message: 'Error loading payment methods: $e',
        );
      }
    }
  }

  void _proceedToPayment() {
    if (_selectedPaymentMethod == null) {
      FeedbackManager.showError(
        context,
        message: 'Please select a payment method',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      FeedbackManager.showError(
        context,
        message: 'Please log in to continue',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentFormScreen(
          paymentMethod: _selectedPaymentMethod!,
          amount: widget.amount,
          description: widget.description,
          metadata: widget.metadata,
        ),
      ),
    );
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

  String _getPaymentMethodDescription(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.creditCard:
        return 'Pay securely with your credit or debit card';
      case PaymentMethod.paypal:
        return 'Pay with your PayPal account';
      case PaymentMethod.googlePay:
        return 'Quick and secure payment with Google Pay';
      case PaymentMethod.applePay:
        return 'Pay with Touch ID or Face ID';
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

  Color _getPaymentMethodColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.creditCard:
        return Colors.blue[800]!;
      case PaymentMethod.paypal:
        return Colors.blue[600]!;
      case PaymentMethod.googlePay:
        return Colors.green[700]!;
      case PaymentMethod.applePay:
        return Colors.grey[800]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Select Payment Method'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: LoadingStateWidget(
                message: 'Loading payment methods...',
                color: Colors.white,
              ),
            )
          : Column(
              children: [
                // Payment summary
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[800]!.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Summary',
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
                          Text(
                            widget.description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '\$${widget.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Payment methods list
                Expanded(
                  child: _availablePaymentMethods.isEmpty
                      ? _buildNoPaymentMethodsView()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _availablePaymentMethods.length,
                          itemBuilder: (context, index) {
                            final method = _availablePaymentMethods[index];
                            final isSelected = _selectedPaymentMethod == method;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedPaymentMethod = method;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? _getPaymentMethodColor(method).withOpacity(0.1)
                                          : Colors.grey[800],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected 
                                            ? _getPaymentMethodColor(method)
                                            : Colors.grey[700]!,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: _getPaymentMethodColor(method).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            _getPaymentMethodIcon(method),
                                            color: _getPaymentMethodColor(method),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _getPaymentMethodDisplayName(method),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _getPaymentMethodDescription(method),
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Radio<PaymentMethod>(
                                          value: method,
                                          groupValue: _selectedPaymentMethod,
                                          onChanged: (PaymentMethod? value) {
                                            setState(() {
                                              _selectedPaymentMethod = value;
                                            });
                                          },
                                          activeColor: _getPaymentMethodColor(method),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Continue button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _availablePaymentMethods.isEmpty ? null : _proceedToPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Continue to Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                // Security notice
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: Colors.green[400],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Your payment information is encrypted and secure',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNoPaymentMethodsView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.orange[800]?.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange[800]!.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_rounded,
              color: Colors.orange[800],
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No Payment Methods Available',
              style: TextStyle(
                color: Colors.orange[800],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your device settings and ensure you have a supported payment method configured.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAvailablePaymentMethods,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}