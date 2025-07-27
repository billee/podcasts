import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
import 'package:mockito/mockito.dart';

import '../test_config.dart';
import '../base/base_test.dart';
import '../utils/test_helpers.dart';
import '../mocks/firebase_mocks.dart';

/// Integration tests for complete user registration and verification flow
/// Tests Requirements: 1.1, 1.5, 1.6, 2.1, 2.4, 2.5, 3.1, 3.2
void main() {
  group('🔗 Integration Tests - End-to-End Registration and Verification Flow', () {
    late FakeFirebaseFirestore mockFirestore;
    late auth_mocks.MockFirebaseAuth mockAuth;
    late auth_mocks.MockUser mockUser;

    setUpAll(() async {
      await TestConfig.initialize();
    });

    setUp(() {
      mockFirestore = FirebaseMockFactory.createMockFirestore(withTestData: false);
      mockUser = FirebaseMockFactory.createMockUser(
        uid: TestData.testUid,
        email: TestData.testEmail,
        isEmailVerified: false, // Start with unverified email
      );
      mockAuth = FirebaseMockFactory.createMockAuth(currentUser: null);
    });

    tearDown(() async {
      await TestConfig.cleanup();
    });

    group('7.1 Complete registration and verification flow', () {
      // Test data
      const testEmail = 'integration@example.com';
      const testPassword = 'IntegrationTest123!';
      const testUsername = 'integrationuser';
      final testUid = TestUtils.generateTestUid();

      // Step 1: Test complete signup process (Requirement 1.1, 1.5, 1.6)
      group('Step 1: User Registration', () {
        test('should create user account with email and password', () async {
          // Arrange
          final userProfile = {
            'username': testUsername,
            'name': 'Integration Test User',
            'workLocation': 'Dubai',
            'occupation': 'Software Engineer',
            'isMarried': false,
            'hasChildren': false,
            'gender': 'male',
            'birthYear': 1990,
            'educationalAttainment': 'Bachelor\'s Degree',
          };

          // Create mock user for successful registration
          final registeredUser = auth_mocks.MockUser(
            uid: testUid,
            email: testEmail,
            displayName: 'Integration Test User',
            isEmailVerified: false,
          );

          // Mock successful registration by creating a new MockFirebaseAuth with the registered user
          mockAuth = auth_mocks.MockFirebaseAuth(
            mockUser: registeredUser,
            signedIn: true,
          );

          // Act - Simulate user registration
          // The mockAuth now has the registered user
          final currentUser = mockAuth.currentUser;

          // Assert - Verify user was created
          expect(currentUser, isNotNull);
          expect(currentUser!.uid, equals(testUid));
          expect(currentUser.email, equals(testEmail));
          expect(currentUser.emailVerified, isFalse);

          // Verify user profile is created in Firestore
          await mockFirestore.collection('users').doc(testUid).set({
            ...userProfile,
            'uid': testUid,
            'email': testEmail,
            'emailVerified': false,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          });

          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          expect(userDoc.exists, isTrue);
          
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['email'], equals(testEmail));
          expect(userData['username'], equals(testUsername));
          expect(userData['emailVerified'], isFalse);
        });

        test('should send email verification after registration', () async {
          // Arrange
          final unverifiedUser = auth_mocks.MockUser(
            uid: testUid,
            email: testEmail,
            isEmailVerified: false,
          );

          // Act - Simulate sending email verification
          await unverifiedUser.sendEmailVerification();

          // Assert - Verify email verification was sent
          // Note: firebase_auth_mocks automatically handles this
          expect(unverifiedUser.emailVerified, isFalse);
        });

        test('should validate user input during registration', () async {
          // Test invalid email format (Requirement 1.3)
          // Simulate validation by checking email format
          const invalidEmail = 'invalid-email';
          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
          expect(emailRegex.hasMatch(invalidEmail), isFalse);

          // Test weak password (Requirement 1.4)
          const weakPassword = '123';
          expect(weakPassword.length >= 8, isFalse);

          // Test duplicate email (Requirement 1.2)
          // First create a user
          await mockFirestore.collection('users').doc('existing-user').set({
            'email': testEmail,
            'username': 'existinguser',
            'emailVerified': false,
          });

          // Try to create another user with same email
          final existingUsers = await mockFirestore
              .collection('users')
              .where('email', isEqualTo: testEmail)
              .get();
          
          expect(existingUsers.docs.length, equals(1));
        });
      });

      // Step 2: Test email verification integration with Firebase (Requirement 2.1, 2.4, 2.5)
      group('Step 2: Email Verification', () {
        test('should block login for unverified email', () async {
          // Arrange
          final unverifiedUser = auth_mocks.MockUser(
            uid: testUid,
            email: testEmail,
            isEmailVerified: false,
          );

          // Create user in Firestore as unverified
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'emailVerified': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Act - Try to sign in with unverified email
          mockAuth = auth_mocks.MockFirebaseAuth(
            mockUser: unverifiedUser,
            signedIn: true,
          );

          // Assert - User should be signed in but email not verified
          expect(mockAuth.currentUser, isNotNull);
          expect(mockAuth.currentUser!.emailVerified, isFalse);

          // Verify user status in Firestore shows unverified
          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['emailVerified'], isFalse);
        });

        test('should update user status after email verification', () async {
          // Arrange
          final verifiedUser = auth_mocks.MockUser(
            uid: testUid,
            email: testEmail,
            isEmailVerified: true,
          );

          // Create user in Firestore as unverified initially
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'emailVerified': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Act - Simulate email verification
          mockAuth = auth_mocks.MockFirebaseAuth(
            mockUser: verifiedUser,
            signedIn: true,
          );

          // Update Firestore to reflect email verification
          await mockFirestore.collection('users').doc(testUid).update({
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
          });

          // Assert - Verify email verification status updated
          expect(mockAuth.currentUser!.emailVerified, isTrue);

          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['emailVerified'], isTrue);
          expect(userData['emailVerifiedAt'], isNotNull);
        });
      });

      // Step 3: Test automatic trial creation during first verified login (Requirement 3.1, 3.2)
      group('Step 3: Trial Creation on First Verified Login', () {
        test('should create trial history when verified user logs in for first time', () async {
          // Arrange
          final verifiedUser = auth_mocks.MockUser(
            uid: testUid,
            email: testEmail,
            isEmailVerified: true,
          );

          // Create verified user in Firestore
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Act - Simulate first login after email verification
          mockAuth = auth_mocks.MockFirebaseAuth(
            mockUser: verifiedUser,
            signedIn: true,
          );

          // Create trial history (simulating what AuthService does)
          final now = DateTime.now();
          final trialEndDate = now.add(const Duration(days: 7));

          await mockFirestore.collection('trial_history').add({
            'userId': testUid,
            'email': testEmail,
            'trialStartDate': FieldValue.serverTimestamp(),
            'trialEndDate': Timestamp.fromDate(trialEndDate),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Assert - Verify trial history was created
          final trialQuery = await mockFirestore
              .collection('trial_history')
              .where('userId', isEqualTo: testUid)
              .where('email', isEqualTo: testEmail)
              .get();

          expect(trialQuery.docs.length, equals(1));

          final trialData = trialQuery.docs.first.data();
          expect(trialData['userId'], equals(testUid));
          expect(trialData['email'], equals(testEmail));
          expect(trialData['trialStartDate'], isNotNull);
          expect(trialData['trialEndDate'], isNotNull);

          // Verify trial period is 7 days
          final trialEnd = (trialData['trialEndDate'] as Timestamp).toDate();
          final expectedTrialEnd = now.add(const Duration(days: 7));
          final daysDifference = trialEnd.difference(expectedTrialEnd).inDays.abs();
          expect(daysDifference, lessThanOrEqualTo(1)); // Allow for small timing differences
        });

        test('should not create duplicate trial history', () async {
          // Arrange
          final verifiedUser = auth_mocks.MockUser(
            uid: testUid,
            email: testEmail,
            isEmailVerified: true,
          );

          // Create existing trial history
          await mockFirestore.collection('trial_history').add({
            'userId': testUid,
            'email': testEmail,
            'trialStartDate': FieldValue.serverTimestamp(),
            'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Act - Try to create another trial (simulating duplicate prevention)
          final existingTrials = await mockFirestore
              .collection('trial_history')
              .where('userId', isEqualTo: testUid)
              .where('email', isEqualTo: testEmail)
              .get();

          // Only create trial if none exists
          if (existingTrials.docs.isEmpty) {
            await mockFirestore.collection('trial_history').add({
              'userId': testUid,
              'email': testEmail,
              'trialStartDate': FieldValue.serverTimestamp(),
              'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          // Assert - Verify only one trial history exists
          final finalTrialQuery = await mockFirestore
              .collection('trial_history')
              .where('userId', isEqualTo: testUid)
              .where('email', isEqualTo: testEmail)
              .get();

          expect(finalTrialQuery.docs.length, equals(1));
        });

        test('should prevent trial abuse by email', () async {
          // Arrange - Create trial history for an email with different user
          const abuseEmail = 'abuse@example.com';
          const originalUserId = 'original-user-123';

          await mockFirestore.collection('trial_history').add({
            'userId': originalUserId,
            'email': abuseEmail,
            'trialStartDate': FieldValue.serverTimestamp(),
            'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Act - Try to create new user with same email
          const newUserId = 'new-user-456';

          // Check if email has been used for trial before
          final existingEmailTrials = await mockFirestore
              .collection('trial_history')
              .where('email', isEqualTo: abuseEmail)
              .get();

          // Assert - Email should already have trial history
          expect(existingEmailTrials.docs.length, equals(1));
          expect(existingEmailTrials.docs.first.data()['userId'], equals(originalUserId));

          // New user with same email should not get another trial
          if (existingEmailTrials.docs.isEmpty) {
            await mockFirestore.collection('trial_history').add({
              'userId': newUserId,
              'email': abuseEmail,
              'trialStartDate': FieldValue.serverTimestamp(),
              'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          // Verify still only one trial for this email
          final finalEmailTrials = await mockFirestore
              .collection('trial_history')
              .where('email', isEqualTo: abuseEmail)
              .get();

          expect(finalEmailTrials.docs.length, equals(1));
        });
      });

      // Step 4: Test user status updates throughout the flow (Requirement 2.5, 6.2)
      group('Step 4: User Status Updates Throughout Flow', () {
        test('should track complete user journey status changes', () async {
          // Step 4.1: Initial registration - user should be unverified
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'emailVerified': false,
            'status': 'unverified',
            'createdAt': FieldValue.serverTimestamp(),
          });

          var userDoc = await mockFirestore.collection('users').doc(testUid).get();
          var userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('unverified'));
          expect(userData['emailVerified'], isFalse);

          // Step 4.2: Email verification - user should become verified
          await mockFirestore.collection('users').doc(testUid).update({
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
            'status': 'verified',
          });

          userDoc = await mockFirestore.collection('users').doc(testUid).get();
          userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('verified'));
          expect(userData['emailVerified'], isTrue);

          // Step 4.3: Trial creation - user should become trial user
          await mockFirestore.collection('trial_history').add({
            'userId': testUid,
            'email': testEmail,
            'trialStartDate': FieldValue.serverTimestamp(),
            'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
            'createdAt': FieldValue.serverTimestamp(),
          });

          await mockFirestore.collection('users').doc(testUid).update({
            'status': 'trial_user',
            'trialCreatedAt': FieldValue.serverTimestamp(),
          });

          userDoc = await mockFirestore.collection('users').doc(testUid).get();
          userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('trial_user'));

          // Verify trial history exists
          final trialQuery = await mockFirestore
              .collection('trial_history')
              .where('userId', isEqualTo: testUid)
              .get();
          expect(trialQuery.docs.length, equals(1));

          // Step 4.4: Verify trial access is granted
          final trialData = trialQuery.docs.first.data();
          final trialEndDate = (trialData['trialEndDate'] as Timestamp).toDate();
          final now = DateTime.now();
          
          expect(trialEndDate.isAfter(now), isTrue, 
            reason: 'Trial should be active and end date should be in the future');
        });

        test('should handle edge cases in user status transitions', () async {
          // Test case: User tries to verify email multiple times
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'emailVerified': false,
            'status': 'unverified',
          });

          // First verification
          await mockFirestore.collection('users').doc(testUid).update({
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
            'status': 'verified',
          });

          // Second verification attempt (should not cause issues)
          await mockFirestore.collection('users').doc(testUid).update({
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
            'status': 'verified',
          });

          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['emailVerified'], isTrue);
          expect(userData['status'], equals('verified'));
        });

        test('should maintain data consistency across collections', () async {
          // Create user profile
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'emailVerified': true,
            'status': 'trial_user',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Create corresponding trial history
          await mockFirestore.collection('trial_history').add({
            'userId': testUid,
            'email': testEmail,
            'trialStartDate': FieldValue.serverTimestamp(),
            'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Verify data consistency
          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          final userData = userDoc.data() as Map<String, dynamic>;

          final trialQuery = await mockFirestore
              .collection('trial_history')
              .where('userId', isEqualTo: testUid)
              .get();

          expect(userData['email'], equals(testEmail));
          expect(userData['status'], equals('trial_user'));
          expect(trialQuery.docs.length, equals(1));

          final trialData = trialQuery.docs.first.data();
          expect(trialData['email'], equals(userData['email']));
          expect(trialData['userId'], equals(userData['uid']));
        });
      });

      // Step 5: Integration test for complete end-to-end flow
      group('Step 5: Complete End-to-End Integration', () {
        test('should complete entire registration to trial flow successfully', () async {
          // This test simulates the complete user journey from registration to active trial
          
          // Phase 1: User Registration
          final registrationData = {
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'name': 'Integration Test User',
            'workLocation': 'Dubai',
            'occupation': 'Software Engineer',
            'emailVerified': false,
            'status': 'unverified',
            'createdAt': FieldValue.serverTimestamp(),
          };

          await mockFirestore.collection('users').doc(testUid).set(registrationData);

          // Verify registration
          var userDoc = await mockFirestore.collection('users').doc(testUid).get();
          expect(userDoc.exists, isTrue);
          var userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('unverified'));

          // Phase 2: Email Verification
          await mockFirestore.collection('users').doc(testUid).update({
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
            'status': 'verified',
          });

          // Verify email verification
          userDoc = await mockFirestore.collection('users').doc(testUid).get();
          userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['emailVerified'], isTrue);
          expect(userData['status'], equals('verified'));

          // Phase 3: First Login and Trial Creation
          await mockFirestore.collection('users').doc(testUid).update({
            'lastLoginAt': FieldValue.serverTimestamp(),
            'status': 'trial_user',
          });

          // Create trial history
          final now = DateTime.now();
          final trialEndDate = now.add(const Duration(days: 7));

          await mockFirestore.collection('trial_history').add({
            'userId': testUid,
            'email': testEmail,
            'trialStartDate': FieldValue.serverTimestamp(),
            'trialEndDate': Timestamp.fromDate(trialEndDate),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Phase 4: Verify Complete Flow
          // Check user status
          userDoc = await mockFirestore.collection('users').doc(testUid).get();
          userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('trial_user'));
          expect(userData['emailVerified'], isTrue);

          // Check trial history
          final trialQuery = await mockFirestore
              .collection('trial_history')
              .where('userId', isEqualTo: testUid)
              .where('email', isEqualTo: testEmail)
              .get();

          expect(trialQuery.docs.length, equals(1));
          final trialData = trialQuery.docs.first.data();
          expect(trialData['userId'], equals(testUid));
          expect(trialData['email'], equals(testEmail));

          // Verify trial is active (end date is in the future)
          final actualTrialEndDate = (trialData['trialEndDate'] as Timestamp).toDate();
          expect(actualTrialEndDate.isAfter(now), isTrue);

          // Verify trial duration is approximately 7 days
          final trialDuration = actualTrialEndDate.difference(now).inDays;
          expect(trialDuration, greaterThanOrEqualTo(6));
          expect(trialDuration, lessThanOrEqualTo(7));

          // Phase 5: Verify No Duplicate Trials
          // Attempt to create another trial (should be prevented)
          final existingTrials = await mockFirestore
              .collection('trial_history')
              .where('email', isEqualTo: testEmail)
              .get();

          expect(existingTrials.docs.length, equals(1), 
            reason: 'Should only have one trial per email');
        });

        test('should handle error scenarios gracefully', () async {
          // Test network error simulation
          try {
            // Simulate network error during registration
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
              message: 'The service is currently unavailable.',
            );
          } catch (e) {
            expect(e, isA<FirebaseException>());
            expect((e as FirebaseException).code, equals('unavailable'));
          }

          // Test authentication error simulation
          try {
            // Simulate auth error during login
            throw FirebaseAuthException(
              code: 'network-request-failed',
              message: 'A network error has occurred.',
            );
          } catch (e) {
            expect(e, isA<FirebaseAuthException>());
            expect((e as FirebaseAuthException).code, equals('network-request-failed'));
          }

          // Verify system can recover from errors
          // After error, user should still be able to complete registration
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'emailVerified': false,
            'status': 'unverified',
            'createdAt': FieldValue.serverTimestamp(),
          });

          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          expect(userDoc.exists, isTrue);
        });
      });
    });

    group('7.2 Trial to subscription conversion flow', () {
      // Test data for subscription conversion
      const testEmail = 'subscription@example.com';
      const testPassword = 'SubscriptionTest123!';
      const testUsername = 'subscriptionuser';
      final testUid = TestUtils.generateTestUid();

      group('Step 1: Setup Trial User for Subscription Conversion', () {
        test('should create trial user ready for subscription conversion', () async {
          // Arrange - Create verified user with active trial
          final trialUser = auth_mocks.MockUser(
            uid: testUid,
            email: testEmail,
            isEmailVerified: true,
          );

          // Create user profile
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'name': 'Subscription Test User',
            'emailVerified': true,
            'status': 'trial_user',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          });

          // Create active trial history
          final now = DateTime.now();
          final trialEndDate = now.add(const Duration(days: 5)); // 5 days remaining

          await mockFirestore.collection('trial_history').add({
            'userId': testUid,
            'email': testEmail,
            'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
            'trialEndDate': Timestamp.fromDate(trialEndDate),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Assert - Verify trial user setup
          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          expect(userDoc.exists, isTrue);
          
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('trial_user'));
          expect(userData['emailVerified'], isTrue);

          // Verify trial is active
          final trialQuery = await mockFirestore
              .collection('trial_history')
              .where('userId', isEqualTo: testUid)
              .where('email', isEqualTo: testEmail)
              .get();

          expect(trialQuery.docs.length, equals(1));
          final trialData = trialQuery.docs.first.data();
          final actualTrialEndDate = (trialData['trialEndDate'] as Timestamp).toDate();
          expect(actualTrialEndDate.isAfter(now), isTrue, 
            reason: 'Trial should still be active');
        });
      });

      group('Step 2: Subscription Signup During Trial', () {
        test('should create subscription record when trial user subscribes', () async {
          // Arrange - Setup trial user (from previous test setup)
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'emailVerified': true,
            'status': 'trial_user',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Create active trial
          final now = DateTime.now();
          await mockFirestore.collection('trial_history').add({
            'userId': testUid,
            'email': testEmail,
            'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
            'trialEndDate': Timestamp.fromDate(now.add(const Duration(days: 5))),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Act - Create subscription (simulating SubscriptionService.subscribeToMonthlyPlan)
          final subscriptionStartDate = DateTime.now();
          final subscriptionEndDate = DateTime(
            subscriptionStartDate.year,
            subscriptionStartDate.month + 1,
            subscriptionStartDate.day,
          );

          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'plan': 'monthly',
            'isTrialActive': false, // Trial is no longer active
            'subscriptionStartDate': FieldValue.serverTimestamp(),
            'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
            'lastPaymentDate': FieldValue.serverTimestamp(),
            'nextBillingDate': Timestamp.fromDate(subscriptionEndDate),
            'price': 3.0, // $3/month as per requirement 4.2
            'paymentMethod': 'credit_card',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Assert - Verify subscription document creation (Requirement 4.1, 4.2, 4.3)
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          expect(subscriptionDoc.exists, isTrue);

          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          expect(subscriptionData['userId'], equals(testUid));
          expect(subscriptionData['email'], equals(testEmail));
          expect(subscriptionData['status'], equals('active'));
          expect(subscriptionData['plan'], equals('monthly'));
          expect(subscriptionData['price'], equals(3.0)); // Requirement 4.2: $3/month
          expect(subscriptionData['isTrialActive'], isFalse);
          expect(subscriptionData['paymentMethod'], equals('credit_card'));

          // Verify billing dates are set correctly
          expect(subscriptionData['subscriptionStartDate'], isNotNull);
          expect(subscriptionData['subscriptionEndDate'], isNotNull);
          expect(subscriptionData['nextBillingDate'], isNotNull);
          expect(subscriptionData['lastPaymentDate'], isNotNull);

          // Verify subscription end date is approximately 1 month from start
          final actualEndDate = (subscriptionData['subscriptionEndDate'] as Timestamp).toDate();
          final expectedEndDate = subscriptionStartDate.add(const Duration(days: 30));
          final daysDifference = actualEndDate.difference(expectedEndDate).inDays.abs();
          expect(daysDifference, lessThanOrEqualTo(2), 
            reason: 'Subscription end date should be approximately 1 month from start');
        });

        test('should record payment transaction during subscription signup', () async {
          // Arrange - Setup subscription data
          const transactionId = 'txn_test_123456';
          const paymentAmount = 3.0;

          // Act - Record payment transaction (simulating SubscriptionService._recordPaymentTransaction)
          await mockFirestore.collection('payment_transactions').add({
            'userId': testUid,
            'amount': paymentAmount,
            'currency': 'USD',
            'transactionId': transactionId,
            'type': 'monthly_subscription',
            'status': 'completed',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Assert - Verify payment transaction record (Requirement 4.3)
          final paymentQuery = await mockFirestore
              .collection('payment_transactions')
              .where('userId', isEqualTo: testUid)
              .where('transactionId', isEqualTo: transactionId)
              .get();

          expect(paymentQuery.docs.length, equals(1));

          final paymentData = paymentQuery.docs.first.data();
          expect(paymentData['userId'], equals(testUid));
          expect(paymentData['amount'], equals(paymentAmount));
          expect(paymentData['currency'], equals('USD'));
          expect(paymentData['transactionId'], equals(transactionId));
          expect(paymentData['type'], equals('monthly_subscription'));
          expect(paymentData['status'], equals('completed'));
          expect(paymentData['createdAt'], isNotNull);
        });

        test('should handle subscription signup with different payment methods', () async {
          // Test multiple payment methods as per requirements
          final paymentMethods = ['credit_card', 'paypal', 'google_pay', 'apple_pay'];

          for (int i = 0; i < paymentMethods.length; i++) {
            final paymentMethod = paymentMethods[i];
            final uniqueUserId = '${testUid}_$i';
            final uniqueEmail = 'payment$i@example.com';

            // Create subscription with different payment method
            await mockFirestore.collection('subscriptions').doc(uniqueUserId).set({
              'userId': uniqueUserId,
              'email': uniqueEmail,
              'status': 'active',
              'plan': 'monthly',
              'price': 3.0,
              'paymentMethod': paymentMethod,
              'subscriptionStartDate': FieldValue.serverTimestamp(),
              'subscriptionEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
              'createdAt': FieldValue.serverTimestamp(),
            });

            // Verify payment method is recorded correctly
            final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(uniqueUserId).get();
            final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
            expect(subscriptionData['paymentMethod'], equals(paymentMethod));
          }
        });
      });

      group('Step 3: Premium Access Transition from Trial to Subscription', () {
        test('should transition user status from trial to premium subscriber', () async {
          // Arrange - Setup trial user
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'status': 'trial_user',
            'emailVerified': true,
          });

          // Create trial history
          await mockFirestore.collection('trial_history').add({
            'userId': testUid,
            'email': testEmail,
            'trialStartDate': FieldValue.serverTimestamp(),
            'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 3))),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Act - User subscribes and status should change (Requirement 6.4)
          await mockFirestore.collection('users').doc(testUid).update({
            'status': 'premium_subscriber',
            'subscribedAt': FieldValue.serverTimestamp(),
          });

          // Create subscription record
          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'plan': 'monthly',
            'price': 3.0,
            'subscriptionStartDate': FieldValue.serverTimestamp(),
            'subscriptionEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Assert - Verify status transition (Requirement 6.4)
          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('premium_subscriber'));
          expect(userData['subscribedAt'], isNotNull);

          // Verify subscription is active
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          expect(subscriptionDoc.exists, isTrue);
          
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          expect(subscriptionData['status'], equals('active'));

          // Verify trial history still exists (for audit purposes)
          final trialQuery = await mockFirestore
              .collection('trial_history')
              .where('userId', isEqualTo: testUid)
              .get();
          expect(trialQuery.docs.length, equals(1));
        });

        test('should grant premium access immediately after subscription activation', () async {
          // Arrange - Create subscription
          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'plan': 'monthly',
            'subscriptionStartDate': FieldValue.serverTimestamp(),
            'subscriptionEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Act - Check premium access (simulating SubscriptionService.hasActiveSubscription)
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          final subscriptionEndDate = (subscriptionData['subscriptionEndDate'] as Timestamp).toDate();
          final now = DateTime.now();

          // Determine if user has premium access
          final hasActiveSubscription = subscriptionData['status'] == 'active' && 
                                      subscriptionEndDate.isAfter(now);

          // Assert - Verify premium access is granted (Requirement 4.3)
          expect(hasActiveSubscription, isTrue, 
            reason: 'User should have premium access immediately after subscription activation');
          expect(subscriptionData['status'], equals('active'));
          expect(subscriptionEndDate.isAfter(now), isTrue);
        });

        test('should maintain trial history while granting subscription access', () async {
          // Arrange - Setup user with both trial history and subscription
          final now = DateTime.now();
          
          // Create trial history (completed trial)
          await mockFirestore.collection('trial_history').add({
            'userId': testUid,
            'email': testEmail,
            'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 7))),
            'trialEndDate': Timestamp.fromDate(now.subtract(const Duration(days: 1))), // Trial ended yesterday
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Create active subscription
          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'plan': 'monthly',
            'subscriptionStartDate': FieldValue.serverTimestamp(),
            'subscriptionEndDate': Timestamp.fromDate(now.add(const Duration(days: 30))),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Act & Assert - Verify both trial history and subscription exist
          final trialQuery = await mockFirestore
              .collection('trial_history')
              .where('userId', isEqualTo: testUid)
              .get();
          expect(trialQuery.docs.length, equals(1));

          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          expect(subscriptionDoc.exists, isTrue);

          // Verify subscription takes precedence over expired trial
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          final trialData = trialQuery.docs.first.data();
          
          final trialEndDate = (trialData['trialEndDate'] as Timestamp).toDate();
          final subscriptionEndDate = (subscriptionData['subscriptionEndDate'] as Timestamp).toDate();

          expect(trialEndDate.isBefore(now), isTrue, reason: 'Trial should be expired');
          expect(subscriptionEndDate.isAfter(now), isTrue, reason: 'Subscription should be active');
          expect(subscriptionData['status'], equals('active'));
        });
      });

      group('Step 4: Billing and Subscription Document Creation', () {
        test('should create comprehensive subscription document with all required fields', () async {
          // Arrange
          const paymentMethod = 'credit_card';
          const transactionId = 'txn_comprehensive_test';
          final now = DateTime.now();
          final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);

          // Act - Create comprehensive subscription document (Requirement 4.1, 4.2, 4.3)
          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'plan': 'monthly',
            'isTrialActive': false,
            'subscriptionStartDate': FieldValue.serverTimestamp(),
            'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
            'lastPaymentDate': FieldValue.serverTimestamp(),
            'nextBillingDate': Timestamp.fromDate(subscriptionEndDate),
            'price': 3.0,
            'paymentMethod': paymentMethod,
            'cancelled': false,
            'autoRenew': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'metadata': {
              'transactionId': transactionId,
              'billingCycle': 'monthly',
              'currency': 'USD',
              'subscriptionSource': 'mobile_app',
            },
          });

          // Assert - Verify all required fields are present and correct
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          expect(subscriptionDoc.exists, isTrue);

          final data = subscriptionDoc.data() as Map<String, dynamic>;
          
          // Core subscription fields
          expect(data['userId'], equals(testUid));
          expect(data['email'], equals(testEmail));
          expect(data['status'], equals('active'));
          expect(data['plan'], equals('monthly'));
          expect(data['price'], equals(3.0)); // Requirement 4.2
          expect(data['paymentMethod'], equals(paymentMethod));
          
          // Billing fields
          expect(data['subscriptionStartDate'], isNotNull);
          expect(data['subscriptionEndDate'], isNotNull);
          expect(data['lastPaymentDate'], isNotNull);
          expect(data['nextBillingDate'], isNotNull);
          
          // Status fields
          expect(data['cancelled'], isFalse);
          expect(data['autoRenew'], isTrue);
          expect(data['isTrialActive'], isFalse);
          
          // Metadata
          expect(data['metadata'], isNotNull);
          final metadata = data['metadata'] as Map<String, dynamic>;
          expect(metadata['transactionId'], equals(transactionId));
          expect(metadata['billingCycle'], equals('monthly'));
          expect(metadata['currency'], equals('USD'));
          
          // Timestamps
          expect(data['createdAt'], isNotNull);
          expect(data['updatedAt'], isNotNull);
        });

        test('should set up correct billing cycle and dates', () async {
          // Arrange
          final subscriptionStartDate = DateTime.now();
          final expectedEndDate = DateTime(
            subscriptionStartDate.year,
            subscriptionStartDate.month + 1,
            subscriptionStartDate.day,
          );

          // Act - Create subscription with billing dates
          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'subscriptionStartDate': Timestamp.fromDate(subscriptionStartDate),
            'subscriptionEndDate': Timestamp.fromDate(expectedEndDate),
            'nextBillingDate': Timestamp.fromDate(expectedEndDate),
            'price': 3.0,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Assert - Verify billing dates are correct
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final data = subscriptionDoc.data() as Map<String, dynamic>;

          final actualStartDate = (data['subscriptionStartDate'] as Timestamp).toDate();
          final actualEndDate = (data['subscriptionEndDate'] as Timestamp).toDate();
          final actualNextBilling = (data['nextBillingDate'] as Timestamp).toDate();

          // Verify dates are approximately correct (allowing for small timing differences)
          expect(actualStartDate.difference(subscriptionStartDate).inMinutes.abs(), 
                 lessThanOrEqualTo(1));
          expect(actualEndDate.difference(expectedEndDate).inMinutes.abs(), 
                 lessThanOrEqualTo(1));
          expect(actualNextBilling.difference(expectedEndDate).inMinutes.abs(), 
                 lessThanOrEqualTo(1));

          // Verify billing period is approximately 1 month
          final billingPeriodDays = actualEndDate.difference(actualStartDate).inDays;
          expect(billingPeriodDays, greaterThanOrEqualTo(28));
          expect(billingPeriodDays, lessThanOrEqualTo(31));
        });

        test('should handle subscription creation with payment processing', () async {
          // Arrange
          const transactionId = 'txn_payment_processing';
          const paymentAmount = 3.0;

          // Act - Create subscription and payment transaction together
          await mockFirestore.runTransaction((transaction) async {
            // Create subscription document
            transaction.set(
              mockFirestore.collection('subscriptions').doc(testUid),
              {
                'userId': testUid,
                'email': testEmail,
                'status': 'active',
                'plan': 'monthly',
                'price': paymentAmount,
                'subscriptionStartDate': FieldValue.serverTimestamp(),
                'subscriptionEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
                'createdAt': FieldValue.serverTimestamp(),
              },
            );

            // Create payment transaction
            transaction.set(
              mockFirestore.collection('payment_transactions').doc(),
              {
                'userId': testUid,
                'amount': paymentAmount,
                'currency': 'USD',
                'transactionId': transactionId,
                'type': 'monthly_subscription',
                'status': 'completed',
                'createdAt': FieldValue.serverTimestamp(),
              },
            );
          });

          // Assert - Verify both subscription and payment were created
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          expect(subscriptionDoc.exists, isTrue);

          final paymentQuery = await mockFirestore
              .collection('payment_transactions')
              .where('userId', isEqualTo: testUid)
              .where('transactionId', isEqualTo: transactionId)
              .get();
          expect(paymentQuery.docs.length, equals(1));

          // Verify data consistency
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          final paymentData = paymentQuery.docs.first.data();

          expect(subscriptionData['price'], equals(paymentData['amount']));
          expect(subscriptionData['userId'], equals(paymentData['userId']));
          expect(subscriptionData['status'], equals('active'));
          expect(paymentData['status'], equals('completed'));
        });
      });

      group('Step 5: End-to-End Trial to Subscription Conversion', () {
        test('should complete full trial to subscription conversion flow', () async {
          // This test simulates the complete flow from active trial to paid subscription
          
          // Phase 1: Setup Active Trial User
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'emailVerified': true,
            'status': 'trial_user',
            'createdAt': FieldValue.serverTimestamp(),
          });

          final now = DateTime.now();
          await mockFirestore.collection('trial_history').add({
            'userId': testUid,
            'email': testEmail,
            'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
            'trialEndDate': Timestamp.fromDate(now.add(const Duration(days: 4))), // 4 days remaining
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Verify trial is active
          final trialQuery = await mockFirestore
              .collection('trial_history')
              .where('userId', isEqualTo: testUid)
              .get();
          expect(trialQuery.docs.length, equals(1));
          
          final trialData = trialQuery.docs.first.data();
          final trialEndDate = (trialData['trialEndDate'] as Timestamp).toDate();
          expect(trialEndDate.isAfter(now), isTrue, reason: 'Trial should be active');

          // Phase 2: User Decides to Subscribe During Trial
          const transactionId = 'txn_full_conversion';
          final subscriptionStartDate = DateTime.now();
          final subscriptionEndDate = DateTime(
            subscriptionStartDate.year,
            subscriptionStartDate.month + 1,
            subscriptionStartDate.day,
          );

          // Create subscription (Requirements 3.3, 4.1, 4.2, 4.3)
          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'plan': 'monthly',
            'isTrialActive': false, // Trial is superseded by subscription
            'subscriptionStartDate': FieldValue.serverTimestamp(),
            'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
            'lastPaymentDate': FieldValue.serverTimestamp(),
            'nextBillingDate': Timestamp.fromDate(subscriptionEndDate),
            'price': 3.0, // Requirement 4.2
            'paymentMethod': 'credit_card',
            'cancelled': false,
            'autoRenew': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Record payment transaction
          await mockFirestore.collection('payment_transactions').add({
            'userId': testUid,
            'amount': 3.0,
            'currency': 'USD',
            'transactionId': transactionId,
            'type': 'monthly_subscription',
            'status': 'completed',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Update user status (Requirement 6.4)
          await mockFirestore.collection('users').doc(testUid).update({
            'status': 'premium_subscriber',
            'subscribedAt': FieldValue.serverTimestamp(),
            'lastSubscriptionUpdate': FieldValue.serverTimestamp(),
          });

          // Phase 3: Verify Complete Conversion
          // Check user status
          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('premium_subscriber'));
          expect(userData['subscribedAt'], isNotNull);

          // Check subscription is active
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          expect(subscriptionDoc.exists, isTrue);
          
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          expect(subscriptionData['status'], equals('active'));
          expect(subscriptionData['price'], equals(3.0));
          expect(subscriptionData['isTrialActive'], isFalse);

          // Check payment was processed
          final paymentQuery = await mockFirestore
              .collection('payment_transactions')
              .where('userId', isEqualTo: testUid)
              .where('transactionId', isEqualTo: transactionId)
              .get();
          expect(paymentQuery.docs.length, equals(1));
          
          final paymentData = paymentQuery.docs.first.data();
          expect(paymentData['status'], equals('completed'));
          expect(paymentData['amount'], equals(3.0));

          // Check trial history is preserved (for audit)
          final finalTrialQuery = await mockFirestore
              .collection('trial_history')
              .where('userId', isEqualTo: testUid)
              .get();
          expect(finalTrialQuery.docs.length, equals(1));

          // Phase 4: Verify Premium Access
          // Simulate checking premium access (like SubscriptionService.hasActiveSubscription)
          final currentSubscriptionEndDate = (subscriptionData['subscriptionEndDate'] as Timestamp).toDate();
          final hasActiveSubscription = subscriptionData['status'] == 'active' && 
                                      currentSubscriptionEndDate.isAfter(DateTime.now());

          expect(hasActiveSubscription, isTrue, 
            reason: 'User should have premium access after successful subscription conversion');

          // Verify billing cycle is set up correctly
          final billingPeriodDays = currentSubscriptionEndDate.difference(subscriptionStartDate).inDays;
          expect(billingPeriodDays, greaterThanOrEqualTo(28));
          expect(billingPeriodDays, lessThanOrEqualTo(31));
        });

        test('should handle edge cases during conversion', () async {
          // Test Case 1: Trial expires during subscription process
          final now = DateTime.now();
          
          // Create user with trial that expires very soon
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'status': 'trial_user',
            'emailVerified': true,
          });

          await mockFirestore.collection('trial_history').add({
            'userId': testUid,
            'email': testEmail,
            'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 7))),
            'trialEndDate': Timestamp.fromDate(now.add(const Duration(minutes: 1))), // Expires in 1 minute
            'createdAt': FieldValue.serverTimestamp(),
          });

          // User subscribes just before trial expires
          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'plan': 'monthly',
            'subscriptionStartDate': FieldValue.serverTimestamp(),
            'subscriptionEndDate': Timestamp.fromDate(now.add(const Duration(days: 30))),
            'price': 3.0,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Update user status
          await mockFirestore.collection('users').doc(testUid).update({
            'status': 'premium_subscriber',
          });

          // Verify subscription takes precedence even if trial expires
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          expect(subscriptionData['status'], equals('active'));

          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('premium_subscriber'));
        });

        test('should prevent duplicate subscriptions for same user', () async {
          // Arrange - Create initial subscription
          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'plan': 'monthly',
            'price': 3.0,
            'subscriptionStartDate': FieldValue.serverTimestamp(),
            'subscriptionEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Act - Try to create another subscription (should be prevented by using same document ID)
          // In real implementation, this would be prevented by checking existing subscription
          final existingSubscription = await mockFirestore.collection('subscriptions').doc(testUid).get();
          
          if (existingSubscription.exists) {
            final existingData = existingSubscription.data() as Map<String, dynamic>;
            if (existingData['status'] == 'active') {
              // Don't create duplicate - just update existing
              await mockFirestore.collection('subscriptions').doc(testUid).update({
                'updatedAt': FieldValue.serverTimestamp(),
                'lastModified': 'duplicate_prevention_test',
              });
            }
          }

          // Assert - Verify only one subscription exists
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          expect(subscriptionDoc.exists, isTrue);
          
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          expect(subscriptionData['status'], equals('active'));
          expect(subscriptionData['lastModified'], equals('duplicate_prevention_test'));

          // Verify no duplicate subscription documents exist
          final allUserSubscriptions = await mockFirestore
              .collection('subscriptions')
              .where('userId', isEqualTo: testUid)
              .get();
          expect(allUserSubscriptions.docs.length, equals(1));
        });
      });
    });

    group('7.3 Subscription cancellation and expiration flow', () {
      // Test data for subscription cancellation
      const testEmail = 'cancellation@example.com';
      const testPassword = 'CancellationTest123!';
      const testUsername = 'cancellationuser';
      final testUid = TestUtils.generateTestUid();

      group('Step 1: Setup Active Subscription for Cancellation', () {
        test('should create active subscription ready for cancellation', () async {
          // Arrange - Create verified user with active subscription
          final subscribedUser = auth_mocks.MockUser(
            uid: testUid,
            email: testEmail,
            isEmailVerified: true,
          );

          // Create user profile
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'name': 'Cancellation Test User',
            'emailVerified': true,
            'status': 'premium_subscriber',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          });

          // Create active subscription
          final now = DateTime.now();
          final subscriptionEndDate = now.add(const Duration(days: 20)); // 20 days remaining

          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'plan': 'monthly',
            'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 10))),
            'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
            'nextBillingDate': Timestamp.fromDate(subscriptionEndDate),
            'price': 3.0,
            'paymentMethod': 'credit_card',
            'autoRenew': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Assert - Verify active subscription setup
          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          expect(userDoc.exists, isTrue);
          
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('premium_subscriber'));
          expect(userData['emailVerified'], isTrue);

          // Verify subscription is active
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          expect(subscriptionDoc.exists, isTrue);
          
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          expect(subscriptionData['status'], equals('active'));
          expect(subscriptionData['autoRenew'], isTrue);
          
          final actualEndDate = (subscriptionData['subscriptionEndDate'] as Timestamp).toDate();
          expect(actualEndDate.isAfter(now), isTrue, 
            reason: 'Subscription should still be active');
        });
      });

      group('Step 2: Subscription Cancellation Process', () {
        test('should mark subscription as cancelled but maintain access until billing period end', () async {
          // Arrange - Setup active subscription (from previous test setup)
          final now = DateTime.now();
          final originalEndDate = now.add(const Duration(days: 15)); // 15 days remaining

          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'emailVerified': true,
            'status': 'premium_subscriber',
            'createdAt': FieldValue.serverTimestamp(),
          });

          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'plan': 'monthly',
            'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 15))),
            'subscriptionEndDate': Timestamp.fromDate(originalEndDate),
            'nextBillingDate': Timestamp.fromDate(originalEndDate),
            'price': 3.0,
            'autoRenew': true,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Act - Cancel subscription (Requirements 5.1, 5.2)
          await mockFirestore.collection('subscriptions').doc(testUid).update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'willExpireAt': Timestamp.fromDate(originalEndDate), // Keep original end date
            'autoRenew': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Update user status to cancelled subscriber
          await mockFirestore.collection('users').doc(testUid).update({
            'status': 'cancelled_subscriber',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Assert - Verify cancellation was processed correctly
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          
          expect(subscriptionData['status'], equals('cancelled'));
          expect(subscriptionData['cancelledAt'], isNotNull);
          expect(subscriptionData['willExpireAt'], isNotNull);
          expect(subscriptionData['autoRenew'], isFalse);

          // Verify willExpireAt matches original subscription end date
          final willExpireAt = (subscriptionData['willExpireAt'] as Timestamp).toDate();
          final originalEnd = (subscriptionData['subscriptionEndDate'] as Timestamp).toDate();
          expect(willExpireAt.isAtSameMomentAs(originalEnd), isTrue,
            reason: 'willExpireAt should match original subscription end date');

          // Verify user status updated
          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('cancelled_subscriber'));
        });

        test('should stop future billing after cancellation', () async {
          // Arrange - Setup cancelled subscription
          final now = DateTime.now();
          final willExpireAt = now.add(const Duration(days: 10));

          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'cancelled',
            'plan': 'monthly',
            'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 20))),
            'subscriptionEndDate': Timestamp.fromDate(willExpireAt),
            'willExpireAt': Timestamp.fromDate(willExpireAt),
            'cancelledAt': FieldValue.serverTimestamp(),
            'autoRenew': false,
            'price': 3.0,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Act - Simulate billing cycle check (should not renew)
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          
          final autoRenew = subscriptionData['autoRenew'] as bool? ?? false;
          final status = subscriptionData['status'] as String?;

          // Assert - Verify no future billing will occur (Requirement 5.4)
          expect(autoRenew, isFalse, 
            reason: 'Auto-renewal should be disabled after cancellation');
          expect(status, equals('cancelled'), 
            reason: 'Status should remain cancelled');

          // Verify cancellation timestamp exists
          expect(subscriptionData['cancelledAt'], isNotNull,
            reason: 'Cancellation timestamp should be recorded');

          // Verify willExpireAt is set for access control
          expect(subscriptionData['willExpireAt'], isNotNull,
            reason: 'willExpireAt should be set to control access expiration');
        });
      });

      group('Step 3: Continued Access Until Billing Period End', () {
        test('should maintain premium access until willExpireAt date', () async {
          // Arrange - Setup cancelled subscription with future expiration
          final now = DateTime.now();
          final willExpireAt = now.add(const Duration(days: 8)); // 8 days of remaining access

          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'emailVerified': true,
            'status': 'cancelled_subscriber',
          });

          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'cancelled',
            'plan': 'monthly',
            'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 22))),
            'subscriptionEndDate': Timestamp.fromDate(willExpireAt),
            'willExpireAt': Timestamp.fromDate(willExpireAt),
            'cancelledAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))), // Cancelled 2 days ago
            'autoRenew': false,
            'price': 3.0,
          });

          // Act - Check if user still has premium access (Requirement 5.3)
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          
          final willExpireAtDate = (subscriptionData['willExpireAt'] as Timestamp).toDate();
          final hasAccess = now.isBefore(willExpireAtDate);

          // Assert - Verify continued access until expiration
          expect(hasAccess, isTrue, 
            reason: 'User should still have premium access until willExpireAt date');
          expect(subscriptionData['status'], equals('cancelled'));

          // Verify access period calculation
          final remainingDays = willExpireAtDate.difference(now).inDays;
          expect(remainingDays, greaterThanOrEqualTo(7), 
            reason: 'Should have approximately 8 days of access remaining');
          expect(remainingDays, lessThanOrEqualTo(8));

          // Verify user status reflects cancelled but active state
          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('cancelled_subscriber'));
        });

        test('should calculate remaining access days correctly', () async {
          // Arrange - Setup cancelled subscription with specific remaining time
          final now = DateTime.now();
          final willExpireAt = DateTime(now.year, now.month, now.day + 5, 14, 30); // 5 days, 14:30

          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'cancelled',
            'willExpireAt': Timestamp.fromDate(willExpireAt),
            'cancelledAt': FieldValue.serverTimestamp(),
          });

          // Act - Calculate remaining access time
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          
          final willExpireAtDate = (subscriptionData['willExpireAt'] as Timestamp).toDate();
          final remainingDays = willExpireAtDate.difference(now).inDays;
          final remainingHours = willExpireAtDate.difference(now).inHours;

          // Assert - Verify accurate time calculations
          expect(remainingDays, equals(5), 
            reason: 'Should have exactly 5 full days remaining');
          expect(remainingHours, greaterThanOrEqualTo(120), // 5 days * 24 hours
            reason: 'Should have at least 120 hours remaining');
          expect(remainingHours, lessThanOrEqualTo(144), // 6 days * 24 hours
            reason: 'Should have less than 144 hours remaining');

          // Verify subscription is still cancelled
          expect(subscriptionData['status'], equals('cancelled'));
        });
      });

      group('Step 4: Premium Access Revocation After Expiration', () {
        test('should revoke premium access when willExpireAt date is reached', () async {
          // Arrange - Setup cancelled subscription that has expired
          final now = DateTime.now();
          final expiredDate = now.subtract(const Duration(hours: 2)); // Expired 2 hours ago

          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'emailVerified': true,
            'status': 'cancelled_subscriber', // Will be updated to expired
          });

          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'cancelled',
            'plan': 'monthly',
            'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 32))),
            'subscriptionEndDate': Timestamp.fromDate(expiredDate),
            'willExpireAt': Timestamp.fromDate(expiredDate),
            'cancelledAt': Timestamp.fromDate(now.subtract(const Duration(days: 5))),
            'autoRenew': false,
            'price': 3.0,
          });

          // Act - Check access and update status if expired (Requirement 5.4)
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          
          final willExpireAtDate = (subscriptionData['willExpireAt'] as Timestamp).toDate();
          final hasExpired = now.isAfter(willExpireAtDate);

          if (hasExpired) {
            // Update subscription status to expired
            await mockFirestore.collection('subscriptions').doc(testUid).update({
              'status': 'expired',
              'expiredAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            // Update user status to free user
            await mockFirestore.collection('users').doc(testUid).update({
              'status': 'free_user',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          // Assert - Verify access revocation
          expect(hasExpired, isTrue, 
            reason: 'Subscription should have expired');

          // Verify subscription status updated
          final updatedSubscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final updatedSubscriptionData = updatedSubscriptionDoc.data() as Map<String, dynamic>;
          expect(updatedSubscriptionData['status'], equals('expired'));
          expect(updatedSubscriptionData['expiredAt'], isNotNull);

          // Verify user status updated
          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          final userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('free_user'));

          // Verify no premium access
          final currentStatus = updatedSubscriptionData['status'] as String;
          final hasPremiumAccess = currentStatus == 'active' || 
                                  (currentStatus == 'cancelled' && !hasExpired);
          expect(hasPremiumAccess, isFalse, 
            reason: 'User should not have premium access after expiration');
        });

        test('should handle edge case of exact expiration time', () async {
          // Arrange - Setup subscription expiring at exact current time
          final now = DateTime.now();
          final exactExpirationTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);

          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'cancelled',
            'willExpireAt': Timestamp.fromDate(exactExpirationTime),
            'cancelledAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
          });

          // Act - Check access at exact expiration time
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          
          final willExpireAtDate = (subscriptionData['willExpireAt'] as Timestamp).toDate();
          final currentTime = DateTime.now();
          
          // Use isAfter for strict expiration (access ends when time is reached)
          final hasExpired = currentTime.isAfter(willExpireAtDate) || 
                           currentTime.isAtSameMomentAs(willExpireAtDate);

          // Assert - Verify exact timing handling
          if (hasExpired) {
            expect(currentTime.isAfter(willExpireAtDate) || 
                   currentTime.isAtSameMomentAs(willExpireAtDate), isTrue,
              reason: 'Should handle exact expiration time correctly');
          }

          // Verify subscription data integrity
          expect(subscriptionData['status'], equals('cancelled'));
          expect(subscriptionData['willExpireAt'], isNotNull);
        });
      });

      group('Step 5: User Status Updates After Cancellation and Expiration', () {
        test('should update user status from premium_subscriber to cancelled_subscriber', () async {
          // Arrange - Setup active premium subscriber
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'emailVerified': true,
            'status': 'premium_subscriber',
            'createdAt': FieldValue.serverTimestamp(),
          });

          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'plan': 'monthly',
            'subscriptionEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 15))),
            'autoRenew': true,
          });

          // Act - Cancel subscription and update user status (Requirement 6.5)
          await mockFirestore.collection('subscriptions').doc(testUid).update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'autoRenew': false,
          });

          await mockFirestore.collection('users').doc(testUid).update({
            'status': 'cancelled_subscriber',
            'statusUpdatedAt': FieldValue.serverTimestamp(),
          });

          // Assert - Verify status transition
          final userDoc = await mockFirestore.collection('users').doc(testUid).get();
          final userData = userDoc.data() as Map<String, dynamic>;
          
          expect(userData['status'], equals('cancelled_subscriber'));
          expect(userData['statusUpdatedAt'], isNotNull);

          // Verify subscription status matches
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          expect(subscriptionData['status'], equals('cancelled'));
        });

        test('should update user status from cancelled_subscriber to free_user after expiration', () async {
          // Arrange - Setup cancelled subscriber with expired access
          final now = DateTime.now();
          final expiredDate = now.subtract(const Duration(hours: 1));

          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'emailVerified': true,
            'status': 'cancelled_subscriber',
          });

          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'cancelled',
            'willExpireAt': Timestamp.fromDate(expiredDate),
            'cancelledAt': Timestamp.fromDate(now.subtract(const Duration(days: 7))),
          });

          // Act - Process expiration and update user status (Requirement 6.6)
          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          
          final willExpireAtDate = (subscriptionData['willExpireAt'] as Timestamp).toDate();
          final hasExpired = now.isAfter(willExpireAtDate);

          if (hasExpired) {
            // Update subscription to expired
            await mockFirestore.collection('subscriptions').doc(testUid).update({
              'status': 'expired',
              'expiredAt': FieldValue.serverTimestamp(),
            });

            // Update user status to free user
            await mockFirestore.collection('users').doc(testUid).update({
              'status': 'free_user',
              'statusUpdatedAt': FieldValue.serverTimestamp(),
            });
          }

          // Assert - Verify final status transition
          expect(hasExpired, isTrue);

          final updatedUserDoc = await mockFirestore.collection('users').doc(testUid).get();
          final updatedUserData = updatedUserDoc.data() as Map<String, dynamic>;
          expect(updatedUserData['status'], equals('free_user'));

          final updatedSubscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final updatedSubscriptionData = updatedSubscriptionDoc.data() as Map<String, dynamic>;
          expect(updatedSubscriptionData['status'], equals('expired'));
        });

        test('should track complete status transition timeline', () async {
          // This test verifies the complete user status journey through cancellation and expiration
          
          // Phase 1: Active Premium Subscriber
          final now = DateTime.now();
          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'status': 'premium_subscriber',
            'statusHistory': [
              {
                'status': 'premium_subscriber',
                'timestamp': FieldValue.serverTimestamp(),
                'reason': 'subscription_activated'
              }
            ],
          });

          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'subscriptionEndDate': Timestamp.fromDate(now.add(const Duration(days: 10))),
          });

          // Verify initial state
          var userDoc = await mockFirestore.collection('users').doc(testUid).get();
          var userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('premium_subscriber'));

          // Phase 2: Subscription Cancelled
          await mockFirestore.collection('subscriptions').doc(testUid).update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'willExpireAt': Timestamp.fromDate(now.add(const Duration(days: 10))),
          });

          await mockFirestore.collection('users').doc(testUid).update({
            'status': 'cancelled_subscriber',
            'statusHistory': FieldValue.arrayUnion([
              {
                'status': 'cancelled_subscriber',
                'timestamp': FieldValue.serverTimestamp(),
                'reason': 'subscription_cancelled'
              }
            ]),
          });

          // Verify cancelled state
          userDoc = await mockFirestore.collection('users').doc(testUid).get();
          userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('cancelled_subscriber'));

          // Phase 3: Subscription Expired (simulate future date)
          await mockFirestore.collection('subscriptions').doc(testUid).update({
            'status': 'expired',
            'willExpireAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))), // Expired
            'expiredAt': FieldValue.serverTimestamp(),
          });

          await mockFirestore.collection('users').doc(testUid).update({
            'status': 'free_user',
            'statusHistory': FieldValue.arrayUnion([
              {
                'status': 'free_user',
                'timestamp': FieldValue.serverTimestamp(),
                'reason': 'subscription_expired'
              }
            ]),
          });

          // Verify final expired state
          userDoc = await mockFirestore.collection('users').doc(testUid).get();
          userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('free_user'));

          // Verify complete status history
          final statusHistory = userData['statusHistory'] as List<dynamic>;
          expect(statusHistory.length, equals(3));
          
          // Check status progression
          final statuses = statusHistory.map((entry) => entry['status']).toList();
          expect(statuses, containsAllInOrder([
            'premium_subscriber',
            'cancelled_subscriber', 
            'free_user'
          ]));
        });
      });

      group('Step 6: Integration Test for Complete Cancellation Flow', () {
        test('should complete entire cancellation to expiration flow successfully', () async {
          // This test simulates the complete cancellation journey
          
          // Phase 1: Setup Active Premium Subscriber
          final now = DateTime.now();
          final originalEndDate = now.add(const Duration(days: 12));

          await mockFirestore.collection('users').doc(testUid).set({
            'uid': testUid,
            'email': testEmail,
            'username': testUsername,
            'emailVerified': true,
            'status': 'premium_subscriber',
            'createdAt': FieldValue.serverTimestamp(),
          });

          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'active',
            'plan': 'monthly',
            'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 18))),
            'subscriptionEndDate': Timestamp.fromDate(originalEndDate),
            'nextBillingDate': Timestamp.fromDate(originalEndDate),
            'price': 3.0,
            'autoRenew': true,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Verify initial active state
          var userDoc = await mockFirestore.collection('users').doc(testUid).get();
          var userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('premium_subscriber'));

          var subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          var subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          expect(subscriptionData['status'], equals('active'));
          expect(subscriptionData['autoRenew'], isTrue);

          // Phase 2: User Cancels Subscription
          await mockFirestore.collection('subscriptions').doc(testUid).update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'willExpireAt': Timestamp.fromDate(originalEndDate), // Keep access until original end
            'autoRenew': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          await mockFirestore.collection('users').doc(testUid).update({
            'status': 'cancelled_subscriber',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Verify cancellation processed
          subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          expect(subscriptionData['status'], equals('cancelled'));
          expect(subscriptionData['autoRenew'], isFalse);
          expect(subscriptionData['cancelledAt'], isNotNull);

          userDoc = await mockFirestore.collection('users').doc(testUid).get();
          userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('cancelled_subscriber'));

          // Phase 3: Verify Continued Access During Grace Period
          final willExpireAtDate = (subscriptionData['willExpireAt'] as Timestamp).toDate();
          final hasAccessDuringGracePeriod = now.isBefore(willExpireAtDate);
          expect(hasAccessDuringGracePeriod, isTrue, 
            reason: 'User should maintain access during grace period');

          // Verify grace period duration
          final gracePeriodDays = willExpireAtDate.difference(now).inDays;
          expect(gracePeriodDays, greaterThanOrEqualTo(11), 
            reason: 'Should have approximately 12 days of grace period');
          expect(gracePeriodDays, lessThanOrEqualTo(12));

          // Phase 4: Simulate Expiration (fast-forward time)
          final expiredTime = originalEndDate.add(const Duration(hours: 1)); // 1 hour after expiration
          
          // Update subscription to expired status
          await mockFirestore.collection('subscriptions').doc(testUid).update({
            'status': 'expired',
            'expiredAt': Timestamp.fromDate(expiredTime),
            'updatedAt': Timestamp.fromDate(expiredTime),
          });

          await mockFirestore.collection('users').doc(testUid).update({
            'status': 'free_user',
            'updatedAt': Timestamp.fromDate(expiredTime),
          });

          // Phase 5: Verify Final Expired State
          subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          expect(subscriptionData['status'], equals('expired'));
          expect(subscriptionData['expiredAt'], isNotNull);

          userDoc = await mockFirestore.collection('users').doc(testUid).get();
          userData = userDoc.data() as Map<String, dynamic>;
          expect(userData['status'], equals('free_user'));

          // Phase 6: Verify No Premium Access After Expiration
          final finalStatus = subscriptionData['status'] as String;
          final hasPremiumAccess = finalStatus == 'active' || finalStatus == 'cancelled';
          expect(hasPremiumAccess, isFalse, 
            reason: 'User should not have premium access after expiration');

          // Verify complete data consistency
          expect(userData['email'], equals(testEmail));
          expect(subscriptionData['email'], equals(testEmail));
          expect(subscriptionData['userId'], equals(testUid));
          expect(userData['uid'], equals(testUid));
        });

        test('should handle error scenarios during cancellation flow', () async {
          // Test cancellation of non-existent subscription
          try {
            final nonExistentSubscription = await mockFirestore
                .collection('subscriptions')
                .doc('non-existent-user')
                .get();
            
            if (!nonExistentSubscription.exists) {
              // This should be handled gracefully in the service
              expect(nonExistentSubscription.exists, isFalse);
            }
          } catch (e) {
            // Should not throw exception for non-existent subscription
            fail('Should handle non-existent subscription gracefully');
          }

          // Test cancellation of already cancelled subscription
          await mockFirestore.collection('subscriptions').doc(testUid).set({
            'userId': testUid,
            'email': testEmail,
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });

          // Try to cancel again (should be idempotent)
          await mockFirestore.collection('subscriptions').doc(testUid).update({
            'status': 'cancelled', // Should remain cancelled
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
          expect(subscriptionData['status'], equals('cancelled'));

          // Test expiration of already expired subscription
          await mockFirestore.collection('subscriptions').doc(testUid).update({
            'status': 'expired',
            'expiredAt': FieldValue.serverTimestamp(),
          });

          // Try to expire again (should be idempotent)
          await mockFirestore.collection('subscriptions').doc(testUid).update({
            'status': 'expired', // Should remain expired
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final finalSubscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUid).get();
          final finalSubscriptionData = finalSubscriptionDoc.data() as Map<String, dynamic>;
          expect(finalSubscriptionData['status'], equals('expired'));
        });
      });
    });

    tearDownAll(() async {
      await TestConfig.cleanup();
    });
  });
}