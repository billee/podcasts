# Integration Tests - User Management System

## Overview

This directory contains integration tests for the User Management System that verify complete end-to-end user flows. These tests ensure that all components work together correctly and that the user journey from registration to trial activation functions as expected.

## Test Coverage

### Task 7.1: End-to-End Registration and Verification Flow

**File:** `user_journey_test.dart`

**Requirements Covered:**
- **1.1**: User registration with email and password
- **1.5**: User data storage in Firestore
- **1.6**: Email verification sending
- **2.1**: Email verification integration with Firebase
- **2.4**: Automatic trial creation during first verified login
- **2.5**: User status updates throughout the flow
- **3.1**: 7-day trial period creation
- **3.2**: Trial data storage with userId to prevent abuse

### Task 7.2: Trial to Subscription Conversion Flow

**File:** `user_journey_test.dart`

**Requirements Covered:**
- **3.3**: Trial-to-paid conversion during active trial
- **4.1**: Subscription record creation
- **4.2**: Monthly billing at $3/month
- **4.3**: Premium access activation
- **6.4**: User status transition to premium subscriber

### Task 7.3: Subscription Cancellation and Expiration Flow

**File:** `user_journey_test.dart`

**Requirements Covered:**
- **5.1**: Subscription cancellation marking
- **5.2**: willExpireAt date calculation for billing period
- **5.3**: Continued premium access until expiration
- **5.4**: Premium access revocation after expiration
- **6.5**: User status update to cancelled subscriber
- **6.6**: User status update to free user after expiration

**Test Scenarios:**

#### Step 1: User Registration
- ✅ **Complete signup process**: Verifies user account creation with email and password
- ✅ **Email verification sending**: Confirms verification email is sent after registration
- ✅ **Input validation**: Tests email format validation and password strength requirements
- ✅ **Duplicate prevention**: Ensures duplicate email registration is prevented

#### Step 2: Email Verification
- ✅ **Unverified user blocking**: Confirms unverified users cannot access full functionality
- ✅ **Verification status updates**: Verifies email verification updates user status in Firestore
- ✅ **Firebase integration**: Tests email verification integration with Firebase Auth

#### Step 3: Trial Creation on First Verified Login
- ✅ **Automatic trial creation**: Verifies trial history is created when verified user logs in
- ✅ **7-day trial period**: Confirms trial duration is exactly 7 days
- ✅ **Duplicate prevention**: Ensures no duplicate trials are created for same user
- ✅ **Email abuse prevention**: Prevents multiple trials using same email address

#### Step 4: User Status Updates Throughout Flow
- ✅ **Status progression**: Tracks user status from unverified → verified → trial_user
- ✅ **Data consistency**: Ensures data consistency across users and trial_history collections
- ✅ **Edge case handling**: Tests multiple verification attempts and error recovery

#### Step 5: Complete End-to-End Integration
- ✅ **Full user journey**: Tests complete flow from registration to active trial
- ✅ **Error handling**: Verifies graceful handling of network and authentication errors
- ✅ **Data integrity**: Ensures all data is properly stored and linked across collections

## Test Data Structure

### User Profile Data
```dart
{
  'uid': 'test-uid-123',
  'email': 'integration@example.com',
  'username': 'integrationuser',
  'name': 'Integration Test User',
  'workLocation': 'Dubai',
  'occupation': 'Software Engineer',
  'emailVerified': true,
  'status': 'trial_user',
  'createdAt': Timestamp,
  'lastLoginAt': Timestamp,
}
```

### Trial History Data
```dart
{
  'userId': 'test-uid-123',
  'email': 'integration@example.com',
  'trialStartDate': Timestamp,
  'trialEndDate': Timestamp, // 7 days from start
  'createdAt': Timestamp,
}
```

## Running the Tests

### Individual Test File
```bash
flutter test test/integration/user_journey_test.dart --reporter=expanded
```

