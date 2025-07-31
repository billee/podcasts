# Design Document

## Overview

The daily token limits feature will implement a comprehensive usage tracking system that monitors input tokens for trial and subscribed users. The system will enforce daily limits, provide real-time usage feedback, store historical data for admin reporting, and reset limits daily. The feature will be configurable through the AppConfig class and integrate with existing chat and admin systems.

## Architecture

The solution will consist of several key components:

1. **Configuration Management**: Extend AppConfig with token limit settings
2. **Token Tracking Service**: Core service for monitoring and enforcing limits
3. **Database Schema**: Firestore collections for daily and historical usage
4. **UI Components**: Usage indicators and limit notifications
5. **Admin Dashboard Integration**: Monthly usage reporting and analytics
6. **Daily Reset Mechanism**: Automated daily limit resets

## Components and Interfaces

### AppConfig Enhancement

**New Configuration Properties in config.dart:**
```dart
class AppConfig {
  // Token limit configurations - Owner can configure these values directly
  static const int trialUserDailyTokenLimit = 10000;        // Owner configures this value
  static const int subscribedUserDailyTokenLimit = 50000;   // Owner configures this value
  static const bool tokenLimitsEnabled = true;              // Owner can enable/disable feature
  
  // Optional: Add validation method
  static void validateTokenLimits() {
    assert(trialUserDailyTokenLimit > 0, 'Trial token limit must be positive');
    assert(subscribedUserDailyTokenLimit > 0, 'Subscribed token limit must be positive');
    assert(subscribedUserDailyTokenLimit >= trialUserDailyTokenLimit, 
           'Subscribed limit should be >= trial limit');
  }
}
```

**Owner Configuration Process:**
1. Open `lib/core/config.dart`
2. Modify the const values:
   - `trialUserDailyTokenLimit = 15000;` (increase trial limit)
   - `subscribedUserDailyTokenLimit = 75000;` (increase subscribed limit)
3. Save file and restart app - changes take effect immediately

### TokenLimitService

**Core Service Interface:**
```dart
class TokenLimitService {
  Future<bool> canUserChat(String userId);
  Future<int> getRemainingTokens(String userId);
  Future<void> recordTokenUsage(String userId, int tokenCount);
  Future<TokenUsageInfo> getUserUsageInfo(String userId);
  Future<void> resetDailyLimits();
  Stream<TokenUsageInfo> watchUserUsage(String userId);
}
```

### Database Schema

**Daily Usage Collection (`daily_token_usage`):**
```dart
{
  'userId': String,
  'date': String, // YYYY-MM-DD format
  'tokensUsed': int,
  'tokenLimit': int,
  'userType': String, // 'trial' or 'subscribed'
  'lastUpdated': Timestamp,
  'resetAt': Timestamp
}
```

**Historical Usage Collection (`token_usage_history`):**
```dart
{
  'userId': String,
  'year': int,
  'month': int,
  'dailyUsage': Map<String, int>, // date -> tokens used
  'totalMonthlyTokens': int,
  'averageDailyUsage': double,
  'peakUsageDate': String,
  'userType': String
}
```

### UI Components

**TokenUsageWidget:**
- Real-time token counter
- Progress bar showing usage percentage
- Warning messages for low tokens
- Limit reached notifications

**ChatLimitDialog:**
- Informative dialog when limit is reached
- Countdown to next reset
- Upgrade prompts for trial users

## Data Models

### TokenUsageInfo Model

```dart
class TokenUsageInfo {
  final String userId;
  final int tokensUsed;
  final int tokenLimit;
  final int remainingTokens;
  final DateTime resetTime;
  final String userType;
  final double usagePercentage;
  final bool isLimitReached;
  final bool isWarningThreshold; // < 10% remaining
}
```

### MonthlyUsageReport Model

```dart
class MonthlyUsageReport {
  final String userId;
  final int year;
  final int month;
  final int totalTokens;
  final double averageDaily;
  final int peakDayUsage;
  final String peakDate;
  final Map<String, int> dailyBreakdown;
  final String userType;
}
```

## Error Handling

### Token Calculation Errors
- **Fallback Strategy**: Use conservative estimates if token counting fails
- **Logging**: Log all token calculation errors for debugging
- **User Experience**: Never block users due to calculation errors

### Database Failures
- **Offline Support**: Cache usage data locally when Firestore is unavailable
- **Sync Strategy**: Sync cached data when connection is restored
- **Graceful Degradation**: Allow limited functionality during outages

### Configuration Errors
- **Default Values**: Use sensible defaults if config values are invalid
- **Validation**: Validate config values on app startup
- **Admin Alerts**: Notify admins of configuration issues

## Testing Strategy

### Unit Tests
- Test token limit calculations with various user types
- Test daily reset logic with different timezones
- Test usage tracking accuracy with concurrent requests
- Test configuration loading and validation

### Integration Tests
- Test complete chat flow with token limits
- Test database operations for usage tracking
- Test admin dashboard data retrieval
- Test daily reset automation

### Performance Tests
- Test token tracking performance with high message volume
- Test database query performance for historical data
- Test real-time usage updates with multiple concurrent users

## Implementation Plan

### Phase 1: Core Infrastructure
1. Extend AppConfig with token limit configurations
2. Create TokenLimitService with basic tracking functionality
3. Design and implement Firestore database schema
4. Add token counting integration to chat service

### Phase 2: User Experience
1. Create TokenUsageWidget for real-time usage display
2. Implement ChatLimitDialog for limit notifications
3. Add usage warnings and notifications
4. Integrate with existing chat UI components

### Phase 3: Admin Features
1. Create monthly usage aggregation system
2. Build admin dashboard usage reporting
3. Implement historical data visualization
4. Add user usage analytics and insights

### Phase 4: Automation & Optimization
1. Implement automated daily reset system
2. Add offline support and data synchronization
3. Optimize database queries for performance
4. Add comprehensive monitoring and alerting

## Design Decisions

### Why Direct Configuration in config.dart?
- **Simple Management**: Owner can easily modify limits by editing one file
- **No Environment Setup**: No need to manage .env files or environment variables
- **Immediate Changes**: Compile-time constants ensure changes take effect on restart
- **Version Control**: Configuration changes are tracked in source control
- **Validation**: Can add compile-time validation for configuration values

### Why Daily Limits Instead of Monthly?
- **Predictable Costs**: Daily limits provide more predictable cost management
- **User Experience**: Users get a fresh start each day rather than being blocked for weeks
- **Simpler Reset Logic**: Daily resets are easier to implement and understand

### Why Track Input Tokens Only?
- **Cost Control**: Input tokens are what users control and what drives API costs
- **User Understanding**: Users can see direct correlation between their messages and usage
- **Simpler Implementation**: Avoids complexity of tracking AI response variations

### Why Separate Daily and Historical Collections?
- **Performance**: Daily collection optimized for real-time queries
- **Scalability**: Historical collection optimized for reporting and analytics
- **Data Lifecycle**: Different retention and archival policies for each collection

### Why Real-time Usage Updates?
- **User Awareness**: Users can manage their usage throughout the day
- **Prevents Overuse**: Early warnings help users avoid hitting limits
- **Better Experience**: Transparent usage tracking builds user trust