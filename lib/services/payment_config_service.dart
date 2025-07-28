import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';

class PaymentConfigService {
  static final Logger _logger = Logger('PaymentConfigService');
  
  // Stripe configuration
  static String get stripePublishableKey {
    if (kDebugMode) {
      return dotenv.env['STRIPE_PUBLISHABLE_KEY_TEST'] ?? 'pk_test_default_key';
    } else {
      return dotenv.env['STRIPE_PUBLISHABLE_KEY_LIVE'] ?? '';
    }
  }

  static String get stripeSecretKey {
    if (kDebugMode) {
      return dotenv.env['STRIPE_SECRET_KEY_TEST'] ?? 'sk_test_default_key';
    } else {
      return dotenv.env['STRIPE_SECRET_KEY_LIVE'] ?? '';
    }
  }

  // PayPal configuration
  static String get paypalClientId {
    if (kDebugMode) {
      return dotenv.env['PAYPAL_CLIENT_ID_TEST'] ?? 'paypal_test_client_id';
    } else {
      return dotenv.env['PAYPAL_CLIENT_ID_LIVE'] ?? '';
    }
  }

  static String get paypalClientSecret {
    if (kDebugMode) {
      return dotenv.env['PAYPAL_CLIENT_SECRET_TEST'] ?? 'paypal_test_secret';
    } else {
      return dotenv.env['PAYPAL_CLIENT_SECRET_LIVE'] ?? '';
    }
  }

  // Google Pay configuration
  static String get googlePayMerchantId {
    return dotenv.env['GOOGLE_PAY_MERCHANT_ID'] ?? 'your_merchant_id';
  }

  // Apple Pay configuration
  static String get applePayMerchantId {
    return dotenv.env['APPLE_PAY_MERCHANT_ID'] ?? 'merchant.com.yourcompany.ofwcompanion';
  }

  // Payment environment
  static bool get isTestEnvironment => kDebugMode;

  // Backend server configuration
  static String get backendServerUrl {
    if (kDebugMode) {
      return dotenv.env['BACKEND_SERVER_URL_TEST'] ?? 'http://localhost:3000';
    } else {
      return dotenv.env['BACKEND_SERVER_URL_LIVE'] ?? 'https://your-backend-server.com';
    }
  }

  // Webhook configuration
  static String get stripeWebhookSecret {
    return dotenv.env['STRIPE_WEBHOOK_SECRET'] ?? '';
  }

  static String get paypalWebhookId {
    return dotenv.env['PAYPAL_WEBHOOK_ID'] ?? '';
  }

  /// Validate payment configuration
  static bool validateConfiguration() {
    try {
      final checks = [
        stripePublishableKey.isNotEmpty,
        paypalClientId.isNotEmpty,
        googlePayMerchantId.isNotEmpty,
        applePayMerchantId.isNotEmpty,
        backendServerUrl.isNotEmpty,
      ];

      final isValid = checks.every((check) => check);
      
      if (isValid) {
        _logger.info('Payment configuration validation passed');
      } else {
        _logger.warning('Payment configuration validation failed');
        _logger.warning('Stripe key present: ${stripePublishableKey.isNotEmpty}');
        _logger.warning('PayPal client ID present: ${paypalClientId.isNotEmpty}');
        _logger.warning('Google Pay merchant ID present: ${googlePayMerchantId.isNotEmpty}');
        _logger.warning('Apple Pay merchant ID present: ${applePayMerchantId.isNotEmpty}');
        _logger.warning('Backend server URL present: ${backendServerUrl.isNotEmpty}');
      }

      return isValid;
    } catch (e) {
      _logger.severe('Error validating payment configuration: $e');
      return false;
    }
  }

  /// Get payment configuration for debugging (without sensitive data)
  static Map<String, dynamic> getConfigurationInfo() {
    return {
      'environment': isTestEnvironment ? 'test' : 'production',
      'stripe_configured': stripePublishableKey.isNotEmpty,
      'paypal_configured': paypalClientId.isNotEmpty,
      'google_pay_configured': googlePayMerchantId.isNotEmpty,
      'apple_pay_configured': applePayMerchantId.isNotEmpty,
      'backend_configured': backendServerUrl.isNotEmpty,
    };
  }

  /// Initialize payment configuration
  static Future<void> initialize() async {
    try {
      _logger.info('Initializing payment configuration...');
      
      final isValid = validateConfiguration();
      if (!isValid) {
        _logger.warning('Payment configuration is incomplete');
      }

      final configInfo = getConfigurationInfo();
      _logger.info('Payment configuration: $configInfo');
      
      _logger.info('Payment configuration initialized');
    } catch (e) {
      _logger.severe('Error initializing payment configuration: $e');
      rethrow;
    }
  }
}