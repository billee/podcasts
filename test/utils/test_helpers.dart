import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;

/// Test utilities and helpers for consistent testing patterns
class TestHelpers {
  /// Creates a test widget with necessary providers and dependencies
  static Widget createTestWidget({
    required Widget child,
    FirebaseAuth? mockAuth,
    FirebaseFirestore? mockFirestore,
  }) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          // Add providers here as needed for testing
          Provider<FirebaseAuth>.value(
            value: mockAuth ?? auth_mocks.MockFirebaseAuth(),
          ),
          Provider<FirebaseFirestore>.value(
            value: mockFirestore ?? FakeFirebaseFirestore(),
          ),
        ],
        child: child,
      ),
    );
  }

  /// Creates a mock user for testing authentication flows
  static auth_mocks.MockUser createMockUser({
    String uid = 'test-uid-123',
    String email = 'test@example.com',
    bool emailVerified = true,
    String displayName = 'Test User',
  }) {
    return auth_mocks.MockUser(
      uid: uid,
      email: email,
      displayName: displayName,
      isEmailVerified: emailVerified,
    );
  }

  /// Creates test data for Firestore collections
  static Map<String, dynamic> createTestUserData({
    String? uid,
    String? email,
    String? username,
    bool emailVerified = false,
    DateTime? createdAt,
  }) {
    return {
      'uid': uid ?? 'test-uid-123',
      'email': email ?? 'test@example.com',
      'username': username ?? 'testuser',
      'emailVerified': emailVerified,
      'createdAt': createdAt ?? DateTime.now(),
      'lastLoginAt': DateTime.now(),
    };
  }

  /// Creates test trial history data
  static Map<String, dynamic> createTestTrialData({
    String? userId,
    String? email,
    DateTime? trialStartDate,
    DateTime? trialEndDate,
  }) {
    final now = DateTime.now();
    return {
      'userId': userId ?? 'test-uid-123',
      'email': email ?? 'test@example.com',
      'trialStartDate': trialStartDate ?? now,
      'trialEndDate': trialEndDate ?? now.add(const Duration(days: 7)),
      'createdAt': now,
    };
  }

  /// Creates test subscription data
  static Map<String, dynamic> createTestSubscriptionData({
    String? email,
    bool isActive = true,
    bool cancelled = false,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    double monthlyPrice = 3.0,
  }) {
    final now = DateTime.now();
    return {
      'email': email ?? 'test@example.com',
      'isActive': isActive,
      'cancelled': cancelled,
      'subscriptionStartDate': subscriptionStartDate ?? now,
      'subscriptionEndDate': subscriptionEndDate ?? now.add(const Duration(days: 30)),
      'monthlyPrice': monthlyPrice,
      'willExpireAt': cancelled ? now.add(const Duration(days: 30)) : null,
    };
  }

  /// Waits for async operations to complete in tests
  static Future<void> pumpAndSettle(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  /// Finds widgets by text with error handling
  static Finder findTextSafely(String text) {
    try {
      return find.text(text);
    } catch (e) {
      return find.byKey(Key('text-$text'));
    }
  }

  /// Finds widgets by key with error handling
  static Finder findKeySafely(String key) {
    return find.byKey(Key(key));
  }

  /// Verifies that a widget exists and is visible
  static void expectWidgetExists(Finder finder) {
    expect(finder, findsOneWidget);
  }

  /// Verifies that a widget does not exist
  static void expectWidgetNotExists(Finder finder) {
    expect(finder, findsNothing);
  }

  /// Creates a test context for services that need BuildContext
  static BuildContext createTestContext() {
    return MockBuildContext();
  }
}

/// Mock BuildContext for testing services
class MockBuildContext extends Mock implements BuildContext {}

/// Test constants for consistent testing
class TestConstants {
  static const String testEmail = 'test@example.com';
  static const String testPassword = 'testPassword123';
  static const String testUsername = 'testuser';
  static const String testUid = 'test-uid-123';
  
  // Test error messages
  static const String invalidEmailError = 'Invalid email format';
  static const String weakPasswordError = 'Password is too weak';
  static const String emailAlreadyInUseError = 'Email is already in use';
  
  // Test success messages
  static const String registrationSuccessMessage = 'Registration successful';
  static const String loginSuccessMessage = 'Login successful';
  static const String emailVerificationSentMessage = 'Verification email sent';
}

/// Custom matchers for testing
class TestMatchers {
  /// Matches email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Matches strong password
  static bool isStrongPassword(String password) {
    return password.length >= 8 && 
           password.contains(RegExp(r'[A-Z]')) &&
           password.contains(RegExp(r'[a-z]')) &&
           password.contains(RegExp(r'[0-9]'));
  }
}