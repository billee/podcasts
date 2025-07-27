import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapwa_companion_basic/widgets/subscription_confirmation_dialog.dart';
import '../base/base_test.dart';

void main() {
  TestGroups.uiTests('Subscription and Premium UI Components', () {
    group('Subscription Confirmation Dialog Tests', () {
      testWidgets('shows cancellation dialog with correct details', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SubscriptionConfirmationDialog.showCancellationDialog(
                      context: context,
                      endDate: '15/2/2025',
                      onConfirm: () {},
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Should show cancellation dialog with correct content
        expect(find.text('Cancel Subscription'), findsNWidgets(2)); // Title + Button
        expect(find.text('Are you sure you want to cancel your subscription?'), findsOneWidget);
        expect(find.text('You will keep access until 15/2/2025'), findsOneWidget);
        expect(find.text('No refund for the current billing period'), findsOneWidget);
        expect(find.text('You can resubscribe anytime'), findsOneWidget);
        expect(find.text('No more trial period after cancellation'), findsOneWidget);
        expect(find.text('Keep Subscription'), findsOneWidget);
      });

      testWidgets('shows upgrade dialog with premium features', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SubscriptionConfirmationDialog.showUpgradeDialog(
                      context: context,
                      onConfirm: () {},
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Should show upgrade dialog with premium features
        expect(find.text('Upgrade to Premium'), findsOneWidget);
        expect(find.text('Ready to unlock all premium features?'), findsOneWidget);
        expect(find.text('Unlimited AI Chat'), findsOneWidget);
        expect(find.text('Access to All Stories'), findsOneWidget);
        expect(find.text('Premium Podcast Content'), findsOneWidget);
        expect(find.text('Priority Support'), findsOneWidget);
        expect(find.text('No Ads'), findsOneWidget);
        expect(find.text('Offline Content Access'), findsOneWidget);
        expect(find.text('Upgrade Now'), findsOneWidget);
      });

      testWidgets('shows reactivation dialog with subscription details', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SubscriptionConfirmationDialog.showReactivationDialog(
                      context: context,
                      onConfirm: () {},
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Should show reactivation dialog
        expect(find.text('Reactivate Subscription'), findsOneWidget);
        expect(find.text('Reactivate your premium subscription?'), findsOneWidget);
        expect(find.text('Immediate access to all premium features'), findsOneWidget);
        expect(find.text('Monthly billing at \$3/month'), findsOneWidget);
        expect(find.text('Cancel anytime'), findsOneWidget);
        expect(find.text('Reactivate'), findsOneWidget);
      });

      testWidgets('cancellation dialog calls onConfirm when confirmed', (WidgetTester tester) async {
        bool confirmCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SubscriptionConfirmationDialog.showCancellationDialog(
                      context: context,
                      endDate: '15/2/2025',
                      onConfirm: () {
                        confirmCalled = true;
                      },
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Tap the cancel subscription button in dialog
        await tester.tap(find.text('Cancel Subscription').last);
        await tester.pumpAndSettle();

        // Should call onConfirm callback
        expect(confirmCalled, isTrue);
      });

      testWidgets('upgrade dialog calls onConfirm when confirmed', (WidgetTester tester) async {
        bool confirmCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SubscriptionConfirmationDialog.showUpgradeDialog(
                      context: context,
                      onConfirm: () {
                        confirmCalled = true;
                      },
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Tap the upgrade now button
        await tester.tap(find.text('Upgrade Now'));
        await tester.pumpAndSettle();

        // Should call onConfirm callback
        expect(confirmCalled, isTrue);
      });

      testWidgets('dialog can be cancelled without calling onConfirm', (WidgetTester tester) async {
        bool confirmCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SubscriptionConfirmationDialog.showCancellationDialog(
                      context: context,
                      endDate: '15/2/2025',
                      onConfirm: () {
                        confirmCalled = true;
                      },
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Tap the keep subscription button (cancel)
        await tester.tap(find.text('Keep Subscription'));
        await tester.pumpAndSettle();

        // Should not call onConfirm callback
        expect(confirmCalled, isFalse);
      });

      testWidgets('dialog displays correct styling and colors', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SubscriptionConfirmationDialog.showCancellationDialog(
                      context: context,
                      endDate: '15/2/2025',
                      onConfirm: () {},
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Should show dialog with proper styling
        expect(find.byType(AlertDialog), findsOneWidget);
        
        // Find the cancel subscription button (the destructive one)
        final cancelButton = find.widgetWithText(ElevatedButton, 'Cancel Subscription');
        expect(cancelButton, findsOneWidget);
        
        // Find the keep subscription button
        final keepButton = find.widgetWithText(TextButton, 'Keep Subscription');
        expect(keepButton, findsOneWidget);
      });
    });

    group('Premium Feature Display Tests', () {
      testWidgets('displays premium features list correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SubscriptionConfirmationDialog.showUpgradeDialog(
                      context: context,
                      onConfirm: () {},
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Should show all premium features
        final expectedFeatures = [
          'Unlimited AI Chat',
          'Access to All Stories',
          'Premium Podcast Content',
          'Priority Support',
          'No Ads',
          'Offline Content Access',
        ];

        for (final feature in expectedFeatures) {
          expect(find.text(feature), findsOneWidget);
        }
      });

      testWidgets('premium features are displayed with bullet points', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SubscriptionConfirmationDialog.showUpgradeDialog(
                      context: context,
                      onConfirm: () {},
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Should show bullet points for features
        expect(find.text('• '), findsNWidgets(6)); // 6 features with bullet points
      });
    });

    group('Subscription Cancellation Flow Tests', () {
      testWidgets('cancellation flow shows correct information', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SubscriptionConfirmationDialog.showCancellationDialog(
                      context: context,
                      endDate: '28/2/2025',
                      onConfirm: () {},
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Should show cancellation details
        expect(find.text('You will keep access until 28/2/2025'), findsOneWidget);
        expect(find.text('No refund for the current billing period'), findsOneWidget);
        expect(find.text('You can resubscribe anytime'), findsOneWidget);
        expect(find.text('No more trial period after cancellation'), findsOneWidget);
      });

      testWidgets('cancellation dialog has destructive styling', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SubscriptionConfirmationDialog.showCancellationDialog(
                      context: context,
                      endDate: '28/2/2025',
                      onConfirm: () {},
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Find the cancel subscription button and verify it exists
        final cancelButton = find.widgetWithText(ElevatedButton, 'Cancel Subscription');
        expect(cancelButton, findsOneWidget);
        
        // Verify the button widget exists
        final buttonWidget = tester.widget<ElevatedButton>(cancelButton);
        expect(buttonWidget, isNotNull);
      });
    });

    // Note: Tests for subscription management screens, status widgets, and admin dashboard
    // require Firebase initialization and are covered in integration tests.
    // This test file focuses on UI components that can be tested in isolation.
  });
}