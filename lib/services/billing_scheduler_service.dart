import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'billing_service.dart';
import 'payment_service.dart';

class BillingSchedulerService {
  static final Logger _logger = Logger('BillingSchedulerService');
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Timer? _schedulerTimer;
  static bool _isRunning = false;

  // For testing purposes - allow dependency injection
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }

  /// Start the billing scheduler
  static void startScheduler() {
    if (_isRunning) {
      _logger.info('Billing scheduler is already running');
      return;
    }

    _logger.info('Starting billing scheduler');
    _isRunning = true;

    // Run billing checks every hour
    _schedulerTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _processPendingBilling();
    });

    // Also run immediately on startup
    _processPendingBilling();
  }

  /// Stop the billing scheduler
  static void stopScheduler() {
    if (!_isRunning) {
      _logger.info('Billing scheduler is not running');
      return;
    }

    _logger.info('Stopping billing scheduler');
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
    _isRunning = false;
  }

  /// Process all pending billing operations
  static Future<void> _processPendingBilling() async {
    try {
      _logger.info('Processing pending billing operations');

      final now = DateTime.now();
      
      // Process due billings
      await _processDueBillings(now);
      
      // Process retry billings
      await _processRetryBillings(now);
      
      // Process expired grace periods
      await _processExpiredGracePeriods(now);

      _logger.info('Completed processing pending billing operations');
    } catch (e) {
      _logger.severe('Error processing pending billing: $e');
    }
  }

  /// Process billings that are due
  static Future<void> _processDueBillings(DateTime now) async {
    try {
      // Get all active billing configurations with due dates
      final query = await _firestore
          .collection('billing_config')
          .where('status', isEqualTo: BillingStatus.active.name)
          .where('nextBillingDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      _logger.info('Found ${query.docs.length} due billings to process');

      for (final doc in query.docs) {
        final billingData = doc.data();
        final userId = billingData['userId'] as String;
        
        try {
          await BillingService.processMonthlyBilling(userId);
          _logger.info('Processed billing for user: $userId');
        } catch (e) {
          _logger.warning('Failed to process billing for user $userId: $e');
        }
      }
    } catch (e) {
      _logger.severe('Error processing due billings: $e');
    }
  }

  /// Process retry billings
  static Future<void> _processRetryBillings(DateTime now) async {
    try {
      // Get billing histories with retry dates that are due
      final query = await _firestore
          .collection('billing_history')
          .where('status', isEqualTo: PaymentStatus.failed.name)
          .where('nextRetryDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      _logger.info('Found ${query.docs.length} retry billings to process');

      for (final doc in query.docs) {
        final billingData = doc.data();
        final userId = billingData['userId'] as String;
        
        try {
          await BillingService.retryFailedBilling(userId);
          _logger.info('Processed retry billing for user: $userId');
        } catch (e) {
          _logger.warning('Failed to process retry billing for user $userId: $e');
        }
      }
    } catch (e) {
      _logger.severe('Error processing retry billings: $e');
    }
  }

  /// Process expired grace periods
  static Future<void> _processExpiredGracePeriods(DateTime now) async {
    try {
      // Get billing configurations with expired grace periods
      final query = await _firestore
          .collection('billing_config')
          .where('status', isEqualTo: BillingStatus.pastDue.name)
          .where('gracePeriodEnd', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      _logger.info('Found ${query.docs.length} expired grace periods to process');

      for (final doc in query.docs) {
        final billingData = doc.data();
        final userId = billingData['userId'] as String;
        
        try {
          // Suspend billing for users whose grace period has expired
          await _firestore.collection('billing_config').doc(userId).update({
            'status': BillingStatus.suspended.name,
            'suspensionReason': 'Grace period expired after payment failures',
            'suspendedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Update subscription status
          await _firestore.collection('subscriptions').doc(userId).update({
            'status': 'suspended',
            'suspensionReason': 'Payment failure - grace period expired',
            'suspendedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          _logger.info('Suspended billing for user with expired grace period: $userId');
        } catch (e) {
          _logger.warning('Failed to suspend billing for user $userId: $e');
        }
      }
    } catch (e) {
      _logger.severe('Error processing expired grace periods: $e');
    }
  }

  /// Manually trigger billing for a specific user (for testing/admin use)
  static Future<bool> triggerBillingForUser(String userId) async {
    try {
      _logger.info('Manually triggering billing for user: $userId');
      
      final success = await BillingService.processMonthlyBilling(userId);
      
      if (success) {
        _logger.info('Manual billing successful for user: $userId');
      } else {
        _logger.warning('Manual billing failed for user: $userId');
      }
      
      return success;
    } catch (e) {
      _logger.severe('Error manually triggering billing for user $userId: $e');
      return false;
    }
  }

  /// Get billing scheduler status
  static Map<String, dynamic> getSchedulerStatus() {
    return {
      'isRunning': _isRunning,
      'nextRun': _schedulerTimer != null 
          ? DateTime.now().add(const Duration(hours: 1)).toIso8601String()
          : null,
      'intervalHours': 1,
    };
  }

  /// Get pending billing operations count
  static Future<Map<String, int>> getPendingBillingCounts() async {
    try {
      final now = DateTime.now();
      
      // Count due billings
      final dueBillingsQuery = await _firestore
          .collection('billing_config')
          .where('status', isEqualTo: BillingStatus.active.name)
          .where('nextBillingDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      // Count retry billings
      final retryBillingsQuery = await _firestore
          .collection('billing_history')
          .where('status', isEqualTo: PaymentStatus.failed.name)
          .where('nextRetryDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      // Count expired grace periods
      final expiredGraceQuery = await _firestore
          .collection('billing_config')
          .where('status', isEqualTo: BillingStatus.pastDue.name)
          .where('gracePeriodEnd', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      return {
        'dueBillings': dueBillingsQuery.docs.length,
        'retryBillings': retryBillingsQuery.docs.length,
        'expiredGracePeriods': expiredGraceQuery.docs.length,
      };
    } catch (e) {
      _logger.severe('Error getting pending billing counts: $e');
      return {
        'dueBillings': 0,
        'retryBillings': 0,
        'expiredGracePeriods': 0,
      };
    }
  }

  /// Process all billing operations immediately (for testing/admin use)
  static Future<void> processAllPendingBilling() async {
    _logger.info('Manually processing all pending billing operations');
    await _processPendingBilling();
  }

  /// Get billing statistics
  static Future<Map<String, dynamic>> getBillingStatistics() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      // Get billing history for current month
      final billingHistoryQuery = await _firestore
          .collection('billing_history')
          .where('billingDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('billingDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      int successfulBillings = 0;
      int failedBillings = 0;
      double totalRevenue = 0;

      for (final doc in billingHistoryQuery.docs) {
        final data = doc.data();
        final status = data['status'] as String;
        final amount = data['amount'] as double;

        if (status == PaymentStatus.succeeded.name) {
          successfulBillings++;
          totalRevenue += amount;
        } else if (status == PaymentStatus.failed.name) {
          failedBillings++;
        }
      }

      // Get active billing configurations
      final activeBillingsQuery = await _firestore
          .collection('billing_config')
          .where('status', isEqualTo: BillingStatus.active.name)
          .get();

      // Get suspended billing configurations
      final suspendedBillingsQuery = await _firestore
          .collection('billing_config')
          .where('status', isEqualTo: BillingStatus.suspended.name)
          .get();

      return {
        'currentMonth': {
          'successfulBillings': successfulBillings,
          'failedBillings': failedBillings,
          'totalRevenue': totalRevenue,
          'successRate': successfulBillings + failedBillings > 0 
              ? (successfulBillings / (successfulBillings + failedBillings) * 100).round()
              : 0,
        },
        'activeBillings': activeBillingsQuery.docs.length,
        'suspendedBillings': suspendedBillingsQuery.docs.length,
        'schedulerStatus': getSchedulerStatus(),
      };
    } catch (e) {
      _logger.severe('Error getting billing statistics: $e');
      return {};
    }
  }
}