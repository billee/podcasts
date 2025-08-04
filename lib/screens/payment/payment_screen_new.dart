import 'package:flutter/material.dart';
import 'dart:io';
import 'package:kapwa_companion_basic/services/payment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.creditCard;

  Future<void> _processPayment() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final result = await PaymentService.processCreditCardPayment(
        userId: userId,
        amount: PaymentService.monthlySubscriptionPrice,
        metadata: {
          'type': 'subscription',
          'plan': 'monthly',
          'method': _selectedPaymentMethod.toString(),
        },
      );

      if (result.status == PaymentStatus.succeeded) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment successful!'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate back to main screen
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Payment failed: ${result.error ?? "Unknown error"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isProcessing) {
          // Prevent going back while processing payment
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[850],
        appBar: AppBar(
          title: const Text('Payment'),
          backgroundColor: Colors.grey[900],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Subscription details card
                Card(
                  color: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
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
                            const Text(
                              'Premium Monthly',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              '\$3.00',
                              style: TextStyle(
                                color: Colors.green[400],
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              ' /month',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Payment methods section
                const Text(
                  'Payment Methods',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.credit_card, color: Colors.white),
                        title: const Text(
                          'Credit or Debit Card',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Visa, Mastercard, and more',
                          style: TextStyle(color: Colors.grey),
                        ),
                        trailing: Radio<PaymentMethod>(
                          value: PaymentMethod.creditCard,
                          groupValue: _selectedPaymentMethod,
                          onChanged: _isProcessing
                              ? null
                              : (PaymentMethod? value) {
                                  setState(() {
                                    _selectedPaymentMethod = value!;
                                  });
                                },
                        ),
                        onTap: _isProcessing
                            ? null
                            : () {
                                setState(() {
                                  _selectedPaymentMethod =
                                      PaymentMethod.creditCard;
                                });
                              },
                      ),
                      const Divider(height: 1, color: Colors.grey),
                      if (Platform.isAndroid)
                        ListTile(
                          leading:
                              Icon(Icons.phone_android, color: Colors.white),
                          title: const Text(
                            'Google Pay',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Fast and secure checkout',
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: Radio<PaymentMethod>(
                            value: PaymentMethod.googlePay,
                            groupValue: _selectedPaymentMethod,
                            onChanged: _isProcessing
                                ? null
                                : (PaymentMethod? value) {
                                    setState(() {
                                      _selectedPaymentMethod = value!;
                                    });
                                  },
                          ),
                          onTap: _isProcessing
                              ? null
                              : () {
                                  setState(() {
                                    _selectedPaymentMethod =
                                        PaymentMethod.googlePay;
                                  });
                                },
                        ),
                      if (Platform.isIOS)
                        ListTile(
                          leading:
                              Icon(Icons.phone_iphone, color: Colors.white),
                          title: const Text(
                            'Apple Pay',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Fast and secure checkout',
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: Radio<PaymentMethod>(
                            value: PaymentMethod.applePay,
                            groupValue: _selectedPaymentMethod,
                            onChanged: _isProcessing
                                ? null
                                : (PaymentMethod? value) {
                                    setState(() {
                                      _selectedPaymentMethod = value!;
                                    });
                                  },
                          ),
                          onTap: _isProcessing
                              ? null
                              : () {
                                  setState(() {
                                    _selectedPaymentMethod =
                                        PaymentMethod.applePay;
                                  });
                                },
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                // Process payment button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
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
                            'Process Payment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Secure payment notice
                Text(
                  'Payments are processed securely via Stripe',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
