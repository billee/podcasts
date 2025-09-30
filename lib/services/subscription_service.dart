import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../core/config.dart';
import 'in_app_purchase_service.dart';

enum SubscriptionStatus { trial, active, expired, cancelled, trialExpired }

enum SubscriptionPlan { trial, monthly }

class SubscriptionService {
  static final Logger _logger = Logger('SubscriptionService');
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
  static const int trialDurationDays = 7;
  static const double monthlyPrice = 3.0;

  /// Activate subscription after successful payment
  static Future<void> activateSubscription({
    required String userId,
    required String plan,
    required double amount,
  }) async {
    try {
      final now = AppConfig.currentDateTime;
      final expiryDate =
          now.add(const Duration(days: 30)); // 30-day subscription

      await _firestore.collection('subscriptions').doc(userId).set({
        'userId': userId,
        'status': SubscriptionStatus.active.name,
        'plan': plan,
        'amount': amount,
        'startDate': now,
        'subscriptionEndDate': expiryDate,
        'lastPayment': {'amount': amount, 'date': now, 'status': 'succeeded'}
      });

      _logger.info('Subscription activated for user: $userId');
    } catch (e) {
      _logger.severe('Error activating subscription: $e');
      rethrow;
    }
  }

  /// Check current subscription status
  static Future<SubscriptionStatus> getSubscriptionStatus(String userId) async {
    try {
      // First check if user's email is verified
      final user = _auth.currentUser;
      if (user == null || !user.emailVerified) {
        _logger.info(
            'User email not verified, no subscription access for user: $userId');
        return SubscriptionStatus.expired; // No access until email verified
      }

      // Get user email
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return SubscriptionStatus.expired;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userEmail = userData['email'] as String?;
      final emailVerified = userData['emailVerified'] as bool? ?? false;

      if (userEmail == null || !emailVerified) {
        return SubscriptionStatus.expired;
      }

      // Check if user has an active subscription first
      final subscriptionDoc =
          await _firestore.collection('subscriptions').doc(userId).get();

      if (subscriptionDoc.exists) {
        final subscription = subscriptionDoc.data() as Map<String, dynamic>;
        final status = subscription['status'] as String?;

        _logger.info('Checking subscription for user $userId. Status: $status');

        // Check if the subscription is active or cancelled
        if (status == SubscriptionStatus.active.name || status == 'cancelled') {
          final now = AppConfig.currentDateTime;
          final subscriptionEndDate = subscription['subscriptionEndDate'];

          if (subscriptionEndDate == null) {
            _logger.info('No end date found, treating as active subscription');
            return status == 'cancelled' ? SubscriptionStatus.cancelled : SubscriptionStatus.active;
          }

          final endDate = (subscriptionEndDate as Timestamp).toDate();
          if (now.isBefore(endDate)) {
            _logger.info('Subscription is ${status == 'cancelled' ? 'cancelled but' : ''} active and not expired');
            return status == 'cancelled' ? SubscriptionStatus.cancelled : SubscriptionStatus.active;
          }

          _logger.info('Subscription has expired. Setting expired status.');
          await _updateSubscriptionStatus(userId, SubscriptionStatus.expired);
        }
      }

      // No active subscription or not marked as active
      final trialQuery = await _firestore
          .collection('trial_history')
          .where('userId', isEqualTo: userId)
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (trialQuery.docs.isNotEmpty) {
        final trialDoc = trialQuery.docs.first;
        final trialData = trialDoc.data();
        final trialEndDate = trialData['trialEndDate'] as Timestamp?;
        final bannedAt = trialData['banned_at'] as Timestamp?;

        // If trial is banned, treat as expired regardless of end date
        if (bannedAt != null) {
          _logger.info('Trial for user $userId is banned (banned_at: $bannedAt), treating as expired');
          return SubscriptionStatus.trialExpired;
        }

        if (trialEndDate != null) {
          final now = AppConfig.currentDateTime;
          if (now.isBefore(trialEndDate.toDate())) {
            return SubscriptionStatus.trial;
          } else {
            return SubscriptionStatus.trialExpired;
          }
        }
      }

      // Check if email has been used for trial before (different user)
      final emailTrialQuery = await _firestore
          .collection('trial_history')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (emailTrialQuery.docs.isNotEmpty) {
        return SubscriptionStatus.trialExpired;
      }

      return SubscriptionStatus.expired;
    } catch (e) {
      _logger.severe('Error getting subscription status: $e');
      return SubscriptionStatus.expired;
    }
  }

