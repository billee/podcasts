import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'payment_service.dart';
import 'subscription_service.dart';

enum BillingStatus {
  active,
  pastDue,
  cancelled,
  suspended,
  failed
}

enum RefundStatus {
  pending,
  approved,
  processed,
  rejected,
  failed
}

class BillingCycle {
  final DateTime startDate;
  final DateTime endDate;
  final DateTime nextBillingDate;
  final double amount;
  final String currency;

  BillingCycle({
    required this.startDate,
    required this.endDate,
    required this.nextBillingDate,
    required this.amount,
    required this.currency,
  });

  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'nextBillingDate': Timestamp.fromDate(nextBillingDate),
      'amount': amount,
      'currency': currency,
    };
  }

  factory BillingCycle.fromMap(Map<String, dynamic> map) {
    return BillingCycle(
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      nextBillingDate: (map['nextBillingDate'] as Timestamp).toDate(),
      amount: map['amount'] as double,
      currency: map['currency'] as String,
    );
  }
}

class BillingHistory {
  final String id;
  final String userId;
  final DateTime billingDate;
  final double amount;
  final String currency;
  final String status;
  final String? transactionId;
  final String? failureReason;
  final int retryCount;
  final DateTime? nextRetryDate;

  BillingHistory({
    required this.id,
    required this.userId,
    required this.billingDate,
    required this.amount,
    required this.currency,
    required this.status,
    this.transactionId,
    this.failureReason,
    this.retryCount = 0,
    this.nextRetryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'billingDate': Timestamp.fromDate(billingDate),
      'amount': amount,
      'currency': currency,
      'status': status,
      'transactionId': transactionId,
      'failureReason': failureReason,
      'retryCount': retryCount,
      'nextRetryDate': nextRetryDate != null ? Timestamp.fromDate(nextRetryDate!) : null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory BillingHistory.fromMap(String id, Map<String, dynamic> map) {
    return BillingHistory(
      id: id,
      userId: map['userId'] as String,
      billingDate: (map['billingDate'] as Timestamp).toDate(),
      amount: map['amount'] as double,
      currency: map['currency'] as String,
      status: map['status'] as String,
      transactionId: map['transactionId'] as String?,
      failureReason: map['failureReason'] as String?,
      retryCount: map['retryCount'] as int? ?? 0,
      nextRetryDate: map['nextRetryDate'] != null 
          ? (map['nextRetryDate'] as Timestamp).toDate() 
          : null,
    );
  }
}

class RefundRequest {
  final String id;
  final String userId;
  final String originalTransactionId;
  final double amount;
  final String currency;
  final String reason;
  final RefundStatus status;
  final DateTime requestDate;
  final DateTime? processedDate;
  final String? refundTransactionId;

  RefundRequest({
    required this.id,
    required this.userId,
    required this.originalTransactionId,
    required this.amount,
    required this.currency,
    required this.reason,
    required this.status,
    required this.requestDate,
    this.processedDate,
    this.refundTransactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'originalTransactionId': originalTransactionId,
      'amount': amount,
      'currency': currency,
      'reason': reason,
      'status': status.name,
      'requestDate': Timestamp.fromDate(requestDate),
      'processedDate': processedDate != null ? Timestamp.fromDate(processedDate!) : null,
      'refundTransactionId': refundTransactionId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory RefundRequest.fromMap(String id, Map<String, dynamic> map) {
    return RefundRequest(
      id: id,
      userId: map['userId'] as String,
      originalTransactionId: map['originalTransactionId'] as String,
      amount: map['amount'] as double,
      currency: map['currency'] as String,
      reason: map['reason'] as String,
      status: RefundStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RefundStatus.pending,
      ),
      requestDate: (map['requestDate'] as Timestamp).toDate(),
      processedDate: map['processedDate'] != null 
          ? (map['processedDate'] as Timestamp).toDate() 
          : null,
      refundTransactionId: map['refundTransactionId'] as String?,
    );
  }
}

class Receipt {
  final String id;
  final String userId;
  final String transactionId;
  final DateTime date;
  final double amount;
  final String currency;
  final String description;
  final String paymentMethod;
  final Map<String, dynamic> metadata;

  Receipt({
    required this.id,
    required this.userId,
    required this.transactionId,
    required this.date,
    required this.amount,
    required this.currency,
    required this.description,
    required this.paymentMethod,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'transactionId': transactionId,
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'currency': currency,
      'description': description,
      'paymentMethod': paymentMethod,
      'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Receipt.fromMap(String id, Map<String, dynamic> map) {
    return Receipt(
      id: id,
      userId: map['userId'] as String,
      transactionId: map['transactionId'] as String,
      date: (map['date'] as Timestamp).toDate(),
      amount: map['amount'] as double,
      currency: map['currency'] as String,
      description: map['description'] as String,
      paymentMethod: map['paymentMethod'] as String,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
}

class BillingService {
  static final Logger _logger = Logger('BillingService');
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static FirebaseAuth _auth = FirebaseAuth.instance;

  // For testing purposes - allow dependency injection
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }

  static void setAuthInstance(FirebaseAuth auth) {
    _auth = auth;
  }

  // Constants
  static const double monthlySubscriptionPrice = 3.0;
  static const String currency = 'USD';
  static const int maxRetryAttempts = 3;
  static const int gracePeriodDays = 3;

  /// Set up automatic monthly billing for a user
  static Future<bool> setupAutomaticBilling({
    required String userId,
    required PaymentMethod paymentMethod,
  }) async {
    try {
      _logger.info('Setting up automatic billing for user: $userId');

      final now = DateTime.now();
      final nextBillingDate = DateTime(now.year, now.month + 1, now.day);

      // Create billing configuration
      await _firestore.collection('billing_config').doc(userId).set({
        'userId': userId,
        'status': BillingStatus.active.name,
        'paymentMethod': paymentMethod.name,
        'amount': monthlySubscriptionPrice,
        'currency': currency,
        'billingCycle': 'monthly',
        'nextBillingDate': Timestamp.fromDate(nextBillingDate),
        'lastBillingDate': null,
        'failedAttempts': 0,
        'gracePeriodEnd': null,
        'autoRetry': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Schedule first billing
      await _scheduleBilling(userId, nextBillingDate);

      _logger.info('Automatic billing setup completed for user: $userId');
      return true;
    } catch (e) {
      _logger.severe('Error setting up automatic billing: $e');
      return false;
    }
  }

  /// Process monthly billing for a user
  static Future<bool> processMonthlyBilling(String userId) async {
    try {
      _logger.info('Processing monthly billing for user: $userId');

      // Get billing configuration
      final billingDoc = await _firestore.collection('billing_config').doc(userId).get();
      if (!billingDoc.exists) {
        _logger.warning('No billing configuration found for user: $userId');
        return false;
      }

      final billingData = billingDoc.data() as Map<String, dynamic>;
      final paymentMethodStr = billingData['paymentMethod'] as String;
      final amount = billingData['amount'] as double;
      final status = billingData['status'] as String;

      if (status != BillingStatus.active.name) {
        _logger.info('Billing not active for user: $userId, status: $status');
        return false;
      }

      // Convert string to PaymentMethod enum
      final paymentMethod = PaymentMethod.values.firstWhere(
        (e) => e.name == paymentMethodStr,
        orElse: () => PaymentMethod.creditCard,
      );

      // Process payment
      final paymentResult = await PaymentService.processSubscriptionPayment(
        userId: userId,
        paymentMethod: paymentMethod,
        metadata: {
          'billing_type': 'monthly_recurring',
          'billing_cycle': DateTime.now().toIso8601String(),
        },
      );

      // Record billing history
      final billingHistoryId = _generateBillingId();
      final billingHistory = BillingHistory(
        id: billingHistoryId,
        userId: userId,
        billingDate: DateTime.now(),
        amount: amount,
        currency: currency,
        status: paymentResult.status.name,
        transactionId: paymentResult.transactionId,
        failureReason: paymentResult.error,
      );

      await _firestore.collection('billing_history').doc(billingHistoryId).set(billingHistory.toMap());

      if (paymentResult.status == PaymentStatus.succeeded) {
        // Update billing configuration for next cycle
        await _updateBillingConfigAfterSuccess(userId);
        
        // Generate receipt
        await _generateReceipt(userId, paymentResult.transactionId!, amount, paymentMethod);
        
        // Renew subscription
        await SubscriptionService.renewMonthlySubscription(
          userId,
          paymentMethod: paymentMethod.name,
          transactionId: paymentResult.transactionId,
        );

        _logger.info('Monthly billing successful for user: $userId');
        return true;
      } else {
        // Handle payment failure
        await _handleBillingFailure(userId, billingHistoryId, paymentResult.error ?? 'Payment failed');
        return false;
      }
    } catch (e) {
      _logger.severe('Error processing monthly billing: $e');
      return false;
    }
  }

  /// Handle billing failure with retry logic
  static Future<void> _handleBillingFailure(String userId, String billingHistoryId, String failureReason) async {
    try {
      _logger.info('Handling billing failure for user: $userId');

      // Get current billing configuration
      final billingDoc = await _firestore.collection('billing_config').doc(userId).get();
      final billingData = billingDoc.data() as Map<String, dynamic>;
      final failedAttempts = (billingData['failedAttempts'] as int? ?? 0) + 1;

      if (failedAttempts >= maxRetryAttempts) {
        // Max retries reached, suspend billing
        await _suspendBilling(userId, 'Maximum retry attempts reached');
        return;
      }

      // Calculate next retry date (exponential backoff)
      final nextRetryDate = DateTime.now().add(Duration(days: failedAttempts * 2));

      // Update billing configuration
      await _firestore.collection('billing_config').doc(userId).update({
        'failedAttempts': failedAttempts,
        'status': BillingStatus.pastDue.name,
        'gracePeriodEnd': Timestamp.fromDate(DateTime.now().add(Duration(days: gracePeriodDays))),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update billing history with retry information
      await _firestore.collection('billing_history').doc(billingHistoryId).update({
        'retryCount': failedAttempts,
        'nextRetryDate': Timestamp.fromDate(nextRetryDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Schedule retry
      await _scheduleRetryBilling(userId, nextRetryDate);

      // Notify user about payment failure
      await _notifyPaymentFailure(userId, failedAttempts, nextRetryDate);

      _logger.info('Billing failure handled for user: $userId, retry scheduled for: $nextRetryDate');
    } catch (e) {
      _logger.severe('Error handling billing failure: $e');
    }
  }

  /// Retry failed billing
  static Future<bool> retryFailedBilling(String userId) async {
    try {
      _logger.info('Retrying failed billing for user: $userId');

      // Get billing configuration
      final billingDoc = await _firestore.collection('billing_config').doc(userId).get();
      if (!billingDoc.exists) {
        return false;
      }

      final billingData = billingDoc.data() as Map<String, dynamic>;
      final status = billingData['status'] as String;

      if (status != BillingStatus.pastDue.name) {
        _logger.info('Billing not in past due status for user: $userId');
        return false;
      }

      // Check if still within grace period
      final gracePeriodEnd = billingData['gracePeriodEnd'] as Timestamp?;
      if (gracePeriodEnd != null && DateTime.now().isAfter(gracePeriodEnd.toDate())) {
        // Grace period expired, suspend billing
        await _suspendBilling(userId, 'Grace period expired');
        return false;
      }

      // Attempt billing again
      final success = await processMonthlyBilling(userId);

      if (success) {
        // Reset failed attempts
        await _firestore.collection('billing_config').doc(userId).update({
          'failedAttempts': 0,
          'status': BillingStatus.active.name,
          'gracePeriodEnd': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return success;
    } catch (e) {
      _logger.severe('Error retrying failed billing: $e');
      return false;
    }
  }

  /// Suspend billing for a user
  static Future<void> _suspendBilling(String userId, String reason) async {
    try {
      _logger.info('Suspending billing for user: $userId, reason: $reason');

      await _firestore.collection('billing_config').doc(userId).update({
        'status': BillingStatus.suspended.name,
        'suspensionReason': reason,
        'suspendedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update subscription status
      await _firestore.collection('subscriptions').doc(userId).update({
        'status': 'suspended',
        'suspensionReason': reason,
        'suspendedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify user about suspension
      await _notifyBillingSuspension(userId, reason);

      _logger.info('Billing suspended for user: $userId');
    } catch (e) {
      _logger.severe('Error suspending billing: $e');
    }
  }

  /// Process refund request
  static Future<RefundRequest?> processRefundRequest({
    required String userId,
    required String transactionId,
    required double amount,
    required String reason,
  }) async {
    try {
      _logger.info('Processing refund request for user: $userId, transaction: $transactionId');

      // Validate refund eligibility
      final isEligible = await _validateRefundEligibility(userId, transactionId, amount);
      if (!isEligible) {
        _logger.warning('Refund not eligible for user: $userId, transaction: $transactionId');
        return null;
      }

      // Create refund request
      final refundId = _generateRefundId();
      final refundRequest = RefundRequest(
        id: refundId,
        userId: userId,
        originalTransactionId: transactionId,
        amount: amount,
        currency: currency,
        reason: reason,
        status: RefundStatus.pending,
        requestDate: DateTime.now(),
      );

      await _firestore.collection('refund_requests').doc(refundId).set(refundRequest.toMap());

      // Process refund with payment service
      final refundResult = await PaymentService.processRefund(
        transactionId: transactionId,
        amount: amount,
        reason: reason,
      );

      RefundStatus finalStatus;
      String? refundTransactionId;

      if (refundResult.status == PaymentStatus.succeeded) {
        finalStatus = RefundStatus.processed;
        refundTransactionId = refundResult.transactionId;
        
        // Update subscription if needed
        await _handleRefundSubscriptionUpdate(userId, amount);
      } else {
        finalStatus = RefundStatus.failed;
      }

      // Update refund request
      await _firestore.collection('refund_requests').doc(refundId).update({
        'status': finalStatus.name,
        'processedDate': FieldValue.serverTimestamp(),
        'refundTransactionId': refundTransactionId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Generate refund receipt
      if (finalStatus == RefundStatus.processed && refundTransactionId != null) {
        await _generateRefundReceipt(userId, refundTransactionId, amount);
      }

      // Notify user about refund status
      await _notifyRefundStatus(userId, finalStatus, amount);

      _logger.info('Refund request processed for user: $userId, status: ${finalStatus.name}');
      
      return RefundRequest(
        id: refundId,
        userId: userId,
        originalTransactionId: transactionId,
        amount: amount,
        currency: currency,
        reason: reason,
        status: finalStatus,
        requestDate: DateTime.now(),
        processedDate: finalStatus == RefundStatus.processed ? DateTime.now() : null,
        refundTransactionId: refundTransactionId,
      );
    } catch (e) {
      _logger.severe('Error processing refund request: $e');
      return null;
    }
  }

  /// Get billing history for a user
  static Future<List<BillingHistory>> getBillingHistory(String userId, {int limit = 50}) async {
    try {
      final query = await _firestore
          .collection('billing_history')
          .where('userId', isEqualTo: userId)
          .orderBy('billingDate', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) => BillingHistory.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      _logger.severe('Error getting billing history: $e');
      return [];
    }
  }

  /// Get receipts for a user
  static Future<List<Receipt>> getReceipts(String userId, {int limit = 50}) async {
    try {
      final query = await _firestore
          .collection('receipts')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) => Receipt.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      _logger.severe('Error getting receipts: $e');
      return [];
    }
  }

  /// Get refund requests for a user
  static Future<List<RefundRequest>> getRefundRequests(String userId) async {
    try {
      final query = await _firestore
          .collection('refund_requests')
          .where('userId', isEqualTo: userId)
          .orderBy('requestDate', descending: true)
          .get();

      return query.docs.map((doc) => RefundRequest.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      _logger.severe('Error getting refund requests: $e');
      return [];
    }
  }

  /// Cancel automatic billing
  static Future<bool> cancelAutomaticBilling(String userId) async {
    try {
      _logger.info('Cancelling automatic billing for user: $userId');

      await _firestore.collection('billing_config').doc(userId).update({
        'status': BillingStatus.cancelled.name,
        'cancelledAt': FieldValue.serverTimestamp(),
        'autoRetry': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.info('Automatic billing cancelled for user: $userId');
      return true;
    } catch (e) {
      _logger.severe('Error cancelling automatic billing: $e');
      return false;
    }
  }

  // Private helper methods

  static Future<void> _updateBillingConfigAfterSuccess(String userId) async {
    final now = DateTime.now();
    final nextBillingDate = DateTime(now.year, now.month + 1, now.day);

    await _firestore.collection('billing_config').doc(userId).update({
      'lastBillingDate': FieldValue.serverTimestamp(),
      'nextBillingDate': Timestamp.fromDate(nextBillingDate),
      'failedAttempts': 0,
      'status': BillingStatus.active.name,
      'gracePeriodEnd': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Schedule next billing
    await _scheduleBilling(userId, nextBillingDate);
  }

  static Future<void> _generateReceipt(String userId, String transactionId, double amount, PaymentMethod paymentMethod) async {
    final receiptId = _generateReceiptId();
    final receipt = Receipt(
      id: receiptId,
      userId: userId,
      transactionId: transactionId,
      date: DateTime.now(),
      amount: amount,
      currency: currency,
      description: 'Monthly Subscription - OFW Companion App',
      paymentMethod: paymentMethod.name,
      metadata: {
        'billing_type': 'monthly_subscription',
        'app_name': 'OFW Companion App',
      },
    );

    await _firestore.collection('receipts').doc(receiptId).set(receipt.toMap());
  }

  static Future<void> _generateRefundReceipt(String userId, String refundTransactionId, double amount) async {
    final receiptId = _generateReceiptId();
    final receipt = Receipt(
      id: receiptId,
      userId: userId,
      transactionId: refundTransactionId,
      date: DateTime.now(),
      amount: -amount, // Negative amount for refund
      currency: currency,
      description: 'Refund - Monthly Subscription',
      paymentMethod: 'refund',
      metadata: {
        'type': 'refund',
        'app_name': 'OFW Companion App',
      },
    );

    await _firestore.collection('receipts').doc(receiptId).set(receipt.toMap());
  }

  static Future<bool> _validateRefundEligibility(String userId, String transactionId, double amount) async {
    try {
      // Get original transaction
      final transactionDoc = await _firestore
          .collection('payment_transactions')
          .doc(transactionId)
          .get();

      if (!transactionDoc.exists) {
        return false;
      }

      final transactionData = transactionDoc.data() as Map<String, dynamic>;
      final transactionUserId = transactionData['userId'] as String;
      final transactionAmount = transactionData['amount'] as double;
      final transactionDate = (transactionData['createdAt'] as Timestamp).toDate();

      // Validate user ownership
      if (transactionUserId != userId) {
        return false;
      }

      // Validate amount
      if (amount > transactionAmount) {
        return false;
      }

      // Check if refund is within allowed timeframe (30 days)
      final daysSinceTransaction = DateTime.now().difference(transactionDate).inDays;
      if (daysSinceTransaction > 30) {
        return false;
      }

      // Check if already refunded
      final existingRefunds = await _firestore
          .collection('refund_requests')
          .where('originalTransactionId', isEqualTo: transactionId)
          .where('status', isEqualTo: RefundStatus.processed.name)
          .get();

      if (existingRefunds.docs.isNotEmpty) {
        return false;
      }

      return true;
    } catch (e) {
      _logger.severe('Error validating refund eligibility: $e');
      return false;
    }
  }

  static Future<void> _handleRefundSubscriptionUpdate(String userId, double refundAmount) async {
    try {
      // If full monthly amount refunded, adjust subscription end date
      if (refundAmount >= monthlySubscriptionPrice) {
        final subscriptionDoc = await _firestore.collection('subscriptions').doc(userId).get();
        if (subscriptionDoc.exists) {
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          final currentEndDate = (subscriptionData['subscriptionEndDate'] as Timestamp).toDate();
          
          // Move end date back by one month
          final adjustedEndDate = DateTime(currentEndDate.year, currentEndDate.month - 1, currentEndDate.day);
          
          await _firestore.collection('subscriptions').doc(userId).update({
            'subscriptionEndDate': Timestamp.fromDate(adjustedEndDate),
            'refundAdjustment': refundAmount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      _logger.warning('Error handling refund subscription update: $e');
    }
  }

  static Future<void> _scheduleBilling(String userId, DateTime billingDate) async {
    // In a real implementation, this would integrate with a job scheduler
    // For now, we'll just log the scheduled billing
    _logger.info('Billing scheduled for user: $userId on: $billingDate');
  }

  static Future<void> _scheduleRetryBilling(String userId, DateTime retryDate) async {
    // In a real implementation, this would integrate with a job scheduler
    // For now, we'll just log the scheduled retry
    _logger.info('Billing retry scheduled for user: $userId on: $retryDate');
  }

  static Future<void> _notifyPaymentFailure(String userId, int attemptNumber, DateTime nextRetryDate) async {
    // In a real implementation, this would send email/push notifications
    _logger.info('Payment failure notification sent to user: $userId, attempt: $attemptNumber, next retry: $nextRetryDate');
  }

  static Future<void> _notifyBillingSuspension(String userId, String reason) async {
    // In a real implementation, this would send email/push notifications
    _logger.info('Billing suspension notification sent to user: $userId, reason: $reason');
  }

  static Future<void> _notifyRefundStatus(String userId, RefundStatus status, double amount) async {
    // In a real implementation, this would send email/push notifications
    _logger.info('Refund status notification sent to user: $userId, status: ${status.name}, amount: $amount');
  }

  static String _generateBillingId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'BILL_${timestamp}_${(timestamp % 10000).toString().padLeft(4, '0')}';
  }

  static String _generateRefundId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'REF_${timestamp}_${(timestamp % 10000).toString().padLeft(4, '0')}';
  }

  static String _generateReceiptId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'RCP_${timestamp}_${(timestamp % 10000).toString().padLeft(4, '0')}';
  }
}