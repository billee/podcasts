import 'package:flutter_test/flutter_test.dart';
import 'package:kapwa_companion_basic/core/token_counter.dart';

void main() {
  group('TokenCounter - Simple Approximation', () {
    test('should count tokens for simple English text', () {
      const text = 'Hello world';
      final tokenCount = TokenCounter.countTokens(text);
      
      // 2 words * 1.75 tokens/word = 4 tokens (rounded up)
      expect(tokenCount, equals(4));
    });

    test('should return 0 for empty text', () {
      const text = '';
      final tokenCount = TokenCounter.countTokens(text);
      
      expect(tokenCount, equals(0));
    });

    test('should handle whitespace correctly', () {
      const text = '  Hello   world  ';
      final tokenCount = TokenCounter.countTokens(text);
      
      // Should normalize to 2 words = 4 tokens
      expect(tokenCount, equals(4));
    });

    test('should count tokens for longer text', () {
      const text = 'This is a longer message with more words to test token counting';
      final tokenCount = TokenCounter.countTokens(text);
      
      // 12 words * 1.75 tokens/word = 21 tokens
      expect(tokenCount, equals(21));
    });

    test('should count message tokens correctly', () {
      final message = {
        'role': 'user',
        'content': 'Hello world',
        'senderName': 'Test User'
      };
      
      final tokenCount = TokenCounter.countMessageTokens(message);
      expect(tokenCount, equals(4));
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
      // "Hello" (2) + "Hi there" (4) + "How are you" (6) = 12 tokens
      expect(tokenCount, equals(12));
    });

    test('should count only user message tokens', () {
      final messages = [
        {'role': 'user', 'content': 'Hello'},
        {'role': 'assistant', 'content': 'Hi there'},
        {'role': 'user', 'content': 'How are you'},
        {'role': 'system', 'content': 'System message'},
      ];
      
      final tokenCount = TokenCounter.countUserMessageTokens(messages);
      // Only "Hello" (2) + "How are you" (6) = 8 tokens
      expect(tokenCount, equals(8));
    });

    test('should count real input tokens same as multiple messages', () {
      final messages = [
        {'role': 'system', 'content': 'You are a helpful assistant'},
        {'role': 'user', 'content': 'Hello'},
      ];
      
      final multipleTokens = TokenCounter.countMultipleMessageTokens(messages);
      final realTokens = TokenCounter.countRealInputTokens(messages);
      
      // Should be the same with simple approximation
      expect(realTokens, equals(multipleTokens));
    });

    test('should count output tokens same as regular tokens', () {
      const response = 'Hello there!';
      
      final baseTokens = TokenCounter.countTokens(response);
      final outputTokens = TokenCounter.countOutputTokens(response);
      
      // Should be the same with simple approximation
      expect(outputTokens, equals(baseTokens));
    });

    test('should handle error gracefully', () {
      final message = {
        'role': 'user',
        'content': null, // This should cause an error
      };
      
      final tokenCount = TokenCounter.countMessageTokens(message);
      expect(tokenCount, equals(0));
    });

    test('should use improved ratio for better accuracy', () {
      const text = 'This is a test message with ten words total';
      final tokenCount = TokenCounter.countTokens(text);
      
      // 9 words * 1.75 = 15.75 -> 16 tokens (rounded up)
      expect(tokenCount, equals(16));
    });
  });
}