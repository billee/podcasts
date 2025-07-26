import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'test_config.dart';
import 'utils/test_helpers.dart';
import 'mocks/firebase_mocks.dart';
import 'base/base_test.dart';

/// Test to verify that our testing infrastructure is working correctly
void main() {
  setUpAll(() async {
    await TestConfig.initialize();
  });

  tearDownAll(() async {
    await TestConfig.cleanup();
  });

  group('🧪 Testing Infrastructure Verification', () {
    test('should create mock Firebase Auth successfully', () {
      // Arrange
      final mockAuth = FirebaseMockFactory.createMockAuth();
      
      // Act & Assert
      expect(mockAuth, isNotNull);
      expect(mockAuth, isA<FirebaseAuth>());
    });

    test('should create mock Firestore successfully', () {
      // Arrange
      final mockFirestore = FirebaseMockFactory.createMockFirestore();
      
      // Act & Assert
      expect(mockFirestore, isNotNull);
      expect(mockFirestore, isA<FirebaseFirestore>());
    });

    test('should create mock user with correct properties', () {
      // Arrange
      const testEmail = 'test@example.com';
      const testUid = 'test-uid-123';
      
      // Act
      final mockUser = FirebaseMockFactory.createMockUser(
        uid: testUid,
        email: testEmail,
        isEmailVerified: true,
      );
      
      // Assert
      expect(mockUser.uid, equals(testUid));
      expect(mockUser.email, equals(testEmail));
      expect(mockUser.emailVerified, isTrue);
    });

    test('should create test data helpers successfully', () {
      // Act
      final userData = TestHelpers.createTestUserData(
        email: 'test@example.com',
        username: 'testuser',
        emailVerified: true,
      );
      
      // Assert
      expect(userData['email'], equals('test@example.com'));
      expect(userData['username'], equals('testuser'));
      expect(userData['emailVerified'], isTrue);
      expect(userData['createdAt'], isA<DateTime>());
    });

    test('should create trial data helpers successfully', () {
      // Act
      final trialData = TestHelpers.createTestTrialData(
        email: 'test@example.com',
        userId: 'test-uid-123',
      );
      
      // Assert
      expect(trialData['email'], equals('test@example.com'));
      expect(trialData['userId'], equals('test-uid-123'));
      expect(trialData['trialStartDate'], isA<DateTime>());
      expect(trialData['trialEndDate'], isA<DateTime>());
      
      // Verify trial is 7 days long
      final startDate = trialData['trialStartDate'] as DateTime;
      final endDate = trialData['trialEndDate'] as DateTime;
      final difference = endDate.difference(startDate).inDays;
      expect(difference, equals(7));
    });

    test('should create subscription data helpers successfully', () {
      // Act
      final subscriptionData = TestHelpers.createTestSubscriptionData(
        email: 'test@example.com',
        isActive: true,
        monthlyPrice: 3.0,
      );
      
      // Assert
      expect(subscriptionData['email'], equals('test@example.com'));
      expect(subscriptionData['isActive'], isTrue);
      expect(subscriptionData['monthlyPrice'], equals(3.0));
      expect(subscriptionData['subscriptionStartDate'], isA<DateTime>());
      expect(subscriptionData['subscriptionEndDate'], isA<DateTime>());
    });

    test('should validate email format correctly', () {
      // Valid emails
      expect(TestMatchers.isValidEmail('test@example.com'), isTrue);
      expect(TestMatchers.isValidEmail('user.name@domain.co.uk'), isTrue);
      expect(TestMatchers.isValidEmail('test123@test-domain.org'), isTrue);
      
      // Invalid emails
      expect(TestMatchers.isValidEmail('invalid-email'), isFalse);
      expect(TestMatchers.isValidEmail('test@'), isFalse);
      expect(TestMatchers.isValidEmail('@domain.com'), isFalse);
      expect(TestMatchers.isValidEmail('test.domain.com'), isFalse);
    });

    test('should validate password strength correctly', () {
      // Strong passwords
      expect(TestMatchers.isStrongPassword('TestPassword123'), isTrue);
      expect(TestMatchers.isStrongPassword('MySecure1Pass'), isTrue);
      expect(TestMatchers.isStrongPassword('Complex9Password'), isTrue);
      
      // Weak passwords
      expect(TestMatchers.isStrongPassword('weak'), isFalse);
      expect(TestMatchers.isStrongPassword('nouppercaseornumbers'), isFalse);
      expect(TestMatchers.isStrongPassword('NOLOWERCASEORNUMBERS'), isFalse);
      expect(TestMatchers.isStrongPassword('NoNumbers'), isFalse);
      expect(TestMatchers.isStrongPassword('nonumbers1'), isFalse);
    });

    test('should generate unique test identifiers', () async {
      // Act
      final email1 = TestUtils.generateTestEmail();
      await Future.delayed(const Duration(milliseconds: 1)); // Ensure different timestamps
      final email2 = TestUtils.generateTestEmail();
      
      final username1 = TestUtils.generateTestUsername();
      await Future.delayed(const Duration(milliseconds: 1));
      final username2 = TestUtils.generateTestUsername();
      
      final uid1 = TestUtils.generateTestUid();
      await Future.delayed(const Duration(milliseconds: 1));
      final uid2 = TestUtils.generateTestUid();
      
      // Assert - all should be unique
      expect(email1, isNot(equals(email2)));
      expect(username1, isNot(equals(username2)));
      expect(uid1, isNot(equals(uid2)));
      
      // Assert - should follow expected format
      expect(email1, contains('@example.com'));
      expect(username1, startsWith('testuser'));
      expect(uid1, startsWith('test-uid-'));
    });

    test('should create Firebase exception scenarios', () {
      // Act & Assert
      expect(FirebaseExceptionScenarios.userNotFound.code, equals('user-not-found'));
      expect(FirebaseExceptionScenarios.wrongPassword.code, equals('wrong-password'));
      expect(FirebaseExceptionScenarios.emailAlreadyInUse.code, equals('email-already-in-use'));
      expect(FirebaseExceptionScenarios.weakPassword.code, equals('weak-password'));
      expect(FirebaseExceptionScenarios.invalidEmail.code, equals('invalid-email'));
      expect(FirebaseExceptionScenarios.networkRequestFailed.code, equals('network-request-failed'));
    });
  });

  group('🏗️ Base Test Classes', () {
    test('BaseUnitTest should initialize correctly', () {
      // Arrange
      final testClass = _TestUnitTestClass();
      
      // Act
      testClass.setUp();
      
      // Assert
      expect(testClass.mockAuth, isNotNull);
      expect(testClass.mockFirestore, isNotNull);
      expect(testClass.mockUser, isNotNull);
    });

    test('BaseUnitTest should set up authenticated user scenario', () {
      // Arrange
      final testClass = _TestUnitTestClass();
      testClass.setUp();
      
      // Act
      testClass.setUpAuthenticatedUser(
        uid: 'custom-uid',
        email: 'custom@example.com',
        emailVerified: true,
      );
      
      // Assert
      expect(testClass.mockUser.uid, equals('custom-uid'));
      expect(testClass.mockUser.email, equals('custom@example.com'));
      expect(testClass.mockUser.emailVerified, isTrue);
    });

    test('BaseUnitTest should set up unauthenticated user scenario', () {
      // Arrange
      final testClass = _TestUnitTestClass();
      testClass.setUp();
      
      // Act
      testClass.setUpUnauthenticatedUser();
      
      // Assert
      expect(testClass.mockAuth.currentUser, isNull);
    });
  });

  group('📊 Test Assertions', () {
    test('should assert authentication success correctly', () {
      // Arrange
      final mockUser = FirebaseMockFactory.createMockUser(
        email: 'test@example.com',
      );
      
      // Act & Assert - should not throw
      expect(() => TestAssertions.assertAuthenticationSuccess(mockUser), 
             returnsNormally);
    });

    test('should assert authentication failure correctly', () {
      // Act & Assert - should not throw
      expect(() => TestAssertions.assertAuthenticationFailure(null), 
             returnsNormally);
    });

    test('should assert trial creation correctly', () {
      // Arrange
      final trialData = TestHelpers.createTestTrialData();
      
      // Act & Assert - should not throw
      expect(() => TestAssertions.assertTrialCreated(trialData), 
             returnsNormally);
    });

    test('should assert subscription activation correctly', () {
      // Arrange
      final subscriptionData = TestHelpers.createTestSubscriptionData(
        isActive: true,
      );
      
      // Act & Assert - should not throw
      expect(() => TestAssertions.assertSubscriptionActive(subscriptionData), 
             returnsNormally);
    });
  });
}

/// Test implementation of BaseUnitTest for testing the base class
class _TestUnitTestClass extends BaseUnitTest {
  // This class is used to test the BaseUnitTest functionality
  // It inherits all the setup and utility methods
}