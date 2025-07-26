import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;

import '../utils/test_helpers.dart';
import '../mocks/firebase_mocks.dart';

/// Base class for all unit tests with common setup and utilities
abstract class BaseUnitTest {
  late auth_mocks.MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore mockFirestore;
  late auth_mocks.MockUser mockUser;

  /// Setup method called before each test
  @mustCallSuper
  void setUp() {
    // Create mock Firebase services
    mockUser = FirebaseMockFactory.createMockUser();
    mockAuth = FirebaseMockFactory.createMockAuth(currentUser: mockUser);
    mockFirestore = FirebaseMockFactory.createMockFirestore();
  }

  /// Teardown method called after each test
  @mustCallSuper
  void tearDown() {
    // Clean up resources if needed
  }

  /// Helper method to create authenticated user scenario
  void setUpAuthenticatedUser({
    String uid = 'test-uid-123',
    String email = 'test@example.com',
    bool emailVerified = true,
  }) {
    mockUser = FirebaseMockFactory.createMockUser(
      uid: uid,
      email: email,
      isEmailVerified: emailVerified,
    );
    mockAuth = FirebaseMockFactory.createMockAuth(currentUser: mockUser);
  }

  /// Helper method to create unauthenticated user scenario
  void setUpUnauthenticatedUser() {
    mockAuth = FirebaseMockFactory.createMockAuth(currentUser: null);
  }

  /// Helper method to simulate authentication errors
  void setUpAuthenticationError({
    bool signInError = false,
    bool signUpError = false,
    bool signOutError = false,
  }) {
    mockAuth = FirebaseMockFactory.createMockAuth(
      shouldThrowOnSignIn: signInError,
      shouldThrowOnSignUp: signUpError,
      shouldThrowOnSignOut: signOutError,
    );
  }
}

/// Base class for all widget tests with common setup and utilities
abstract class BaseWidgetTest {
  late auth_mocks.MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore mockFirestore;
  late auth_mocks.MockUser mockUser;

  /// Setup method called before each test
  @mustCallSuper
  void setUp() {
    mockUser = FirebaseMockFactory.createMockUser();
    mockAuth = FirebaseMockFactory.createMockAuth(currentUser: mockUser);
    mockFirestore = FirebaseMockFactory.createMockFirestore();
  }

  /// Teardown method called after each test
  @mustCallSuper
  void tearDown() {
    // Clean up resources if needed
  }

  /// Creates a test widget with all necessary providers
  Widget createTestWidget({
    required Widget child,
    FirebaseAuth? customAuth,
    FirebaseFirestore? customFirestore,
  }) {
    return TestHelpers.createTestWidget(
      child: child,
      mockAuth: customAuth ?? mockAuth,
      mockFirestore: customFirestore ?? mockFirestore,
    );
  }

  /// Pumps the widget and waits for animations to complete
  Future<void> pumpAndSettle(WidgetTester tester) async {
    await TestHelpers.pumpAndSettle(tester);
  }

  /// Helper method to enter text in a form field
  Future<void> enterText(
    WidgetTester tester,
    String key,
    String text,
  ) async {
    await tester.enterText(find.byKey(Key(key)), text);
    await pumpAndSettle(tester);
  }

  /// Helper method to tap a widget
  Future<void> tapWidget(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await pumpAndSettle(tester);
  }

  /// Helper method to verify widget visibility
  void expectWidgetVisible(Finder finder) {
    TestHelpers.expectWidgetExists(finder);
  }

  /// Helper method to verify widget is not visible
  void expectWidgetNotVisible(Finder finder) {
    TestHelpers.expectWidgetNotExists(finder);
  }
}

/// Base class for integration tests with common setup
abstract class BaseIntegrationTest {
  late auth_mocks.MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore mockFirestore;

  /// Setup method called before each test
  @mustCallSuper
  void setUp() {
    mockAuth = FirebaseMockFactory.createMockAuth();
    mockFirestore = FirebaseMockFactory.createMockFirestore(withTestData: true);
  }

  /// Teardown method called after each test
  @mustCallSuper
  void tearDown() {
    // Clean up resources if needed
  }

  /// Creates the main app widget for integration testing
  Widget createApp() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: mockFirestore),
        ],
        child: const Scaffold(
          body: Center(
            child: Text('Integration Test App'),
          ),
        ),
      ),
    );
  }

  /// Simulates complete user registration flow
  Future<void> simulateUserRegistration(
    WidgetTester tester, {
    String email = 'test@example.com',
    String password = 'testPassword123',
    String username = 'testuser',
  }) async {
    // Implementation will be added when we create actual registration screens
    // This is a placeholder for the integration test pattern
  }

  /// Simulates complete user login flow
  Future<void> simulateUserLogin(
    WidgetTester tester, {
    String email = 'test@example.com',
    String password = 'testPassword123',
  }) async {
    // Implementation will be added when we create actual login screens
    // This is a placeholder for the integration test pattern
  }
}

/// Test group utilities for organizing tests
class TestGroups {
  /// Creates a test group for authentication tests
  static void authenticationTests(String description, Function() body) {
    group('🔐 Authentication Tests - $description', body);
  }

  /// Creates a test group for subscription tests
  static void subscriptionTests(String description, Function() body) {
    group('💳 Subscription Tests - $description', body);
  }

  /// Creates a test group for UI tests
  static void uiTests(String description, Function() body) {
    group('🎨 UI Tests - $description', body);
  }

  /// Creates a test group for integration tests
  static void integrationTests(String description, Function() body) {
    group('🔗 Integration Tests - $description', body);
  }

  /// Creates a test group for performance tests
  static void performanceTests(String description, Function() body) {
    group('⚡ Performance Tests - $description', body);
  }
}

/// Test assertions with descriptive messages
class TestAssertions {
  /// Asserts that authentication was successful
  static void assertAuthenticationSuccess(User? user) {
    expect(user, isNotNull, reason: 'User should be authenticated');
    expect(user!.email, isNotEmpty, reason: 'User email should not be empty');
  }

  /// Asserts that authentication failed
  static void assertAuthenticationFailure(User? user) {
    expect(user, isNull, reason: 'User should not be authenticated');
  }

  /// Asserts that email verification was sent
  static void assertEmailVerificationSent(bool sent) {
    expect(sent, isTrue, reason: 'Email verification should be sent');
  }

  /// Asserts that trial was created successfully
  static void assertTrialCreated(Map<String, dynamic>? trialData) {
    expect(trialData, isNotNull, reason: 'Trial data should exist');
    expect(trialData!['trialStartDate'], isNotNull, reason: 'Trial start date should be set');
    expect(trialData['trialEndDate'], isNotNull, reason: 'Trial end date should be set');
  }

  /// Asserts that subscription is active
  static void assertSubscriptionActive(Map<String, dynamic>? subscriptionData) {
    expect(subscriptionData, isNotNull, reason: 'Subscription data should exist');
    expect(subscriptionData!['isActive'], isTrue, reason: 'Subscription should be active');
  }
}