import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:kapwa_companion_basic/screens/subscription/subscription_management_screen.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';

void main() {
  group('SubscriptionManagementScreen Widget Tests', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;
    late MockUser mockUser;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = FakeFirebaseFirestore();
      mockUser = MockUser(
        uid: 'test-user-id',
        email: 'test@example.com',
        displayName: 'Test User',
        isEmailVerified: true,
      );

      // Set up dependency injection for testing
      SubscriptionService.setAuthInstance(mockAuth);
      SubscriptionService.setFirestoreInstance(mockFirestore);
    });

    testWidgets('displays loading state initially', (WidgetTester tester) async {
      // Sign in the mock user
      await mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: const SubscriptionManagementScreen(),
        ),
      );

      // Should show loading initially
      expect(find.text('Loading subscription details...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays subscription management UI after loading', (WidgetTester tester) async {
      // Sign in the mock user
      await mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      // Set up user document
      await mockFirestore.collection('users').doc('test-user-id').set({
        'email': 'test@example.com',
        'emailVerified': true,
        'createdAt': DateTime.now(),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: const SubscriptionManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Should show subscription management UI
      expect(find.text('Current Plan'), findsOneWidget);
      expect(find.text('Plan Details'), findsOneWidget);
      expect(find.text('Available Plans'), findsOneWidget);
      expect(find.text('Manage Subscription'), findsOneWidget);
    });

    testWidgets('displays trial status correctly', (WidgetTester tester) async {
      // Sign in the mock user
      await mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      // Set up user document
      await mockFirestore.collection('users').doc('test-user-id').set({
        'email': 'test@example.com',
        'emailVerified': true,
        'createdAt': DateTime.now(),
      });

      // Set up trial history
      final trialEndDate = DateTime.now().add(const Duration(days: 5));
      await mockFirestore.collection('trial_history').add({
        'userId': 'test-user-id',
        'email': 'test@example.com',
        'trialStartDate': DateTime.now().subtract(const Duration(days: 2)),
        'trialEndDate': trialEndDate,
        'createdAt': DateTime.now(),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: const SubscriptionManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Should show trial information
      expect(find.text('Free Trial'), findsOneWidget);
      expect(find.text('TRIAL ACTIVE'), findsOneWidget);
      expect(find.text('Upgrade to Premium'), findsOneWidget);
    });

    testWidgets('displays premium subscription status correctly', (WidgetTester tester) async {
      // Sign in the mock user
      await mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      // Set up user document
      await mockFirestore.collection('users').doc('test-user-id').set({
        'email': 'test@example.com',
        'emailVerified': true,
        'createdAt': DateTime.now(),
      });

      // Set up active subscription
      final subscriptionEndDate = DateTime.now().add(const Duration(days: 30));
      await mockFirestore.collection('subscriptions').doc('test-user-id').set({
        'userId': 'test-user-id',
        'email': 'test@example.com',
        'status': 'active',
        'plan': 'monthly',
        'price': 3.0,
        'subscriptionStartDate': DateTime.now().subtract(const Duration(days: 5)),
        'subscriptionEndDate': subscriptionEndDate,
        'nextBillingDate': subscriptionEndDate,
        'createdAt': DateTime.now(),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: const SubscriptionManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Should show premium subscription information
      expect(find.text('Premium Monthly'), findsOneWidget);
      expect(find.text('PREMIUM ACTIVE'), findsOneWidget);
      expect(find.text('Cancel Subscription'), findsOneWidget);
      expect(find.text('\$3.00'), findsOneWidget);
    });

    testWidgets('shows upgrade button for trial users', (WidgetTester tester) async {
      // Sign in the mock user
      await mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      // Set up user document
      await mockFirestore.collection('users').doc('test-user-id').set({
        'email': 'test@example.com',
        'emailVerified': true,
        'createdAt': DateTime.now(),
      });

      // Set up trial history
      final trialEndDate = DateTime.now().add(const Duration(days: 3));
      await mockFirestore.collection('trial_history').add({
        'userId': 'test-user-id',
        'email': 'test@example.com',
        'trialStartDate': DateTime.now().subtract(const Duration(days: 4)),
        'trialEndDate': trialEndDate,
        'createdAt': DateTime.now(),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: const SubscriptionManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Should show upgrade button
      expect(find.text('Upgrade to Premium'), findsOneWidget);
      expect(find.byIcon(Icons.upgrade), findsOneWidget);
    });

    testWidgets('shows cancel button for active subscribers', (WidgetTester tester) async {
      // Sign in the mock user
      await mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      // Set up user document
      await mockFirestore.collection('users').doc('test-user-id').set({
        'email': 'test@example.com',
        'emailVerified': true,
        'createdAt': DateTime.now(),
      });

      // Set up active subscription
      final subscriptionEndDate = DateTime.now().add(const Duration(days: 25));
      await mockFirestore.collection('subscriptions').doc('test-user-id').set({
        'userId': 'test-user-id',
        'email': 'test@example.com',
        'status': 'active',
        'plan': 'monthly',
        'price': 3.0,
        'subscriptionStartDate': DateTime.now().subtract(const Duration(days: 5)),
        'subscriptionEndDate': subscriptionEndDate,
        'nextBillingDate': subscriptionEndDate,
        'createdAt': DateTime.now(),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: const SubscriptionManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Should show cancel button
      expect(find.text('Cancel Subscription'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });

    testWidgets('displays plan features correctly', (WidgetTester tester) async {
      // Sign in the mock user
      await mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      // Set up user document
      await mockFirestore.collection('users').doc('test-user-id').set({
        'email': 'test@example.com',
        'emailVerified': true,
        'createdAt': DateTime.now(),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: const SubscriptionManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Should show premium plan features
      expect(find.text('Unlimited AI Chat'), findsOneWidget);
      expect(find.text('Access to All Stories'), findsOneWidget);
      expect(find.text('Premium Podcast Content'), findsOneWidget);
      expect(find.text('Priority Support'), findsOneWidget);
      expect(find.text('No Ads'), findsOneWidget);
      expect(find.text('Offline Content Access'), findsOneWidget);
    });

    testWidgets('refresh functionality works', (WidgetTester tester) async {
      // Sign in the mock user
      await mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      // Set up user document
      await mockFirestore.collection('users').doc('test-user-id').set({
        'email': 'test@example.com',
        'emailVerified': true,
        'createdAt': DateTime.now(),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: const SubscriptionManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Perform pull-to-refresh
      await tester.fling(find.byType(RefreshIndicator), const Offset(0, 300), 1000);
      await tester.pump();

      // Should show refresh indicator
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}