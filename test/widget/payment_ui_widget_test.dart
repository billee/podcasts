import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapwa_companion_basic/services/payment_service.dart';
import 'package:kapwa_companion_basic/screens/payment/payment_method_selection_screen.dart';
import 'package:kapwa_companion_basic/screens/payment/payment_form_screen.dart';
import 'package:kapwa_companion_basic/screens/payment/payment_confirmation_screen.dart';

void main() {
  group('Payment UI Widget Tests', () {
    testWidgets('PaymentMethodSelectionScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentMethodSelectionScreen(
            amount: 3.0,
            description: 'Premium Monthly Subscription',
            metadata: {'type': 'monthly_subscription'},
          ),
        ),
      );

      // Wait for initial render
      await tester.pump();

      // Verify basic UI elements are present
      expect(find.text('Select Payment Method'), findsOneWidget);
      expect(find.text('Payment Summary'), findsOneWidget);
      expect(find.text('Premium Monthly Subscription'), findsOneWidget);
      expect(find.text('\$3.00'), findsOneWidget);
    });

    testWidgets('PaymentFormScreen credit card form renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentFormScreen(
            paymentMethod: PaymentMethod.creditCard,
            amount: 3.0,
            description: 'Premium Monthly Subscription',
            metadata: {'type': 'monthly_subscription'},
          ),
        ),
      );

      await tester.pump();

      // Verify credit card form elements
      expect(find.text('Pay with Credit/Debit Card'), findsOneWidget);
      expect(find.text('Card Information'), findsOneWidget);
      expect(find.text('Billing Information'), findsOneWidget);
      
      // Verify form fields
      expect(find.widgetWithText(TextFormField, 'Card Number'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'MM/YY'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'CVV'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Cardholder Name'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email Address'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Full Name'), findsOneWidget);
    });

    testWidgets('PaymentFormScreen PayPal form renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentFormScreen(
            paymentMethod: PaymentMethod.paypal,
            amount: 3.0,
            description: 'Premium Monthly Subscription',
            metadata: {'type': 'monthly_subscription'},
          ),
        ),
      );

      await tester.pump();

      // Verify PayPal form elements
      expect(find.text('Pay with PayPal'), findsOneWidget);
      expect(find.text('You will be redirected to PayPal to complete your payment.'), findsOneWidget);
      expect(find.text('Click "Pay Now" to continue.'), findsOneWidget);
    });

    testWidgets('PaymentConfirmationScreen displays success information', (WidgetTester tester) async {
      final paymentResult = PaymentResult(
        status: PaymentStatus.succeeded,
        transactionId: 'TXN_123456789',
        metadata: {'paymentMethod': 'credit_card'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentConfirmationScreen(
            paymentResult: paymentResult,
            amount: 3.0,
            description: 'Premium Monthly Subscription',
            paymentMethod: PaymentMethod.creditCard,
          ),
        ),
      );

      await tester.pump();

      // Verify success elements
      expect(find.text('Payment Successful!'), findsOneWidget);
      expect(find.text('Payment Receipt'), findsOneWidget);
      expect(find.text('Premium Monthly Subscription'), findsOneWidget);
      expect(find.text('\$3.00'), findsOneWidget);
      expect(find.text('Credit/Debit Card'), findsOneWidget);
      expect(find.text('Continue to App'), findsOneWidget);
      expect(find.text('Download Receipt'), findsOneWidget);
    });

    group('Form Validation Tests', () {
      testWidgets('Credit card form shows validation errors for empty fields', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentFormScreen(
              paymentMethod: PaymentMethod.creditCard,
              amount: 3.0,
              description: 'Premium Monthly Subscription',
            ),
          ),
        );

        await tester.pump();

        // Find and tap the pay button without filling any fields
        final payButton = find.text('Pay \$3.00');
        expect(payButton, findsOneWidget);
        
        await tester.tap(payButton);
        await tester.pump();

        // Verify validation messages appear (at least some of them)
        expect(find.textContaining('Please enter'), findsAtLeastNWidgets(1));
      });

      testWidgets('Email field validates email format', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentFormScreen(
              paymentMethod: PaymentMethod.creditCard,
              amount: 3.0,
              description: 'Premium Monthly Subscription',
            ),
          ),
        );

        await tester.pump();

        // Find email field and enter invalid email
        final emailField = find.widgetWithText(TextFormField, 'Email Address');
        expect(emailField, findsOneWidget);
        
        await tester.enterText(emailField, 'invalid-email');
        
        // Tap pay button to trigger validation
        final payButton = find.text('Pay \$3.00');
        await tester.tap(payButton);
        await tester.pump();

        // Verify email validation message appears
        expect(find.text('Please enter a valid email address'), findsOneWidget);
      });

      testWidgets('Card number field formats input correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentFormScreen(
              paymentMethod: PaymentMethod.creditCard,
              amount: 3.0,
              description: 'Premium Monthly Subscription',
            ),
          ),
        );

        await tester.pump();

        // Find card number field
        final cardNumberField = find.widgetWithText(TextFormField, 'Card Number');
        expect(cardNumberField, findsOneWidget);
        
        // Enter card number digits
        await tester.enterText(cardNumberField, '4111111111111111');
        await tester.pump();

        // Verify the field formats the input with spaces
        final textField = tester.widget<TextFormField>(cardNumberField);
        expect(textField.controller?.text, equals('4111 1111 1111 1111'));
      });

      testWidgets('Expiry date field formats input correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentFormScreen(
              paymentMethod: PaymentMethod.creditCard,
              amount: 3.0,
              description: 'Premium Monthly Subscription',
            ),
          ),
        );

        await tester.pump();

        // Find expiry field
        final expiryField = find.widgetWithText(TextFormField, 'MM/YY');
        expect(expiryField, findsOneWidget);
        
        // Enter expiry date
        await tester.enterText(expiryField, '1225');
        await tester.pump();

        // Verify the field formats the input with slash
        final textField = tester.widget<TextFormField>(expiryField);
        expect(textField.controller?.text, equals('12/25'));
      });
    });

    group('UI Interaction Tests', () {
      testWidgets('CVV help dialog shows when help icon is tapped', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentFormScreen(
              paymentMethod: PaymentMethod.creditCard,
              amount: 3.0,
              description: 'Premium Monthly Subscription',
            ),
          ),
        );

        await tester.pump();

        // Find and tap the CVV help icon
        final helpIcon = find.byIcon(Icons.help_outline);
        expect(helpIcon, findsOneWidget);
        
        await tester.tap(helpIcon);
        await tester.pumpAndSettle();

        // Verify help dialog appears
        expect(find.text('What is CVV?'), findsOneWidget);
        expect(find.text('CVV (Card Verification Value) is a 3 or 4 digit security code found on your card:'), findsOneWidget);
      });

      testWidgets('Security notice is displayed on payment form', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentFormScreen(
              paymentMethod: PaymentMethod.creditCard,
              amount: 3.0,
              description: 'Premium Monthly Subscription',
            ),
          ),
        );

        await tester.pump();

        // Verify security notice is present
        expect(find.text('Your payment information is encrypted and secure. We never store your payment details.'), findsOneWidget);
        expect(find.byIcon(Icons.security), findsOneWidget);
      });
    });

    group('Payment Method Display Tests', () {
      testWidgets('Payment method icons display correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentMethodSelectionScreen(
              amount: 3.0,
              description: 'Premium Monthly Subscription',
            ),
          ),
        );

        await tester.pump();
        
        // Wait for loading to complete
        await tester.pump(const Duration(seconds: 1));

        // Verify security icon is present
        expect(find.byIcon(Icons.security), findsOneWidget);
        expect(find.text('Your payment information is encrypted and secure'), findsOneWidget);
      });
    });
  });

  group('Payment Service Utility Tests', () {
    test('Payment data sanitization removes sensitive fields', () {
      final testData = {
        'cardNumber': '4111111111111111',
        'cvv': '123',
        'expiryDate': '12/25',
        'pin': '1234',
        'password': 'secret',
        'ssn': '123-45-6789',
        'accountNumber': '1234567890',
        'email': 'test@example.com',
        'amount': 3.0,
        'description': 'Test payment',
      };

      final sanitized = PaymentService.sanitizePaymentData(testData);

      // Verify sensitive fields are removed
      expect(sanitized.containsKey('cardNumber'), false);
      expect(sanitized.containsKey('cvv'), false);
      expect(sanitized.containsKey('expiryDate'), false);
      expect(sanitized.containsKey('pin'), false);
      expect(sanitized.containsKey('password'), false);
      expect(sanitized.containsKey('ssn'), false);
      expect(sanitized.containsKey('accountNumber'), false);
      
      // Verify non-sensitive fields remain
      expect(sanitized.containsKey('email'), true);
      expect(sanitized.containsKey('amount'), true);
      expect(sanitized.containsKey('description'), true);
      expect(sanitized['email'], equals('test@example.com'));
      expect(sanitized['amount'], equals(3.0));
    });

    test('Sensitive data hashing produces consistent results', () {
      const testData = 'sensitive_information_123';
      final hash1 = PaymentService.hashSensitiveData(testData);
      final hash2 = PaymentService.hashSensitiveData(testData);

      // Verify hashing is consistent
      expect(hash1, equals(hash2));
      expect(hash1.length, greaterThan(0));
      expect(hash1, isNot(equals(testData)));
      
      // Verify different inputs produce different hashes
      final differentHash = PaymentService.hashSensitiveData('different_data');
      expect(hash1, isNot(equals(differentHash)));
    });

    test('PCI compliance validation returns boolean result', () {
      final isCompliant = PaymentService.validatePCICompliance();
      expect(isCompliant, isA<bool>());
    });
  });
}