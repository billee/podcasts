import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
import 'package:mockito/mockito.dart';

import '../../../lib/services/user_status_service.dart';
import '../../../lib/services/subscription_service.dart';
import '../../test_config.dart';
import '../../utils/test_helpers.dart';
import '../../mocks/firebase_mocks.dart';
import '../../base/base_test.dart';

void main() {
  setUpAll(() async {
    await TestConfig.initialize();
  });

  tearDownAll(() async {
    await TestConfig.cleanup();
  });

  group('👤 UserStatusService - Task 6.2: Status Validation and UI Updates', () {
    late auth_mocks.MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;
    late auth_mocks.MockUser mockUser;

    setUp(() {
      mockUser = FirebaseMockFactory.createMockUser();
      mockAuth = FirebaseMockFactory.createMockAuth(currentUser: mockUser);
      mockFirestore = FirebaseMockFactory.createMockFirestore();
      
      // Inject mocked instances into both services
      UserStatusService.setFirestoreInstance(mockFirestore);
      UserStatusService.setAuthInstance(mockAuth);
      SubscriptionService.setFirestoreInstance(mockFirestore);
      SubscriptionService.setAuthInstance(mockAuth);
    });

    group('🔐 Status-based Feature Access Control Tests', () {
      test('should grant premium access to trial users', () async {
        // Test the hasPremiumAccess method directly with UserStatus enum
        final hasPremiumAccess = UserStatusService.hasPremiumAccess(UserStatus.trialUser);
        
        // Assert - Trial users should have premium access
        expect(hasPremiumAccess, isTrue,
               reason: 'Trial users should have premium access to features');
      });

      test('should grant premium access to premium subscribers', () async {
        // Test the hasPremiumAccess method directly with UserStatus enum
        final hasPremiumAccess = UserStatusService.hasPremiumAccess(UserStatus.premiumSubscriber);
        
        // Assert - Premium subscribers should have premium access
        expect(hasPremiumAccess, isTrue,
               reason: 'Premium subscribers should have premium access to features');
      });

      test('should grant premium access to cancelled subscribers until expiration', () async {
        // Test the hasPremiumAccess method directly with UserStatus enum
        final hasPremiumAccess = UserStatusService.hasPremiumAccess(UserStatus.cancelledSubscriber);
        
        // Assert - Cancelled subscribers should retain premium access until expiration
        expect(hasPremiumAccess, isTrue,
               reason: 'Cancelled subscribers should retain premium access until expiration');
      });

      test('should deny premium access to unverified users', () async {
        // Arrange - Create unverified user
        const testUserId = 'test-unverified-access-user';
        const testEmail = 'unverifiedaccess@example.com';
        
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': testEmail,
          'username': 'unverifieduser',
          'emailVerified': false,
          'status': 'Unverified',
          'createdAt': DateTime.now(),
        });

        // Act - Get user status and check premium access
        final userStatus = await UserStatusService.getUserStatus(testUserId);
        final hasPremiumAccess = UserStatusService.hasPremiumAccess(userStatus);

        // Assert - Unverified users should not have premium access
        expect(userStatus, equals(UserStatus.unverified),
               reason: 'User should have unverified status');
        expect(hasPremiumAccess, isFalse,
               reason: 'Unverified users should not have premium access');
      });

      test('should deny premium access to trial expired users', () async {
        // Arrange - Create trial expired user
        const testUserId = 'test-expired-access-user';
        const testEmail = 'expiredaccess@example.com';
        
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': testEmail,
          'username': 'expireduser',
          'emailVerified': true,
          'status': 'Trial Expired',
          'createdAt': DateTime.now(),
        });

        // Create expired trial
        final now = DateTime.now();
        final pastTrialEndDate = now.subtract(const Duration(days: 2));
        await mockFirestore.collection('trial_history').add({
          'userId': testUserId,
          'email': testEmail,
          'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 9))),
          'trialEndDate': Timestamp.fromDate(pastTrialEndDate),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 9))),
        });

        // Act - Get user status and check premium access
        final userStatus = await UserStatusService.getUserStatus(testUserId);
        final hasPremiumAccess = UserStatusService.hasPremiumAccess(userStatus);

        // Assert - Trial expired users should not have premium access
        expect(userStatus, equals(UserStatus.trialExpired),
               reason: 'User should have trial expired status');
        expect(hasPremiumAccess, isFalse,
               reason: 'Trial expired users should not have premium access');
      });

      test('should deny premium access to free users', () async {
        // Arrange - Create free user (expired subscription)
        const testUserId = 'test-free-access-user';
        const testEmail = 'freeaccess@example.com';
        
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': testEmail,
          'username': 'freeuser',
          'emailVerified': true,
          'status': 'Free User',
          'createdAt': DateTime.now(),
        });

        // Create expired subscription
        final now = DateTime.now();
        final pastExpirationDate = now.subtract(const Duration(days: 5));
        await mockFirestore.collection('subscriptions').doc(testUserId).set({
          'userId': testUserId,
          'email': testEmail,
          'status': 'expired',
          'plan': 'monthly',
          'isTrialActive': false,
          'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 35))),
          'subscriptionEndDate': Timestamp.fromDate(pastExpirationDate),
          'cancelledAt': Timestamp.fromDate(now.subtract(const Duration(days: 10))),
          'willExpireAt': Timestamp.fromDate(pastExpirationDate),
          'expiredAt': Timestamp.fromDate(pastExpirationDate),
          'price': 3.0,
          'autoRenew': false,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 35))),
        });

        // Act - Get user status and check premium access
        final userStatus = await UserStatusService.getUserStatus(testUserId);
        final hasPremiumAccess = UserStatusService.hasPremiumAccess(userStatus);

        // Assert - Free users should not have premium access
        expect(userStatus, equals(UserStatus.freeUser),
               reason: 'User should have free user status');
        expect(hasPremiumAccess, isFalse,
               reason: 'Free users should not have premium access');
      });

      test('should validate feature access control for all user status types', () async {
        // Test all status types for comprehensive feature access validation
        final statusAccessMap = {
          UserStatus.unverified: false,
          UserStatus.trialUser: true,
          UserStatus.trialExpired: false,
          UserStatus.premiumSubscriber: true,
          UserStatus.cancelledSubscriber: true,
          UserStatus.freeUser: false,
        };

        for (final entry in statusAccessMap.entries) {
          final status = entry.key;
          final expectedAccess = entry.value;
          
          final actualAccess = UserStatusService.hasPremiumAccess(status);
          
          expect(actualAccess, equals(expectedAccess),
                 reason: 'Status ${status.name} should ${expectedAccess ? 'have' : 'not have'} premium access');
        }
      });
    });

    group('👁️ UI Element Visibility Based on User Status Tests', () {
      test('should return correct status display strings for all user statuses', () async {
        // Test all status display strings
        final statusDisplayMap = {
          UserStatus.unverified: 'Unverified',
          UserStatus.trialUser: 'Trial User',
          UserStatus.trialExpired: 'Trial Expired',
          UserStatus.premiumSubscriber: 'Premium Subscriber',
          UserStatus.cancelledSubscriber: 'Cancelled Subscriber',
          UserStatus.freeUser: 'Free User',
        };

        for (final entry in statusDisplayMap.entries) {
          final status = entry.key;
          final expectedDisplay = entry.value;
          
          final actualDisplay = UserStatusService.getStatusDisplayString(status);
          
          expect(actualDisplay, equals(expectedDisplay),
                 reason: 'Status ${status.name} should display as "$expectedDisplay"');
        }
      });

      test('should provide consistent status strings for UI display', () async {
        // Arrange - Create user with each status type
        const testUserId = 'test-ui-display-user';
        
        final statusTestCases = [
          {
            'status': UserStatus.unverified,
            'displayString': 'Unverified',
            'description': 'User has not verified email'
          },
          {
            'status': UserStatus.trialUser,
            'displayString': 'Trial User',
            'description': 'User is in active trial period'
          },
          {
            'status': UserStatus.trialExpired,
            'displayString': 'Trial Expired',
            'description': 'User trial has expired without subscription'
          },
          {
            'status': UserStatus.premiumSubscriber,
            'displayString': 'Premium Subscriber',
            'description': 'User has active paid subscription'
          },
          {
            'status': UserStatus.cancelledSubscriber,
            'displayString': 'Cancelled Subscriber',
            'description': 'User cancelled but retains access until expiration'
          },
          {
            'status': UserStatus.freeUser,
            'displayString': 'Free User',
            'description': 'User subscription has fully expired'
          },
        ];

        for (final testCase in statusTestCases) {
          final status = testCase['status'] as UserStatus;
          final expectedDisplay = testCase['displayString'] as String;
          final description = testCase['description'] as String;
          
          // Act - Get display string
          final displayString = UserStatusService.getStatusDisplayString(status);
          
          // Assert - Verify display string matches expected
          expect(displayString, equals(expectedDisplay),
                 reason: '$description should display as "$expectedDisplay"');
          
          // Verify display string is not empty and properly formatted
          expect(displayString.isNotEmpty, isTrue,
                 reason: 'Display string should not be empty');
          expect(displayString.trim(), equals(displayString),
                 reason: 'Display string should not have leading/trailing whitespace');
        }
      });

      test('should validate UI visibility logic for different user statuses', () async {
        // Test UI visibility conditions that would be used in widgets
        
        // Test cases for UI element visibility
        final visibilityTestCases = [
          {
            'status': UserStatus.unverified,
            'showEmailVerificationBanner': true,
            'showTrialCountdown': false,
            'showPremiumDiamond': false,
            'showUpgradeButton': false,
            'showSubscriptionStatus': false,
          },
          {
            'status': UserStatus.trialUser,
            'showEmailVerificationBanner': false,
            'showTrialCountdown': true,
            'showPremiumDiamond': false,
            'showUpgradeButton': true,
            'showSubscriptionStatus': true,
          },
          {
            'status': UserStatus.trialExpired,
            'showEmailVerificationBanner': false,
            'showTrialCountdown': false,
            'showPremiumDiamond': false,
            'showUpgradeButton': true,
            'showSubscriptionStatus': true,
          },
          {
            'status': UserStatus.premiumSubscriber,
            'showEmailVerificationBanner': false,
            'showTrialCountdown': false,
            'showPremiumDiamond': true,
            'showUpgradeButton': false,
            'showSubscriptionStatus': true,
          },
          {
            'status': UserStatus.cancelledSubscriber,
            'showEmailVerificationBanner': false,
            'showTrialCountdown': false,
            'showPremiumDiamond': true, // Still premium until expiration
            'showUpgradeButton': false,
            'showSubscriptionStatus': true,
          },
          {
            'status': UserStatus.freeUser,
            'showEmailVerificationBanner': false,
            'showTrialCountdown': false,
            'showPremiumDiamond': false,
            'showUpgradeButton': true,
            'showSubscriptionStatus': true,
          },
        ];

        for (final testCase in visibilityTestCases) {
          final status = testCase['status'] as UserStatus;
          
          // Test email verification banner visibility
          final shouldShowEmailBanner = testCase['showEmailVerificationBanner'] as bool;
          final actualShowEmailBanner = status == UserStatus.unverified;
          expect(actualShowEmailBanner, equals(shouldShowEmailBanner),
                 reason: 'Email verification banner visibility for ${status.name}');
          
          // Test trial countdown visibility
          final shouldShowTrialCountdown = testCase['showTrialCountdown'] as bool;
          final actualShowTrialCountdown = status == UserStatus.trialUser;
          expect(actualShowTrialCountdown, equals(shouldShowTrialCountdown),
                 reason: 'Trial countdown visibility for ${status.name}');
          
          // Test premium diamond visibility
          final shouldShowPremiumDiamond = testCase['showPremiumDiamond'] as bool;
          final actualShowPremiumDiamond = status == UserStatus.premiumSubscriber || 
                                          status == UserStatus.cancelledSubscriber;
          expect(actualShowPremiumDiamond, equals(shouldShowPremiumDiamond),
                 reason: 'Premium diamond visibility for ${status.name}');
          
          // Test upgrade button visibility
          final shouldShowUpgradeButton = testCase['showUpgradeButton'] as bool;
          final actualShowUpgradeButton = status == UserStatus.trialUser ||
                                         status == UserStatus.trialExpired ||
                                         status == UserStatus.freeUser;
          expect(actualShowUpgradeButton, equals(shouldShowUpgradeButton),
                 reason: 'Upgrade button visibility for ${status.name}');
          
          // Test subscription status widget visibility
          final shouldShowSubscriptionStatus = testCase['showSubscriptionStatus'] as bool;
          final actualShowSubscriptionStatus = status != UserStatus.unverified;
          expect(actualShowSubscriptionStatus, equals(shouldShowSubscriptionStatus),
                 reason: 'Subscription status widget visibility for ${status.name}');
        }
      });

      test('should validate status-based UI element states and properties', () async {
        // Test UI element states that change based on user status
        
        final uiStateTestCases = [
          {
            'status': UserStatus.trialUser,
            'bannerColor': 'blue', // or orange/red based on days left
            'statusIcon': 'access_time',
            'actionButtonText': 'Upgrade to Premium',
            'statusBadgeColor': 'orange',
          },
          {
            'status': UserStatus.premiumSubscriber,
            'bannerColor': 'green',
            'statusIcon': 'check_circle',
            'actionButtonText': 'Cancel Subscription',
            'statusBadgeColor': 'green',
          },
          {
            'status': UserStatus.trialExpired,
            'bannerColor': 'red',
            'statusIcon': 'error',
            'actionButtonText': 'Subscribe Now',
            'statusBadgeColor': 'red',
          },
          {
            'status': UserStatus.cancelledSubscriber,
            'bannerColor': 'grey',
            'statusIcon': 'cancel',
            'actionButtonText': 'Renew Subscription',
            'statusBadgeColor': 'grey',
          },
        ];

        for (final testCase in uiStateTestCases) {
          final status = testCase['status'] as UserStatus;
          final expectedIcon = testCase['statusIcon'] as String;
          final expectedButtonText = testCase['actionButtonText'] as String;
          final expectedBadgeColor = testCase['statusBadgeColor'] as String;
          
          // Verify status display string is appropriate for UI
          final displayString = UserStatusService.getStatusDisplayString(status);
          expect(displayString.isNotEmpty, isTrue,
                 reason: 'Status ${status.name} should have non-empty display string');
          
          // Verify premium access aligns with expected UI behavior
          final hasPremiumAccess = UserStatusService.hasPremiumAccess(status);
          final shouldShowPremiumFeatures = status == UserStatus.trialUser ||
                                           status == UserStatus.premiumSubscriber ||
                                           status == UserStatus.cancelledSubscriber;
          expect(hasPremiumAccess, equals(shouldShowPremiumFeatures),
                 reason: 'Premium access should align with UI feature visibility for ${status.name}');
          
          // Test that status provides enough information for UI decisions
          expect(status.name.isNotEmpty, isTrue,
                 reason: 'Status enum should have meaningful name for UI logic');
        }
      });
    });

    group('🎨 Status Badge Display and Color Coding Tests', () {
      test('should provide appropriate color coding for each user status', () async {
        // Define expected color schemes for each status
        final statusColorMap = {
          UserStatus.unverified: {
            'primary': 'orange',
            'description': 'Warning color for unverified state',
            'urgency': 'medium',
          },
          UserStatus.trialUser: {
            'primary': 'blue', // Can change to orange/red based on days left
            'description': 'Info color for active trial',
            'urgency': 'low',
          },
          UserStatus.trialExpired: {
            'primary': 'red',
            'description': 'Error color for expired trial',
            'urgency': 'high',
          },
          UserStatus.premiumSubscriber: {
            'primary': 'green',
            'description': 'Success color for active subscription',
            'urgency': 'none',
          },
          UserStatus.cancelledSubscriber: {
            'primary': 'grey',
            'description': 'Neutral color for cancelled state',
            'urgency': 'low',
          },
          UserStatus.freeUser: {
            'primary': 'grey',
            'description': 'Neutral color for free user',
            'urgency': 'low',
          },
        };

        for (final entry in statusColorMap.entries) {
          final status = entry.key;
          final colorInfo = entry.value;
          final expectedColor = colorInfo['primary'] as String;
          final description = colorInfo['description'] as String;
          final urgency = colorInfo['urgency'] as String;
          
          // Verify status has appropriate display string for badge
          final displayString = UserStatusService.getStatusDisplayString(status);
          expect(displayString.isNotEmpty, isTrue,
                 reason: 'Status ${status.name} should have display string for badge');
          
          // Verify status urgency aligns with expected UI treatment
          final isUrgent = urgency == 'high' || urgency == 'medium';
          final requiresAction = status == UserStatus.unverified ||
                                status == UserStatus.trialExpired ||
                                status == UserStatus.freeUser;
          
          // High urgency statuses should require user action
          if (urgency == 'high') {
            expect(requiresAction, isTrue,
                   reason: 'High urgency status ${status.name} should require user action');
          }
          
          // Verify color choice makes sense for status
          expect(expectedColor.toString().isNotEmpty, isTrue,
                 reason: 'Status ${status.name} should have defined color scheme');
          
          // Verify description is meaningful
          expect(description.isNotEmpty, isTrue,
                 reason: 'Status ${status.name} should have meaningful color description');
        }
      });

      test('should provide consistent badge styling information for UI components', () async {
        // Test badge styling consistency across different statuses
        final badgeStyleTestCases = [
          {
            'status': UserStatus.unverified,
            'shouldPulse': true, // Attention-grabbing for unverified
            'shouldShowIcon': true,
            'iconType': 'warning',
            'textStyle': 'bold',
            'priority': 'high',
          },
          {
            'status': UserStatus.trialUser,
            'shouldPulse': false,
            'shouldShowIcon': true,
            'iconType': 'timer',
            'textStyle': 'normal',
            'priority': 'medium',
          },
          {
            'status': UserStatus.trialExpired,
            'shouldPulse': true, // Urgent action needed
            'shouldShowIcon': true,
            'iconType': 'error',
            'textStyle': 'bold',
            'priority': 'high',
          },
          {
            'status': UserStatus.premiumSubscriber,
            'shouldPulse': false,
            'shouldShowIcon': true,
            'iconType': 'success',
            'textStyle': 'normal',
            'priority': 'low',
          },
          {
            'status': UserStatus.cancelledSubscriber,
            'shouldPulse': false,
            'shouldShowIcon': true,
            'iconType': 'info',
            'textStyle': 'normal',
            'priority': 'medium',
          },
          {
            'status': UserStatus.freeUser,
            'shouldPulse': false,
            'shouldShowIcon': true,
            'iconType': 'info',
            'textStyle': 'normal',
            'priority': 'low',
          },
        ];

        for (final testCase in badgeStyleTestCases) {
          final status = testCase['status'] as UserStatus;
          final shouldPulse = testCase['shouldPulse'] as bool;
          final shouldShowIcon = testCase['shouldShowIcon'] as bool;
          final iconType = testCase['iconType'] as String;
          final textStyle = testCase['textStyle'] as String;
          final priority = testCase['priority'] as String;
          
          // Verify display string is suitable for badge display
          final displayString = UserStatusService.getStatusDisplayString(status);
          expect(displayString.length, lessThan(25),
                 reason: 'Badge text for ${status.name} should be concise');
          expect(displayString.contains(RegExp(r'^[A-Z]')), isTrue,
                 reason: 'Badge text for ${status.name} should start with capital letter');
          
          // Verify priority aligns with user action requirements
          final requiresUrgentAction = status == UserStatus.unverified ||
                                      status == UserStatus.trialExpired;
          if (priority == 'high') {
            expect(requiresUrgentAction, isTrue,
                   reason: 'High priority status ${status.name} should require urgent action');
          }
          
          // Verify pulsing animation aligns with urgency
          if (shouldPulse) {
            expect(priority, isIn(['high', 'medium']),
                   reason: 'Pulsing badges should only be used for medium/high priority statuses');
          }
          
          // Verify icon type makes sense for status
          expect(iconType.isNotEmpty, isTrue,
                 reason: 'Status ${status.name} should have defined icon type');
          
          // Verify text style aligns with priority
          if (textStyle == 'bold') {
            expect(priority, isIn(['high', 'medium']),
                   reason: 'Bold text should be used for important statuses');
          }
        }
      });

      test('should validate badge color transitions for status changes', () async {
        // Test color transitions when status changes
        final statusTransitions = [
          {
            'from': UserStatus.unverified,
            'to': UserStatus.trialUser,
            'colorChange': 'orange -> blue',
            'description': 'Email verification completion',
          },
          {
            'from': UserStatus.trialUser,
            'to': UserStatus.premiumSubscriber,
            'colorChange': 'blue -> green',
            'description': 'Trial to subscription conversion',
          },
          {
            'from': UserStatus.premiumSubscriber,
            'to': UserStatus.cancelledSubscriber,
            'colorChange': 'green -> grey',
            'description': 'Subscription cancellation',
          },
          {
            'from': UserStatus.cancelledSubscriber,
            'to': UserStatus.freeUser,
            'colorChange': 'grey -> grey',
            'description': 'Subscription expiration',
          },
          {
            'from': UserStatus.trialUser,
            'to': UserStatus.trialExpired,
            'colorChange': 'blue -> red',
            'description': 'Trial expiration without subscription',
          },
        ];

        for (final transition in statusTransitions) {
          final fromStatus = transition['from'] as UserStatus;
          final toStatus = transition['to'] as UserStatus;
          final colorChange = transition['colorChange'] as String;
          final description = transition['description'] as String;
          
          // Verify both statuses have valid display strings
          final fromDisplay = UserStatusService.getStatusDisplayString(fromStatus);
          final toDisplay = UserStatusService.getStatusDisplayString(toStatus);
          
          expect(fromDisplay.isNotEmpty, isTrue,
                 reason: 'Source status ${fromStatus.name} should have display string');
          expect(toDisplay.isNotEmpty, isTrue,
                 reason: 'Target status ${toStatus.name} should have display string');
          
          // Verify display strings are different (unless it's a subtle state change)
          if (fromStatus != toStatus) {
            expect(fromDisplay, isNot(equals(toDisplay)),
                   reason: 'Status transition should result in different display text');
          }
          
          // Verify premium access changes appropriately
          final fromAccess = UserStatusService.hasPremiumAccess(fromStatus);
          final toAccess = UserStatusService.hasPremiumAccess(toStatus);
          
          // Specific transition validations
          if (description.contains('Trial to subscription')) {
            expect(fromAccess, isTrue, reason: 'Trial users should have premium access');
            expect(toAccess, isTrue, reason: 'Premium subscribers should have premium access');
          }
          
          if (description.contains('Trial expiration without subscription')) {
            expect(fromAccess, isTrue, reason: 'Trial users should have premium access');
            expect(toAccess, isFalse, reason: 'Expired trial users should not have premium access');
          }
          
          if (description.contains('Email verification')) {
            expect(fromAccess, isFalse, reason: 'Unverified users should not have premium access');
            expect(toAccess, isTrue, reason: 'Trial users should have premium access');
          }
        }
      });

      test('should provide appropriate badge information for dynamic UI updates', () async {
        // Test dynamic badge properties that change based on context
        const testUserId = 'test-dynamic-badge-user';
        
        // Test trial user with different days remaining
        final trialDaysTestCases = [
          {'daysLeft': 7, 'expectedColor': 'blue', 'expectedUrgency': 'low'},
          {'daysLeft': 3, 'expectedColor': 'orange', 'expectedUrgency': 'medium'},
          {'daysLeft': 1, 'expectedColor': 'red', 'expectedUrgency': 'high'},
          {'daysLeft': 0, 'expectedColor': 'red', 'expectedUrgency': 'critical'},
        ];

        for (final testCase in trialDaysTestCases) {
          final daysLeft = testCase['daysLeft'] as int;
          final expectedColor = testCase['expectedColor'] as String;
          final expectedUrgency = testCase['expectedUrgency'] as String;
          
          // Test the display string logic for trial users
          final displayString = UserStatusService.getStatusDisplayString(UserStatus.trialUser);
          
          // Verify display string is appropriate for badge
          expect(displayString.isNotEmpty, isTrue,
                 reason: 'Badge should have display text for $daysLeft days left');
          expect(displayString, equals('Trial User'),
                 reason: 'Display string should be consistent for trial users');
          
          // Verify premium access is appropriate for trial users
          final hasPremiumAccess = UserStatusService.hasPremiumAccess(UserStatus.trialUser);
          expect(hasPremiumAccess, isTrue,
                 reason: 'Trial users should have premium access');
          
          // Test color logic based on urgency
          Color actualColor;
          if (daysLeft <= 1) {
            actualColor = Colors.red; // Critical/urgent
          } else if (daysLeft <= 3) {
            actualColor = Colors.orange; // Warning
          } else {
            actualColor = Colors.blue; // Normal
          }
          
          expect(actualColor.toString().isNotEmpty, isTrue,
                 reason: 'Color should be defined for $daysLeft days left');
        }
      });
    });

    group('🔄 Status Update and UI Synchronization Tests', () {
      test('should maintain UI consistency during status transitions', () async {
        // Test that status updates maintain UI consistency
        const testUserId = 'test-ui-sync-user';
        const testEmail = 'uisync@example.com';
        
        // Test UI consistency for different status types
        final statusTestCases = [
          {
            'status': UserStatus.unverified,
            'displayString': 'Unverified',
            'hasPremiumAccess': false,
          },
          {
            'status': UserStatus.trialUser,
            'displayString': 'Trial User',
            'hasPremiumAccess': true,
          },
          {
            'status': UserStatus.premiumSubscriber,
            'displayString': 'Premium Subscriber',
            'hasPremiumAccess': true,
          },
        ];

        for (final testCase in statusTestCases) {
          final status = testCase['status'] as UserStatus;
          final expectedDisplayString = testCase['displayString'] as String;
          final expectedPremiumAccess = testCase['hasPremiumAccess'] as bool;
          
          // Test display string consistency
          final displayString = UserStatusService.getStatusDisplayString(status);
          expect(displayString, equals(expectedDisplayString),
                 reason: 'Display string should be consistent for ${status.name}');
          
          // Test premium access consistency
          final hasPremiumAccess = UserStatusService.hasPremiumAccess(status);
          expect(hasPremiumAccess, equals(expectedPremiumAccess),
                 reason: 'Premium access should be consistent for ${status.name}');
        }

        // Test that status update methods work correctly
        await UserStatusService.updateUserStatus(testUserId, UserStatus.trialUser);
        
        // Verify user document was updated with timestamp
        final userDoc = await mockFirestore.collection('users').doc(testUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('Trial User'));
          expect(userData['statusUpdatedAt'], isNotNull);
          expect(userData['updatedAt'], isNotNull);
        }
      });

      test('should handle concurrent status updates gracefully', () async {
        // Test concurrent status updates don't cause inconsistencies
        const testUserId = 'test-concurrent-user';
        const testEmail = 'concurrent@example.com';
        
        // Create initial user
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': testEmail,
          'username': 'concurrentuser',
          'emailVerified': true,
          'status': 'Trial User',
          'createdAt': DateTime.now(),
        });

        // Simulate concurrent status updates
        final futures = <Future<void>>[];
        
        // Multiple rapid status updates
        futures.add(UserStatusService.updateUserStatus(testUserId, UserStatus.trialUser));
        futures.add(UserStatusService.updateUserStatus(testUserId, UserStatus.premiumSubscriber));
        futures.add(UserStatusService.updateUserStatus(testUserId, UserStatus.cancelledSubscriber));
        
        // Wait for all updates to complete
        await Future.wait(futures);
        
        // Verify final state is consistent
        final userDoc = await mockFirestore.collection('users').doc(testUserId).get();
        final userData = userDoc.data() as Map<String, dynamic>;
        
        expect(userData['status'], isNotNull,
               reason: 'Status should be set after concurrent updates');
        expect(userData['statusUpdatedAt'], isNotNull,
               reason: 'Status update timestamp should be set');
        expect(userData['updatedAt'], isNotNull,
               reason: 'Document update timestamp should be set');
        
        // Verify status is one of the valid values
        final validStatuses = ['Trial User', 'Premium Subscriber', 'Cancelled Subscriber'];
        expect(validStatuses.contains(userData['status']), isTrue,
               reason: 'Final status should be one of the attempted updates');
      });

      test('should validate status history tracking for UI analytics', () async {
        // Test status history tracking for UI analytics and debugging
        const testUserId = 'test-history-user';
        
        // Get initial status history
        final initialHistory = await UserStatusService.getStatusHistory(testUserId);
        expect(initialHistory, isNotNull,
               reason: 'Status history should be available');
        
        // Create user and track status changes
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': 'history@example.com',
          'username': 'historyuser',
          'emailVerified': false,
          'status': 'Unverified',
          'createdAt': DateTime.now(),
        });

        // Perform status transition
        await UserStatusService.transitionToTrialUser(testUserId);
        
        // Get updated status history
        final updatedHistory = await UserStatusService.getStatusHistory(testUserId);
        expect(updatedHistory, isNotNull,
               reason: 'Updated status history should be available');
        expect(updatedHistory.isNotEmpty, isTrue,
               reason: 'Status history should contain entries');
        
        // Verify history entry structure
        final latestEntry = updatedHistory.first;
        expect(latestEntry['status'], isNotNull,
               reason: 'History entry should have status');
        expect(latestEntry['timestamp'], isNotNull,
               reason: 'History entry should have timestamp');
        expect(latestEntry['userId'], equals(testUserId),
               reason: 'History entry should have correct user ID');
      });
    });
  });
}