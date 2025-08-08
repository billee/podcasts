# Implementation Plan

- [x] 1. Add token limit configuration to AppConfig





  - Add const values for trial and subscribed user daily token limits in config.dart
  - Add tokenLimitsEnabled flag for feature toggle
  - Add validation method for configuration values
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 2. Create Firestore database schema for token tracking





  - Design daily_token_usage collection structure
  - Design token_usage_history collection structure for monthly reporting
  - Create Firestore security rules for token usage collections
  - Add database indexes for efficient querying
  - _Requirements: 5.1, 5.2, 5.3, 5.5, 6.2, 6.5_

- [x] 3. Implement TokenLimitService core functionality





  - Create TokenLimitService class with basic token tracking methods
  - Implement canUserChat() method to check if user can send messages
  - Implement getRemainingTokens() method for real-time usage display
  - Implement recordTokenUsage() method to track token consumption
  - Add getUserUsageInfo() method for comprehensive usage data
  - _Requirements: 1.1, 1.2, 2.1, 2.2, 5.1, 5.3_

- [x] 4. Integrate token counting with chat service





  - Add token counting logic to chat message processing
  - Integrate TokenLimitService with existing chat flow
  - Add pre-chat validation to prevent messages when limit reached
  - Ensure accurate token counting for input messages only
  - _Requirements: 1.1, 2.1, 5.4_

- [x] 5. Create daily reset mechanism





  - Implement automated daily token limit reset functionality
  - Add timezone-aware reset logic for accurate daily boundaries
  - Create background service or scheduled task for daily resets
  - Update database with reset timestamps and new daily records
  - _Requirements: 1.4, 2.4, 5.5, 1.6, 2.6_

- [x] 6. Build user interface components for token usage





  - Create TokenUsageWidget to display remaining tokens in chat interface
  - Implement real-time token counter updates during chat
  - Add warning notifications when tokens are running low (< 10%)
  - Create ChatLimitDialog for when users reach their daily limit
  - Display exact reset time when limit is reached
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 1.3, 1.5, 2.3, 2.5_

- [x] 7. Implement historical usage tracking and aggregation





  - Create monthly usage aggregation system for historical data
  - Implement data migration from daily usage to monthly history
  - Add methods to calculate monthly totals and averages
  - Store historical data for at least 12 months as specified
  - _Requirements: 6.2, 6.5, 6.6_

- [x] 8. Build admin dashboard integration for usage reporting









  - Add monthly token usage display to admin dashboard
  - Create user-specific usage history views in admin interface
  - Implement monthly usage reports with breakdown by user type
  - Add usage analytics and insights for business decision making
  - _Requirements: 1.7, 2.7, 6.1, 6.3, 6.4_

- [ ] 9. Add comprehensive error handling and offline support
  - Implement graceful handling of token calculation errors
  - Add offline token usage caching when Firestore is unavailable
  - Create data synchronization for cached usage when connection restored
  - Add logging and monitoring for token tracking system
  - _Requirements: 5.1, 5.2, 5.3_

- [ ] 10. Create comprehensive testing suite
  - Write unit tests for TokenLimitService methods and token calculations
  - Write integration tests for complete chat flow with token limits
  - Write tests for daily reset logic and timezone handling
  - Write tests for admin dashboard data retrieval and reporting
  - Test configuration validation and error handling scenarios
  - _Requirements: All requirements validation_