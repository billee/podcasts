import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import '../services/payment_service.dart';
import 'feedback_widget.dart';
import 'loading_state_widget.dart';

class PaymentMethodManagementWidget extends StatefulWidget {
  const PaymentMethodManagementWidget({super.key});

  @override
  State<PaymentMethodManagementWidget> createState() => _PaymentMethodManagementWidgetState();
}

class _PaymentMethodManagementWidgetState extends State<PaymentMethodManagementWidget> {
  static final Logger _logger = Logger('PaymentMethodManagementWidget');
  
  bool _isLoading = true;
  bool _isUpdating = false;
  List<PaymentMethod> _availablePaymentMethods = [];
  PaymentMethod? _currentPaymentMethod;
  List<Map<String, dynamic>> _paymentHistory = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentInfo();
  }

  Future<void> _loadPaymentInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      // Load available payment methods
      final availableMethods = await PaymentService.getAvailablePaymentMethods();
      
      // Load current payment method from user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      PaymentMethod? currentMethod;
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final methodName = userData['preferredPaymentMethod'] as String?;
        if (methodName != null) {
          try {
            currentMethod = PaymentMethod.values.firstWhere(
              (method) => method.name == methodName,
            );
          } catch (e) {
            _logger.warning('Invalid payment method in user profile: $methodName');
          }
        }
      }
      
      // Load payment history
      final history = await PaymentService.getPaymentHistory(user.uid);
      
      setState(() {
        _availablePaymentMethods = availableMethods;
        _currentPaymentMethod = currentMethod;
        _paymentHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      _logger.severe('Error loading payment info: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        FeedbackManager.showError(
          context,
          message: 'Error loading payment information: $e',
        );
      }
    }
  }

  Future<void> _updatePaymentMethod(PaymentMethod newMethod) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUpdating = true);

    try {
      final success = await PaymentService.updatePaymentMethod(
        userId: user.uid,
        newPaymentMethod: newMethod,
      );

      if (success) {
        setState(() {
          _currentPaymentMethod = newMethod;
        });
        
        if (mounted) {
          FeedbackManager.showSuccess(
            context,
            message: 'Payment method updated successfully!',
          );
        }
      } else {
        if (mounted) {
          FeedbackManager.showError(
            context,
            message: 'Failed to update payment method. Please try again.',
          );
        }
      }
    } catch (e) {
      _logger.severe('Error updating payment method: $e');
      if (mounted) {
        FeedbackManager.showError(
          context,
          message: 'Error updating payment method: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
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

  Color _getPaymentMethodColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.creditCard:
        return Colors.blue[800]!;
      case PaymentMethod.paypal:
        return Colors.blue[600]!;
      case PaymentMethod.googlePay:
        return Colors.green[700]!;
      case PaymentMethod.applePay:
        return Colors.grey[600]!;
    }
  }

  String _formatTransactionDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = timestamp.toDate();
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatTransactionAmount(dynamic amount) {
    if (amount == null) return '\$0.00';
    
    try {
      final value = amount is double ? amount : double.parse(amount.toString());
      return '\$${value.toStringAsFixed(2)}';
    } catch (e) {
      return '\$0.00';
    }
  }

  String _getTransactionStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'succeeded':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color _getTransactionStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'succeeded':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingStateWidget(
        message: 'Loading payment information...',
        color: Colors.white,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current payment method section
        _buildCurrentPaymentMethodSection(),
        
        const SizedBox(height: 24),
        
        // Available payment methods section
        if (_availablePaymentMethods.isNotEmpty)
          _buildAvailablePaymentMethodsSection(),
        
        const SizedBox(height: 24),
        
        // Payment history section
        _buildPaymentHistorySection(),
      ],
    );
  }

  Widget _buildCurrentPaymentMethodSection() {
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
            'Current Payment Method',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_currentPaymentMethod != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getPaymentMethodColor(_currentPaymentMethod!).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getPaymentMethodIcon(_currentPaymentMethod!),
                    color: _getPaymentMethodColor(_currentPaymentMethod!),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getPaymentMethodDisplayName(_currentPaymentMethod!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Default payment method for subscriptions',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[800]?.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[800]!.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: Colors.orange[800],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No payment method selected. Choose one below to set as default.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailablePaymentMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Payment Methods',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        ..._availablePaymentMethods.map((method) {
          final isCurrent = _currentPaymentMethod == method;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isUpdating || isCurrent ? null : () => _updatePaymentMethod(method),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCurrent 
                        ? _getPaymentMethodColor(method).withOpacity(0.1)
                        : Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent 
                          ? _getPaymentMethodColor(method)
                          : Colors.grey[700]!,
                      width: isCurrent ? 2 : 1,
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
                        child: Text(
                          _getPaymentMethodDisplayName(method),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_isUpdating) ...[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ] else if (isCurrent) ...[
                        Icon(
                          Icons.check_circle,
                          color: _getPaymentMethodColor(method),
                          size: 24,
                        ),
                      ] else ...[
                        Text(
                          'Set as Default',
                          style: TextStyle(
                            color: _getPaymentMethodColor(method),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildPaymentHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Payment History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_paymentHistory.isNotEmpty)
              TextButton(
                onPressed: () => _loadPaymentInfo(),
                child: const Text('Refresh'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_paymentHistory.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.white60,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Payment History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your payment transactions will appear here',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _paymentHistory.take(5).map((transaction) {
                final isLast = _paymentHistory.indexOf(transaction) == 
                    (_paymentHistory.length > 5 ? 4 : _paymentHistory.length - 1);
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(
                      bottom: BorderSide(color: Colors.grey[700]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getTransactionStatusColor(transaction['status']).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          transaction['type'] == 'refund' 
                              ? Icons.undo 
                              : Icons.payment,
                          color: _getTransactionStatusColor(transaction['status']),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction['type'] == 'refund' 
                                  ? 'Refund' 
                                  : 'Payment',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTransactionDate(transaction['createdAt']),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTransactionAmount(transaction['amount']),
                            style: TextStyle(
                              color: transaction['type'] == 'refund' 
                                  ? Colors.orange 
                                  : Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getTransactionStatusText(transaction['status']),
                            style: TextStyle(
                              color: _getTransactionStatusColor(transaction['status']),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          
          if (_paymentHistory.length > 5) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  // In a real implementation, this would show a full payment history screen
                  FeedbackManager.showInfo(
                    context,
                    message: 'Full payment history feature coming soon!',
                  );
                },
                child: Text(
                  'View All ${_paymentHistory.length} Transactions',
                  style: TextStyle(color: Colors.blue[800]),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}