import '../utils/date_test_helper.dart';
import '../services/token_limit_service.dart';
import '../services/subscription_service.dart';

/// Example of how to use the date testing system
/// This shows how to test different user status scenarios by manipulating dates
class DateTestingExample {
  
  /// Example: Test trial expiration
  static Future<void> testTrialExpiration() async {
    print('=== Testing Trial Expiration ===');
    
    // Set date to start of trial (e.g., August 8, 2025)
    DateTestHelper.setTestDate(DateTime(2025, 8, 8));
    print('Current date: ${DateTestHelper.getCurrentDateString()}');
    
    // User starts trial - check their status
    final userId = 'test_user_123';
    var status = await SubscriptionService.getUserSubscriptionStatus(userId);
    print('Initial status: $status');
    
    // Advance 6 days (trial should still be active)
    DateTestHelper.advanceDays(6);
    print('After 6 days: ${DateTestHelper.getCurrentDateString()}');
    status = await SubscriptionService.getUserSubscriptionStatus(userId);
    print('Status after 6 days: $status');
    
    // Advance 2 more days (trial should expire)
    DateTestHelper.advanceDays(2);
    print('After 8 days total: ${DateTestHelper.getCurrentDateString()}');
    status = await SubscriptionService.getUserSubscriptionStatus(userId);
    print('Status after trial expires: $status');
    
    // Reset to real time
    DateTestHelper.useRealTime();
    print('Reset to real time: ${DateTestHelper.getCurrentDateString()}');
  }
  
  /// Example: Test daily token reset
  static Future<void> testDailyTokenReset() async {
    print('=== Testing Daily Token Reset ===');
    
    // Set date to specific time (e.g., 11 PM on August 8)
    DateTestHelper.setTestDate(DateTime(2025, 8, 8, 23, 0));
    print('Current date: ${DateTestHelper.getCurrentDateString()}');
    
    final userId = 'test_user_456';
    
    // Use some tokens
    await TokenLimitService.recordTokenUsage(userId, 5000);
    var usage = await TokenLimitService.getUserUsageInfo(userId);
    print('Tokens used: ${usage.tokensUsed}/${usage.tokenLimit}');
    
    // Advance 2 hours (should trigger daily reset at midnight)
    DateTestHelper.advanceHours(2);
    print('After 2 hours: ${DateTestHelper.getCurrentDateString()}');
    
    // Check if tokens reset
    usage = await TokenLimitService.getUserUsageInfo(userId);
    print('Tokens after reset: ${usage.tokensUsed}/${usage.tokenLimit}');
    
    // Reset to real time
    DateTestHelper.useRealTime();
  }
  
  /// Example: Test subscription renewal
  static Future<void> testSubscriptionRenewal() async {
    print('=== Testing Subscription Renewal ===');
    
    // Set date to near end of subscription period
    DateTestHelper.setTestDate(DateTime(2025, 8, 28)); // 3 days before month end
    print('Current date: ${DateTestHelper.getCurrentDateString()}');
    
    final userId = 'test_subscriber_789';
    var details = await SubscriptionService.getUserSubscriptionDetails(userId);
    print('Subscription details: $details');
    
    // Advance to renewal date
    DateTestHelper.advanceDays(5);
    print('After renewal: ${DateTestHelper.getCurrentDateString()}');
    
    details = await SubscriptionService.getUserSubscriptionDetails(userId);
    print('Details after renewal: $details');
    
    // Reset to real time
    DateTestHelper.useRealTime();
  }
}