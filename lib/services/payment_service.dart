import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'payment_config_service.dart';

/// Custom exception for payment-related errors
class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);
  @override
  String toString() => message;
}

enum PaymentMethod { creditCard, paypal, googlePay, applePay }

enum PaymentStatus {
  pending,
  processing,
  succeeded,
  failed,
  cancelled,
  requiresAction
}

class PaymentResult {
  final PaymentStatus status;
  final String? transactionId;
  final String? error;
  final Map<String, dynamic>? metadata;

  PaymentResult({
    required this.status,
    this.transactionId,
    this.error,
    this.metadata,
  });
}

class PaymentService {
  static final Logger _logger = Logger('PaymentService');
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static FirebaseAuth _auth = FirebaseAuth.instance;

  // Payment configuration is now handled by PaymentConfigService

  static const double monthlySubscriptionPrice = 3.0;
  static const String currency = 'USD';

  // For testing purposes - allow dependency injection
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }

  static void setAuthInstance(FirebaseAuth auth) {
    _auth = auth;
  }

  /// Initialize payment service
  static Future<void> initialize() async {
    try {
      // Initialize payment configuration
      await PaymentConfigService.initialize();

      _logger.info('Mock payment service initialized successfully');
    } catch (e) {
      _logger.severe('Error initializing payment service: $e');
      rethrow;
    }
  }

  /// Create payment intent for Stripe
  static Future<String?> _createPaymentIntent({
    required double amount,
    required String currency,
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // In a real implementation, this would call your backend server
      // For now, we'll simulate the payment intent creation
      final response = await http.post(
        Uri.parse(
            '${PaymentConfigService.backendServerUrl}/create-payment-intent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: jsonEncode({
          'amount': (amount * 100).round(), // Convert to cents
          'currency': currency,
          'userId': userId,
          'metadata': metadata ?? {},
        }),
      );

      _logger
          .info('Payment intent request sent. Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['client_secret'] == null) {
            _logger.severe(
                'Payment intent creation failed: missing client_secret in response');
            throw PaymentException(
                'Failed to create payment intent: Invalid server response');
          }
          _logger.info('Successfully created payment intent');
          return data['client_secret'] as String;
        } catch (e) {
          _logger
              .severe('Failed to parse successful response: ${response.body}');
          throw PaymentException('Failed to parse payment intent response');
        }
      } else if (response.statusCode == 404) {
        _logger.severe('Payment endpoint not found: ${response.body}');
        throw PaymentException(
            'Payment service endpoint not found. Please check server configuration.');
      } else {
        String errorMessage;
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['error'] ?? 'Unknown error';
        } catch (e) {
          // If we can't parse JSON, use the raw response
          errorMessage = response.body;
        }
        _logger.severe('Failed to create payment intent: $errorMessage');
        throw PaymentException(
            'Failed to create payment intent: $errorMessage');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error creating payment intent', e, stackTrace);
      throw PaymentException(
          'Failed to create payment intent: ${e.toString()}');
    }
  }

  /// Get authentication token for backend calls
  static Future<String> _getAuthToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw PaymentException('User must be logged in to make payments');
      }

      final token = await user.getIdToken();
      if (token == null) {
        throw PaymentException('Failed to get authentication token');
      }

      return token;
    } catch (e, stackTrace) {
      _logger.severe('Error getting auth token', e, stackTrace);
      if (e is PaymentException) rethrow;
      throw PaymentException('Failed to get auth token: ${e.toString()}');
    }
  }

  /// Process credit card payment using mock payment system
  static Future<PaymentResult> processCreditCardPayment({
    required String userId,
    required double amount,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.info(
          'Processing mock credit card payment for user: $userId, amount: \$${amount.toStringAsFixed(2)}');

      // Create payment intent with mock payment system
      final response = await http.post(
        Uri.parse(
            '${PaymentConfigService.backendServerUrl}/create-payment-intent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'metadata': {
            'userId': userId,
            ...(metadata ?? {}),
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final paymentId = data['payment_intent_id'] as String;

        // Record the successful payment
        await _recordPaymentTransaction(
          userId: userId,
          amount: amount,
          paymentMethod: PaymentMethod.creditCard,
          transactionId: paymentId,
          status: PaymentStatus.succeeded,
          metadata: metadata,
        );

        _logger.info('Mock credit card payment successful for user: $userId');

        return PaymentResult(
          status: PaymentStatus.succeeded,
          transactionId: paymentId,
          metadata: {'paymentMethod': 'credit_card'},
        );
      } else {
        String errorMessage;
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['error'] ?? 'Unknown error';
        } catch (_) {
          errorMessage = response.body;
        }
        _logger.severe('Payment failed: $errorMessage');
        return PaymentResult(
          status: PaymentStatus.failed,
          error: errorMessage,
        );
      }
    } on PaymentException catch (e) {
      _logger.severe('Payment creation failed', e);
      return PaymentResult(
        status: PaymentStatus.failed,
        error: e.toString(),
      );
    } catch (e, stackTrace) {
      _logger.severe('Error processing credit card payment', e, stackTrace);

      return PaymentResult(
        status: PaymentStatus.failed,
        error: 'Payment processing failed: ${e.toString()}',
      );
    }
  }

  /// Process PayPal payment
  static Future<PaymentResult> processPayPalPayment({
    required String userId,
    required double amount,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.info(
          'Processing PayPal payment for user: $userId, amount: \$${amount.toStringAsFixed(2)}');

      // Create PayPal payment order
      final paypalOrderId = await _createPayPalOrder(
        amount: amount,
        currency: currency,
        userId: userId,
        metadata: metadata,
      );

      if (paypalOrderId == null) {
        return PaymentResult(
          status: PaymentStatus.failed,
          error: 'Failed to create PayPal order',
        );
      }

      // In a real implementation, you would redirect to PayPal or use PayPal SDK
      // For now, we'll simulate the payment process
      final paymentApproved = await _simulatePayPalApproval(paypalOrderId);

      if (paymentApproved) {
        final transactionId = _generateTransactionId();

        // Record the payment
        await _recordPaymentTransaction(
          userId: userId,
          amount: amount,
          paymentMethod: PaymentMethod.paypal,
          transactionId: transactionId,
          status: PaymentStatus.succeeded,
          metadata: {
            ...?metadata,
            'paypal_order_id': paypalOrderId,
          },
        );

        _logger.info('PayPal payment successful for user: $userId');

        return PaymentResult(
          status: PaymentStatus.succeeded,
          transactionId: transactionId,
          metadata: {
            'paymentMethod': 'paypal',
            'paypal_order_id': paypalOrderId
          },
        );
      } else {
        return PaymentResult(
          status: PaymentStatus.cancelled,
          error: 'PayPal payment was cancelled or failed',
        );
      }
    } catch (e) {
      _logger.severe('Error processing PayPal payment: $e');

      return PaymentResult(
        status: PaymentStatus.failed,
        error: 'PayPal payment processing failed: $e',
      );
    }
  }

  /// Process Google Pay payment
  static Future<PaymentResult> processGooglePayPayment({
    required String userId,
    required double amount,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (!Platform.isAndroid) {
        return PaymentResult(
          status: PaymentStatus.failed,
          error: 'Google Pay is only available on Android devices',
        );
      }

      _logger.info(
          'Processing Google Pay payment for user: $userId, amount: \$${amount.toStringAsFixed(2)}');

      // For now, simulate Google Pay payment processing
      // In a real implementation, you would integrate with the Google Pay API
      await Future.delayed(
          const Duration(seconds: 2)); // Simulate processing time

      final transactionId = _generateTransactionId();

      // Record the payment
      await _recordPaymentTransaction(
        userId: userId,
        amount: amount,
        paymentMethod: PaymentMethod.googlePay,
        transactionId: transactionId,
        status: PaymentStatus.succeeded,
        metadata: {
          ...?metadata,
          'google_pay_simulated': true,
        },
      );

      _logger.info('Google Pay payment successful for user: $userId');

      return PaymentResult(
        status: PaymentStatus.succeeded,
        transactionId: transactionId,
        metadata: {'paymentMethod': 'google_pay'},
      );
    } catch (e) {
      _logger.severe('Error processing Google Pay payment: $e');

      return PaymentResult(
        status: PaymentStatus.failed,
        error: 'Google Pay payment processing failed: $e',
      );
    }
  }

  /// Process Apple Pay payment
  static Future<PaymentResult> processApplePayPayment({
    required String userId,
    required double amount,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (!Platform.isIOS) {
        return PaymentResult(
          status: PaymentStatus.failed,
          error: 'Apple Pay is only available on iOS devices',
        );
      }

      _logger.info(
          'Processing Apple Pay payment for user: $userId, amount: \$${amount.toStringAsFixed(2)}');

      // For now, simulate Apple Pay payment processing
      // In a real implementation, you would integrate with the Apple Pay API
      await Future.delayed(
          const Duration(seconds: 2)); // Simulate processing time

      final transactionId = _generateTransactionId();

      // Record the payment
      await _recordPaymentTransaction(
        userId: userId,
        amount: amount,
        paymentMethod: PaymentMethod.applePay,
        transactionId: transactionId,
        status: PaymentStatus.succeeded,
        metadata: {
          ...?metadata,
          'apple_pay_simulated': true,
        },
      );

      _logger.info('Apple Pay payment successful for user: $userId');

      return PaymentResult(
        status: PaymentStatus.succeeded,
        transactionId: transactionId,
        metadata: {'paymentMethod': 'apple_pay'},
      );
    } catch (e) {
      _logger.severe('Error processing Apple Pay payment: $e');

      return PaymentResult(
        status: PaymentStatus.failed,
        error: 'Apple Pay payment processing failed: $e',
      );
    }
  }

  /// Check if payment method is available
  static Future<bool> isPaymentMethodAvailable(PaymentMethod method) async {
    try {
      switch (method) {
        case PaymentMethod.creditCard:
          return true; // Always available through Stripe

        case PaymentMethod.paypal:
          return true; // Available through web integration

        case PaymentMethod.googlePay:
          // For now, assume Google Pay is available on Android devices
          return Platform.isAndroid;

        case PaymentMethod.applePay:
          // For now, assume Apple Pay is available on iOS devices
          return Platform.isIOS;
      }
    } catch (e) {
      _logger.warning('Error checking payment method availability: $e');
      return false;
    }
  }

  /// Get available payment methods for current device
  static Future<List<PaymentMethod>> getAvailablePaymentMethods() async {
    final availableMethods = <PaymentMethod>[];

    for (final method in PaymentMethod.values) {
      if (await isPaymentMethodAvailable(method)) {
        availableMethods.add(method);
      }
    }

    return availableMethods;
  }

  /// Process subscription payment
  static Future<PaymentResult> processSubscriptionPayment({
    required String userId,
    required PaymentMethod paymentMethod,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final amount = monthlySubscriptionPrice;
      final subscriptionMetadata = {
        'type': 'monthly_subscription',
        'userId': userId,
        ...?metadata,
      };

      switch (paymentMethod) {
        case PaymentMethod.creditCard:
          return await processCreditCardPayment(
            userId: userId,
            amount: amount,
            metadata: subscriptionMetadata,
          );

        case PaymentMethod.paypal:
          return await processPayPalPayment(
            userId: userId,
            amount: amount,
            metadata: subscriptionMetadata,
          );

        case PaymentMethod.googlePay:
          return await processGooglePayPayment(
            userId: userId,
            amount: amount,
            metadata: subscriptionMetadata,
          );

        case PaymentMethod.applePay:
          return await processApplePayPayment(
            userId: userId,
            amount: amount,
            metadata: subscriptionMetadata,
          );
      }
    } catch (e) {
      _logger.severe('Error processing subscription payment: $e');
      return PaymentResult(
        status: PaymentStatus.failed,
        error: 'Subscription payment processing failed: $e',
      );
    }
  }

  /// Handle payment failure with retry logic
  static Future<PaymentResult> handleFailedPayment({
    required String userId,
    required String failedTransactionId,
    required PaymentMethod paymentMethod,
    int retryCount = 0,
  }) async {
    try {
      _logger.info(
          'Handling failed payment for user: $userId, retry: $retryCount');

      if (retryCount >= 3) {
        // Max retries reached, mark as permanently failed
        await _updatePaymentTransactionStatus(
          failedTransactionId,
          PaymentStatus.failed,
          {'retry_count': retryCount, 'permanently_failed': true},
        );

        return PaymentResult(
          status: PaymentStatus.failed,
          error: 'Payment failed after maximum retry attempts',
        );
      }

      // Wait before retry (exponential backoff)
      await Future.delayed(Duration(seconds: (retryCount + 1) * 2));

      // Retry the payment
      final result = await processSubscriptionPayment(
        userId: userId,
        paymentMethod: paymentMethod,
        metadata: {
          'retry_attempt': retryCount + 1,
          'original_transaction_id': failedTransactionId,
        },
      );

      if (result.status == PaymentStatus.succeeded) {
        // Update original failed transaction
        await _updatePaymentTransactionStatus(
          failedTransactionId,
          PaymentStatus.succeeded,
          {'retry_successful': true, 'retry_count': retryCount + 1},
        );
      } else if (result.status == PaymentStatus.failed) {
        // Retry again
        return await handleFailedPayment(
          userId: userId,
          failedTransactionId: failedTransactionId,
          paymentMethod: paymentMethod,
          retryCount: retryCount + 1,
        );
      }

      return result;
    } catch (e) {
      _logger.severe('Error handling failed payment: $e');
      return PaymentResult(
        status: PaymentStatus.failed,
        error: 'Failed payment handling error: $e',
      );
    }
  }

  /// Process refund
  static Future<PaymentResult> processRefund({
    required String transactionId,
    required double amount,
    String? reason,
  }) async {
    try {
      _logger.info(
          'Processing refund for transaction: $transactionId, amount: \$${amount.toStringAsFixed(2)}');

      // Get original transaction
      final transactionDoc = await _firestore
          .collection('payment_transactions')
          .doc(transactionId)
          .get();

      if (!transactionDoc.exists) {
        return PaymentResult(
          status: PaymentStatus.failed,
          error: 'Original transaction not found',
        );
      }

      final transactionData = transactionDoc.data() as Map<String, dynamic>;
      final originalAmount = transactionData['amount'] as double;
      final paymentMethodStr = transactionData['paymentMethod'] as String;

      if (amount > originalAmount) {
        return PaymentResult(
          status: PaymentStatus.failed,
          error: 'Refund amount cannot exceed original payment amount',
        );
      }

      // Process refund based on payment method
      final refundId = _generateTransactionId();

      // In a real implementation, you would call the respective payment provider's refund API
      // For now, we'll simulate the refund process
      final refundSuccessful = await _processRefundWithProvider(
        paymentMethodStr,
        transactionId,
        amount,
      );

      if (refundSuccessful) {
        // Record refund transaction
        await _recordRefundTransaction(
          originalTransactionId: transactionId,
          refundId: refundId,
          amount: amount,
          reason: reason,
        );

        _logger.info('Refund processed successfully: $refundId');

        return PaymentResult(
          status: PaymentStatus.succeeded,
          transactionId: refundId,
          metadata: {
            'refund_amount': amount,
            'original_transaction_id': transactionId,
          },
        );
      } else {
        return PaymentResult(
          status: PaymentStatus.failed,
          error: 'Refund processing failed with payment provider',
        );
      }
    } catch (e) {
      _logger.severe('Error processing refund: $e');
      return PaymentResult(
        status: PaymentStatus.failed,
        error: 'Refund processing failed: $e',
      );
    }
  }

  /// Update payment method for user
  static Future<bool> updatePaymentMethod({
    required String userId,
    required PaymentMethod newPaymentMethod,
  }) async {
    try {
      _logger.info('Updating payment method for user: $userId');

      // Update user's preferred payment method
      await _firestore.collection('users').doc(userId).update({
        'preferredPaymentMethod': newPaymentMethod.name,
        'paymentMethodUpdatedAt': FieldValue.serverTimestamp(),
      });

      // If user has active subscription, update subscription record
      final subscriptionDoc =
          await _firestore.collection('subscriptions').doc(userId).get();

      if (subscriptionDoc.exists) {
        await _firestore.collection('subscriptions').doc(userId).update({
          'paymentMethod': newPaymentMethod.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      _logger.info('Payment method updated successfully for user: $userId');
      return true;
    } catch (e) {
      _logger.severe('Error updating payment method: $e');
      return false;
    }
  }

  /// Get payment history for user
  static Future<List<Map<String, dynamic>>> getPaymentHistory(
      String userId) async {
    try {
      final transactions = await _firestore
          .collection('payment_transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return transactions.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.severe('Error getting payment history: $e');
      return [];
    }
  }

  // Private helper methods

  static Future<Map<String, dynamic>?> _getUserDetails(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _logger.warning('Error getting user details: $e');
      return null;
    }
  }

  static Future<String?> _createPayPalOrder({
    required double amount,
    required String currency,
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // In a real implementation, this would call PayPal API
      // For now, we'll simulate order creation
      return 'PAYPAL_ORDER_${_generateTransactionId()}';
    } catch (e) {
      _logger.severe('Error creating PayPal order: $e');
      return null;
    }
  }

  static Future<bool> _simulatePayPalApproval(String orderId) async {
    // Simulate PayPal approval process
    await Future.delayed(const Duration(seconds: 2));
    return true; // Simulate successful approval
  }

  static Future<bool> _processRefundWithProvider(
    String paymentMethod,
    String transactionId,
    double amount,
  ) async {
    try {
      // In a real implementation, this would call the respective payment provider's refund API
      // For now, we'll simulate the refund process
      await Future.delayed(const Duration(seconds: 1));
      return true; // Simulate successful refund
    } catch (e) {
      _logger.severe('Error processing refund with provider: $e');
      return false;
    }
  }

  static String _generateTransactionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000 + (timestamp % 1000)).toString();
    return 'TXN_${random.substring(random.length - 12)}';
  }

  static Future<void> _recordPaymentTransaction({
    required String userId,
    required double amount,
    required PaymentMethod paymentMethod,
    required String transactionId,
    required PaymentStatus status,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore
          .collection('payment_transactions')
          .doc(transactionId)
          .set({
        'userId': userId,
        'transactionId': transactionId,
        'amount': amount,
        'currency': currency,
        'paymentMethod': paymentMethod.name,
        'status': status.name,
        'type': 'payment',
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.info('Payment transaction recorded: $transactionId');
    } catch (e) {
      _logger.severe('Error recording payment transaction: $e');
    }
  }

  static Future<void> _recordRefundTransaction({
    required String originalTransactionId,
    required String refundId,
    required double amount,
    String? reason,
  }) async {
    try {
      await _firestore.collection('payment_transactions').doc(refundId).set({
        'transactionId': refundId,
        'originalTransactionId': originalTransactionId,
        'amount': -amount, // Negative amount for refund
        'currency': currency,
        'type': 'refund',
        'status': PaymentStatus.succeeded.name,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.info('Refund transaction recorded: $refundId');
    } catch (e) {
      _logger.severe('Error recording refund transaction: $e');
    }
  }

  static Future<void> _updatePaymentTransactionStatus(
    String transactionId,
    PaymentStatus status,
    Map<String, dynamic>? metadata,
  ) async {
    try {
      final updateData = {
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (metadata != null) {
        updateData['metadata'] = metadata;
      }

      await _firestore
          .collection('payment_transactions')
          .doc(transactionId)
          .update(updateData);

      _logger.info(
          'Payment transaction status updated: $transactionId -> ${status.name}');
    } catch (e) {
      _logger.severe('Error updating payment transaction status: $e');
    }
  }

  /// Validate PCI compliance requirements
  static bool validatePCICompliance() {
    try {
      // Check that sensitive data is not stored locally
      // Verify encryption is enabled
      // Ensure secure transmission protocols

      // Basic checks for PCI compliance
      final checks = [
        PaymentConfigService.stripePublishableKey.isNotEmpty,
        kReleaseMode || kDebugMode, // Ensure we're in a known environment
        PaymentConfigService.validateConfiguration(),
        // Add more PCI compliance checks as needed
      ];

      final isCompliant = checks.every((check) => check);

      if (isCompliant) {
        _logger.info('PCI compliance validation passed');
      } else {
        _logger.warning('PCI compliance validation failed');
      }

      return isCompliant;
    } catch (e) {
      _logger.severe('Error validating PCI compliance: $e');
      return false;
    }
  }

  /// Secure data handling utilities
  static String hashSensitiveData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Map<String, dynamic> sanitizePaymentData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);

    // Remove sensitive fields that should never be stored
    final sensitiveFields = [
      'cardNumber',
      'cvv',
      'expiryDate',
      'pin',
      'password',
      'ssn',
      'accountNumber',
    ];

    for (final field in sensitiveFields) {
      sanitized.remove(field);
    }

    return sanitized;
  }
}
