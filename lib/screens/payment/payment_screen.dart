import 'package:flutter/material.dart';
import 'dart:io';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:kapwa_companion_basic/services/in_app_purchase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/core/config.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final Logger _logger = Logger('PaymentScreen');
  bool _isProcessing = false;
  List<ProductDetails> _products = [];
  bool _inAppPurchaseAvailable = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _initializeInAppPurchase();
  }
  
  Future<void> _initializeInAppPurchase() async {
    try {
      final available = await InAppPurchaseService.initialize();
      if (available) {
        final products = await InAppPurchaseService.loadProducts();
        setState(() {
          _inAppPurchaseAvailable = true;
          _products = products;
        });
        
        // Listen to purchase updates
        InAppPurchaseService.purchaseResultStream.listen(_handlePurchaseUpdate);
      }
    } catch (e) {
      _logger.warning('Error initializing in-app purchase: $e');
    }
  }
  
  void _handlePurchaseUpdate(InAppPurchaseResult result) {
    if (!mounted) return;
    
    setState(() {
      _isProcessing = false;
    });
    
    switch (result.status) {
      case InAppPurchaseStatus.purchased:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription activated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
        
      case InAppPurchaseStatus.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
        break;
        
      case InAppPurchaseStatus.canceled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
        
      case InAppPurchaseStatus.pending:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase is being processed...'),
            backgroundColor: Colors.blue,
          ),
        );
        break;
        
      default:
        break;
    }
  }

  Future<void> _processInAppPurchase() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      _logger.info('🛒 PAYMENT FLOW: Starting In-App Purchase process');
      _logger.info('🛒 PAYMENT FLOW: Using SubscriptionService.purchaseSubscriptionWithInAppPurchase()');
      print('🛒 DEBUG: Payment button clicked - using IAP flow');
      print('🛒 DEBUG: Available products: ${_products.length}');
      
      final success = await SubscriptionService.purchaseSubscriptionWithInAppPurchase();
      
      _logger.info('🛒 PAYMENT FLOW: IAP initiation result: $success');
      print('🛒 DEBUG: IAP purchase initiation success: $success');
      
      if (!success) {
        setState(() {
          _isProcessing = false;
        });
        
        _logger.warning('🛒 PAYMENT FLOW: IAP initiation failed');
        print('🛒 DEBUG: IAP purchase failed to initiate');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to initiate in-app purchase. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        _logger.info('🛒 PAYMENT FLOW: IAP initiated successfully, waiting for platform response');
        print('🛒 DEBUG: IAP initiated - waiting for platform store response');
      }
      // Note: _isProcessing is set to false in _handlePurchaseUpdate when the purchase completes
    } catch (e) {
      _logger.severe('🛒 PAYMENT FLOW: Error in IAP process: $e');
      print('🛒 DEBUG: Exception in IAP flow: $e');
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing in-app purchase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      _logger.info('Restoring purchases');
      await SubscriptionService.restoreInAppPurchases();
      
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored. Check your subscription status.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      _logger.severe('Error restoring purchases: $e');
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring purchases: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isProcessing) {
          return false; // Prevent going back while processing payment
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[850],
        appBar: AppBar(
          title: Text(Platform.isIOS ? 'App Store Purchase' : 'Google Play Purchase'),
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
          actions: [
            // Restore purchases button
            IconButton(
              icon: const Icon(Icons.restore),
              onPressed: _isProcessing ? null : _restorePurchases,
              tooltip: 'Restore Purchases',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
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
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.diamond,
                              color: Colors.blue[400],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Premium Monthly',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              AppConfig.formattedMonthlyPrice,
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
                        const SizedBox(height: 12),
                        Text(
                          'Unlock premium features including unlimited AI chat, stories, and podcast content.',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // In-app purchase status
                if (!_inAppPurchaseAvailable)
                  Card(
                    color: Colors.red[900]?.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[400],
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'In-App Purchases Unavailable',
                            style: TextStyle(
                              color: Colors.red[400],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'In-app purchases are not available on this device. Please try again later or contact support.',
                            style: TextStyle(
                              color: Colors.red[300],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_inAppPurchaseAvailable) ...[
                  // Payment method card
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
                                Platform.isIOS ? Icons.phone_iphone : Icons.phone_android,
                                color: Colors.green[400],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  Platform.isIOS ? 'App Store' : 'Google Play Store',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your subscription will be managed through ${Platform.isIOS ? 'the App Store' : 'Google Play Store'}. You can cancel anytime in your account settings.',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[900]?.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green[400]!.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.security,
                                  color: Colors.green[400],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Secure payment processing by ${Platform.isIOS ? 'Apple' : 'Google'}',
                                    style: TextStyle(
                                      color: Colors.green[400],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Purchase button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_isProcessing || !_inAppPurchaseAvailable) ? null : _processInAppPurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isProcessing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Processing...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Subscribe for ${AppConfig.formattedMonthlyPrice}/month',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // Restore purchases button
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _isProcessing ? null : _restorePurchases,
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text(
                      'Restore Previous Purchases',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[400],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Terms notice
                Text(
                  'By subscribing, you agree to our Terms of Service and Privacy Policy. Subscription automatically renews unless cancelled.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
