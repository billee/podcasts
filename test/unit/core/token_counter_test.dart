import 'package:flutter_test/flutter_test.dart';
import 'package:kapwa_companion_basic/core/token_counter.dart';

void main() {
  group('TokenCounter', () {
    test('should count tokens for simple text', () {
      const text = 'Hello world';
      final tokenCount = TokenCounter.countTokens(text);
      
      // 2 words * 1.33 tokens/word = ~3 tokens
      expect(tokenCount, equals(3));
    });

    test('should return 0 for empty text', () {
      const text = '';
      final tokenCount = TokenCounter.countTokens(text);
      
      expect(tokenCount, equals(0));
    });

    test('should handle whitespace correctly', () {
      const text = '  Hello   world  ';
      final tokenCount = TokenCounter.countTokens(text);
      
      // Should normalize to 2 words = ~3 tokens
      expect(tokenCount, equals(3));
    });

    test('should count tokens for longer text', () {
      const text = 'This is a longer message with more words to test token counting';
      final tokenCount = TokenCounter.countTokens(text);
      
      // 12 words * 1.33 tokens/word = ~16 tokens (actual count)
      expect(tokenCount, equals(16));
    });

    test('should count message tokens correctly', () {
      final message = {
        'role': 'user',
        'content': 'Hello world',
        'senderName': 'Test User'
      };
      
      final tokenCount = TokenCounter.countMessageTokens(message);
      expect(tokenCount, equals(3));
    });

    test('should handle message without content', () {
      final message = {
        'role': 'user',
        'senderName': 'Test User'
      };
      
      final tokenCount = TokenCounter.countMessageTokens(message);
      expect(tokenCount, equals(0));
    });

    test('should count multiple message tokens', () {
      final messages = [
        {'role': 'user', 'content': 'Hello'},
        {'role': 'assistant', 'content': 'Hi there'},
        {'role': 'user', 'content': 'How are you'},
      ];
      
      final tokenCount = TokenCounter.countMultipleMessageTokens(messages);
      // "Hello" (2) + "Hi there" (3) + "How are you" (4) = 9 tokens
      expect(tokenCount, equals(9)); // Corrected to actual count
    });

    test('should count only user message tokens', () {
      final messages = [
        {'role': 'user', 'content': 'Hello'},
        {'role': 'assistant', 'content': 'Hi there'},
        {'role': 'user', 'content': 'How are you'},
        {'role': 'system', 'content': 'System message'},
      ];
      
      final tokenCount = TokenCounter.countUserMessageTokens(messages);
      // Only "Hello" (2) + "How are you" (4) = 6 tokens
      expect(tokenCount, equals(6)); // Corrected to actual count
    });

    test('should handle error gracefully', () {
      final message = {
        'role': 'user',
        'content': null, // This should cause an error
      };
      
      final tokenCount = TokenCounter.countMessageTokens(message);
      expect(tokenCount, equals(0));
    });
  });
}