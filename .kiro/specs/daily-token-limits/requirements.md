# Requirements Document

## Introduction

This feature implements daily token limits for trial and subscribed users to manage usage and costs. Users will have a configurable daily limit on input tokens they can use for chat interactions. Once the limit is reached, users must wait until the next day to continue chatting. The system will provide clear feedback about remaining tokens and reset limits daily.

## Requirements

### Requirement 1

**User Story:** As a trial user, I want to have a daily limit on my chat usage, so that the service can manage costs while still allowing me to experience the product.

#### Acceptance Criteria

1. WHEN a trial user starts chatting THEN the system SHALL track their daily input token usage
2. WHEN a trial user reaches their daily token limit THEN the system SHALL prevent further chat interactions
3. WHEN a trial user reaches their limit THEN the system SHALL display a message explaining the limit and when it resets
4. WHEN the next day begins THEN the system SHALL reset the trial user's token count to zero
5. WHEN a trial user has tokens remaining THEN the system SHALL display their remaining token count
6. WHEN the daily reset occurs THEN unused tokens SHALL NOT be carried over to the next day
7. WHEN tracking usage THEN the system SHALL report accumulated daily usage to the Admin dashboard for monitoring

### Requirement 2

**User Story:** As a subscribed user, I want to have a higher daily token limit than trial users, so that I can have more extensive conversations as a paying customer.

#### Acceptance Criteria

1. WHEN a subscribed user starts chatting THEN the system SHALL track their daily input token usage with a higher limit than trial users
2. WHEN a subscribed user reaches their daily token limit THEN the system SHALL prevent further chat interactions
3. WHEN a subscribed user reaches their limit THEN the system SHALL display a message explaining the limit and when it resets
4. WHEN the next day begins THEN the system SHALL reset the subscribed user's token count to zero
5. WHEN a subscribed user has tokens remaining THEN the system SHALL display their remaining token count
6. WHEN the daily reset occurs THEN unused tokens SHALL NOT be carried over to the next day
7. WHEN tracking usage THEN the system SHALL report accumulated daily usage to the Admin dashboard for monitoring

### Requirement 3

**User Story:** As an app owner, I want to configure the daily token limits for trial and subscribed users, so that I can adjust usage limits based on business needs and costs.

#### Acceptance Criteria

1. WHEN configuring the app THEN the system SHALL provide a config setting for trial user daily token limit
2. WHEN configuring the app THEN the system SHALL provide a config setting for subscribed user daily token limit
3. WHEN the config is updated THEN the system SHALL apply the new limits immediately
4. WHEN no config is provided THEN the system SHALL show error message
5. WHEN the config values are invalid THEN the system SHALL show a warning

### Requirement 4

**User Story:** As a user, I want to see my current token usage and remaining tokens, so that I can manage my daily chat usage effectively.

#### Acceptance Criteria

1. WHEN a user opens the chat interface THEN the system SHALL display their remaining daily tokens underneath the chatbox with very small font words.
2. WHEN a user sends a message THEN the system SHALL update their remaining token count in real-time
3. WHEN a user has less than 10% tokens remaining THEN the system SHALL display a warning message
4. WHEN a user reaches their limit THEN the system SHALL display the exact time when tokens will reset
5. WHEN tokens reset THEN the system SHALL notify the user that they can resume chatting

### Requirement 5

**User Story:** As a developer, I want the token tracking system to be accurate and persistent, so that users cannot bypass limits by restarting the app or logging out.

#### Acceptance Criteria

1. WHEN tracking token usage THEN the system SHALL store usage data in Firestore
2. WHEN a user logs out and back in THEN the system SHALL maintain their current daily usage count
3. WHEN the app is restarted THEN the system SHALL load the current daily usage from the database
4. WHEN calculating token usage THEN the system SHALL count total tokens sent to and received from OpenAI API (input tokens including system prompts, conversation history, user message + output tokens from LLM response)
5. WHEN the daily reset occurs THEN the system SHALL update the database with the new reset timestamp

### Requirement 6

**User Story:** As an app owner, I want to view monthly token usage history for each user in the admin dashboard, so that I can analyze usage patterns and make informed business decisions.

#### Acceptance Criteria

1. WHEN viewing the admin dashboard THEN the system SHALL display monthly token usage for each user
2. WHEN a user completes a day of usage THEN the system SHALL store their daily usage in a cumulative field of the users database
3. WHEN viewing user details in admin THEN the system SHALL show monthly token usage for each user from the historical token usage database
4. WHEN generating reports THEN the system SHALL provide monthly usage totals for all users
5. WHEN storing usage history THEN the system SHALL maintain records for at least 12 months
6. WHEN calculating monthly usage THEN the system SHALL aggregate daily usage records for accurate totals