import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import '../core/config.dart';

enum InAppPurchaseStatus {
  pending,
  purchased,
  restored,
  error,
  canceled,
}

class InAppPurchaseResult {
  final InAppPurchaseStatus status;
  final String? error;
  final PurchaseDetails? purchaseDetails;
  final String? transactionId;

  InAppPurchaseResult({
    required this.status,
    this.error,
    this.purchaseDetails,
    this.transactionId,
  });
}

class InAppPurchaseService {
  static final Logger _logger = Logger('InAppPurchaseService');
  static final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static FirebaseAuth _auth = FirebaseAuth.instance;
  
  static late StreamSubscription<List<PurchaseDetails>> _subscription;
  static final StreamController<InAppPurchaseResult> _purchaseController = 
      StreamController<InAppPurchaseResult>.broadcast();

  // Product IDs
  static const String monthlySubscriptionProductId = 'monthly_premium_subscription';
  static const Set<String> _productIds = {monthlySubscriptionProductId};

  // For testing purposes
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }

  static void setAuthInstance(FirebaseAuth auth) {
    _auth = auth;
  }

  /// Initialize the in-app purchase service
  static Future<bool> initialize() async {
    try {
      _logger.info('Initializing InAppPurchaseService');
      
      // Check if in-app purchases are available
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        _logger.warning('In-app purchases not available on this device');
        return false;
      }

      // Set up purchase listener
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdated,
        onDone: () => _subscription.cancel(),
        onError: (error) => _logger.severe('Purchase stream error: $error'),
      );

      // iOS specific setup
      if (Platform.isIOS) {
        var iosPlatformAddition = _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        await iosPlatformAddition.setDelegate(IOSPaymentQueueDelegate());
      }

      _logger.info('InAppPurchaseService initialized successfully');
      return true;
    } catch (e) {
      _logger.severe('Error initializing InAppPurchaseService: $e');
      return false;
    }
  }

  /// Get stream of purchase results
  static Stream<InAppPurchaseResult> get purchaseResultStream => _purchaseController.stream;

  /// Load available products
  static Future<List<ProductDetails>> loadProducts() async {
    try {
      _logger.info('Loading products: $_productIds');
      
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_productIds);
      
      if (response.error != null) {
        _logger.severe('Error loading products: ${response.error}');
        return [];
      }

      if (response.notFoundIDs.isNotEmpty) {
        _logger.warning('Products not found: ${response.notFoundIDs}');
      }

      _logger.info('Loaded ${response.productDetails.length} products');
      return response.productDetails;
    } catch (e) {
      _logger.severe('Error loading products: $e');
      return [];
    }
  }

  /// Purchase a product
  static Future<void> purchaseProduct(ProductDetails productDetails) async {
    try {
      _logger.info('🛒 IAP SERVICE: Initiating purchase for product: ${productDetails.id}');
      print('🛒 DEBUG: InAppPurchaseService.purchaseProduct called');
      print('🛒 DEBUG: Product ID: ${productDetails.id}');
      print('🛒 DEBUG: Product price: ${productDetails.price}');
      
      final user = _auth.currentUser;
      if (user == null) {
        _logger.warning('🛒 IAP SERVICE: User not logged in, cannot purchase');
        print('🛒 DEBUG: User authentication failed');
        _purchaseController.add(InAppPurchaseResult(
          status: InAppPurchaseStatus.error,
          error: 'User must be logged in to make purchases',
        ));
        return;
      }

      _logger.info('🛒 IAP SERVICE: User authenticated: ${user.uid}');
      print('🛒 DEBUG: User ID: ${user.uid}');

      PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: user.uid,
      );

      bool success;
      if (productDetails.id == monthlySubscriptionProductId) {
        _logger.info('🛒 IAP SERVICE: Calling buyNonConsumable for subscription');
        print('🛒 DEBUG: Using buyNonConsumable for subscription product');
        success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        _logger.info('🛒 IAP SERVICE: Calling buyConsumable for regular product');
        print('🛒 DEBUG: Using buyConsumable for regular product');
        success = await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      }

      _logger.info('🛒 IAP SERVICE: Purchase initiation result: $success');
      print('🛒 DEBUG: Purchase initiation success: $success');

      if (!success) {
        _logger.warning('🛒 IAP SERVICE: Failed to initiate purchase');
        print('🛒 DEBUG: Platform purchase initiation failed');
        _purchaseController.add(InAppPurchaseResult(
          status: InAppPurchaseStatus.error,
          error: 'Failed to initiate purchase',
        ));
      } else {
        _logger.info('🛒 IAP SERVICE: Purchase initiated successfully, waiting for platform response');
        print('🛒 DEBUG: Purchase initiated - waiting for platform store response');
      }
    } catch (e) {
      _logger.severe('🛒 IAP SERVICE: Error purchasing product: $e');
      print('🛒 DEBUG: Exception in purchaseProduct: $e');
      _purchaseController.add(InAppPurchaseResult(
        status: InAppPurchaseStatus.error,
        error: 'Purchase failed: $e',
      ));
    }
  }

  /// Restore previous purchases
  static Future<void> restorePurchases() async {
    try {
      _logger.info('Restoring purchases');
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      _logger.severe('Error restoring purchases: $e');
      _purchaseController.add(InAppPurchaseResult(
        status: InAppPurchaseStatus.error,
        error: 'Failed to restore purchases: $e',
      ));
    }
  }

  /// Handle purchase updates
  static void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final PurchaseDetails purchase in purchases) {
      _logger.info('Purchase update: ${purchase.productID} - ${purchase.status}');
      
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchaseController.add(InAppPurchaseResult(
            status: InAppPurchaseStatus.pending,
            purchaseDetails: purchase,
          ));
          break;
          
        case PurchaseStatus.purchased:
          _handlePurchaseCompleted(purchase);
          break;
          
        case PurchaseStatus.restored:
          _handlePurchaseRestored(purchase);
          break;
          
        case PurchaseStatus.error:
          _purchaseController.add(InAppPurchaseResult(
            status: InAppPurchaseStatus.error,
            error: purchase.error?.message ?? 'Purchase failed',
            purchaseDetails: purchase,
          ));
          break;
          
        case PurchaseStatus.canceled:
          _purchaseController.add(InAppPurchaseResult(
            status: InAppPurchaseStatus.canceled,
            purchaseDetails: purchase,
          ));
          break;
      }

      // Complete the purchase if it's pending
      if (purchase.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  /// Handle completed purchase
  static Future<void> _handlePurchaseCompleted(PurchaseDetails purchase) async {
    try {
      _logger.info('Handling completed purchase: ${purchase.productID}');
      
      // Verify purchase with server (important for security)
      final bool verified = await _verifyPurchase(purchase);
      if (!verified) {
        _purchaseController.add(InAppPurchaseResult(
          status: InAppPurchaseStatus.error,
          error: 'Purchase verification failed',
          purchaseDetails: purchase,
        ));
        return;
      }

      // Record purchase in Firestore
      await _recordPurchase(purchase);

      // Activate subscription if it's a subscription product
      if (purchase.productID == monthlySubscriptionProductId) {
        await _activateSubscription(purchase);
      }

      _purchaseController.add(InAppPurchaseResult(
        status: InAppPurchaseStatus.purchased,
        purchaseDetails: purchase,
        transactionId: purchase.purchaseID,
      ));
    } catch (e) {
      _logger.severe('Error handling completed purchase: $e');
      _purchaseController.add(InAppPurchaseResult(
        status: InAppPurchaseStatus.error,
        error: 'Failed to process purchase: $e',
        purchaseDetails: purchase,
      ));
    }
  }

  /// Handle restored purchase
  static Future<void> _handlePurchaseRestored(PurchaseDetails purchase) async {
    try {
      _logger.info('Handling restored purchase: ${purchase.productID}');
      
      // Verify and reactivate subscription if needed
      if (purchase.productID == monthlySubscriptionProductId) {
        await _activateSubscription(purchase);
      }

      _purchaseController.add(InAppPurchaseResult(
        status: InAppPurchaseStatus.restored,
        purchaseDetails: purchase,
        transactionId: purchase.purchaseID,
      ));
    } catch (e) {
      _logger.severe('Error handling restored purchase: $e');
      _purchaseController.add(InAppPurchaseResult(
        status: InAppPurchaseStatus.error,
        error: 'Failed to restore purchase: $e',
        purchaseDetails: purchase,
      ));
    }
  }

  /// Verify purchase with receipt validation
  static Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    try {
      // In a production app, you should verify the purchase receipt with your server
      // This is crucial for security to prevent fraud
      _logger.info('Verifying purchase: ${purchase.purchaseID}');
      
      // For now, we'll do basic validation
      if (purchase.purchaseID == null || purchase.purchaseID!.isEmpty) {
        return false;
      }

      // TODO: Implement server-side receipt verification
      // This should validate the receipt with Apple App Store or Google Play Store
      
      return true;
    } catch (e) {
      _logger.severe('Error verifying purchase: $e');
      return false;
    }
  }

  /// Record purchase in Firestore
  static Future<void> _recordPurchase(PurchaseDetails purchase) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('in_app_purchases').doc(purchase.purchaseID).set({
        'userId': user.uid,
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'transactionDate': purchase.transactionDate,
        'verificationData': {
          'localVerificationData': purchase.verificationData.localVerificationData,
          'serverVerificationData': purchase.verificationData.serverVerificationData,
          'source': purchase.verificationData.source,
        },
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _logger.info('Purchase recorded in Firestore: ${purchase.purchaseID}');
    } catch (e) {
      _logger.severe('Error recording purchase: $e');
    }
  }

  /// Activate subscription after purchase
  static Future<void> _activateSubscription(PurchaseDetails purchase) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final now = AppConfig.currentDateTime;
      final expiryDate = now.add(const Duration(days: 30)); // 30-day subscription

      await _firestore.collection('subscriptions').doc(user.uid).set({
        'userId': user.uid,
        'status': 'active',
        'plan': 'monthly',
        'purchaseId': purchase.purchaseID,
        'productId': purchase.productID,
        'startDate': now,
        'subscriptionEndDate': expiryDate,
        'lastPayment': {
          'purchaseId': purchase.purchaseID,
          'date': now,
          'status': 'succeeded',
          'source': 'in_app_purchase'
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _logger.info('Subscription activated for user: ${user.uid}');
    } catch (e) {
      _logger.severe('Error activating subscription: $e');
    }
  }

  /// Check if user has active subscription
  static Future<bool> hasActiveSubscription() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final subscriptionDoc = await _firestore.collection('subscriptions').doc(user.uid).get();
      if (!subscriptionDoc.exists) return false;

      final subscription = subscriptionDoc.data() as Map<String, dynamic>;
      final status = subscription['status'] as String?;
      
      if (status != 'active') return false;

      final subscriptionEndDate = subscription['subscriptionEndDate'];
      if (subscriptionEndDate == null) return false;

      final endDate = (subscriptionEndDate as Timestamp).toDate();
      final now = AppConfig.currentDateTime;
      
      return now.isBefore(endDate);
    } catch (e) {
      _logger.severe('Error checking active subscription: $e');
      return false;
    }
  }

  /// Get pending purchases
  static Future<List<PurchaseDetails>> getPendingPurchases() async {
    try {
      // This is automatically handled by the purchase stream
      // but you can implement additional logic here if needed
      return [];
    } catch (e) {
      _logger.severe('Error getting pending purchases: $e');
      return [];
    }
  }

  /// Dispose resources
  static void dispose() {
    _subscription.cancel();
    _purchaseController.close();
  }
}

/// iOS Payment Queue Delegate
class IOSPaymentQueueDelegate extends SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
