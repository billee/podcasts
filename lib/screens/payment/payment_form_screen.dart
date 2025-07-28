import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import '../../services/payment_service.dart';
import '../../widgets/loading_state_widget.dart';
import '../../widgets/feedback_widget.dart';
import 'payment_confirmation_screen.dart';

class PaymentFormScreen extends StatefulWidget {
  final PaymentMethod paymentMethod;
  final double amount;
  final String description;
  final Map<String, dynamic>? metadata;

  const PaymentFormScreen({
    super.key,
    required this.paymentMethod,
    required this.amount,
    required this.description,
    this.metadata,
  });

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  static final Logger _logger = Logger('PaymentFormScreen');
  
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;
  
  // Credit card form controllers
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();
  
  // Billing address controllers
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  
  // Form validation states
  bool _isCardNumberValid = false;
  bool _isExpiryValid = false;
  bool _isCvvValid = false;
  String? _cardType;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _nameController.text = user.displayName ?? '';
    }
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) {
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

    setState(() => _isProcessing = true);

    try {
      PaymentResult result;
      
      switch (widget.paymentMethod) {
        case PaymentMethod.creditCard:
          result = await PaymentService.processCreditCardPayment(
            userId: user.uid,
            amount: widget.amount,
            metadata: {
              ...?widget.metadata,
              'billing_email': _emailController.text,
              'billing_name': _nameController.text,
              'billing_address': _addressController.text,
              'billing_city': _cityController.text,
              'billing_zip': _zipController.text,
            },
          );
          break;
        case PaymentMethod.paypal:
          result = await PaymentService.processPayPalPayment(
            userId: user.uid,
            amount: widget.amount,
            metadata: widget.metadata,
          );
          break;
        case PaymentMethod.googlePay:
          result = await PaymentService.processGooglePayPayment(
            userId: user.uid,
            amount: widget.amount,
            metadata: widget.metadata,
          );
          break;
        case PaymentMethod.applePay:
          result = await PaymentService.processApplePayPayment(
            userId: user.uid,
            amount: widget.amount,
            metadata: widget.metadata,
          );
          break;
      }

      if (result.status == PaymentStatus.succeeded) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentConfirmationScreen(
                paymentResult: result,
                amount: widget.amount,
                description: widget.description,
                paymentMethod: widget.paymentMethod,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          FeedbackManager.showError(
            context,
            message: result.error ?? 'Payment failed. Please try again.',
          );
        }
      }
    } catch (e) {
      _logger.severe('Error processing payment: $e');
      if (mounted) {
        FeedbackManager.showError(
          context,
          message: 'Payment processing failed: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: Text('Pay with ${_getPaymentMethodDisplayName()}'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: _isProcessing
          ? const Center(
              child: LoadingStateWidget(
                message: 'Processing payment...',
                color: Colors.white,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment summary
                    _buildPaymentSummary(),
                    const SizedBox(height: 24),
                    
                    // Payment form based on method
                    if (widget.paymentMethod == PaymentMethod.creditCard)
                      _buildCreditCardForm()
                    else
                      _buildAlternativePaymentForm(),
                    
                    const SizedBox(height: 24),
                    
                    // Billing information
                    _buildBillingForm(),
                    
                    const SizedBox(height: 32),
                    
                    // Pay button
                    _buildPayButton(),
                    
                    const SizedBox(height: 16),
                    
                    // Security notice
                    _buildSecurityNotice(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      width: double.infinity,
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
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Payment Method: ${_getPaymentMethodDisplayName()}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Card Information',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Card number
        TextFormField(
          controller: _cardNumberController,
          decoration: InputDecoration(
            labelText: 'Card Number',
            hintText: '1234 5678 9012 3456',
            prefixIcon: Icon(
              _getCardIcon(),
              color: Colors.blue[800],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[700],
            labelStyle: const TextStyle(color: Colors.white70),
            hintStyle: const TextStyle(color: Colors.white60),
          ),
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _CardNumberInputFormatter(),
          ],
          onChanged: _validateCardNumber,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter card number';
            }
            if (!_isCardNumberValid) {
              return 'Please enter a valid card number';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            // Expiry date
            Expanded(
              child: TextFormField(
                controller: _expiryController,
                decoration: InputDecoration(
                  labelText: 'MM/YY',
                  hintText: '12/25',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[700],
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintStyle: const TextStyle(color: Colors.white60),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ExpiryDateInputFormatter(),
                ],
                onChanged: _validateExpiry,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  if (!_isExpiryValid) {
                    return 'Invalid date';
                  }
                  return null;
                },
              ),
            ),
            
            const SizedBox(width: 16),
            
            // CVV
            Expanded(
              child: TextFormField(
                controller: _cvvController,
                decoration: InputDecoration(
                  labelText: 'CVV',
                  hintText: '123',
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.help_outline,
                      color: Colors.white60,
                      size: 20,
                    ),
                    onPressed: () => _showCvvHelp(),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[700],
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintStyle: const TextStyle(color: Colors.white60),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                obscureText: true,
                onChanged: _validateCvv,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  if (!_isCvvValid) {
                    return 'Invalid CVV';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Cardholder name
        TextFormField(
          controller: _cardHolderController,
          decoration: InputDecoration(
            labelText: 'Cardholder Name',
            hintText: 'John Doe',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[700],
            labelStyle: const TextStyle(color: Colors.white70),
            hintStyle: const TextStyle(color: Colors.white60),
          ),
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter cardholder name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAlternativePaymentForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            _getPaymentMethodIcon(),
            size: 48,
            color: Colors.blue[800],
          ),
          const SizedBox(height: 16),
          Text(
            'You will be redirected to ${_getPaymentMethodDisplayName()} to complete your payment.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Click "Pay Now" to continue.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBillingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Billing Information',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Email
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email Address',
            hintText: 'john@example.com',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[700],
            labelStyle: const TextStyle(color: Colors.white70),
            hintStyle: const TextStyle(color: Colors.white60),
          ),
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter email address';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Full name
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Full Name',
            hintText: 'John Doe',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[700],
            labelStyle: const TextStyle(color: Colors.white70),
            hintStyle: const TextStyle(color: Colors.white60),
          ),
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter full name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Text(
          'Pay \$${widget.amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[900]?.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[700]!.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security,
            color: Colors.green[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your payment information is encrypted and secure. We never store your payment details.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCardIcon() {
    switch (_cardType) {
      case 'visa':
        return Icons.credit_card;
      case 'mastercard':
        return Icons.credit_card;
      case 'amex':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }

  IconData _getPaymentMethodIcon() {
    switch (widget.paymentMethod) {
      case PaymentMethod.paypal:
        return Icons.account_balance_wallet;
      case PaymentMethod.googlePay:
        return Icons.payment;
      case PaymentMethod.applePay:
        return Icons.apple;
      default:
        return Icons.payment;
    }
  }

  void _validateCardNumber(String value) {
    final cleanValue = value.replaceAll(' ', '');
    setState(() {
      _isCardNumberValid = cleanValue.length >= 13 && cleanValue.length <= 19;
      _cardType = _detectCardType(cleanValue);
    });
  }

  void _validateExpiry(String value) {
    setState(() {
      _isExpiryValid = _isValidExpiryDate(value);
    });
  }

  void _validateCvv(String value) {
    setState(() {
      _isCvvValid = value.length >= 3 && value.length <= 4;
    });
  }

  String? _detectCardType(String cardNumber) {
    if (cardNumber.startsWith('4')) return 'visa';
    if (cardNumber.startsWith('5') || cardNumber.startsWith('2')) return 'mastercard';
    if (cardNumber.startsWith('3')) return 'amex';
    return null;
  }

  bool _isValidExpiryDate(String value) {
    if (value.length != 5) return false;
    
    final parts = value.split('/');
    if (parts.length != 2) return false;
    
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    
    if (month == null || year == null) return false;
    if (month < 1 || month > 12) return false;
    
    final currentYear = DateTime.now().year % 100;
    final currentMonth = DateTime.now().month;
    
    if (year < currentYear) return false;
    if (year == currentYear && month < currentMonth) return false;
    
    return true;
  }

  void _showCvvHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text(
          'What is CVV?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'CVV (Card Verification Value) is a 3 or 4 digit security code found on your card:\n\n'
          '• Visa/Mastercard: 3 digits on the back\n'
          '• American Express: 4 digits on the front',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got it',
              style: TextStyle(color: Colors.blue[800]),
            ),
          ),
        ],
      ),
    );
  }
}

// Input formatters
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    if (text.length == 2 && oldValue.text.length == 1) {
      return TextEditingValue(
        text: '$text/',
        selection: const TextSelection.collapsed(offset: 3),
      );
    }
    
    if (text.length > 5) {
      return oldValue;
    }
    
    return newValue;
  }
}