  /// Check if a user's trial is banned
  static Future<bool> isTrialBanned(String userId) async {
    try {
      // Get user email
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return false;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userEmail = userData['email'] as String?;
      
      if (userEmail == null) {
        return false;
      }

      // Check trial history for banned_at field
      final trialQuery = await _firestore
          .collection('trial_history')
          .where('userId', isEqualTo: userId)
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (trialQuery.docs.isNotEmpty) {
        final trialData = trialQuery.docs.first.data();
        final bannedAt = trialData['banned_at'] as Timestamp?;
        return bannedAt != null;
      }

      return false;
    } catch (e) {
      _logger.severe('Error checking if trial is banned for user $userId: $e');
      return false;
    }
  }

  /// Update subscription status
  static Future<void> _updateSubscriptionStatus(
      String userId, SubscriptionStatus status) async {
    try {
      await _firestore.collection('subscriptions').doc(userId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _logger.info(
          'Updated subscription status for user $userId to ${status.name}');
    } catch (e) {
      _logger.severe('Error updating subscription status: $e');
    }
  }

  /// Get subscription details
  static Future<Map<String, dynamic>?> getSubscriptionDetails(
      String userId) async {
    try {
      final now = AppConfig.currentDateTime;
      Map<String, dynamic> details = {};

      // Get user email
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      final userEmail = userData['email'] as String?;
      if (userEmail == null) return null;

      // Check subscription first
      final subscriptionDoc =
          await _firestore.collection('subscriptions').doc(userId).get();

      if (subscriptionDoc.exists) {
        final subscription = subscriptionDoc.data() as Map<String, dynamic>;
        details = Map<String, dynamic>.from(subscription);

        final subscriptionEndDate =
            subscription['subscriptionEndDate'] as Timestamp?;
        if (subscriptionEndDate != null) {
          final daysLeft = subscriptionEndDate.toDate().difference(now).inDays;
          details['subscriptionDaysLeft'] = daysLeft > 0 ? daysLeft : 0;
        }

        return details;
      }

      // Check trial history
      final trialQuery = await _firestore
          .collection('trial_history')
          .where('userId', isEqualTo: userId)
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (trialQuery.docs.isNotEmpty) {
        final trialDoc = trialQuery.docs.first;
        final trialData = trialDoc.data();

        details = Map<String, dynamic>.from(trialData);
        details['status'] = 'trial';
        details['plan'] = 'trial';

        final trialEndDate = trialData['trialEndDate'] as Timestamp?;
        if (trialEndDate != null) {
          final daysLeft = trialEndDate.toDate().difference(now).inDays;
          final hoursLeft = trialEndDate.toDate().difference(now).inHours;
          details['trialDaysLeft'] = daysLeft > 0 ? daysLeft : 0;
          details['trialHoursLeft'] = hoursLeft > 0 ? hoursLeft : 0;
        }

        return details;
      }

      return null;
    } catch (e) {
      _logger.severe('Error getting subscription details: $e');
      return null;
    }
  }

  /// Subscribe to monthly plan
  static Future<bool> subscribeToMonthlyPlan(
    String userId, {
    required String paymentMethod,
    String? transactionId,
  }) async {
    try {
      final now = AppConfig.currentDateTime;
      final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);

      // Get user email
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final userEmail = userData['email'] as String;

      // Create subscription record (first time for actual subscription)
      await _firestore.collection('subscriptions').doc(userId).set({
        'userId': userId,
        'email': userEmail,
        'status': 'active',
        'plan': 'monthly',
        'isTrialActive': false,
        'subscriptionStartDate': FieldValue.serverTimestamp(),
        'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
        'lastPaymentDate': FieldValue.serverTimestamp(),
        'nextBillingDate': Timestamp.fromDate(subscriptionEndDate),
        'price': monthlyPrice,
        'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Record payment transaction
      await _recordPaymentTransaction(
          userId, monthlyPrice, transactionId, 'monthly_subscription');

      _logger.info('Monthly subscription activated for user: $userId');
      return true;
    } catch (e) {
      _logger.severe('Error subscribing to monthly plan: $e');
      return false;
    }
  }

  /// Record payment transaction
  static Future<void> _recordPaymentTransaction(
      String userId, double amount, String? transactionId, String type) async {
    try {
      await _firestore.collection('payment_transactions').add({
        'userId': userId,
        'amount': amount,
        'currency': 'USD',
        'transactionId': transactionId,
        'type': type,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.warning('Error recording payment transaction: $e');
    }
  }

  /// Check if user has access to premium features
  static Future<bool> hasActiveSubscription(String userId) async {
    final status = await getSubscriptionStatus(userId);
    return status == SubscriptionStatus.trial ||
        status == SubscriptionStatus.active ||
        status == SubscriptionStatus.cancelled; // Cancelled users still have access until expiration
  }

  /// Get trial days remaining
  static Future<int> getTrialDaysRemaining(String userId) async {
    try {
      final details = await getSubscriptionDetails(userId);
      if (details == null) return 0;

      return details['trialDaysLeft'] as int? ?? 0;
    } catch (e) {
      _logger.severe('Error getting trial days remaining: $e');
      return 0;
    }
  }

  /// Cancel subscription (ends at current billing period)
  static Future<bool> cancelSubscription(String userId) async {
    try {
      // Get current subscription details
      final subscriptionDoc =
          await _firestore.collection('subscriptions').doc(userId).get();
      if (!subscriptionDoc.exists) {
        _logger.warning('No subscription found to cancel for user: $userId');
        return false;
      }

      final subscription = subscriptionDoc.data() as Map<String, dynamic>;
      final subscriptionEndDate =
          subscription['subscriptionEndDate'] as Timestamp?;

      // Update subscription to cancelled but keep it active until end date
      await _firestore.collection('subscriptions').doc(userId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'willExpireAt': subscriptionEndDate, // Keep original end date
        'autoRenew': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.info(
          'Subscription cancelled for user: $userId - will expire at: ${subscriptionEndDate?.toDate()}');
      return true;
    } catch (e) {
      _logger.severe('Error cancelling subscription: $e');
      return false;
    }
  }

  /// Reactivate a cancelled subscription (if not expired)
  static Future<bool> reactivateSubscription(String userId) async {
    try {
      _logger.info('Reactivating subscription for user: $userId');

      // Update subscription status back to active and remove cancellation fields
      await _firestore.collection('subscriptions').doc(userId).update({
        'status': 'active',
        'cancelledAt': FieldValue.delete(),
        'willExpireAt': FieldValue.delete(),
        'autoRenew': true,
      });

      _logger.info('Subscription reactivated successfully for user: $userId');
      return true;
    } catch (e) {
      _logger.severe('Error reactivating subscription: $e');
      return false;
    }
  }

  /// Renew monthly subscription
  static Future<bool> renewMonthlySubscription(
    String userId, {
    required String paymentMethod,
    String? transactionId,
  }) async {
    try {
      final now = AppConfig.currentDateTime;
      final nextBillingDate = DateTime(now.year, now.month + 1, now.day);

      await _firestore.collection('subscriptions').doc(userId).update({
        'lastPaymentDate': FieldValue.serverTimestamp(),
        'nextBillingDate': Timestamp.fromDate(nextBillingDate),
        'subscriptionEndDate': Timestamp.fromDate(nextBillingDate),
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Record payment transaction
      await _recordPaymentTransaction(
          userId, monthlyPrice, transactionId, 'monthly_renewal');

      _logger.info('Monthly subscription renewed for user: $userId');
      return true;
    } catch (e) {
      _logger.severe('Error renewing monthly subscription: $e');
      return false;
    }
  }

  /// Check if email has been used for trial before
  static Future<bool> hasEmailUsedTrial(String email) async {
    try {
      final existingTrials = await _firestore
          .collection('trial_history')
          .where('email', isEqualTo: email)
          .get();

      return existingTrials.docs.isNotEmpty;
    } catch (e) {
      _logger.severe('Error checking trial history: $e');
      return false;
    }
  }

  /// Get subscription statistics (for admin)
  static Future<Map<String, int>> getSubscriptionStats() async {
    try {
      final subscriptions = await _firestore.collection('subscriptions').get();

      int trialUsers = 0;
      int activeSubscribers = 0;
      int expiredUsers = 0;
      int cancelledUsers = 0;

      for (var doc in subscriptions.docs) {
        final subscription = doc.data();
        final status = subscription['status'] as String?;

        switch (status) {
          case 'trial':
            trialUsers++;
            break;
          case 'active':
            activeSubscribers++;
            break;
          case 'expired':
          case 'trialExpired':
            expiredUsers++;
            break;
          case 'cancelled':
            cancelledUsers++;
            break;
        }
      }

      return {
        'trial': trialUsers,
        'active': activeSubscribers,
        'expired': expiredUsers,
        'cancelled': cancelledUsers,
      };
    } catch (e) {
      _logger.severe('Error getting subscription stats: $e');
      return {};
    }
  }

  // ========================= IN-APP PURCHASE METHODS =========================

  /// Purchase subscription using in-app purchase
  static Future<bool> purchaseSubscriptionWithInAppPurchase() async {
    try {
      _logger.info('Initiating in-app purchase subscription');
      
      // Load available products
      final products = await InAppPurchaseService.loadProducts();
      if (products.isEmpty) {
        _logger.warning('No products available for purchase');
        return false;
      }

      // Find the monthly subscription product
      final monthlyProduct = products.firstWhere(
        (product) => product.id == InAppPurchaseService.monthlySubscriptionProductId,
        orElse: () => throw Exception('Monthly subscription product not found'),
      );

      // Initiate purchase
      await InAppPurchaseService.purchaseProduct(monthlyProduct);
      return true;
    } catch (e) {
      _logger.severe('Error purchasing subscription with in-app purchase: $e');
      return false;
    }
  }

  /// Restore previous purchases
  static Future<bool> restoreInAppPurchases() async {
    try {
      _logger.info('Restoring in-app purchases');
      await InAppPurchaseService.restorePurchases();
      return true;
    } catch (e) {
      _logger.severe('Error restoring in-app purchases: $e');
      return false;
    }
  }

  /// Check subscription status including in-app purchases
  static Future<SubscriptionStatus> getSubscriptionStatusWithInAppPurchase(String userId) async {
    try {
      // First check using existing logic
      final currentStatus = await getSubscriptionStatus(userId);
      
      // If already active or trial, return current status
      if (currentStatus == SubscriptionStatus.active || 
          currentStatus == SubscriptionStatus.trial ||
          currentStatus == SubscriptionStatus.cancelled) {
        return currentStatus;
      }

      // Check if user has active in-app purchase subscription
      final hasInAppSubscription = await InAppPurchaseService.hasActiveSubscription();
      if (hasInAppSubscription) {
        return SubscriptionStatus.active;
      }

      return currentStatus;
    } catch (e) {
      _logger.severe('Error getting subscription status with in-app purchase: $e');
      return SubscriptionStatus.expired;
    }
  }

  /// Get available subscription products for in-app purchase
  static Future<List<ProductDetails>> getAvailableProducts() async {
    try {
      return await InAppPurchaseService.loadProducts();
    } catch (e) {
      _logger.severe('Error getting available products: $e');
      return [];
    }
  }

  /// Handle in-app purchase completion (called by InAppPurchaseService)
  static Future<void> handleInAppPurchaseCompletion(String userId, String productId, String purchaseId) async {
    try {
      _logger.info('Handling in-app purchase completion for user: $userId');
      
      // Activate subscription based on the purchased product
      if (productId == InAppPurchaseService.monthlySubscriptionProductId) {
        final now = AppConfig.currentDateTime;
        final expiryDate = now.add(const Duration(days: 30));

        await _firestore.collection('subscriptions').doc(userId).set({
          'userId': userId,
          'status': SubscriptionStatus.active.name,
          'plan': 'monthly',
          'amount': monthlyPrice,
          'startDate': now,
          'subscriptionEndDate': expiryDate,
          'lastPayment': {
            'purchaseId': purchaseId,
            'productId': productId,
            'date': now,
            'status': 'succeeded',
            'source': 'in_app_purchase',
          },
          'paymentMethod': 'in_app_purchase',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        _logger.info('Subscription activated via in-app purchase for user: $userId');
      }
    } catch (e) {
      _logger.severe('Error handling in-app purchase completion: $e');
    }
  }

  /// Check if user has access to premium features (including in-app purchases)
  static Future<bool> hasActiveSubscriptionWithInAppPurchase(String userId) async {
    try {
      // Check existing subscription status first
      final hasSubscription = await hasActiveSubscription(userId);
      if (hasSubscription) return true;

      // Check in-app purchase subscription
      return await InAppPurchaseService.hasActiveSubscription();
    } catch (e) {
      _logger.severe('Error checking active subscription with in-app purchase: $e');
      return false;
    }
  }
}
