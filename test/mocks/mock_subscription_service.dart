import 'package:kapwa_companion_basic/services/subscription_service.dart';

/// Mock implementation of SubscriptionService for testing
class MockSubscriptionService {
  static final Map<String, String> _userSubscriptionStatuses = {};
  static final Map<String, Map<String, dynamic>> _userSubscriptionDetails = {};

  /// Setup default mocks for testing
  static void setupMocks() {
    // Clear any existing mocks
    clearMocks();
    
    // Set default subscription statuses for common test users
    _userSubscriptionStatuses['trial_user'] = 'trial';
    _userSubscriptionStatuses['subscribed_user'] = 'subscribed';
    _userSubscriptionStatuses['expired_user'] = 'expired';
    _userSubscriptionStatuses['cancelled_user'] = 'cancelled';
  }

  /// Clear all mocks
  static void clearMocks() {
    _userSubscriptionStatuses.clear();
    _userSubscriptionDetails.clear();
  }

  /// Set subscription status for a specific user
  static void setUserSubscriptionStatus(String userId, String status) {
    _userSubscriptionStatuses[userId] = status;
  }

  /// Set subscription details for a specific user
  static void setUserSubscriptionDetails(String userId, Map<String, dynamic> details) {
    _userSubscriptionDetails[userId] = details;
  }

  /// Mock implementation of getSubscriptionStatus
  static Future<SubscriptionStatus> getSubscriptionStatus(String userId) async {
    final status = _userSubscriptionStatuses[userId] ?? 'trial';
    
    switch (status) {
      case 'active':
      case 'subscribed':
        return SubscriptionStatus.active;
      case 'trial':
        return SubscriptionStatus.trial;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'trialExpired':
        return SubscriptionStatus.trialExpired;
      default:
        return SubscriptionStatus.trial;
    }
  }

  /// Mock implementation of getSubscriptionDetails
  static Future<Map<String, dynamic>?> getSubscriptionDetails(String userId) async {
    return _userSubscriptionDetails[userId];
  }

  /// Mock implementation of hasActiveSubscription
  static Future<bool> hasActiveSubscription(String userId) async {
    final status = await getSubscriptionStatus(userId);
    return status == SubscriptionStatus.trial || status == SubscriptionStatus.active;
  }
}