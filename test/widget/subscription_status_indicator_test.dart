import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:kapwa_companion_basic/widgets/subscription_status_indicator.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';

void main() {
  group('SubscriptionStatusIndicator', () {
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

    testWidgets('shows loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubscriptionStatusIndicator(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows trial indicator for trial user', (WidgetTester tester) async {
      // Setup trial user data
      await fakeFirestore.collection('users').doc('test_user_123').set({
        'email': 'test@example.com',
        'emailVerified': true,
      });

      final trialEndDate = DateTime.now().add(const Duration(days: 5));
      await fakeFirestore.collection('trial_history').add({
        'userId': 'test_user_123',
        'email': 'test@example.com',
        'trialEndDate': trialEndDate,
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubscriptionStatusIndicator(),
          ),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      expect(find.text('5d'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('shows premium indicator for subscribed user', (WidgetTester tester) async {
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
            body: SubscriptionStatusIndicator(),
          ),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      expect(find.text('PRO'), findsOneWidget);
      expect(find.byIcon(Icons.diamond), findsOneWidget);
    });

    testWidgets('shows nothing when user is not logged in', (WidgetTester tester) async {
      // Create a new auth instance with no user
      final noUserAuth = MockFirebaseAuth(signedIn: false);
      SubscriptionService.setAuthInstance(noUserAuth);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubscriptionStatusIndicator(),
          ),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsNothing);
      expect(find.text('5d'), findsNothing);
      expect(find.text('PRO'), findsNothing);
    });

    testWidgets('shows expired indicator for expired user', (WidgetTester tester) async {
      // Setup expired user data
      await fakeFirestore.collection('users').doc('test_user_123').set({
        'email': 'test@example.com',
        'emailVerified': true,
      });

      // No active subscription or trial

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubscriptionStatusIndicator(),
          ),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      expect(find.text('EXPIRED'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });
  });
}