### All Integration Tests
```bash
dart test/integration/run_integration_tests.dart
```

### With Coverage
```bash
flutter test test/integration/user_journey_test.dart --coverage
```

## Test Environment

The integration tests use:
- **FakeFirebaseFirestore**: For simulating Firestore operations
- **MockFirebaseAuth**: For simulating Firebase Authentication
- **TestConfig**: For consistent test environment setup
- **TestUtils**: For generating test data and utilities

## Assertions and Validations

### User Registration Assertions
- User account is created with correct UID and email
- User profile is stored in Firestore with all required fields
- Email verification status is initially false
- User status is set to 'unverified'

### Email Verification Assertions
- Email verification updates emailVerified field to true
- emailVerifiedAt timestamp is recorded
- User status changes to 'verified'
- Firebase Auth emailVerified property is true

### Trial Creation Assertions
- Trial history document is created in Firestore
- Trial duration is exactly 7 days
- Trial uses userId as document identifier
- No duplicate trials are created for same email
- User status changes to 'trial_user'

### Data Consistency Assertions
- User email matches across users and trial_history collections
- User ID is consistent across all related documents
- Timestamps are properly recorded for all operations
- Status transitions follow the correct sequence

## Error Scenarios Tested

1. **Network Errors**: Firestore unavailable, network request failed
2. **Authentication Errors**: Invalid credentials, user not found
3. **Validation Errors**: Invalid email format, weak password
4. **Duplicate Data**: Duplicate email registration, multiple trial attempts
5. **Edge Cases**: Multiple verification attempts, concurrent operations

## Success Criteria

All tests must pass with the following validations:
- ✅ User registration creates proper user profile
- ✅ Email verification integrates correctly with Firebase
- ✅ Trial creation happens automatically on first verified login
- ✅ User status updates correctly throughout the flow
- ✅ Data consistency is maintained across all collections
- ✅ Error scenarios are handled gracefully
- ✅ No duplicate trials or data corruption occurs

**Test Scenarios:**

#### Step 1: Setup Active Subscription for Cancellation
- ✅ **Active subscription creation**: Verifies premium subscriber with active subscription ready for cancellation
- ✅ **Subscription data validation**: Confirms all subscription fields are properly set

#### Step 2: Subscription Cancellation Process
- ✅ **Cancellation marking**: Tests subscription status change to 'cancelled'
- ✅ **willExpireAt date setting**: Verifies access continues until original billing period end
- ✅ **Auto-renewal disabling**: Confirms future billing is stopped after cancellation

#### Step 3: Continued Access Until Billing Period End
- ✅ **Grace period access**: Verifies premium access continues until willExpireAt date
- ✅ **Access time calculation**: Tests accurate calculation of remaining access days
- ✅ **Status consistency**: Ensures cancelled status is maintained during grace period

#### Step 4: Premium Access Revocation After Expiration
- ✅ **Access revocation**: Tests premium access removal when willExpireAt is reached
- ✅ **Status transition**: Verifies subscription status changes to 'expired'
- ✅ **Edge case handling**: Tests exact expiration time scenarios

#### Step 5: User Status Updates After Cancellation and Expiration
- ✅ **Cancellation status update**: Tests user status change from premium_subscriber to cancelled_subscriber
- ✅ **Expiration status update**: Tests user status change from cancelled_subscriber to free_user
- ✅ **Status timeline tracking**: Verifies complete status transition history

#### Step 6: Integration Test for Complete Cancellation Flow
- ✅ **End-to-end cancellation flow**: Tests complete journey from active subscription to expired access
- ✅ **Error scenario handling**: Verifies graceful handling of edge cases and errors
- ✅ **Data consistency**: Ensures data integrity throughout the cancellation process

## Future Enhancements

Potential additions to the integration test suite:
- Widget testing integration for UI components
- Performance testing for large user datasets
- Concurrent user registration testing
- Payment integration testing (when implemented)
- Admin dashboard integration testing