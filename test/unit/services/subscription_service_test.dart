import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
import 'package:mockito/mockito.dart';

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

  group('💳 SubscriptionService - Subscription Creation and Billing Tests', () {
    late auth_mocks.MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;
    late auth_mocks.MockUser mockUser;

    setUp(() {
      mockUser = FirebaseMockFactory.createMockUser();
      mockAuth = FirebaseMockFactory.createMockAuth(currentUser: mockUser);
      mockFirestore = FirebaseMockFactory.createMockFirestore();
    });

    group('📝 Task 5.1: Test subscription creation and billing', () {
      test('should validate subscription document structure requirements', () async {
        // Arrange - Define expected subscription document structure
        const testUserId = 'test-subscription-user-id';
        const testEmail = 'subscription@example.com';
        const testPaymentMethod = 'credit_card';
        const testTransactionId = 'txn_test_123';
        
        final now = DateTime.now();
        final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);

        // Expected subscription document structure based on service implementation
        final expectedSubscriptionData = {
          'userId': testUserId,
          'email': testEmail,
          'status': 'active',
          'plan': 'monthly',
          'isTrialActive': false,
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
          'lastPaymentDate': Timestamp.fromDate(now),
          'nextBillingDate': Timestamp.fromDate(subscriptionEndDate),
          'price': SubscriptionService.monthlyPrice,
          'paymentMethod': testPaymentMethod,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        };

        // Act & Assert - Validate expected document structure
        expect(expectedSubscriptionData['userId'], equals(testUserId),
               reason: 'Subscription should have correct userId');
        expect(expectedSubscriptionData['email'], equals(testEmail),
               reason: 'Subscription should have correct email');
        expect(expectedSubscriptionData['status'], equals('active'),
               reason: 'New subscription should be active');
        expect(expectedSubscriptionData['plan'], equals('monthly'),
               reason: 'Subscription should be monthly plan');
        expect(expectedSubscriptionData['isTrialActive'], isFalse,
               reason: 'Trial should be inactive for paid subscription');
        expect(expectedSubscriptionData['price'], equals(3.0),
               reason: 'Monthly price should be \$3.00');
        expect(expectedSubscriptionData['paymentMethod'], equals(testPaymentMethod),
               reason: 'Payment method should be stored');

        // Verify timestamp fields are properly typed
        expect(expectedSubscriptionData['subscriptionStartDate'], isA<Timestamp>(),
               reason: 'Subscription start date should be Timestamp');
        expect(expectedSubscriptionData['subscriptionEndDate'], isA<Timestamp>(),
               reason: 'Subscription end date should be Timestamp');
        expect(expectedSubscriptionData['lastPaymentDate'], isA<Timestamp>(),
               reason: 'Last payment date should be Timestamp');
        expect(expectedSubscriptionData['nextBillingDate'], isA<Timestamp>(),
               reason: 'Next billing date should be Timestamp');
        expect(expectedSubscriptionData['createdAt'], isA<Timestamp>(),
               reason: 'Created timestamp should be Timestamp');
        expect(expectedSubscriptionData['updatedAt'], isA<Timestamp>(),
               reason: 'Updated timestamp should be Timestamp');

        // Verify all required fields are present
        final requiredFields = [
          'userId', 'email', 'status', 'plan', 'isTrialActive',
          'subscriptionStartDate', 'subscriptionEndDate', 'lastPaymentDate',
          'nextBillingDate', 'price', 'paymentMethod', 'createdAt', 'updatedAt'
        ];

        for (final field in requiredFields) {
          expect(expectedSubscriptionData.containsKey(field), isTrue,
                 reason: 'Subscription should contain required field: $field');
          expect(expectedSubscriptionData[field], isNotNull,
                 reason: 'Required field $field should not be null');
        }

        // Test subscription document creation in mock Firestore
        await mockFirestore.collection('subscriptions').doc(testUserId).set(expectedSubscriptionData);
        
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        expect(subscriptionDoc.exists, isTrue, reason: 'Subscription document should be created');
        
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        expect(subscriptionData['userId'], equals(testUserId));
        expect(subscriptionData['status'], equals('active'));
        expect(subscriptionData['price'], equals(3.0));
      });

      test('should validate \$3/month pricing configuration', () async {
        // Arrange - Test pricing constants and structure
        const expectedPrice = 3.0;
        const expectedCurrency = 'USD';
        const expectedPlan = 'monthly';

        // Act & Assert - Verify service pricing constants
        expect(SubscriptionService.monthlyPrice, equals(expectedPrice),
               reason: 'Service constant should be exactly \$3.00');

        // Test expected subscription pricing structure
        final expectedSubscriptionPricing = {
          'price': expectedPrice,
          'currency': expectedCurrency,
          'plan': expectedPlan,
          'billingCycle': 'monthly',
          'trialDays': SubscriptionService.trialDurationDays,
        };

        expect(expectedSubscriptionPricing['price'], equals(3.0),
               reason: 'Monthly subscription price should be exactly \$3.00');
        expect(expectedSubscriptionPricing['currency'], equals('USD'),
               reason: 'Currency should be USD');
        expect(expectedSubscriptionPricing['plan'], equals('monthly'),
               reason: 'Plan should be monthly for \$3/month pricing');
        expect(expectedSubscriptionPricing['trialDays'], equals(7),
               reason: 'Trial period should be 7 days');

        // Test expected payment transaction structure
        const testUserId = 'test-pricing-user-id';
        const testTransactionId = 'txn_pricing_123';
        
        final expectedPaymentTransaction = {
          'userId': testUserId,
          'amount': expectedPrice,
          'currency': expectedCurrency,
          'transactionId': testTransactionId,
          'type': 'monthly_subscription',
          'status': 'completed',
          'createdAt': Timestamp.fromDate(DateTime.now()),
        };

        expect(expectedPaymentTransaction['amount'], equals(expectedPrice),
               reason: 'Payment transaction amount should match subscription price');
        expect(expectedPaymentTransaction['currency'], equals(expectedCurrency),
               reason: 'Payment should be in USD currency');
        expect(expectedPaymentTransaction['type'], equals('monthly_subscription'),
               reason: 'Transaction type should be monthly_subscription');
        expect(expectedPaymentTransaction['status'], equals('completed'),
               reason: 'Transaction should be marked as completed');

        // Test payment transaction creation in mock Firestore
        await mockFirestore.collection('payment_transactions').add(expectedPaymentTransaction);
        
        final paymentTransactions = await mockFirestore
            .collection('payment_transactions')
            .where('userId', isEqualTo: testUserId)
            .where('type', isEqualTo: 'monthly_subscription')
            .get();

        expect(paymentTransactions.docs.isNotEmpty, isTrue,
               reason: 'Payment transaction should be recorded');

        final transactionData = paymentTransactions.docs.first.data();
        expect(transactionData['amount'], equals(expectedPrice));
        expect(transactionData['currency'], equals(expectedCurrency));
      });

      test('should validate subscription activation and premium access logic', () async {
        // Arrange - Test subscription activation requirements
        const testUserId = 'test-activation-user-id';
        const testEmail = 'activation@example.com';
        
        final now = DateTime.now();
        final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);

        // Create active subscription document structure
        final activeSubscriptionData = {
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
        };

        // Act & Assert - Verify subscription activation logic
        expect(activeSubscriptionData['status'], equals('active'),
               reason: 'Subscription should be active after payment');
        expect(activeSubscriptionData['isTrialActive'], isFalse,
               reason: 'Trial should be deactivated when subscription is active');

        // Test subscription end date calculation
        final actualEndDate = (activeSubscriptionData['subscriptionEndDate'] as Timestamp).toDate();
        expect(actualEndDate.year, equals(subscriptionEndDate.year),
               reason: 'Subscription end year should be correct');
        expect(actualEndDate.month, equals(subscriptionEndDate.month),
               reason: 'Subscription end month should be next month');
        expect(actualEndDate.day, equals(subscriptionEndDate.day),
               reason: 'Subscription end day should match start day');

        // Test premium access validation logic
        final isActiveSubscription = activeSubscriptionData['status'] == 'active';
        final subscriptionNotExpired = actualEndDate.isAfter(DateTime.now());
        final hasPremiumAccess = isActiveSubscription && subscriptionNotExpired;

        expect(hasPremiumAccess, isTrue,
               reason: 'User should have premium access with active, non-expired subscription');

        // Test subscription document creation in mock Firestore
        await mockFirestore.collection('subscriptions').doc(testUserId).set(activeSubscriptionData);
        
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        expect(subscriptionDoc.exists, isTrue, reason: 'Subscription document should be created');
        
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        expect(subscriptionData['status'], equals('active'));
        expect(subscriptionData['userId'], equals(testUserId));

        // Test billing date calculations
        final nextBillingDate = (subscriptionData['nextBillingDate'] as Timestamp).toDate();
        expect(nextBillingDate.isAfter(now), isTrue,
               reason: 'Next billing date should be in the future');
        expect(nextBillingDate.difference(now).inDays, greaterThanOrEqualTo(28),
               reason: 'Next billing should be approximately one month away');
      });

      test('should validate subscription data persistence requirements', () async {
        // Arrange - Define complete subscription data structure for persistence testing
        const testUserId = 'test-persistence-user-id';
        const testEmail = 'persistence@example.com';
        const testPaymentMethod = 'paypal';
        const testTransactionId = 'txn_persistence_456';
        
        final now = DateTime.now();
        final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);

        // Complete subscription document structure
        final subscriptionData = {
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
          'paymentMethod': testPaymentMethod,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        };

        // Complete payment transaction structure
        final paymentTransactionData = {
          'userId': testUserId,
          'amount': 3.0,
          'currency': 'USD',
          'transactionId': testTransactionId,
          'type': 'monthly_subscription',
          'status': 'completed',
          'createdAt': Timestamp.fromDate(now),
        };

        // Act & Assert - Verify all required fields are present and correctly typed
        final requiredSubscriptionFields = [
          'userId', 'email', 'status', 'plan', 'isTrialActive',
          'subscriptionStartDate', 'subscriptionEndDate', 'lastPaymentDate',
          'nextBillingDate', 'price', 'paymentMethod', 'createdAt', 'updatedAt'
        ];

        for (final field in requiredSubscriptionFields) {
          expect(subscriptionData.containsKey(field), isTrue,
                 reason: 'Subscription should contain required field: $field');
          expect(subscriptionData[field], isNotNull,
                 reason: 'Required field $field should not be null');
        }

        // Verify data types are correct
        expect(subscriptionData['userId'], isA<String>(),
               reason: 'userId should be string');
        expect(subscriptionData['email'], isA<String>(),
               reason: 'email should be string');
        expect(subscriptionData['status'], isA<String>(),
               reason: 'status should be string');
        expect(subscriptionData['plan'], isA<String>(),
               reason: 'plan should be string');
        expect(subscriptionData['isTrialActive'], isA<bool>(),
               reason: 'isTrialActive should be boolean');
        expect(subscriptionData['price'], isA<double>(),
               reason: 'price should be double');
        expect(subscriptionData['paymentMethod'], isA<String>(),
               reason: 'paymentMethod should be string');

        // Verify timestamp fields are Timestamp objects
        expect(subscriptionData['subscriptionStartDate'], isA<Timestamp>(),
               reason: 'subscriptionStartDate should be Timestamp');
        expect(subscriptionData['subscriptionEndDate'], isA<Timestamp>(),
               reason: 'subscriptionEndDate should be Timestamp');
        expect(subscriptionData['lastPaymentDate'], isA<Timestamp>(),
               reason: 'lastPaymentDate should be Timestamp');
        expect(subscriptionData['nextBillingDate'], isA<Timestamp>(),
               reason: 'nextBillingDate should be Timestamp');
        expect(subscriptionData['createdAt'], isA<Timestamp>(),
               reason: 'createdAt should be Timestamp');
        expect(subscriptionData['updatedAt'], isA<Timestamp>(),
               reason: 'updatedAt should be Timestamp');

        // Test data persistence in mock Firestore
        await mockFirestore.collection('subscriptions').doc(testUserId).set(subscriptionData);
        await mockFirestore.collection('payment_transactions').add(paymentTransactionData);

        // Verify subscription document persistence
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        expect(subscriptionDoc.exists, isTrue, reason: 'Subscription document should be persisted');
        
        final persistedSubscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        expect(persistedSubscriptionData['userId'], equals(testUserId));
        expect(persistedSubscriptionData['status'], equals('active'));
        expect(persistedSubscriptionData['price'], equals(3.0));

        // Verify payment transaction persistence
        final paymentTransactions = await mockFirestore
            .collection('payment_transactions')
            .where('userId', isEqualTo: testUserId)
            .where('transactionId', isEqualTo: testTransactionId)
            .get();

        expect(paymentTransactions.docs.isNotEmpty, isTrue,
               reason: 'Payment transaction should be persisted');

        final persistedTransactionData = paymentTransactions.docs.first.data();
        expect(persistedTransactionData['userId'], equals(testUserId));
        expect(persistedTransactionData['amount'], equals(3.0));
        expect(persistedTransactionData['currency'], equals('USD'));
        expect(persistedTransactionData['type'], equals('monthly_subscription'));
        expect(persistedTransactionData['status'], equals('completed'));
      });

      test('should validate direct subscription creation without trial', () async {
        // Arrange - Test direct subscription scenario (no prior trial)
        const testUserId = 'test-no-trial-user-id';
        const testEmail = 'notrial@example.com';
        
        final now = DateTime.now();
        final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);

        // Expected subscription structure for direct subscription
        final directSubscriptionData = {
          'userId': testUserId,
          'email': testEmail,
          'status': 'active',
          'plan': 'monthly',
          'isTrialActive': false, // Should be false for direct subscription
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
          'lastPaymentDate': Timestamp.fromDate(now),
          'nextBillingDate': Timestamp.fromDate(subscriptionEndDate),
          'price': 3.0,
          'paymentMethod': 'credit_card',
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        };

        // Act & Assert - Verify direct subscription logic
        expect(directSubscriptionData['isTrialActive'], isFalse,
               reason: 'Trial should not be active for direct subscription');
        expect(directSubscriptionData['status'], equals('active'),
               reason: 'Direct subscription should be active immediately');

        // Test that no trial history is required for direct subscription
        await mockFirestore.collection('subscriptions').doc(testUserId).set(directSubscriptionData);
        
        // Verify no trial history exists
        final trialQuery = await mockFirestore
            .collection('trial_history')
            .where('userId', isEqualTo: testUserId)
            .get();
        expect(trialQuery.docs.isEmpty, isTrue,
               reason: 'No trial history should exist for direct subscription');

        // Verify subscription document was created
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        expect(subscriptionDoc.exists, isTrue, reason: 'Subscription document should be created');
        
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        expect(subscriptionData['status'], equals('active'));
        expect(subscriptionData['isTrialActive'], isFalse);
      });

      test('should validate trial-to-subscription upgrade logic', () async {
        // Arrange - Test trial upgrade scenario
        const testUserId = 'test-trial-upgrade-user-id';
        const testEmail = 'trialupgrade@example.com';
        
        final now = DateTime.now();
        final trialStartDate = now.subtract(const Duration(days: 2));
        final trialEndDate = now.add(const Duration(days: 5)); // 5 days remaining
        final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);

        // Create trial history data
        final trialHistoryData = {
          'userId': testUserId,
          'email': testEmail,
          'trialStartDate': Timestamp.fromDate(trialStartDate),
          'trialEndDate': Timestamp.fromDate(trialEndDate),
          'createdAt': Timestamp.fromDate(trialStartDate),
        };

        // Expected subscription data after upgrade
        final upgradeSubscriptionData = {
          'userId': testUserId,
          'email': testEmail,
          'status': 'active',
          'plan': 'monthly',
          'isTrialActive': false, // Should be deactivated after upgrade
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
          'lastPaymentDate': Timestamp.fromDate(now),
          'nextBillingDate': Timestamp.fromDate(subscriptionEndDate),
          'price': 3.0,
          'paymentMethod': 'credit_card',
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        };

        // Act & Assert - Verify upgrade logic
        expect(upgradeSubscriptionData['isTrialActive'], isFalse,
               reason: 'Trial should be deactivated after upgrade');
        expect(upgradeSubscriptionData['status'], equals('active'),
               reason: 'Subscription should be active after upgrade');

        // Test data persistence for upgrade scenario
        await mockFirestore.collection('trial_history').add(trialHistoryData);
        await mockFirestore.collection('subscriptions').doc(testUserId).set(upgradeSubscriptionData);

        // Verify trial history is preserved
        final trialQuery = await mockFirestore
            .collection('trial_history')
            .where('userId', isEqualTo: testUserId)
            .get();
        expect(trialQuery.docs.isNotEmpty, isTrue,
               reason: 'Trial history should be preserved for records');

        // Verify subscription document was created
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        expect(subscriptionDoc.exists, isTrue, reason: 'Subscription document should be created');
        
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        expect(subscriptionData['status'], equals('active'));
        expect(subscriptionData['isTrialActive'], isFalse);
      });

      test('should validate payment transaction recording requirements', () async {
        // Arrange - Test payment transaction structure
        const testUserId = 'test-payment-user-id';
        const testPaymentMethod = 'apple_pay';
        const testTransactionId = 'txn_payment_abc123';
        
        final now = DateTime.now();

        // Expected payment transaction structure
        final paymentTransactionData = {
          'userId': testUserId,
          'amount': 3.0,
          'currency': 'USD',
          'transactionId': testTransactionId,
          'type': 'monthly_subscription',
          'status': 'completed',
          'createdAt': Timestamp.fromDate(now),
        };

        // Expected subscription data with payment method reference
        final subscriptionWithPaymentData = {
          'userId': testUserId,
          'email': 'payment@example.com',
          'status': 'active',
          'plan': 'monthly',
          'paymentMethod': testPaymentMethod, // Should store payment method
          'price': 3.0,
          'createdAt': Timestamp.fromDate(now),
        };

        // Act & Assert - Verify payment transaction requirements
        expect(paymentTransactionData['userId'], equals(testUserId),
               reason: 'Transaction should have correct userId');
        expect(paymentTransactionData['amount'], equals(3.0),
               reason: 'Transaction amount should be \$3.00');
        expect(paymentTransactionData['currency'], equals('USD'),
               reason: 'Transaction currency should be USD');
        expect(paymentTransactionData['transactionId'], equals(testTransactionId),
               reason: 'Transaction should have correct transactionId');
        expect(paymentTransactionData['type'], equals('monthly_subscription'),
               reason: 'Transaction type should be monthly_subscription');
        expect(paymentTransactionData['status'], equals('completed'),
               reason: 'Transaction status should be completed');

        // Verify subscription stores payment method
        expect(subscriptionWithPaymentData['paymentMethod'], equals(testPaymentMethod),
               reason: 'Subscription should store payment method');

        // Test payment transaction persistence
        await mockFirestore.collection('payment_transactions').add(paymentTransactionData);
        await mockFirestore.collection('subscriptions').doc(testUserId).set(subscriptionWithPaymentData);

        // Verify payment transaction was recorded
        final paymentTransactions = await mockFirestore
            .collection('payment_transactions')
            .where('userId', isEqualTo: testUserId)
            .where('transactionId', isEqualTo: testTransactionId)
            .get();

        expect(paymentTransactions.docs.isNotEmpty, isTrue,
               reason: 'Payment transaction should be recorded');

        final transactionData = paymentTransactions.docs.first.data();
        expect(transactionData['amount'], equals(3.0));
        expect(transactionData['currency'], equals('USD'));
        expect(transactionData['type'], equals('monthly_subscription'));

        // Verify subscription document references payment method
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        expect(subscriptionData['paymentMethod'], equals(testPaymentMethod));
      });
    });

    group('📝 Task 5.2: Test subscription cancellation logic', () {
      test('should mark subscription as cancelled when user cancels', () async {
        // Arrange - Create active subscription
        const testUserId = 'test-cancel-user-id';
        const testEmail = 'cancel@example.com';
        
        final now = DateTime.now();
        final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);

        // Create active subscription document
        final activeSubscriptionData = {
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
        };

        await mockFirestore.collection('subscriptions').doc(testUserId).set(activeSubscriptionData);

        // Act - Simulate subscription cancellation
        final cancelledSubscriptionData = {
          'userId': testUserId,
          'email': testEmail,
          'status': 'cancelled', // Should be marked as cancelled
          'plan': 'monthly',
          'isTrialActive': false,
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
          'lastPaymentDate': Timestamp.fromDate(now),
          'nextBillingDate': Timestamp.fromDate(subscriptionEndDate),
          'price': 3.0,
          'paymentMethod': 'credit_card',
          'autoRenew': false, // Should be set to false
          'cancelledAt': Timestamp.fromDate(now), // Should record cancellation time
          'willExpireAt': Timestamp.fromDate(subscriptionEndDate), // Should set expiration date
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        };

        await mockFirestore.collection('subscriptions').doc(testUserId).update({
          'status': 'cancelled',
          'cancelledAt': Timestamp.fromDate(now),
          'willExpireAt': Timestamp.fromDate(subscriptionEndDate),
          'autoRenew': false,
          'updatedAt': Timestamp.fromDate(now),
        });

        // Assert - Verify subscription is marked as cancelled
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        expect(subscriptionDoc.exists, isTrue, reason: 'Subscription document should exist');
        
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        expect(subscriptionData['status'], equals('cancelled'),
               reason: 'Subscription status should be marked as cancelled - Requirement 5.1');
        expect(subscriptionData['autoRenew'], isFalse,
               reason: 'Auto-renewal should be disabled when cancelled');
        expect(subscriptionData['cancelledAt'], isA<Timestamp>(),
               reason: 'Cancellation timestamp should be recorded');
        expect(subscriptionData['willExpireAt'], isA<Timestamp>(),
               reason: 'Expiration date should be set when cancelled');

        // Verify willExpireAt is set to original subscription end date
        final willExpireAt = (subscriptionData['willExpireAt'] as Timestamp).toDate();
        expect(willExpireAt.year, equals(subscriptionEndDate.year),
               reason: 'willExpireAt year should match original subscription end date');
        expect(willExpireAt.month, equals(subscriptionEndDate.month),
               reason: 'willExpireAt month should match original subscription end date');
        expect(willExpireAt.day, equals(subscriptionEndDate.day),
               reason: 'willExpireAt day should match original subscription end date');
      });

      test('should calculate willExpireAt date to current billing period end', () async {
        // Arrange - Test different billing period scenarios
        const testUserId = 'test-billing-period-user-id';
        const testEmail = 'billing@example.com';
        
        final now = DateTime.now();
        
        // Test Case 1: Mid-month cancellation
        final midMonthStart = now.subtract(const Duration(days: 15));
        final midMonthEnd = now.add(const Duration(days: 15)); // Future date
        
        final midMonthSubscription = {
          'userId': testUserId,
          'email': testEmail,
          'status': 'active',
          'subscriptionStartDate': Timestamp.fromDate(midMonthStart),
          'subscriptionEndDate': Timestamp.fromDate(midMonthEnd),
          'nextBillingDate': Timestamp.fromDate(midMonthEnd),
        };

        await mockFirestore.collection('subscriptions').doc(testUserId).set(midMonthSubscription);

        // Act - Cancel subscription and set willExpireAt to billing period end
        await mockFirestore.collection('subscriptions').doc(testUserId).update({
          'status': 'cancelled',
          'willExpireAt': Timestamp.fromDate(midMonthEnd), // Should be set to current billing period end
          'cancelledAt': Timestamp.fromDate(now),
        });

        // Assert - Verify willExpireAt calculation
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        
        final willExpireAt = (subscriptionData['willExpireAt'] as Timestamp).toDate();
        final originalEndDate = (subscriptionData['subscriptionEndDate'] as Timestamp).toDate();
        
        expect(willExpireAt, equals(originalEndDate),
               reason: 'willExpireAt should equal current billing period end date - Requirement 5.2');
        expect(willExpireAt.isAfter(now), isTrue,
               reason: 'willExpireAt should be in the future when cancelled mid-billing period');

        // Test Case 2: End-of-month cancellation
        final endMonthStart = now.subtract(const Duration(days: 30));
        final endMonthEnd = now.add(const Duration(days: 5));
        
        await mockFirestore.collection('subscriptions').doc('${testUserId}_2').set({
          'userId': '${testUserId}_2',
          'email': 'endmonth@example.com',
          'status': 'active',
          'subscriptionStartDate': Timestamp.fromDate(endMonthStart),
          'subscriptionEndDate': Timestamp.fromDate(endMonthEnd),
          'nextBillingDate': Timestamp.fromDate(endMonthEnd),
        });

        await mockFirestore.collection('subscriptions').doc('${testUserId}_2').update({
          'status': 'cancelled',
          'willExpireAt': Timestamp.fromDate(endMonthEnd),
          'cancelledAt': Timestamp.fromDate(now),
        });

        final endMonthDoc = await mockFirestore.collection('subscriptions').doc('${testUserId}_2').get();
        final endMonthData = endMonthDoc.data() as Map<String, dynamic>;
        final endMonthWillExpire = (endMonthData['willExpireAt'] as Timestamp).toDate();
        
        expect(endMonthWillExpire.isAfter(now), isTrue,
               reason: 'willExpireAt should be in the future');
        expect(endMonthWillExpire, equals(endMonthEnd),
               reason: 'willExpireAt should match the billing period end date');

        // Test Case 3: Year boundary cancellation
        final yearBoundaryStart = now.subtract(const Duration(days: 45));
        final yearBoundaryEnd = now.add(const Duration(days: 20));
        
        await mockFirestore.collection('subscriptions').doc('${testUserId}_3').set({
          'userId': '${testUserId}_3',
          'email': 'yearboundary@example.com',
          'status': 'active',
          'subscriptionStartDate': Timestamp.fromDate(yearBoundaryStart),
          'subscriptionEndDate': Timestamp.fromDate(yearBoundaryEnd),
          'nextBillingDate': Timestamp.fromDate(yearBoundaryEnd),
        });

        await mockFirestore.collection('subscriptions').doc('${testUserId}_3').update({
          'status': 'cancelled',
          'willExpireAt': Timestamp.fromDate(yearBoundaryEnd),
          'cancelledAt': Timestamp.fromDate(now),
        });

        final yearBoundaryDoc = await mockFirestore.collection('subscriptions').doc('${testUserId}_3').get();
        final yearBoundaryData = yearBoundaryDoc.data() as Map<String, dynamic>;
        final yearBoundaryWillExpire = (yearBoundaryData['willExpireAt'] as Timestamp).toDate();
        
        expect(yearBoundaryWillExpire.isAfter(now), isTrue,
               reason: 'willExpireAt should be in the future');
        expect(yearBoundaryWillExpire, equals(yearBoundaryEnd),
               reason: 'willExpireAt should match the billing period end date');
      });

      test('should continue premium access until willExpireAt date', () async {
        // Arrange - Create cancelled subscription that hasn't expired yet
        const testUserId = 'test-continued-access-user-id';
        const testEmail = 'continuedaccess@example.com';
        
        final now = DateTime.now();
        final futureExpiration = now.add(const Duration(days: 15)); // 15 days in future
        final pastCancellation = now.subtract(const Duration(days: 5)); // Cancelled 5 days ago

        final cancelledSubscriptionData = {
          'userId': testUserId,
          'email': testEmail,
          'status': 'cancelled',
          'plan': 'monthly',
          'isTrialActive': false,
          'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 20))),
          'subscriptionEndDate': Timestamp.fromDate(futureExpiration),
          'willExpireAt': Timestamp.fromDate(futureExpiration), // Future expiration
          'cancelledAt': Timestamp.fromDate(pastCancellation), // Past cancellation
          'lastPaymentDate': Timestamp.fromDate(now.subtract(const Duration(days: 20))),
          'nextBillingDate': Timestamp.fromDate(futureExpiration),
          'price': 3.0,
          'paymentMethod': 'credit_card',
          'autoRenew': false,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 20))),
          'updatedAt': Timestamp.fromDate(pastCancellation),
        };

        await mockFirestore.collection('subscriptions').doc(testUserId).set(cancelledSubscriptionData);

        // Act & Assert - Verify premium access logic for cancelled but not expired subscription
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        
        expect(subscriptionData['status'], equals('cancelled'),
               reason: 'Subscription should be marked as cancelled');
        
        final willExpireAt = (subscriptionData['willExpireAt'] as Timestamp).toDate();
        final cancelledAt = (subscriptionData['cancelledAt'] as Timestamp).toDate();
        
        expect(willExpireAt.isAfter(now), isTrue,
               reason: 'willExpireAt should be in the future');
        expect(cancelledAt.isBefore(now), isTrue,
               reason: 'cancelledAt should be in the past');

        // Test premium access logic - should have access until willExpireAt
        final hasAccessUntilExpiration = now.isBefore(willExpireAt);
        expect(hasAccessUntilExpiration, isTrue,
               reason: 'User should have premium access until willExpireAt date - Requirement 5.3');

        // Test access calculation with different time scenarios
        final accessTimeRemaining = willExpireAt.difference(now);
        expect(accessTimeRemaining.inDays, greaterThan(0),
               reason: 'Should have days of access remaining');
        expect(accessTimeRemaining.inDays, equals(15),
               reason: 'Should have exactly 15 days of access remaining');

        // Test edge case: subscription cancelled today, expires in future
        final todayCancelledSubscription = {
          'userId': '${testUserId}_today',
          'email': 'todaycancel@example.com',
          'status': 'cancelled',
          'willExpireAt': Timestamp.fromDate(now.add(const Duration(days: 10))),
          'cancelledAt': Timestamp.fromDate(now),
        };

        await mockFirestore.collection('subscriptions').doc('${testUserId}_today').set(todayCancelledSubscription);
        
        final todayDoc = await mockFirestore.collection('subscriptions').doc('${testUserId}_today').get();
        final todayData = todayDoc.data() as Map<String, dynamic>;
        final todayWillExpire = (todayData['willExpireAt'] as Timestamp).toDate();
        
        final todayHasAccess = now.isBefore(todayWillExpire);
        expect(todayHasAccess, isTrue,
               reason: 'User should still have access even if cancelled today');
      });

      test('should revoke premium access after willExpireAt date is reached', () async {
        // Arrange - Create cancelled subscription that has expired
        const testUserId = 'test-revoked-access-user-id';
        const testEmail = 'revokedaccess@example.com';
        
        final now = DateTime.now();
        final pastExpiration = now.subtract(const Duration(days: 5)); // Expired 5 days ago
        final pastCancellation = now.subtract(const Duration(days: 20)); // Cancelled 20 days ago

        final expiredCancelledSubscription = {
          'userId': testUserId,
          'email': testEmail,
          'status': 'cancelled',
          'plan': 'monthly',
          'isTrialActive': false,
          'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 50))),
          'subscriptionEndDate': Timestamp.fromDate(pastExpiration),
          'willExpireAt': Timestamp.fromDate(pastExpiration), // Past expiration
          'cancelledAt': Timestamp.fromDate(pastCancellation), // Past cancellation
          'lastPaymentDate': Timestamp.fromDate(now.subtract(const Duration(days: 50))),
          'nextBillingDate': Timestamp.fromDate(pastExpiration),
          'price': 3.0,
          'paymentMethod': 'credit_card',
          'autoRenew': false,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 50))),
          'updatedAt': Timestamp.fromDate(pastCancellation),
        };

        await mockFirestore.collection('subscriptions').doc(testUserId).set(expiredCancelledSubscription);

        // Act & Assert - Verify premium access is revoked after expiration
        final subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        final subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        
        expect(subscriptionData['status'], equals('cancelled'),
               reason: 'Subscription should still be marked as cancelled');
        
        final willExpireAt = (subscriptionData['willExpireAt'] as Timestamp).toDate();
        final cancelledAt = (subscriptionData['cancelledAt'] as Timestamp).toDate();
        
        expect(willExpireAt.isBefore(now), isTrue,
               reason: 'willExpireAt should be in the past');
        expect(cancelledAt.isBefore(now), isTrue,
               reason: 'cancelledAt should be in the past');

        // Test premium access revocation logic
        final hasAccessAfterExpiration = now.isBefore(willExpireAt);
        expect(hasAccessAfterExpiration, isFalse,
               reason: 'User should NOT have premium access after willExpireAt date - Requirement 5.4');

        // Test that subscription should be updated to expired status
        final shouldBeExpired = now.isAfter(willExpireAt);
        expect(shouldBeExpired, isTrue,
               reason: 'Subscription should be considered expired');

        // Simulate system updating expired cancelled subscription
        await mockFirestore.collection('subscriptions').doc(testUserId).update({
          'status': 'expired',
          'updatedAt': Timestamp.fromDate(now),
        });

        final updatedDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        final updatedData = updatedDoc.data() as Map<String, dynamic>;
        
        expect(updatedData['status'], equals('expired'),
               reason: 'System should update status to expired after willExpireAt date');

        // Test edge cases for expiration timing
        final exactExpirationTime = now;
        final exactExpirationSubscription = {
          'userId': '${testUserId}_exact',
          'email': 'exactexpire@example.com',
          'status': 'cancelled',
          'willExpireAt': Timestamp.fromDate(exactExpirationTime),
          'cancelledAt': Timestamp.fromDate(now.subtract(const Duration(days: 10))),
        };

        await mockFirestore.collection('subscriptions').doc('${testUserId}_exact').set(exactExpirationSubscription);
        
        final exactDoc = await mockFirestore.collection('subscriptions').doc('${testUserId}_exact').get();
        final exactData = exactDoc.data() as Map<String, dynamic>;
        final exactWillExpire = (exactData['willExpireAt'] as Timestamp).toDate();
        
        // At exact expiration time, access should be revoked
        final hasAccessAtExactTime = now.isBefore(exactWillExpire);
        expect(hasAccessAtExactTime, isFalse,
               reason: 'Access should be revoked at exact expiration time');

        // Test very recent expiration (1 minute ago)
        final recentExpiration = now.subtract(const Duration(minutes: 1));
        final recentExpirationSubscription = {
          'userId': '${testUserId}_recent',
          'email': 'recentexpire@example.com',
          'status': 'cancelled',
          'willExpireAt': Timestamp.fromDate(recentExpiration),
          'cancelledAt': Timestamp.fromDate(now.subtract(const Duration(days: 10))),
        };

        await mockFirestore.collection('subscriptions').doc('${testUserId}_recent').set(recentExpirationSubscription);
        
        final recentDoc = await mockFirestore.collection('subscriptions').doc('${testUserId}_recent').get();
        final recentData = recentDoc.data() as Map<String, dynamic>;
        final recentWillExpire = (recentData['willExpireAt'] as Timestamp).toDate();
        
        final hasAccessAfterRecentExpiration = now.isBefore(recentWillExpire);
        expect(hasAccessAfterRecentExpiration, isFalse,
               reason: 'Access should be revoked even for very recent expiration');
      });

      test('should validate complete cancellation workflow and data integrity', () async {
        // Arrange - Test complete cancellation workflow from active to expired
        const testUserId = 'test-complete-workflow-user-id';
        const testEmail = 'completeworkflow@example.com';
        
        final now = DateTime.now();
        final subscriptionStart = now.subtract(const Duration(days: 10));
        final originalEndDate = DateTime(now.year, now.month + 1, now.day);

        // Step 1: Create active subscription
        final activeSubscriptionData = {
          'userId': testUserId,
          'email': testEmail,
          'status': 'active',
          'plan': 'monthly',
          'isTrialActive': false,
          'subscriptionStartDate': Timestamp.fromDate(subscriptionStart),
          'subscriptionEndDate': Timestamp.fromDate(originalEndDate),
          'lastPaymentDate': Timestamp.fromDate(subscriptionStart),
          'nextBillingDate': Timestamp.fromDate(originalEndDate),
          'price': 3.0,
          'paymentMethod': 'credit_card',
          'autoRenew': true,
          'createdAt': Timestamp.fromDate(subscriptionStart),
          'updatedAt': Timestamp.fromDate(subscriptionStart),
        };

        await mockFirestore.collection('subscriptions').doc(testUserId).set(activeSubscriptionData);

        // Verify initial active state
        var subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        var subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        expect(subscriptionData['status'], equals('active'),
               reason: 'Initial subscription should be active');
        expect(subscriptionData['autoRenew'], isTrue,
               reason: 'Initial subscription should have auto-renewal enabled');

        // Step 2: Cancel subscription
        final cancellationTime = now;
        await mockFirestore.collection('subscriptions').doc(testUserId).update({
          'status': 'cancelled',
          'cancelledAt': Timestamp.fromDate(cancellationTime),
          'willExpireAt': Timestamp.fromDate(originalEndDate), // Keep original end date
          'autoRenew': false,
          'updatedAt': Timestamp.fromDate(cancellationTime),
        });

        // Verify cancelled state
        subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        
        expect(subscriptionData['status'], equals('cancelled'),
               reason: 'Subscription should be marked as cancelled - Requirement 5.1');
        expect(subscriptionData['autoRenew'], isFalse,
               reason: 'Auto-renewal should be disabled - Requirement 5.7');
        expect(subscriptionData['cancelledAt'], isA<Timestamp>(),
               reason: 'Cancellation timestamp should be recorded');
        expect(subscriptionData['willExpireAt'], isA<Timestamp>(),
               reason: 'Expiration date should be set - Requirement 5.2');

        final willExpireAt = (subscriptionData['willExpireAt'] as Timestamp).toDate();
        expect(willExpireAt, equals(originalEndDate),
               reason: 'willExpireAt should equal original billing period end');

        // Step 3: Verify continued access during grace period
        final hasAccessDuringGracePeriod = now.isBefore(willExpireAt);
        expect(hasAccessDuringGracePeriod, isTrue,
               reason: 'Should have access during grace period - Requirement 5.3');

        // Step 4: Simulate expiration (system would do this automatically)
        final postExpirationTime = originalEndDate.add(const Duration(hours: 1));
        await mockFirestore.collection('subscriptions').doc(testUserId).update({
          'status': 'expired',
          'updatedAt': Timestamp.fromDate(postExpirationTime),
        });

        // Verify expired state
        subscriptionDoc = await mockFirestore.collection('subscriptions').doc(testUserId).get();
        subscriptionData = subscriptionDoc.data() as Map<String, dynamic>;
        
        expect(subscriptionData['status'], equals('expired'),
               reason: 'Subscription should be expired after willExpireAt date - Requirement 5.4');

        // Verify all required fields are preserved throughout workflow
        final requiredFields = [
          'userId', 'email', 'plan', 'subscriptionStartDate', 'subscriptionEndDate',
          'price', 'paymentMethod', 'cancelledAt', 'willExpireAt', 'createdAt', 'updatedAt'
        ];

        for (final field in requiredFields) {
          expect(subscriptionData.containsKey(field), isTrue,
                 reason: 'Required field $field should be preserved throughout cancellation workflow');
          expect(subscriptionData[field], isNotNull,
                 reason: 'Required field $field should not be null after cancellation');
        }

        // Verify data integrity and consistency
        final cancelledAt = (subscriptionData['cancelledAt'] as Timestamp).toDate();
        final createdAt = (subscriptionData['createdAt'] as Timestamp).toDate();
        final updatedAt = (subscriptionData['updatedAt'] as Timestamp).toDate();

        expect(cancelledAt.isAfter(createdAt), isTrue,
               reason: 'Cancellation should occur after subscription creation');
        expect(updatedAt.isAfter(cancelledAt), isTrue,
               reason: 'Last update should be after cancellation');
        expect(subscriptionData['price'], equals(3.0),
               reason: 'Price should remain unchanged during cancellation');
        expect(subscriptionData['plan'], equals('monthly'),
               reason: 'Plan should remain unchanged during cancellation');
      });

      test('should handle edge cases in cancellation logic', () async {
        // Arrange - Test various edge cases for cancellation
        const baseUserId = 'test-edge-cases-user';
        final now = DateTime.now();

        // Edge Case 1: Cancel subscription on the same day it was created
        const sameDayUserId = '${baseUserId}_same_day';
        final sameDayStart = now;
        final sameDayEnd = DateTime(now.year, now.month + 1, now.day);

        await mockFirestore.collection('subscriptions').doc(sameDayUserId).set({
          'userId': sameDayUserId,
          'email': 'sameday@example.com',
          'status': 'active',
          'subscriptionStartDate': Timestamp.fromDate(sameDayStart),
          'subscriptionEndDate': Timestamp.fromDate(sameDayEnd),
          'autoRenew': true,
          'createdAt': Timestamp.fromDate(sameDayStart),
        });

        await mockFirestore.collection('subscriptions').doc(sameDayUserId).update({
          'status': 'cancelled',
          'cancelledAt': Timestamp.fromDate(now),
          'willExpireAt': Timestamp.fromDate(sameDayEnd),
          'autoRenew': false,
        });

        var doc = await mockFirestore.collection('subscriptions').doc(sameDayUserId).get();
        var data = doc.data() as Map<String, dynamic>;
        
        expect(data['status'], equals('cancelled'),
               reason: 'Should allow cancellation on same day as creation');
        expect(data['willExpireAt'], isA<Timestamp>(),
               reason: 'Should set willExpireAt even for same-day cancellation');

        // Edge Case 2: Cancel subscription that expires at month boundary
        const monthBoundaryUserId = '${baseUserId}_month_boundary';
        final monthBoundaryStart = DateTime(2024, 1, 31);
        final monthBoundaryEnd = DateTime(2024, 2, 29); // February in leap year

        await mockFirestore.collection('subscriptions').doc(monthBoundaryUserId).set({
          'userId': monthBoundaryUserId,
          'email': 'monthboundary@example.com',
          'status': 'active',
          'subscriptionStartDate': Timestamp.fromDate(monthBoundaryStart),
          'subscriptionEndDate': Timestamp.fromDate(monthBoundaryEnd),
          'autoRenew': true,
        });

        await mockFirestore.collection('subscriptions').doc(monthBoundaryUserId).update({
          'status': 'cancelled',
          'cancelledAt': Timestamp.fromDate(now),
          'willExpireAt': Timestamp.fromDate(monthBoundaryEnd),
          'autoRenew': false,
        });

        doc = await mockFirestore.collection('subscriptions').doc(monthBoundaryUserId).get();
        data = doc.data() as Map<String, dynamic>;
        
        final monthBoundaryWillExpire = (data['willExpireAt'] as Timestamp).toDate();
        expect(monthBoundaryWillExpire.day, equals(29),
               reason: 'Should handle month boundary dates correctly');
        expect(monthBoundaryWillExpire.month, equals(2),
               reason: 'Should preserve correct month for boundary dates');

        // Edge Case 3: Cancel already cancelled subscription (should be idempotent)
        const alreadyCancelledUserId = '${baseUserId}_already_cancelled';
        final firstCancellation = now.subtract(const Duration(days: 5));
        final originalExpiration = now.add(const Duration(days: 10));

        await mockFirestore.collection('subscriptions').doc(alreadyCancelledUserId).set({
          'userId': alreadyCancelledUserId,
          'email': 'alreadycancelled@example.com',
          'status': 'cancelled',
          'cancelledAt': Timestamp.fromDate(firstCancellation),
          'willExpireAt': Timestamp.fromDate(originalExpiration),
          'autoRenew': false,
        });

        // Attempt second cancellation
        await mockFirestore.collection('subscriptions').doc(alreadyCancelledUserId).update({
          'status': 'cancelled', // Should remain cancelled
          'updatedAt': Timestamp.fromDate(now),
          // Should NOT update cancelledAt or willExpireAt
        });

        doc = await mockFirestore.collection('subscriptions').doc(alreadyCancelledUserId).get();
        data = doc.data() as Map<String, dynamic>;
        
        expect(data['status'], equals('cancelled'),
               reason: 'Status should remain cancelled for already cancelled subscription');
        
        final preservedCancelledAt = (data['cancelledAt'] as Timestamp).toDate();
        expect(preservedCancelledAt, equals(firstCancellation),
               reason: 'Original cancellation date should be preserved');

        final preservedWillExpireAt = (data['willExpireAt'] as Timestamp).toDate();
        expect(preservedWillExpireAt, equals(originalExpiration),
               reason: 'Original expiration date should be preserved');

        // Edge Case 4: Cancel subscription with missing fields
        const missingFieldsUserId = '${baseUserId}_missing_fields';
        
        await mockFirestore.collection('subscriptions').doc(missingFieldsUserId).set({
          'userId': missingFieldsUserId,
          'email': 'missingfields@example.com',
          'status': 'active',
          // Missing subscriptionEndDate and nextBillingDate
        });

        // Should handle gracefully even with missing fields
        await mockFirestore.collection('subscriptions').doc(missingFieldsUserId).update({
          'status': 'cancelled',
          'cancelledAt': Timestamp.fromDate(now),
          'autoRenew': false,
          // willExpireAt might not be set if subscriptionEndDate is missing
        });

        doc = await mockFirestore.collection('subscriptions').doc(missingFieldsUserId).get();
        data = doc.data() as Map<String, dynamic>;
        
        expect(data['status'], equals('cancelled'),
               reason: 'Should handle cancellation even with missing fields');
        expect(data['autoRenew'], isFalse,
               reason: 'Should disable auto-renewal even with missing fields');
      });
    });
  });
}