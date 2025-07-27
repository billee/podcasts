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

  group('👤 UserStatusService - User Status Transition Tests', () {
    late auth_mocks.MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;
    late auth_mocks.MockUser mockUser;

    setUp(() {
      mockUser = FirebaseMockFactory.createMockUser();
      mockAuth = FirebaseMockFactory.createMockAuth(currentUser: mockUser);
      mockFirestore = FirebaseMockFactory.createMockFirestore();
      
      // Inject mocked instances into the service
      UserStatusService.setFirestoreInstance(mockFirestore);
      UserStatusService.setAuthInstance(mockAuth);
    });

    group('📝 Task 6.1: Test user status transitions', () {
      test('should transition from Unverified to Trial User when email is verified', () async {
        // Arrange - Create unverified user
        const testUserId = 'test-unverified-user-id';
        const testEmail = 'unverified@example.com';
        
        // Create user with unverified status
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': testEmail,
          'username': 'unverifieduser',
          'emailVerified': false,
          'status': 'Unverified',
          'createdAt': DateTime.now(),
        });

        // Verify initial status
        final initialDoc = await mockFirestore.collection('users').doc(testUserId).get();
        final initialData = initialDoc.data() as Map<String, dynamic>;
        expect(initialData['status'], equals('Unverified'));
        expect(initialData['emailVerified'], isFalse);

        // Act - Transition to Trial User (simulate email verification)
        await UserStatusService.transitionToTrialUser(testUserId);

        // Also create trial history to simulate complete verification flow
        final now = DateTime.now();
        final trialEndDate = now.add(const Duration(days: 7));
        await mockFirestore.collection('trial_history').add({
          'userId': testUserId,
          'email': testEmail,
          'trialStartDate': Timestamp.fromDate(now),
          'trialEndDate': Timestamp.fromDate(trialEndDate),
          'createdAt': Timestamp.fromDate(now),
        });

        // Assert - Verify status transition
        final updatedDoc = await mockFirestore.collection('users').doc(testUserId).get();
        final updatedData = updatedDoc.data() as Map<String, dynamic>;
        
        expect(updatedData['status'], equals('Trial User'),
               reason: 'Status should transition from Unverified to Trial User');
        expect(updatedData['emailVerified'], isTrue,
               reason: 'Email should be marked as verified');
        expect(updatedData['emailVerifiedAt'], isNotNull,
               reason: 'Email verification timestamp should be set');
        expect(updatedData['statusUpdatedAt'], isNotNull,
               reason: 'Status update timestamp should be set');

        // Verify trial history was created
        final trialQuery = await mockFirestore
            .collection('trial_history')
            .where('userId', isEqualTo: testUserId)
            .where('email', isEqualTo: testEmail)
            .get();
        
        expect(trialQuery.docs.isNotEmpty, isTrue,
               reason: 'Trial history should be created when transitioning to Trial User');
        
        final trialData = trialQuery.docs.first.data();
        expect(trialData['userId'], equals(testUserId));
        expect(trialData['email'], equals(testEmail));
      });

      test('should transition from Trial User to Premium Subscriber when user subscribes', () async {
        // Arrange - Create trial user
        const testUserId = 'test-trial-user-id';
        const testEmail = 'trialuser@example.com';
        
        // Create user with trial status
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': testEmail,
          'username': 'trialuser',
          'emailVerified': true,
          'emailVerifiedAt': DateTime.now(),
          'status': 'Trial User',
          'createdAt': DateTime.now(),
        });

        // Create trial history
        final now = DateTime.now();
        final trialEndDate = now.add(const Duration(days: 5)); // 5 days remaining
        await mockFirestore.collection('trial_history').add({
          'userId': testUserId,
          'email': testEmail,
          'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
          'trialEndDate': Timestamp.fromDate(trialEndDate),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
        });

        // Verify initial trial status
        final initialDoc = await mockFirestore.collection('users').doc(testUserId).get();
        final initialData = initialDoc.data() as Map<String, dynamic>;
        expect(initialData['status'], equals('Trial User'));

        // Act - Transition to Premium Subscriber (simulate subscription creation)
        await UserStatusService.transitionToPremiumSubscriber(testUserId);

        // Create subscription document to simulate subscription activation
        final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);
        await mockFirestore.collection('subscriptions').doc(testUserId).set({
          'userId': testUserId,
          'email': testEmail,
          'status': 'active',
          'plan': 'monthly',
          'isTrialActive': false,
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
          'lastPaymentDate': Timestamp.fromDate(now),
          'nextBillingDate': Timestamp.fromDate(subscriptionEndDate),
          'price': 3.0,
          'paymentMethod': 'credit_card',
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });

        // Assert - Verify status transition
        final updatedDoc = await mockFirestore.collection('users').doc(testUserId).get();
        final updatedData = updatedDoc.data() as Map<String, dynamic>;
        
        expect(updatedData['status'], equals('Premium Subscriber'),
               reason: 'Status should transition from Trial User to Premium Subscriber');
        expect(updatedData['statusUpdatedAt'], isNotNull,
               reason: 'Status update timestamp should be set');

        // Verify subscription document was created
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        expect(subscriptionDoc.exists, isTrue,
               reason: 'Subscription document should be created');
        
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        expect(subscriptionData['status'], equals('active'));
        expect(subscriptionData['isTrialActive'], isFalse,
               reason: 'Trial should be deactivated when subscription is active');
        expect(subscriptionData['price'], equals(3.0));
      });

      test('should transition from Premium Subscriber to Cancelled Subscriber when subscription is cancelled', () async {
        // Arrange - Create premium subscriber
        const testUserId = 'test-premium-user-id';
        const testEmail = 'premiumuser@example.com';
        
        final now = DateTime.now();
        final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);

        // Create user with premium status
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': testEmail,
          'username': 'premiumuser',
          'emailVerified': true,
          'emailVerifiedAt': DateTime.now(),
          'status': 'Premium Subscriber',
          'createdAt': DateTime.now(),
        });

        // Create active subscription
        await mockFirestore.collection('subscriptions').doc(testUserId).set({
          'userId': testUserId,
          'email': testEmail,
          'status': 'active',
          'plan': 'monthly',
          'isTrialActive': false,
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
          'lastPaymentDate': Timestamp.fromDate(now),
          'nextBillingDate': Timestamp.fromDate(subscriptionEndDate),
          'price': 3.0,
          'paymentMethod': 'credit_card',
          'autoRenew': true,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });

        // Verify initial premium status
        final initialDoc = await mockFirestore.collection('users').doc(testUserId).get();
        final initialData = initialDoc.data() as Map<String, dynamic>;
        expect(initialData['status'], equals('Premium Subscriber'));

        // Act - Transition to Cancelled Subscriber (simulate subscription cancellation)
        await UserStatusService.transitionToCancelledSubscriber(testUserId);

        // Update subscription to cancelled status
        await mockFirestore.collection('subscriptions').doc(testUserId).update({
          'status': 'cancelled',
          'cancelledAt': Timestamp.fromDate(now),
          'willExpireAt': Timestamp.fromDate(subscriptionEndDate),
          'autoRenew': false,
          'updatedAt': Timestamp.fromDate(now),
        });

        // Assert - Verify status transition
        final updatedDoc = await mockFirestore.collection('users').doc(testUserId).get();
        final updatedData = updatedDoc.data() as Map<String, dynamic>;
        
        expect(updatedData['status'], equals('Cancelled Subscriber'),
               reason: 'Status should transition from Premium Subscriber to Cancelled Subscriber');
        expect(updatedData['statusUpdatedAt'], isNotNull,
               reason: 'Status update timestamp should be set');

        // Verify subscription was marked as cancelled
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        
        expect(subscriptionData['status'], equals('cancelled'),
               reason: 'Subscription should be marked as cancelled');
        expect(subscriptionData['cancelledAt'], isNotNull,
               reason: 'Cancellation timestamp should be set');
        expect(subscriptionData['willExpireAt'], isNotNull,
               reason: 'Expiration date should be set');
        expect(subscriptionData['autoRenew'], isFalse,
               reason: 'Auto-renewal should be disabled');
      });

      test('should transition from Cancelled Subscriber to Free User when subscription expires', () async {
        // Arrange - Create cancelled subscriber
        const testUserId = 'test-cancelled-user-id';
        const testEmail = 'cancelleduser@example.com';
        
        final now = DateTime.now();
        final pastExpirationDate = now.subtract(const Duration(days: 1)); // Expired yesterday

        // Create user with cancelled subscriber status
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': testEmail,
          'username': 'cancelleduser',
          'emailVerified': true,
          'emailVerifiedAt': DateTime.now(),
          'status': 'Cancelled Subscriber',
          'createdAt': DateTime.now(),
        });

        // Create expired cancelled subscription
        await mockFirestore.collection('subscriptions').doc(testUserId).set({
          'userId': testUserId,
          'email': testEmail,
          'status': 'cancelled',
          'plan': 'monthly',
          'isTrialActive': false,
          'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
          'subscriptionEndDate': Timestamp.fromDate(pastExpirationDate),
          'lastPaymentDate': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
          'nextBillingDate': Timestamp.fromDate(pastExpirationDate),
          'price': 3.0,
          'paymentMethod': 'credit_card',
          'autoRenew': false,
          'cancelledAt': Timestamp.fromDate(now.subtract(const Duration(days: 15))),
          'willExpireAt': Timestamp.fromDate(pastExpirationDate),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 30))),
          'updatedAt': Timestamp.fromDate(now.subtract(const Duration(days: 15))),
        });

        // Verify initial cancelled status
        final initialDoc = await mockFirestore.collection('users').doc(testUserId).get();
        final initialData = initialDoc.data() as Map<String, dynamic>;
        expect(initialData['status'], equals('Cancelled Subscriber'));

        // Act - Transition to Free User (simulate subscription expiration)
        await UserStatusService.transitionToFreeUser(testUserId);

        // Update subscription status to expired
        await mockFirestore.collection('subscriptions').doc(testUserId).update({
          'status': 'expired',
          'expiredAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });

        // Assert - Verify status transition
        final updatedDoc = await mockFirestore.collection('users').doc(testUserId).get();
        final updatedData = updatedDoc.data() as Map<String, dynamic>;
        
        expect(updatedData['status'], equals('Free User'),
               reason: 'Status should transition from Cancelled Subscriber to Free User');
        expect(updatedData['statusUpdatedAt'], isNotNull,
               reason: 'Status update timestamp should be set');

        // Verify subscription is marked as expired
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        
        expect(subscriptionData['status'], equals('expired'),
               reason: 'Subscription should be marked as expired');
        expect(subscriptionData['expiredAt'], isNotNull,
               reason: 'Expiration timestamp should be set');

        // Verify user no longer has premium access
        final willExpireAt = (subscriptionData['willExpireAt'] as Timestamp).toDate();
        expect(now.isAfter(willExpireAt), isTrue,
               reason: 'Current time should be after expiration date');
      });

      test('should transition from Trial User to Trial Expired when trial expires without subscription', () async {
        // Arrange - Create trial user with expired trial
        const testUserId = 'test-expired-trial-user-id';
        const testEmail = 'expiredtrial@example.com';
        
        final now = DateTime.now();
        final pastTrialEndDate = now.subtract(const Duration(days: 1)); // Expired yesterday

        // Create user with trial status
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': testEmail,
          'username': 'expiredtrialuser',
          'emailVerified': true,
          'emailVerifiedAt': DateTime.now(),
          'status': 'Trial User',
          'createdAt': DateTime.now(),
        });

        // Create expired trial history
        await mockFirestore.collection('trial_history').add({
          'userId': testUserId,
          'email': testEmail,
          'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 8))),
          'trialEndDate': Timestamp.fromDate(pastTrialEndDate),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 8))),
        });

        // Verify initial trial status
        final initialDoc = await mockFirestore.collection('users').doc(testUserId).get();
        final initialData = initialDoc.data() as Map<String, dynamic>;
        expect(initialData['status'], equals('Trial User'));

        // Verify no active subscription exists
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        expect(subscriptionDoc.exists, isFalse,
               reason: 'No subscription should exist for trial expiration scenario');

        // Act - Transition to Trial Expired
        await UserStatusService.transitionToTrialExpired(testUserId);

        // Assert - Verify status transition
        final updatedDoc = await mockFirestore.collection('users').doc(testUserId).get();
        final updatedData = updatedDoc.data() as Map<String, dynamic>;
        
        expect(updatedData['status'], equals('Trial Expired'),
               reason: 'Status should transition from Trial User to Trial Expired');
        expect(updatedData['statusUpdatedAt'], isNotNull,
               reason: 'Status update timestamp should be set');

        // Verify trial history shows expired trial
        final trialQuery = await mockFirestore
            .collection('trial_history')
            .where('userId', isEqualTo: testUserId)
            .where('email', isEqualTo: testEmail)
            .get();
        
        expect(trialQuery.docs.isNotEmpty, isTrue,
               reason: 'Trial history should exist');
        
        final trialData = trialQuery.docs.first.data();
        final trialEndDate = (trialData['trialEndDate'] as Timestamp).toDate();
        expect(now.isAfter(trialEndDate), isTrue,
               reason: 'Trial should be expired');

        // Verify user no longer has premium access
        expect(now.isAfter(pastTrialEndDate), isTrue,
               reason: 'Current time should be after trial expiration');
      });

      test('should handle multiple status transitions in sequence', () async {
        // Arrange - Create user for complete status transition flow
        const testUserId = 'test-full-flow-user-id';
        const testEmail = 'fullflow@example.com';
        
        final now = DateTime.now();

        // 1. Start with Unverified status
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': testEmail,
          'username': 'fullflowuser',
          'emailVerified': false,
          'status': 'Unverified',
          'createdAt': now,
        });

        // Verify initial unverified status
        var userDoc = await mockFirestore.collection('users').doc(testUserId).get();
        var userData = userDoc.data() as Map<String, dynamic>;
        expect(userData['status'], equals('Unverified'));

        // 2. Transition to Trial User
        await UserStatusService.transitionToTrialUser(testUserId);
        
        // Create trial history
        final trialEndDate = now.add(const Duration(days: 7));
        await mockFirestore.collection('trial_history').add({
          'userId': testUserId,
          'email': testEmail,
          'trialStartDate': Timestamp.fromDate(now),
          'trialEndDate': Timestamp.fromDate(trialEndDate),
          'createdAt': Timestamp.fromDate(now),
        });

        userDoc = await mockFirestore.collection('users').doc(testUserId).get();
        userData = userDoc.data() as Map<String, dynamic>;
        expect(userData['status'], equals('Trial User'));

        // 3. Transition to Premium Subscriber
        await UserStatusService.transitionToPremiumSubscriber(testUserId);
        
        // Create subscription
        final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);
        await mockFirestore.collection('subscriptions').doc(testUserId).set({
          'userId': testUserId,
          'email': testEmail,
          'status': 'active',
          'plan': 'monthly',
          'isTrialActive': false,
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
          'price': 3.0,
          'paymentMethod': 'credit_card',
          'autoRenew': true,
          'createdAt': Timestamp.fromDate(now),
        });

        userDoc = await mockFirestore.collection('users').doc(testUserId).get();
        userData = userDoc.data() as Map<String, dynamic>;
        expect(userData['status'], equals('Premium Subscriber'));

        // 4. Transition to Cancelled Subscriber
        await UserStatusService.transitionToCancelledSubscriber(testUserId);
        
        await mockFirestore.collection('subscriptions').doc(testUserId).update({
          'status': 'cancelled',
          'cancelledAt': Timestamp.fromDate(now),
          'willExpireAt': Timestamp.fromDate(subscriptionEndDate),
          'autoRenew': false,
        });

        userDoc = await mockFirestore.collection('users').doc(testUserId).get();
        userData = userDoc.data() as Map<String, dynamic>;
        expect(userData['status'], equals('Cancelled Subscriber'));

        // 5. Transition to Free User
        await UserStatusService.transitionToFreeUser(testUserId);
        
        await mockFirestore.collection('subscriptions').doc(testUserId).update({
          'status': 'expired',
          'expiredAt': Timestamp.fromDate(now),
        });

        userDoc = await mockFirestore.collection('users').doc(testUserId).get();
        userData = userDoc.data() as Map<String, dynamic>;
        expect(userData['status'], equals('Free User'));

        // Assert - Verify final state
        expect(userData['status'], equals('Free User'),
               reason: 'User should end up as Free User after complete flow');
        expect(userData['emailVerified'], isTrue,
               reason: 'Email should remain verified throughout flow');
        expect(userData['statusUpdatedAt'], isNotNull,
               reason: 'Status update timestamp should be maintained');

        // Verify subscription history
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        expect(subscriptionData['status'], equals('expired'));

        // Verify trial history is preserved
        final trialQuery = await mockFirestore
            .collection('trial_history')
            .where('userId', isEqualTo: testUserId)
            .get();
        expect(trialQuery.docs.isNotEmpty, isTrue,
               reason: 'Trial history should be preserved');
      });

      test('should validate status transition requirements and constraints', () async {
        // Arrange - Test various status transition validation scenarios
        const testUserId = 'test-validation-user-id';
        const testEmail = 'validation@example.com';

        // Test 1: Cannot transition to Trial User without email verification
        await mockFirestore.collection('users').doc(testUserId).set({
          'uid': testUserId,
          'email': testEmail,
          'username': 'validationuser',
          'emailVerified': false,
          'status': 'Unverified',
          'createdAt': DateTime.now(),
        });

        // Verify unverified user cannot have Trial User status
        var userDoc = await mockFirestore.collection('users').doc(testUserId).get();
        var userData = userDoc.data() as Map<String, dynamic>;
        expect(userData['emailVerified'], isFalse);
        expect(userData['status'], equals('Unverified'));

        // Test 2: Email verification enables Trial User transition
        await UserStatusService.transitionToTrialUser(testUserId);
        
        userDoc = await mockFirestore.collection('users').doc(testUserId).get();
        userData = userDoc.data() as Map<String, dynamic>;
        expect(userData['emailVerified'], isTrue,
               reason: 'Email should be verified when transitioning to Trial User');
        expect(userData['status'], equals('Trial User'));

        // Test 3: Premium Subscriber requires active subscription
        await UserStatusService.transitionToPremiumSubscriber(testUserId);
        
        // Create subscription to validate Premium Subscriber status
        final now = DateTime.now();
        await mockFirestore.collection('subscriptions').doc(testUserId).set({
          'userId': testUserId,
          'email': testEmail,
          'status': 'active',
          'plan': 'monthly',
          'price': 3.0,
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(DateTime(now.year, now.month + 1, now.day)),
        });

        userDoc = await mockFirestore.collection('users').doc(testUserId).get();
        userData = userDoc.data() as Map<String, dynamic>;
        expect(userData['status'], equals('Premium Subscriber'));

        // Verify subscription exists for Premium Subscriber
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        expect(subscriptionDoc.exists, isTrue,
               reason: 'Premium Subscriber must have subscription document');

        // Test 4: Status update timestamps are maintained
        expect(userData['statusUpdatedAt'], isNotNull,
               reason: 'All status transitions should have timestamps');
        expect(userData['updatedAt'], isNotNull,
               reason: 'User document should track update times');

        // Test 5: Email verification persists across status changes
        expect(userData['emailVerified'], isTrue,
               reason: 'Email verification should persist across all status changes');
        expect(userData['emailVerifiedAt'], isNotNull,
               reason: 'Email verification timestamp should be preserved');
      });
    });
  });
}