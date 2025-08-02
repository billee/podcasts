import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kapwa_companion_basic/widgets/chat_limit_dialog.dart';
import 'package:kapwa_companion_basic/models/token_usage_info.dart';

void main() {
  group('ChatLimitDialog', () {
    late TokenUsageInfo trialUsageInfo;
    late TokenUsageInfo subscribedUsageInfo;

    setUp(() {
      final resetTime = DateTime.now().add(const Duration(hours: 2, minutes: 30));
      
      trialUsageInfo = TokenUsageInfo.fromDailyUsage(
        userId: 'trial-user',
        tokensUsed: 10000,
        tokenLimit: 10000,
        userType: 'trial',
        resetTime: resetTime,
      );

      subscribedUsageInfo = TokenUsageInfo.fromDailyUsage(
        userId: 'subscribed-user',
        tokensUsed: 50000,
        tokenLimit: 50000,
        userType: 'subscribed',
        resetTime: resetTime,
      );
    });

    testWidgets('displays correct title and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatLimitDialog(usageInfo: trialUsageInfo),
          ),
        ),
      );

      expect(find.text('Daily Token Limit Reached'), findsOneWidget);
      expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
    });

    testWidgets('shows usage summary with correct token count', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatLimitDialog(usageInfo: trialUsageInfo),
          ),
        ),
      );

      expect(find.textContaining('You have used all 10000 tokens for today'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('displays reset time information', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatLimitDialog(usageInfo: trialUsageInfo),
          ),
        ),
      );

      expect(find.textContaining('Your tokens will reset in'), findsOneWidget);
      expect(find.textContaining('Reset time:'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('shows encouragement message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatLimitDialog(usageInfo: trialUsageInfo),
          ),
        ),
      );

      expect(find.textContaining('Come back tomorrow to continue chatting'), findsOneWidget);
    });

    testWidgets('shows upgrade prompt for trial users', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatLimitDialog(usageInfo: trialUsageInfo),
          ),
        ),
      );

      expect(find.textContaining('Upgrade to get more tokens daily'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('does not show upgrade prompt for subscribed users', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatLimitDialog(usageInfo: subscribedUsageInfo),
          ),
        ),
      );

      expect(find.textContaining('Upgrade to get more tokens daily'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('shows upgrade button for trial users when callback provided', (WidgetTester tester) async {
      bool upgradePressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatLimitDialog(
              usageInfo: trialUsageInfo,
              onUpgradePressed: () {
                upgradePressed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Upgrade Now'), findsOneWidget);
      
      await tester.tap(find.text('Upgrade Now'));
      await tester.pump();
      
      expect(upgradePressed, isTrue);
    });

    testWidgets('does not show upgrade button for subscribed users', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatLimitDialog(
              usageInfo: subscribedUsageInfo,
              onUpgradePressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Upgrade Now'), findsNothing);
    });

    testWidgets('always shows OK button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatLimitDialog(usageInfo: trialUsageInfo),
          ),
        ),
      );

      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('can be shown using static show method', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ChatLimitDialog.show(context, trialUsageInfo);
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Daily Token Limit Reached'), findsOneWidget);
      expect(find.textContaining('You have used all 10000 tokens'), findsOneWidget);
    });

    testWidgets('formats reset time correctly', (WidgetTester tester) async {
      // Create usage info with specific reset time for testing
      final specificResetTime = DateTime(2024, 1, 1, 14, 30); // 2:30 PM
      final usageInfo = TokenUsageInfo.fromDailyUsage(
        userId: 'test-user',
        tokensUsed: 10000,
        tokenLimit: 10000,
        userType: 'trial',
        resetTime: specificResetTime,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatLimitDialog(usageInfo: usageInfo),
          ),
        ),
      );

      // Should show formatted time (2:30 PM)
      expect(find.textContaining('2:30 PM'), findsOneWidget);
    });

    testWidgets('handles reset time less than 1 hour correctly', (WidgetTester tester) async {
      // Create usage info with reset time in 30 minutes
      final resetTime = DateTime.now().add(const Duration(minutes: 30));
      final usageInfo = TokenUsageInfo.fromDailyUsage(
        userId: 'test-user',
        tokensUsed: 10000,
        tokenLimit: 10000,
        userType: 'trial',
        resetTime: resetTime,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatLimitDialog(usageInfo: usageInfo),
          ),
        ),
      );

      // Check that it shows minutes (not exact number due to timing)
      expect(find.textContaining('Your tokens will reset in'), findsOneWidget);
      expect(find.textContaining('minutes'), findsOneWidget);
    });
  });
}