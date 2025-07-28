import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:kapwa_companion_basic/services/payment_service.dart';

void main() {
  group('PaymentService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser(
        uid: 'test_user_123',
        email: 'test@example.com',
        displayName: 'Test User',
      );

      // Inject dependencies
      PaymentService.setFirestoreInstance(fakeFirestore);
      PaymentService.setAuthInstance(mockAuth);
    });

    test('should validate PCI compliance', () {
      final isCompliant = PaymentService.validatePCICompliance();
      expect(isCompliant, isA<bool>());
    });

    test('should get available payment methods', () async {
      final methods = await PaymentService.getAvailablePaymentMethods();
      expect(methods, isA<List<PaymentMethod>>());
      // Credit card should always be available
      expect(methods.contains(PaymentMethod.creditCard), isTrue);
    });

    test('should check payment method availability', () async {
      // Credit card should always be available
      final creditCardAvailable = await PaymentService.isPaymentMethodAvailable(
        PaymentMethod.creditCard,
      );
      expect(creditCardAvailable, isTrue);

      // PayPal should be available (web integration)
      final paypalAvailable = await PaymentService.isPaymentMethodAvailable(
        PaymentMethod.paypal,
      );
      expect(paypalAvailable, isTrue);
    });

    test('should sanitize payment data', () {
      final sensitiveData = {
        'cardNumber': '4111111111111111',
        'cvv': '123',
        'expiryDate': '12/25',
        'amount': 3.0,
        'currency': 'USD',
        'userId': 'test_user_123',
      };

      final sanitized = PaymentService.sanitizePaymentData(sensitiveData);

      expect(sanitized.containsKey('cardNumber'), isFalse);
      expect(sanitized.containsKey('cvv'), isFalse);
      expect(sanitized.containsKey('expiryDate'), isFalse);
      expect(sanitized.containsKey('amount'), isTrue);
      expect(sanitized.containsKey('currency'), isTrue);
      expect(sanitized.containsKey('userId'), isTrue);
    });

    test('should hash sensitive data', () {
      const sensitiveData = 'sensitive_payment_info';
      final hashedData = PaymentService.hashSensitiveData(sensitiveData);
      
      expect(hashedData, isNotEmpty);
      expect(hashedData, isNot(equals(sensitiveData)));
      expect(hashedData.length, equals(64)); // SHA-256 produces 64-character hex string
    });

    test('should update payment method for user', () async {
      const userId = 'test_user_123';
      
      // Create user document
      await fakeFirestore.collection('users').doc(userId).set({
        'email': 'test@example.com',
        'displayName': 'Test User',
      });

      final success = await PaymentService.updatePaymentMethod(
        userId: userId,
        newPaymentMethod: PaymentMethod.creditCard,
      );

      expect(success, isTrue);

      // Verify user document was updated
      final userDoc = await fakeFirestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      expect(userData['preferredPaymentMethod'], equals('creditCard'));
      expect(userData['paymentMethodUpdatedAt'], isNotNull);
    });

    test('should get payment history for user', () async {
      const userId = 'test_user_123';
      
      // Create some payment transactions
      await fakeFirestore.collection('payment_transactions').add({
        'userId': userId,
        'amount': 3.0,
        'currency': 'USD',
        'paymentMethod': 'creditCard',
        'status': 'succeeded',
        'type': 'payment',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await fakeFirestore.collection('payment_transactions').add({
        'userId': userId,
        'amount': 3.0,
        'currency': 'USD',
        'paymentMethod': 'paypal',
        'status': 'succeeded',
        'type': 'payment',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final history = await PaymentService.getPaymentHistory(userId);

      expect(history, isA<List<Map<String, dynamic>>>());
      expect(history.length, equals(2));
      expect(history.every((tx) => tx['userId'] == userId), isTrue);
    });

    test('should process refund', () async {
      const transactionId = 'test_transaction_123';
      const originalAmount = 3.0;
      const refundAmount = 3.0;

      // Create original transaction
      await fakeFirestore.collection('payment_transactions').doc(transactionId).set({
        'userId': 'test_user_123',
        'amount': originalAmount,
        'currency': 'USD',
        'paymentMethod': 'creditCard',
        'status': 'succeeded',
        'type': 'payment',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final refundResult = await PaymentService.processRefund(
        transactionId: transactionId,
        amount: refundAmount,
        reason: 'Customer request',
      );

      expect(refundResult.status, equals(PaymentStatus.succeeded));
      expect(refundResult.transactionId, isNotNull);
      expect(refundResult.metadata?['refund_amount'], equals(refundAmount));
      expect(refundResult.metadata?['original_transaction_id'], equals(transactionId));
    });

    test('should fail refund for non-existent transaction', () async {
      const nonExistentTransactionId = 'non_existent_transaction';
      const refundAmount = 3.0;

      final refundResult = await PaymentService.processRefund(
        transactionId: nonExistentTransactionId,
        amount: refundAmount,
      );

      expect(refundResult.status, equals(PaymentStatus.failed));
      expect(refundResult.error, contains('Original transaction not found'));
    });

    test('should fail refund for amount exceeding original payment', () async {
      const transactionId = 'test_transaction_123';
      const originalAmount = 3.0;
      const excessiveRefundAmount = 5.0;

      // Create original transaction
      await fakeFirestore.collection('payment_transactions').doc(transactionId).set({
        'userId': 'test_user_123',
        'amount': originalAmount,
        'currency': 'USD',
        'paymentMethod': 'creditCard',
        'status': 'succeeded',
        'type': 'payment',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final refundResult = await PaymentService.processRefund(
        transactionId: transactionId,
        amount: excessiveRefundAmount,
      );

      expect(refundResult.status, equals(PaymentStatus.failed));
      expect(refundResult.error, contains('Refund amount cannot exceed original payment amount'));
    });
  });
}