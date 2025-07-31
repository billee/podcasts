import 'package:flutter_test/flutter_test.dart';
import 'package:kapwa_companion_basic/core/token_counter.dart';

void main() {
  group('Chat Token Integration', () {
    test('should count tokens for user message correctly', () async {
      const message = 'Hello, how are you today?';
      
      // Count tokens in the message
      final tokenCount = TokenCounter.countTokens(message);
      expect(tokenCount, greaterThan(0));
      expect(tokenCount, equals(7)); // "Hello, how are you today?" = 7 tokens
    });

    test('should count tokens accurately for different message lengths', () {
      final testCases = [
        {'message': 'Hi', 'expected': 2},
        {'message': 'Hello world', 'expected': 3},
        {'message': 'This is a longer message with multiple words', 'expected': 11},
      ];

      for (final testCase in testCases) {
        final message = testCase['message'] as String;
        final tokenCount = TokenCounter.countTokens(message);
        expect(tokenCount, equals(testCase['expected'] as int));
      }
    });

    test('should handle token counting errors gracefully', () {
      // Test with empty content (should not crash)
      final tokenCount = TokenCounter.countTokens('');
      expect(tokenCount, equals(0));
    });

    test('should only count input tokens, not response tokens', () {
      final messages = [
        {'role': 'user', 'content': 'What is the weather like?'},
        {'role': 'assistant', 'content': 'The weather is sunny and warm today with a temperature of 75 degrees Fahrenheit.'},
        {'role': 'user', 'content': 'Thanks!'},
      ];

      final userTokens = TokenCounter.countUserMessageTokens(messages);
      final allTokens = TokenCounter.countMultipleMessageTokens(messages);

      // User tokens should be less than all tokens
      expect(userTokens, lessThan(allTokens));
      
      // User tokens should only include "What is the weather like?" + "Thanks!"
      expect(userTokens, equals(9)); // Count for user messages only
    });
  });
}