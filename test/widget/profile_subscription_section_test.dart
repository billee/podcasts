import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:kapwa_companion_basic/widgets/profile_subscription_section.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';

void main() {
  group('ProfileSubscriptionSection', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockUser = MockUser(
        uid: 'test_user_123',
        email: 'test@example.com',
        isEmailVerified: true,
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      
      SubscriptionService.setFirestoreInstance(fakeFirestore);
      SubscriptionService.setAuthInstance(mockAuth);
    });

    testWidgets('shows loading state initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileSubscriptionSection(),
          ),
        ),
      );

      expect(find.text('Subscription Status'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows trial status for trial user', (WidgetTester tester) async {
      // Setup trial user data
      await fakeFirestore.collection('users').doc('test_user_123').set({
        'email': 'test@example.com',
        'emailVerified': true,
      });

      final trialEndDate = DateTime.now().add(const Duration(days: 3));
      await fakeFirestore.collection('trial_history').add({
        'userId': 'test_user_123',
        'email': 'test@example.com',
        'trialEndDate': trialEndDate,
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileSubscriptionSection(),
          ),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      expect(find.text('Trial Status'), findsOneWidget);
      expect(find.text('Trial Active'), findsOneWidget);
      expect(find.text('3 days remaining'), findsOneWidget);
      expect(find.text('Subscribe Now'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('shows subscription status for premium user', (WidgetTester tester) async {
      // Setup subscribed user data
      await fakeFirestore.collection('users').doc('test_user_123').set({
        'email': 'test@example.com',
        'emailVerified': true,
      });

      final subscriptionEndDate = DateTime.now().add(const Duration(days: 30));
      await fakeFirestore.collection('subscriptions').doc('test_user_123').set({
        'userId': 'test_user_123',
        'email': 'test@example.com',
        'status': 'active',
        'plan': 'monthly',
        'subscriptionEndDate': subscriptionEndDate,
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileSubscriptionSection(),
          ),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      expect(find.text('Subscription Status'), findsOneWidget);
      expect(find.text('Premium Subscriber'), findsOneWidget);
      expect(find.text('You have full access to all premium features.'), findsOneWidget);
      expect(find.text('Manage Subscription'), findsOneWidget);
      expect(find.byIcon(Icons.diamond), findsOneWidget);
    });

    testWidgets('shows warning for trial ending soon', (WidgetTester tester) async {
      // Setup trial user with 1 day left
      await fakeFirestore.collection('users').doc('test_user_123').set({
        'email': 'test@example.com',
        'emailVerified': true,
      });

      final trialEndDate = DateTime.now().add(const Duration(days: 1));
      await fakeFirestore.collection('trial_history').add({
        'userId': 'test_user_123',
        'email': 'test@example.com',
        'trialEndDate': trialEndDate,
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileSubscriptionSection(),
          ),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      expect(find.text('Trial Status'), findsOneWidget);
      expect(find.text('1 day remaining'), findsOneWidget);
      expect(find.textContaining('Your trial is ending soon'), findsOneWidget);
    });

    testWidgets('shows expired status for expired user', (WidgetTester tester) async {
      // Setup expired user data
      await fakeFirestore.collection('users').doc('test_user_123').set({
        'email': 'test@example.com',
        'emailVerified': true,
      });

      // No active subscription or trial

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileSubscriptionSection(),
          ),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      expect(find.text('Account Status'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Your access to premium features has expired.'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('handles no user logged in', (WidgetTester tester) async {
      // Create a new auth instance with no user
      final noUserAuth = MockFirebaseAuth(signedIn: false);
      SubscriptionService.setAuthInstance(noUserAuth);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileSubscriptionSection(),
          ),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      expect(find.text('Subscription Status'), findsOneWidget);
      expect(find.text('Unable to load subscription information'), findsOneWidget);
    });
  });
}