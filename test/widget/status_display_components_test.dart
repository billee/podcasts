import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapwa_companion_basic/widgets/loading_state_widget.dart';
import 'package:kapwa_companion_basic/widgets/feedback_widget.dart';

void main() {
  group('Status Display Components Tests', () {

    testWidgets('LoadingStateWidget displays different loading types', (WidgetTester tester) async {
      // Test circular loading
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingStateWidget(
              type: LoadingType.circular,
              message: 'Loading...',
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);

      // Test dots loading
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingStateWidget(
              type: LoadingType.dots,
              message: 'Loading...',
            ),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);

      // Test linear loading
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingStateWidget(
              type: LoadingType.linear,
              message: 'Loading...',
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('LoadingButton shows loading state when isLoading is true', (WidgetTester tester) async {
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingButton(
              onPressed: () {
                buttonPressed = true;
              },
              isLoading: true,
              loadingText: 'Saving...',
              child: const Text('Save'),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saving...'), findsOneWidget);
      expect(find.text('Save'), findsNothing);

      // Button should be disabled when loading
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(buttonPressed, false);
    });

    testWidgets('LoadingButton works normally when not loading', (WidgetTester tester) async {
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingButton(
              onPressed: () {
                buttonPressed = true;
              },
              isLoading: false,
              child: const Text('Save'),
            ),
          ),
        ),
      );

      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Button should work when not loading
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(buttonPressed, true);
    });

    testWidgets('FeedbackWidget displays different feedback types', (WidgetTester tester) async {
      // Test success feedback
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedbackWidget(
              type: FeedbackType.success,
              message: 'Success message',
              title: 'Success',
            ),
          ),
        ),
      );

      expect(find.text('Success'), findsOneWidget);
      expect(find.text('Success message'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Test error feedback
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedbackWidget(
              type: FeedbackType.error,
              message: 'Error message',
              title: 'Error',
            ),
          ),
        ),
      );

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Error message'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);

      // Test warning feedback
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedbackWidget(
              type: FeedbackType.warning,
              message: 'Warning message',
              title: 'Warning',
            ),
          ),
        ),
      );

      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Warning message'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);

      // Test info feedback
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedbackWidget(
              type: FeedbackType.info,
              message: 'Info message',
              title: 'Info',
            ),
          ),
        ),
      );

      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Info message'), findsOneWidget);
      expect(find.byIcon(Icons.info), findsOneWidget);
    });

    testWidgets('FeedbackWidget can be dismissed', (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FeedbackWidget(
                type: FeedbackType.info,
                message: 'Test message',
                onDismiss: () {
                  dismissed = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test message'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap dismiss button
      await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(dismissed, true);
    });

    testWidgets('LoadingOverlay shows loading when isLoading is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingOverlay(
              isLoading: true,
              loadingMessage: 'Processing...',
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Processing...'), findsOneWidget);
      expect(find.byType(LoadingStateWidget), findsOneWidget);
    });

    testWidgets('LoadingOverlay hides loading when isLoading is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingOverlay(
              isLoading: false,
              loadingMessage: 'Processing...',
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Processing...'), findsNothing);
      expect(find.byType(LoadingStateWidget), findsNothing);
    });
  });
}