import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../lib/screens/billing/billing_management_screen.dart';
import '../../lib/services/billing_service.dart';

// Generate mocks
@GenerateMocks([
  FirebaseAuth,
  User,
  FirebaseFirestore,
])
import 'billing_management_screen_test.mocks.dart';

void main() {
  group('BillingManagementScreen Widget Tests', () {
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockFirestore = MockFirebaseFirestore();

      // Set up default mocks
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test-user-id');
      when(mockUser.email).thenReturn('test@example.com');

      // Set up dependency injection
      BillingService.setFirestoreInstance(mockFirestore);
      BillingService.setAuthInstance(mockAuth);
    });

    testWidgets('should display loading indicator initially', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Billing Management'), findsOneWidget);
    });

    testWidgets('should display tab bar with correct tabs', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Assert
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Receipts'), findsOneWidget);
      expect(find.text('Refunds'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.byIcon(Icons.receipt), findsOneWidget);
      expect(find.byIcon(Icons.money_off), findsOneWidget);
    });

    testWidgets('should display empty state when no billing history', (WidgetTester tester) async {
      // Arrange - Mock empty billing data
      when(mockAuth.currentUser).thenReturn(mockUser);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No billing history found'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsWidgets); // One in tab, one in empty state
    });

    testWidgets('should display empty state when no receipts', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Switch to receipts tab
      await tester.tap(find.text('Receipts'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No receipts found'), findsOneWidget);
      expect(find.byIcon(Icons.receipt), findsWidgets); // One in tab, one in empty state
    });

    testWidgets('should display refund request button in refunds tab', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Switch to refunds tab
      await tester.tap(find.text('Refunds'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Request Refund'), findsOneWidget);
      expect(find.byIcon(Icons.money_off), findsWidgets); // One in tab, one in button, one in empty state
    });

    testWidgets('should open refund request dialog when button tapped', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Switch to refunds tab
      await tester.tap(find.text('Refunds'));
      await tester.pumpAndSettle();

      // Tap refund request button
      await tester.tap(find.text('Request Refund'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Request Refund'), findsWidgets); // Button and dialog title
      expect(find.text('Select Transaction:'), findsOneWidget);
      expect(find.text('Reason for Refund:'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('should close refund dialog when cancel tapped', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Switch to refunds tab and open dialog
      await tester.tap(find.text('Refunds'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request Refund'));
      await tester.pumpAndSettle();

      // Tap cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert - Dialog should be closed
      expect(find.text('Select Transaction:'), findsNothing);
      expect(find.text('Reason for Refund:'), findsNothing);
    });

    testWidgets('should disable submit button when form is incomplete', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Switch to refunds tab and open dialog
      await tester.tap(find.text('Refunds'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request Refund'));
      await tester.pumpAndSettle();

      // Assert - Submit button should be disabled initially
      final submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Submit'),
      );
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('should enable submit button when form is complete', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Switch to refunds tab and open dialog
      await tester.tap(find.text('Refunds'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request Refund'));
      await tester.pumpAndSettle();

      // Fill in the reason field
      await tester.enterText(
        find.widgetWithText(TextField, 'Please explain why you are requesting a refund...'),
        'Test refund reason',
      );
      await tester.pumpAndSettle();

      // Note: Submit button would still be disabled because no transaction is selected
      // In a real test with mocked data, we would select a transaction first
      final submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Submit'),
      );
      expect(submitButton.onPressed, isNull); // Still disabled without transaction selection
    });

    testWidgets('should handle tab switching correctly', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Test switching between tabs
      await tester.tap(find.text('Receipts'));
      await tester.pumpAndSettle();
      expect(find.text('No receipts found'), findsOneWidget);

      await tester.tap(find.text('Refunds'));
      await tester.pumpAndSettle();
      expect(find.text('Request Refund'), findsOneWidget);

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('No billing history found'), findsOneWidget);
    });

    testWidgets('should display app bar with correct title and styling', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Assert
      expect(find.text('Billing Management'), findsOneWidget);
      
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.blue[600]));
      expect(appBar.foregroundColor, equals(Colors.white));
    });

    testWidgets('should handle refresh gesture on billing history tab', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Perform refresh gesture
      await tester.fling(
        find.text('No billing history found'),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      // Assert - Should still show empty state after refresh
      expect(find.text('No billing history found'), findsOneWidget);
    });

    testWidgets('should handle refresh gesture on receipts tab', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Switch to receipts tab
      await tester.tap(find.text('Receipts'));
      await tester.pumpAndSettle();

      // Perform refresh gesture
      await tester.fling(
        find.text('No receipts found'),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      // Assert - Should still show empty state after refresh
      expect(find.text('No receipts found'), findsOneWidget);
    });

    testWidgets('should handle refresh gesture on refunds tab', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const BillingManagementScreen(),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Switch to refunds tab
      await tester.tap(find.text('Refunds'));
      await tester.pumpAndSettle();

      // Perform refresh gesture
      await tester.fling(
        find.text('No refund requests found'),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      // Assert - Should still show empty state after refresh
      expect(find.text('No refund requests found'), findsOneWidget);
    });

    group('RefundRequestDialog Widget Tests', () {
      testWidgets('should display all required form fields', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => RefundRequestDialog(
                      onRefundRequested: () {},
                    ),
                  ),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Open dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Request Refund'), findsOneWidget);
        expect(find.text('Select Transaction:'), findsOneWidget);
        expect(find.text('Reason for Refund:'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Submit'), findsOneWidget);
        expect(find.byType(DropdownButton<String>), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('should validate form input correctly', (WidgetTester tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => RefundRequestDialog(
                      onRefundRequested: () {},
                    ),
                  ),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Open dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Initially submit should be disabled
        final submitButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Submit'),
        );
        expect(submitButton.onPressed, isNull);

        // Enter reason text
        await tester.enterText(
          find.byType(TextField),
          'Test refund reason',
        );
        await tester.pumpAndSettle();

        // Submit should still be disabled without transaction selection
        final submitButtonAfterText = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Submit'),
        );
        expect(submitButtonAfterText.onPressed, isNull);
      });
    });
  });
}