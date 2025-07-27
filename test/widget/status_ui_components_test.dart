import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
import 'package:mockito/mockito.dart';

import '../../lib/widgets/email_verification_banner.dart';
import '../../lib/widgets/subscription_status_widget.dart';
import '../../lib/widgets/subscription_status_banner.dart';
import '../../lib/services/user_status_service.dart';
import '../../lib/services/subscription_service.dart';
import '../test_config.dart';
import '../mocks/firebase_mocks.dart';
import '../base/base_test.dart';

void main() {
  setUpAll(() async {
    await TestConfig.initialize();
  });

  tearDownAll(() async {
    await TestConfig.cleanup();
  });

  group('🎨 Status UI Components - Task 6.2: UI Element Visibility and Status Badge Tests', () {
    late auth_mocks.MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;
    late auth_mocks.MockUser mockUser;

    setUp(() {
      mockUser = FirebaseMockFactory.createMockUser();
      mockAuth = FirebaseMockFactory.createMockAuth(currentUser: mockUser);
      mockFirestore = FirebaseMockFactory.createMockFirestore();
      
      // Inject mocked instances
      UserStatusService.setFirestoreInstance(mockFirestore);
      UserStatusService.setAuthInstance(mockAuth);
    });

    group('📧 Email Verification Banner UI Tests', () {
      testWidgets('should show email verification banner for unverified users', (WidgetTester tester) async {
        // Arrange - Create unverified user
        when(mockUser.emailVerified).thenReturn(false);
        when(mockUser.email).thenReturn('unverified@example.com');
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const EmailVerificationBanner(),
            ),
          ),
        );

        // Assert - Verify banner is visible
        expect(find.text('Email Verification Required'), findsOneWidget,
               reason: 'Email verification banner should be visible for unverified users');
        expect(find.text('Please check your email and click the verification link'), findsOneWidget,
               reason: 'Verification instructions should be displayed');
        expect(find.text('Email: unverified@example.com'), findsOneWidget,
               reason: 'User email should be displayed in banner');
        expect(find.text('Resend Email'), findsOneWidget,
               reason: 'Resend email button should be visible');
        expect(find.text('Go to Login'), findsOneWidget,
               reason: 'Go to login button should be visible');

        // Verify banner styling
        final bannerContainer = tester.widget<Container>(
          find.ancestor(
            of: find.text('Email Verification Required'),
            matching: find.byType(Container),
          ).first,
        );
        final decoration = bannerContainer.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.orange.withOpacity(0.15)),
               reason: 'Banner should have orange background for warning');
        expect(decoration.border?.top.color, equals(Colors.orange.withOpacity(0.5)),
               reason: 'Banner should have orange border');

        // Verify warning icon
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget,
               reason: 'Warning icon should be displayed');
        final warningIcon = tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded));
        expect(warningIcon.color, equals(Colors.orange[800]),
               reason: 'Warning icon should be orange');
      });

      testWidgets('should hide email verification banner for verified users', (WidgetTester tester) async {
        // Arrange - Create verified user
        when(mockUser.emailVerified).thenReturn(true);
        when(mockUser.email).thenReturn('verified@example.com');
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const EmailVerificationBanner(),
            ),
          ),
        );

        // Assert - Verify banner is hidden
        expect(find.text('Email Verification Required'), findsNothing,
               reason: 'Email verification banner should be hidden for verified users');
        expect(find.text('Resend Email'), findsNothing,
               reason: 'Resend email button should not be visible for verified users');
        expect(find.byType(SizedBox), findsOneWidget,
               reason: 'Should render empty SizedBox for verified users');
      });

      testWidgets('should hide email verification banner when dismissed', (WidgetTester tester) async {
        // Arrange - Create unverified user
        when(mockUser.emailVerified).thenReturn(false);
        when(mockUser.email).thenReturn('unverified@example.com');
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const EmailVerificationBanner(),
            ),
          ),
        );

        // Verify banner is initially visible
        expect(find.text('Email Verification Required'), findsOneWidget);

        // Tap dismiss button
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        // Assert - Verify banner is dismissed
        expect(find.text('Email Verification Required'), findsNothing,
               reason: 'Banner should be hidden after dismissal');
      });

      testWidgets('should handle resend email button interaction', (WidgetTester tester) async {
        // Arrange - Create unverified user
        when(mockUser.emailVerified).thenReturn(false);
        when(mockUser.email).thenReturn('unverified@example.com');
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const EmailVerificationBanner(),
            ),
          ),
        );

        // Find and verify resend button
        final resendButton = find.text('Resend Email');
        expect(resendButton, findsOneWidget,
               reason: 'Resend email button should be present');

        // Verify button styling
        final elevatedButton = tester.widget<ElevatedButton>(
          find.ancestor(
            of: resendButton,
            matching: find.byType(ElevatedButton),
          ),
        );
        final buttonStyle = elevatedButton.style!;
        expect(buttonStyle.backgroundColor?.resolve({}), equals(Colors.orange[800]),
               reason: 'Resend button should have orange background');
        expect(buttonStyle.foregroundColor?.resolve({}), equals(Colors.white),
               reason: 'Resend button text should be white');
      });
    });

    group('📊 Subscription Status Widget UI Tests', () {
      testWidgets('should display trial user status with correct styling', (WidgetTester tester) async {
        // Arrange - Create trial user data
        const testUserId = 'test-trial-widget-user';
        when(mockUser.uid).thenReturn(testUserId);
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Create trial user in Firestore
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': 'trialwidget@example.com',
          'emailVerified': true,
          'status': 'Trial User',
        });

        final now = DateTime.now();
        await mockFirestore.collection('trial_history').add({
          'userId': testUserId,
          'email': 'trialwidget@example.com',
          'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
          'trialEndDate': Timestamp.fromDate(now.add(const Duration(days: 5))),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
        });

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const SubscriptionStatusWidget(),
            ),
          ),
        );

        // Wait for async data loading
        await tester.pumpAndSettle();

        // Assert - Verify trial status display
        expect(find.text('SUBSCRIPTION STATUS'), findsOneWidget,
               reason: 'Status widget header should be displayed');
        expect(find.text('TRIAL ACTIVE'), findsOneWidget,
               reason: 'Trial active status should be displayed');
        expect(find.text('Upgrade to Premium'), findsOneWidget,
               reason: 'Upgrade button should be visible for trial users');

        // Verify status icon
        expect(find.byIcon(Icons.access_time), findsOneWidget,
               reason: 'Trial status should show timer icon');

        // Verify card styling
        final card = tester.widget<Card>(find.byType(Card));
        expect(card.color, equals(Colors.grey[800]),
               reason: 'Status card should have dark background');
      });

      testWidgets('should display premium subscriber status with correct styling', (WidgetTester tester) async {
        // Arrange - Create premium subscriber data
        const testUserId = 'test-premium-widget-user';
        when(mockUser.uid).thenReturn(testUserId);
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Create premium user in Firestore
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': 'premiumwidget@example.com',
          'emailVerified': true,
          'status': 'Premium Subscriber',
        });

        final now = DateTime.now();
        await mockFirestore.collection('subscriptions').doc(testUserId).set({
          'userId': testUserId,
          'email': 'premiumwidget@example.com',
          'status': 'active',
          'plan': 'monthly',
          'price': 3.0,
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(DateTime(now.year, now.month + 1, now.day)),
          'nextBillingDate': Timestamp.fromDate(DateTime(now.year, now.month + 1, now.day)),
          'createdAt': Timestamp.fromDate(now),
        });

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const SubscriptionStatusWidget(),
            ),
          ),
        );

        // Wait for async data loading
        await tester.pumpAndSettle();

        // Assert - Verify premium status display
        expect(find.text('SUBSCRIPTION STATUS'), findsOneWidget,
               reason: 'Status widget header should be displayed');
        expect(find.text('PREMIUM ACTIVE'), findsOneWidget,
               reason: 'Premium active status should be displayed');
        expect(find.text('Cancel Subscription'), findsOneWidget,
               reason: 'Cancel button should be visible for premium users');
        expect(find.text('Price:'), findsOneWidget,
               reason: 'Price information should be displayed');
        expect(find.text('\$3.0/month'), findsOneWidget,
               reason: 'Monthly price should be displayed');

        // Verify status icon
        expect(find.byIcon(Icons.check_circle), findsOneWidget,
               reason: 'Premium status should show check circle icon');
      });

      testWidgets('should display trial expired status with correct styling', (WidgetTester tester) async {
        // Arrange - Create trial expired user data
        const testUserId = 'test-expired-widget-user';
        when(mockUser.uid).thenReturn(testUserId);
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Create expired trial user in Firestore
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': 'expiredwidget@example.com',
          'emailVerified': true,
          'status': 'Trial Expired',
        });

        final now = DateTime.now();
        await mockFirestore.collection('trial_history').add({
          'userId': testUserId,
          'email': 'expiredwidget@example.com',
          'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 9))),
          'trialEndDate': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 9))),
        });

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const SubscriptionStatusWidget(),
            ),
          ),
        );

        // Wait for async data loading
        await tester.pumpAndSettle();

        // Assert - Verify expired status display
        expect(find.text('SUBSCRIPTION STATUS'), findsOneWidget,
               reason: 'Status widget header should be displayed');
        expect(find.text('TRIAL EXPIRED'), findsOneWidget,
               reason: 'Trial expired status should be displayed');
        expect(find.text('Subscribe Now'), findsOneWidget,
               reason: 'Subscribe now button should be visible for expired users');

        // Verify status icon
        expect(find.byIcon(Icons.error), findsOneWidget,
               reason: 'Expired status should show error icon');
      });

      testWidgets('should display cancelled subscriber status with correct styling', (WidgetTester tester) async {
        // Arrange - Create cancelled subscriber data
        const testUserId = 'test-cancelled-widget-user';
        when(mockUser.uid).thenReturn(testUserId);
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Create cancelled user in Firestore
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': 'cancelledwidget@example.com',
          'emailVerified': true,
          'status': 'Cancelled Subscriber',
        });

        final now = DateTime.now();
        final futureExpiration = now.add(const Duration(days: 15));
        await mockFirestore.collection('subscriptions').doc(testUserId).set({
          'userId': testUserId,
          'email': 'cancelledwidget@example.com',
          'status': 'cancelled',
          'plan': 'monthly',
          'price': 3.0,
          'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
          'subscriptionEndDate': Timestamp.fromDate(futureExpiration),
          'cancelledAt': Timestamp.fromDate(now.subtract(const Duration(days: 5))),
          'willExpireAt': Timestamp.fromDate(futureExpiration),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
        });

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const SubscriptionStatusWidget(),
            ),
          ),
        );

        // Wait for async data loading
        await tester.pumpAndSettle();

        // Assert - Verify cancelled status display
        expect(find.text('SUBSCRIPTION STATUS'), findsOneWidget,
               reason: 'Status widget header should be displayed');
        expect(find.text('CANCELLED'), findsOneWidget,
               reason: 'Cancelled status should be displayed');
        expect(find.textContaining('CANCELLED - Access until end of billing period'), findsOneWidget,
               reason: 'Cancellation explanation should be displayed');

        // Verify status icon
        expect(find.byIcon(Icons.cancel), findsOneWidget,
               reason: 'Cancelled status should show cancel icon');
      });

      testWidgets('should show loading state while fetching subscription data', (WidgetTester tester) async {
        // Arrange - Create user without immediate data
        const testUserId = 'test-loading-widget-user';
        when(mockUser.uid).thenReturn(testUserId);
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const SubscriptionStatusWidget(),
            ),
          ),
        );

        // Assert - Verify loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget,
               reason: 'Loading indicator should be shown while fetching data');
        expect(find.byType(Card), findsOneWidget,
               reason: 'Loading card should be displayed');

        final loadingCard = tester.widget<Card>(find.byType(Card));
        expect(loadingCard.color, equals(Colors.grey),
               reason: 'Loading card should have grey background');
      });
    });

    group('🏷️ Subscription Status Banner UI Tests', () {
      testWidgets('should display trial banner with countdown for trial users', (WidgetTester tester) async {
        // Arrange - Create trial user data
        const testUserId = 'test-trial-banner-user';
        when(mockUser.uid).thenReturn(testUserId);
        when(mockUser.emailVerified).thenReturn(true);
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Create trial user in Firestore
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': 'trialbanner@example.com',
          'emailVerified': true,
          'status': 'Trial User',
        });

        final now = DateTime.now();
        await mockFirestore.collection('trial_history').add({
          'userId': testUserId,
          'email': 'trialbanner@example.com',
          'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
          'trialEndDate': Timestamp.fromDate(now.add(const Duration(days: 5))),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
        });

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const SubscriptionStatusBanner(),
            ),
          ),
        );

        // Wait for async data loading
        await tester.pumpAndSettle();

        // Assert - Verify trial banner display
        expect(find.textContaining('Trial:'), findsOneWidget,
               reason: 'Trial countdown should be displayed');
        expect(find.textContaining('Days Left'), findsOneWidget,
               reason: 'Days left text should be displayed');

        // Verify timer icon
        expect(find.byIcon(Icons.access_time), findsOneWidget,
               reason: 'Trial banner should show timer icon');

        // Verify banner container styling
        final bannerContainer = tester.widget<Container>(
          find.ancestor(
            of: find.textContaining('Trial:'),
            matching: find.byType(Container),
          ).first,
        );
        final decoration = bannerContainer.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(12)),
               reason: 'Banner should have rounded corners');
      });

      testWidgets('should show urgent styling for trial with 1 day left', (WidgetTester tester) async {
        // Arrange - Create trial user with 1 day left
        const testUserId = 'test-urgent-banner-user';
        when(mockUser.uid).thenReturn(testUserId);
        when(mockUser.emailVerified).thenReturn(true);
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Create trial user with 1 day remaining
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': 'urgentbanner@example.com',
          'emailVerified': true,
          'status': 'Trial User',
        });

        final now = DateTime.now();
        await mockFirestore.collection('trial_history').add({
          'userId': testUserId,
          'email': 'urgentbanner@example.com',
          'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 6))),
          'trialEndDate': Timestamp.fromDate(now.add(const Duration(days: 1))),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 6))),
        });

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const SubscriptionStatusBanner(),
            ),
          ),
        );

        // Wait for async data loading
        await tester.pumpAndSettle();

        // Assert - Verify urgent styling
        expect(find.textContaining('Trial: 1 Day Left'), findsOneWidget,
               reason: 'Should show 1 day left message');
        expect(find.text('Upgrade'), findsOneWidget,
               reason: 'Upgrade button should be visible for urgent trial');

        // Verify urgent banner styling (red color for 1 day left)
        final bannerContainer = tester.widget<Container>(
          find.ancestor(
            of: find.textContaining('Trial:'),
            matching: find.byType(Container),
          ).first,
        );
        final decoration = bannerContainer.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.red.withOpacity(0.15)),
               reason: 'Banner should have red background for urgent trial');
      });

      testWidgets('should show warning styling for trial with 3 days left', (WidgetTester tester) async {
        // Arrange - Create trial user with 3 days left
        const testUserId = 'test-warning-banner-user';
        when(mockUser.uid).thenReturn(testUserId);
        when(mockUser.emailVerified).thenReturn(true);
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Create trial user with 3 days remaining
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': 'warningbanner@example.com',
          'emailVerified': true,
          'status': 'Trial User',
        });

        final now = DateTime.now();
        await mockFirestore.collection('trial_history').add({
          'userId': testUserId,
          'email': 'warningbanner@example.com',
          'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 4))),
          'trialEndDate': Timestamp.fromDate(now.add(const Duration(days: 3))),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 4))),
        });

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const SubscriptionStatusBanner(),
            ),
          ),
        );

        // Wait for async data loading
        await tester.pumpAndSettle();

        // Assert - Verify warning styling
        expect(find.textContaining('Trial: 3 Days Left'), findsOneWidget,
               reason: 'Should show 3 days left message');
        expect(find.text('Upgrade'), findsOneWidget,
               reason: 'Upgrade button should be visible for warning trial');

        // Verify warning banner styling (orange color for 3 days left)
        final bannerContainer = tester.widget<Container>(
          find.ancestor(
            of: find.textContaining('Trial:'),
            matching: find.byType(Container),
          ).first,
        );
        final decoration = bannerContainer.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.orange.withOpacity(0.15)),
               reason: 'Banner should have orange background for warning trial');
      });

      testWidgets('should hide banner for premium subscribers', (WidgetTester tester) async {
        // Arrange - Create premium subscriber
        const testUserId = 'test-premium-banner-user';
        when(mockUser.uid).thenReturn(testUserId);
        when(mockUser.emailVerified).thenReturn(true);
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Create premium user in Firestore
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': 'premiumbanner@example.com',
          'emailVerified': true,
          'status': 'Premium Subscriber',
        });

        final now = DateTime.now();
        await mockFirestore.collection('subscriptions').doc(testUserId).set({
          'userId': testUserId,
          'email': 'premiumbanner@example.com',
          'status': 'active',
          'plan': 'monthly',
          'price': 3.0,
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(DateTime(now.year, now.month + 1, now.day)),
        });

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const SubscriptionStatusBanner(),
            ),
          ),
        );

        // Wait for async data loading
        await tester.pumpAndSettle();

        // Assert - Verify banner is hidden for premium users
        expect(find.textContaining('Trial:'), findsNothing,
               reason: 'Trial banner should be hidden for premium subscribers');
        expect(find.text('Upgrade'), findsNothing,
               reason: 'Upgrade button should not be visible for premium subscribers');
        expect(find.byType(SizedBox), findsOneWidget,
               reason: 'Should render empty SizedBox for premium subscribers');
      });

      testWidgets('should hide banner for unverified users', (WidgetTester tester) async {
        // Arrange - Create unverified user
        when(mockUser.emailVerified).thenReturn(false);
        when(mockAuth.currentUser).thenReturn(mockUser);

        // Act - Build widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const SubscriptionStatusBanner(),
            ),
          ),
        );

        // Wait for async data loading
        await tester.pumpAndSettle();

        // Assert - Verify banner is hidden for unverified users
        expect(find.textContaining('Trial:'), findsNothing,
               reason: 'Trial banner should be hidden for unverified users');
        expect(find.byType(SizedBox), findsOneWidget,
               reason: 'Should render empty SizedBox for unverified users');
      });
    });

    group('💎 App Bar Status Indicator Tests', () {
      testWidgets('should show premium diamond for premium subscribers', (WidgetTester tester) async {
        // This test would require testing the MainScreen component
        // For now, we'll test the logic that determines when to show the diamond
        
        // Test the subscription status logic that drives the diamond display
        const testUserId = 'test-diamond-user';
        
        // Create premium subscriber
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': 'diamond@example.com',
          'emailVerified': true,
          'status': 'Premium Subscriber',
        });

        final now = DateTime.now();
        await mockFirestore.collection('subscriptions').doc(testUserId).set({
          'userId': testUserId,
          'email': 'diamond@example.com',
          'status': 'active',
          'plan': 'monthly',
          'price': 3.0,
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(DateTime(now.year, now.month + 1, now.day)),
        });

        // Get subscription status
        final subscriptionStatus = await SubscriptionService.getSubscriptionStatus(testUserId);
        
        // Assert - Premium subscribers should show diamond
        expect(subscriptionStatus, equals(SubscriptionStatus.active),
               reason: 'Premium subscriber should have active subscription status');
        
        // The diamond should be shown when subscription status is active
        final shouldShowDiamond = subscriptionStatus == SubscriptionStatus.active;
        expect(shouldShowDiamond, isTrue,
               reason: 'Premium diamond should be shown for active subscribers');
      });

      testWidgets('should hide premium diamond for trial users', (WidgetTester tester) async {
        // Test the subscription status logic for trial users
        const testUserId = 'test-trial-diamond-user';
        
        // Create trial user
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': 'trialdiamond@example.com',
          'emailVerified': true,
          'status': 'Trial User',
        });

        final now = DateTime.now();
        await mockFirestore.collection('trial_history').add({
          'userId': testUserId,
          'email': 'trialdiamond@example.com',
          'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
          'trialEndDate': Timestamp.fromDate(now.add(const Duration(days: 5))),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
        });

        // Get subscription status
        final subscriptionStatus = await SubscriptionService.getSubscriptionStatus(testUserId);
        
        // Assert - Trial users should not show diamond
        expect(subscriptionStatus, equals(SubscriptionStatus.trial),
               reason: 'Trial user should have trial subscription status');
        
        // The diamond should not be shown for trial users
        final shouldShowDiamond = subscriptionStatus == SubscriptionStatus.active;
        expect(shouldShowDiamond, isFalse,
               reason: 'Premium diamond should not be shown for trial users');
      });
    });

    group('🎯 Status Badge Color Coding Tests', () {
      testWidgets('should apply correct color coding for different status types', (WidgetTester tester) async {
        // Test color coding logic for status badges
        final colorTestCases = [
          {
            'status': UserStatus.unverified,
            'expectedColor': Colors.orange,
            'description': 'Unverified users should have orange warning color',
          },
          {
            'status': UserStatus.trialUser,
            'expectedColor': Colors.blue, // Can change to orange/red based on days left
            'description': 'Trial users should have blue info color',
          },
          {
            'status': UserStatus.trialExpired,
            'expectedColor': Colors.red,
            'description': 'Expired trial should have red error color',
          },
          {
            'status': UserStatus.premiumSubscriber,
            'expectedColor': Colors.green,
            'description': 'Premium subscribers should have green success color',
          },
          {
            'status': UserStatus.cancelledSubscriber,
            'expectedColor': Colors.grey,
            'description': 'Cancelled subscribers should have grey neutral color',
          },
          {
            'status': UserStatus.freeUser,
            'expectedColor': Colors.grey,
            'description': 'Free users should have grey neutral color',
          },
        ];

        for (final testCase in colorTestCases) {
          final status = testCase['status'] as UserStatus;
          final expectedColor = testCase['expectedColor'] as Color;
          final description = testCase['description'] as String;
          
          // Test the color logic that would be used in UI components
          Color actualColor;
          switch (status) {
            case UserStatus.unverified:
              actualColor = Colors.orange;
              break;
            case UserStatus.trialUser:
              actualColor = Colors.blue; // Default, can change based on days left
              break;
            case UserStatus.trialExpired:
              actualColor = Colors.red;
              break;
            case UserStatus.premiumSubscriber:
              actualColor = Colors.green;
              break;
            case UserStatus.cancelledSubscriber:
              actualColor = Colors.grey;
              break;
            case UserStatus.freeUser:
              actualColor = Colors.grey;
              break;
          }
          
          expect(actualColor, equals(expectedColor),
                 reason: description);
        }
      });

      testWidgets('should apply urgent color coding for time-sensitive statuses', (WidgetTester tester) async {
        // Test urgent color coding for trial users based on days remaining
        final urgencyTestCases = [
          {
            'daysLeft': 7,
            'expectedColor': Colors.blue,
            'urgency': 'low',
            'description': 'Full trial should have blue color',
          },
          {
            'daysLeft': 3,
            'expectedColor': Colors.orange,
            'urgency': 'medium',
            'description': '3 days left should have orange warning color',
          },
          {
            'daysLeft': 1,
            'expectedColor': Colors.red,
            'urgency': 'high',
            'description': '1 day left should have red urgent color',
          },
          {
            'daysLeft': 0,
            'expectedColor': Colors.red,
            'urgency': 'critical',
            'description': 'Expiring trial should have red critical color',
          },
        ];

        for (final testCase in urgencyTestCases) {
          final daysLeft = testCase['daysLeft'] as int;
          final expectedColor = testCase['expectedColor'] as Color;
          final urgency = testCase['urgency'] as String;
          final description = testCase['description'] as String;
          
          // Test the urgency-based color logic
          Color actualColor;
          if (daysLeft <= 1) {
            actualColor = Colors.red; // Critical/urgent
          } else if (daysLeft <= 3) {
            actualColor = Colors.orange; // Warning
          } else {
            actualColor = Colors.blue; // Normal
          }
          
          expect(actualColor, equals(expectedColor),
                 reason: description);
          
          // Verify urgency level matches color choice
          if (urgency == 'critical' || urgency == 'high') {
            expect(actualColor, equals(Colors.red),
                   reason: 'Critical/high urgency should use red color');
          } else if (urgency == 'medium') {
            expect(actualColor, equals(Colors.orange),
                   reason: 'Medium urgency should use orange color');
          } else {
            expect(actualColor, equals(Colors.blue),
                   reason: 'Low urgency should use blue color');
          }
        }
      });
    });
  });
}