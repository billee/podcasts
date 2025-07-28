import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

import '../../lib/services/billing_scheduler_service.dart';
import '../../lib/services/billing_service.dart';
import '../../lib/services/payment_service.dart';

// Generate mocks
@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  QuerySnapshot,
  QueryDocumentSnapshot,
  Query,
])
import 'billing_scheduler_service_test.mocks.dart';

void main() {
  group('BillingSchedulerService Tests', () {
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocument;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockQuery<Map<String, dynamic>> mockQuery;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocument = MockDocumentReference<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();

      // Set up dependency injection
      BillingSchedulerService.setFirestoreInstance(mockFirestore);

      // Configure logging for tests
      Logger.root.level = Level.WARNING;

      // Stop any running scheduler before each test
      BillingSchedulerService.stopScheduler();
    });

    tearDown(() {
      // Clean up after each test
      BillingSchedulerService.stopScheduler();
    });

    group('Scheduler Management', () {
      test('should start scheduler successfully', () {
        // Act
        BillingSchedulerService.startScheduler();

        // Assert
        final status = BillingSchedulerService.getSchedulerStatus();
        expect(status['isRunning'], isTrue);
        expect(status['intervalHours'], equals(1));
        expect(status['nextRun'], isNotNull);
      });

      test('should not start scheduler if already running', () {
        // Arrange
        BillingSchedulerService.startScheduler();

        // Act
        BillingSchedulerService.startScheduler(); // Try to start again

        // Assert
        final status = BillingSchedulerService.getSchedulerStatus();
        expect(status['isRunning'], isTrue);
      });

      test('should stop scheduler successfully', () {
        // Arrange
        BillingSchedulerService.startScheduler();

        // Act
        BillingSchedulerService.stopScheduler();

        // Assert
        final status = BillingSchedulerService.getSchedulerStatus();
        expect(status['isRunning'], isFalse);
        expect(status['nextRun'], isNull);
      });

      test('should handle stopping scheduler when not running', () {
        // Act & Assert - Should not throw
        expect(() => BillingSchedulerService.stopScheduler(), returnsNormally);
        
        final status = BillingSchedulerService.getSchedulerStatus();
        expect(status['isRunning'], isFalse);
      });
    });

    group('getPendingBillingCounts', () {
      test('should return correct pending billing counts', () async {
        // Arrange
        final now = DateTime.now();
        final mockDocs = <MockQueryDocumentSnapshot<Map<String, dynamic>>>[];

        // Mock due billings query
        when(mockFirestore.collection('billing_config')).thenReturn(mockCollection);
        when(mockCollection.where('status', isEqualTo: BillingStatus.active.name))
            .thenReturn(mockQuery);
        when(mockQuery.where('nextBillingDate', isLessThanOrEqualTo: any))
            .thenReturn(mockQuery);
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn(mockDocs);

        // Mock retry billings query
        final mockBillingHistoryCollection = MockCollectionReference<Map<String, dynamic>>();
        when(mockFirestore.collection('billing_history')).thenReturn(mockBillingHistoryCollection);
        when(mockBillingHistoryCollection.where('status', isEqualTo: PaymentStatus.failed.name))
            .thenReturn(mockQuery);
        when(mockQuery.where('nextRetryDate', isLessThanOrEqualTo: any))
            .thenReturn(mockQuery);

        // Mock expired grace periods query
        when(mockCollection.where('status', isEqualTo: BillingStatus.pastDue.name))
            .thenReturn(mockQuery);
        when(mockQuery.where('gracePeriodEnd', isLessThanOrEqualTo: any))
            .thenReturn(mockQuery);

        // Act
        final result = await BillingSchedulerService.getPendingBillingCounts();

        // Assert
        expect(result, isA<Map<String, int>>());
        expect(result.containsKey('dueBillings'), isTrue);
        expect(result.containsKey('retryBillings'), isTrue);
        expect(result.containsKey('expiredGracePeriods'), isTrue);
        expect(result['dueBillings'], equals(0));
        expect(result['retryBillings'], equals(0));
        expect(result['expiredGracePeriods'], equals(0));
      });

      test('should handle errors when getting pending billing counts', () async {
        // Arrange
        when(mockFirestore.collection('billing_config')).thenReturn(mockCollection);
        when(mockCollection.where('status', isEqualTo: BillingStatus.active.name))
            .thenThrow(Exception('Firestore error'));

        // Act
        final result = await BillingSchedulerService.getPendingBillingCounts();

        // Assert
        expect(result['dueBillings'], equals(0));
        expect(result['retryBillings'], equals(0));
        expect(result['expiredGracePeriods'], equals(0));
      });
    });

    group('getBillingStatistics', () {
      test('should return billing statistics', () async {
        // Arrange
        when(mockFirestore.collection('billing_history')).thenReturn(mockCollection);
        when(mockCollection.where('billingDate', isGreaterThanOrEqualTo: any))
            .thenReturn(mockQuery);
        when(mockQuery.where('billingDate', isLessThanOrEqualTo: any))
            .thenReturn(mockQuery);
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([]);

        // Mock billing config queries
        final mockBillingConfigCollection = MockCollectionReference<Map<String, dynamic>>();
        when(mockFirestore.collection('billing_config')).thenReturn(mockBillingConfigCollection);
        when(mockBillingConfigCollection.where('status', isEqualTo: BillingStatus.active.name))
            .thenReturn(mockQuery);
        when(mockBillingConfigCollection.where('status', isEqualTo: BillingStatus.suspended.name))
            .thenReturn(mockQuery);

        // Act
        final result = await BillingSchedulerService.getBillingStatistics();

        // Assert
        expect(result, isA<Map<String, dynamic>>());
        expect(result.containsKey('currentMonth'), isTrue);
        expect(result.containsKey('activeBillings'), isTrue);
        expect(result.containsKey('suspendedBillings'), isTrue);
        expect(result.containsKey('schedulerStatus'), isTrue);
      });

      test('should handle errors when getting billing statistics', () async {
        // Arrange
        when(mockFirestore.collection('billing_history')).thenReturn(mockCollection);
        when(mockCollection.where('billingDate', isGreaterThanOrEqualTo: any))
            .thenThrow(Exception('Firestore error'));

        // Act
        final result = await BillingSchedulerService.getBillingStatistics();

        // Assert
        expect(result, isEmpty);
      });
    });

    group('triggerBillingForUser', () {
      test('should trigger billing for specific user', () async {
        // Arrange
        const userId = 'test-user-id';

        // Mock billing config
        when(mockFirestore.collection('billing_config')).thenReturn(mockCollection);
        when(mockCollection.doc(userId)).thenReturn(mockDocument);
        
        final mockDocumentSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(mockDocument.get()).thenAnswer((_) async => mockDocumentSnapshot);
        when(mockDocumentSnapshot.exists).thenReturn(false); // No billing config

        // Act
        final result = await BillingSchedulerService.triggerBillingForUser(userId);

        // Assert
        expect(result, isFalse); // Should fail due to no billing config
      });

      test('should handle errors when triggering billing for user', () async {
        // Arrange
        const userId = 'test-user-id';

        when(mockFirestore.collection('billing_config')).thenReturn(mockCollection);
        when(mockCollection.doc(userId)).thenReturn(mockDocument);
        when(mockDocument.get()).thenThrow(Exception('Firestore error'));

        // Act
        final result = await BillingSchedulerService.triggerBillingForUser(userId);

        // Assert
        expect(result, isFalse);
      });
    });

    group('processAllPendingBilling', () {
      test('should process all pending billing operations', () async {
        // Arrange
        when(mockFirestore.collection('billing_config')).thenReturn(mockCollection);
        when(mockCollection.where('status', isEqualTo: BillingStatus.active.name))
            .thenReturn(mockQuery);
        when(mockQuery.where('nextBillingDate', isLessThanOrEqualTo: any))
            .thenReturn(mockQuery);
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([]);

        // Mock billing history collection
        final mockBillingHistoryCollection = MockCollectionReference<Map<String, dynamic>>();
        when(mockFirestore.collection('billing_history')).thenReturn(mockBillingHistoryCollection);
        when(mockBillingHistoryCollection.where('status', isEqualTo: PaymentStatus.failed.name))
            .thenReturn(mockQuery);
        when(mockQuery.where('nextRetryDate', isLessThanOrEqualTo: any))
            .thenReturn(mockQuery);

        // Mock expired grace periods
        when(mockCollection.where('status', isEqualTo: BillingStatus.pastDue.name))
            .thenReturn(mockQuery);
        when(mockQuery.where('gracePeriodEnd', isLessThanOrEqualTo: any))
            .thenReturn(mockQuery);

        // Act & Assert - Should not throw
        await expectLater(
          BillingSchedulerService.processAllPendingBilling(),
          completes,
        );
      });
    });

    group('Scheduler Status', () {
      test('should return correct scheduler status when not running', () {
        // Act
        final status = BillingSchedulerService.getSchedulerStatus();

        // Assert
        expect(status['isRunning'], isFalse);
        expect(status['nextRun'], isNull);
        expect(status['intervalHours'], equals(1));
      });

      test('should return correct scheduler status when running', () {
        // Arrange
        BillingSchedulerService.startScheduler();

        // Act
        final status = BillingSchedulerService.getSchedulerStatus();

        // Assert
        expect(status['isRunning'], isTrue);
        expect(status['nextRun'], isNotNull);
        expect(status['intervalHours'], equals(1));
      });
    });

    group('Error Handling', () {
      test('should handle Firestore errors gracefully', () async {
        // Arrange
        when(mockFirestore.collection(any)).thenThrow(Exception('Firestore connection error'));

        // Act & Assert - Should not throw
        await expectLater(
          BillingSchedulerService.getPendingBillingCounts(),
          completes,
        );

        await expectLater(
          BillingSchedulerService.getBillingStatistics(),
          completes,
        );

        await expectLater(
          BillingSchedulerService.processAllPendingBilling(),
          completes,
        );
      });

      test('should handle individual billing processing errors', () async {
        // Arrange - Mock a document that would cause billing to fail
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(mockDoc.data()).thenReturn({
          'userId': 'test-user-id',
          'paymentMethod': 'creditCard',
          'amount': 3.0,
          'status': 'active',
        });

        when(mockFirestore.collection('billing_config')).thenReturn(mockCollection);
        when(mockCollection.where('status', isEqualTo: BillingStatus.active.name))
            .thenReturn(mockQuery);
        when(mockQuery.where('nextBillingDate', isLessThanOrEqualTo: any))
            .thenReturn(mockQuery);
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);

        // Mock other collections to return empty results
        final mockBillingHistoryCollection = MockCollectionReference<Map<String, dynamic>>();
        when(mockFirestore.collection('billing_history')).thenReturn(mockBillingHistoryCollection);
        when(mockBillingHistoryCollection.where('status', isEqualTo: PaymentStatus.failed.name))
            .thenReturn(mockQuery);
        when(mockQuery.where('nextRetryDate', isLessThanOrEqualTo: any))
            .thenReturn(mockQuery);

        when(mockCollection.where('status', isEqualTo: BillingStatus.pastDue.name))
            .thenReturn(mockQuery);
        when(mockQuery.where('gracePeriodEnd', isLessThanOrEqualTo: any))
            .thenReturn(mockQuery);

        // Act & Assert - Should not throw even if individual billing fails
        await expectLater(
          BillingSchedulerService.processAllPendingBilling(),
          completes,
        );
      });
    });
  });
}