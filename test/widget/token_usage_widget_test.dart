import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kapwa_companion_basic/widgets/token_usage_widget.dart';

void main() {
  group('TokenUsageWidget', () {
    testWidgets('shows nothing when userId is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TokenUsageWidget(userId: null),
          ),
        ),
      );

      expect(find.byType(TokenUsageWidget), findsOneWidget);
      // Widget should render but show nothing when userId is null
      expect(find.text('tokens left'), findsNothing);
    });

    testWidgets('renders widget when userId is provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TokenUsageWidget(userId: 'test-user'),
          ),
        ),
      );

      expect(find.byType(TokenUsageWidget), findsOneWidget);
      // Widget should render successfully
    });

    testWidgets('can be created with showWarnings disabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TokenUsageWidget(
              userId: 'test-user',
              showWarnings: false,
            ),
          ),
        ),
      );

      expect(find.byType(TokenUsageWidget), findsOneWidget);
    });
  });
}