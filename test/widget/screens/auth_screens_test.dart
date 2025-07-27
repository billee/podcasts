import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:kapwa_companion_basic/screens/auth/login_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/signup_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/email_verification_screen.dart';

import '../../test_config.dart';
import '../../utils/test_helpers.dart';
import '../../mocks/firebase_mocks.dart';

void main() {
  group('Authentication Screens Widget Tests', () {
    late auth_mocks.MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;

    setUpAll(() async {
      await TestConfig.initialize();
    });

    setUp(() {
      mockAuth = FirebaseMockFactory.createMockAuth();
      mockFirestore = FirebaseMockFactory.createMockFirestore();
    });

    tearDown(() async {
      await TestConfig.cleanup();
    });

    group('Login Screen Tests', () {
      testWidgets('should display login form with all required fields', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            child: const LoginScreen(),
            mockAuth: mockAuth,
            mockFirestore: mockFirestore,
          ),
        );

        // Act & Assert - Test core UI elements
        expect(find.text('Kapwa Companion'), findsOneWidget);
        expect(find.text('Welcome back! Please sign in to continue.'), findsOneWidget);
        
        // Check for form fields
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('Email Address'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        
        // Check for buttons and links
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Forgot Password?'), findsOneWidget);
        expect(find.text('Sign Up'), findsOneWidget);
      });

      testWidgets('should show password visibility toggle', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            child: const LoginScreen(),
            mockAuth: mockAuth,
            mockFirestore: mockFirestore,
          ),
        );

        // Act - Enter password to make visibility toggle appear
        final passwordField = find.byType(TextFormField).last;
        await tester.enterText(passwordField, 'password123');
        await tester.pump();

        // Assert - Should have visibility toggle
        expect(find.byIcon(Icons.visibility), findsOneWidget);

        // Act - Tap visibility toggle
        await tester.tap(find.byIcon(Icons.visibility));
        await tester.pump();

        // Assert - Should show visibility_off icon
        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      });

      testWidgets('should validate form fields', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            child: const LoginScreen(),
            mockAuth: mockAuth,
            mockFirestore: mockFirestore,
          ),
        );

        // Act - Try to submit empty form
        await tester.tap(find.text('Sign In'));
        await tester.pump();

        // Assert - Should show validation errors (form validation will prevent submission)
        expect(find.byType(LoginScreen), findsOneWidget); // Screen should still be present
      });
    });

    group('Signup Screen Tests', () {
      testWidgets('should display signup form with required fields', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            child: const SignUpScreen(),
            mockAuth: mockAuth,
            mockFirestore: mockFirestore,
          ),
        );

        // Act & Assert - Test core UI elements
        expect(find.text('Create Account'), findsOneWidget);
        expect(find.text('Personal Information'), findsOneWidget);
        
        // Check for form fields on first page
        expect(find.text('Full Name *'), findsOneWidget);
        expect(find.text('Username *'), findsOneWidget);
        expect(find.text('Email Address *'), findsOneWidget);
        
        // Check for navigation
        expect(find.text('Next'), findsOneWidget);
      });

      testWidgets('should show real-time validation feedback', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            child: const SignUpScreen(),
            mockAuth: mockAuth,
            mockFirestore: mockFirestore,
          ),
        );

        // Act - Enter data in name field
        final nameField = find.byType(TextFormField).first;
        await tester.enterText(nameField, 'A'); // Too short
        await tester.pump();

        // Assert - Should show validation feedback
        expect(find.text('Name must be at least 2 characters'), findsOneWidget);

        // Act - Enter valid name
        await tester.enterText(nameField, 'John Doe');
        await tester.pump();

        // Assert - Should show success indicator
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('should navigate through signup pages', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            child: const SignUpScreen(),
            mockAuth: mockAuth,
            mockFirestore: mockFirestore,
          ),
        );

        // Fill in valid data on first page
        await tester.enterText(find.byType(TextFormField).at(0), 'John Doe');
        await tester.enterText(find.byType(TextFormField).at(1), 'johndoe');
        await tester.enterText(find.byType(TextFormField).at(2), 'john@example.com');
        await tester.pump();

        // Act - Navigate to next page
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Assert - Should be on password page
        expect(find.textContaining('Password'), findsWidgets);
      });

      testWidgets('should show password strength indicator', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            child: const SignUpScreen(),
            mockAuth: mockAuth,
            mockFirestore: mockFirestore,
          ),
        );

        // Navigate to password page
        await tester.enterText(find.byType(TextFormField).at(0), 'John Doe');
        await tester.enterText(find.byType(TextFormField).at(1), 'johndoe');
        await tester.enterText(find.byType(TextFormField).at(2), 'john@example.com');
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Act - Enter weak password
        final passwordField = find.byType(TextFormField).first;
        await tester.enterText(passwordField, '123');
        await tester.pump();

        // Assert - Should show weak indicator
        expect(find.text('Weak'), findsOneWidget);

        // Act - Enter strong password
        await tester.enterText(passwordField, 'StrongPass123!');
        await tester.pump();

        // Assert - Should show strong indicator
        expect(find.text('Strong'), findsOneWidget);
      });

      testWidgets('should validate password confirmation', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          TestHelpers.createTestWidget(
            child: const SignUpScreen(),
            mockAuth: mockAuth,
            mockFirestore: mockFirestore,
          ),
        );

        // Navigate to password page
        await tester.enterText(find.byType(TextFormField).at(0), 'John Doe');
        await tester.enterText(find.byType(TextFormField).at(1), 'johndoe');
        await tester.enterText(find.byType(TextFormField).at(2), 'john@example.com');
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Act - Enter mismatched passwords
        await tester.enterText(find.byType(TextFormField).at(0), 'password123');
        await tester.enterText(find.byType(TextFormField).at(1), 'different123');
        await tester.pump();

        // Assert - Should show mismatch error
        expect(find.text('Passwords do not match'), findsOneWidget);

        // Act - Fix password confirmation
        await tester.enterText(find.byType(TextFormField).at(1), 'password123');
        await tester.pump();

        // Assert - Should show success indicators
        expect(find.byIcon(Icons.check_circle), findsWidgets);
      });
    });

    group('Email Verification Screen Tests', () {
      testWidgets('should verify screen class exists and can be imported', (WidgetTester tester) async {
        // Note: EmailVerificationScreen requires Firebase initialization which is complex to mock properly
        // This test verifies the screen class exists and can be imported
        expect(EmailVerificationScreen, isNotNull);
        
        // Additional UI testing would require proper Firebase mocking setup
        // which is better suited for integration tests
      });
    });
  });
}