import 'package:flutter_test/flutter_test.dart';
import 'package:kapwa_companion_basic/core/token_counter.dart';
import 'package:kapwa_companion_basic/core/config.dart';

void main() {
  group('Chat Service Integration', () {
    test('should integrate token counting with chat flow', () {
      // Simulate a user message
      const userMessage = 'Hello, can you help me with something?';
      
      // Count tokens as would happen in _sendMessage
      final inputTokens = TokenCounter.countTokens(userMessage);
      
      // Verify token counting works
      expect(inputTokens, greaterThan(0));
      expect(inputTokens, equals(10)); // Expected token count
      
      // Verify token limits are configured
      expect(AppConfig.trialUserDailyTokenLimit, greaterThan(0));
      expect(AppConfig.subscribedUserDailyTokenLimit, greaterThan(0));
      expect(AppConfig.subscribedUserDailyTokenLimit, 
             greaterThanOrEqualTo(AppConfig.trialUserDailyTokenLimit));
    });

    test('should handle different message types correctly', () {
      final testMessages = [
        'Hi',
        'How are you doing today?',
        'Can you explain quantum physics in simple terms?',
        'Thanks for your help!',
      ];

      for (final message in testMessages) {
        final tokenCount = TokenCounter.countTokens(message);
        
        // All messages should have positive token counts
        expect(tokenCount, greaterThan(0));
        
        // Token count should be reasonable (not too high or too low)
        expect(tokenCount, lessThan(100)); // Sanity check
      }
    });

    test('should validate pre-chat token limit logic', () {
      // Test the logic that would be used in canUserChat validation
      const currentUsage = 9500;
      const tokenLimit = AppConfig.trialUserDailyTokenLimit;
      const newMessageTokens = 100;
      
      // User should be able to chat if under limit
      final canChatBeforeLimit = currentUsage < tokenLimit;
      expect(canChatBeforeLimit, isTrue);
      
      // User should not be able to chat if at or over limit
      const usageAtLimit = AppConfig.trialUserDailyTokenLimit;
      final canChatAtLimit = usageAtLimit < tokenLimit;
      expect(canChatAtLimit, isFalse);
    });

    test('should ensure input-only token counting', () {
      // Simulate a conversation with user and assistant messages
      final conversationMessages = [
        {'role': 'user', 'content': 'What is machine learning?'},
        {'role': 'assistant', 'content': 'Machine learning is a subset of artificial intelligence that enables computers to learn and make decisions from data without being explicitly programmed for every task.'},
        {'role': 'user', 'content': 'Can you give me an example?'},
        {'role': 'assistant', 'content': 'Sure! A common example is email spam detection. The system learns from thousands of emails labeled as spam or not spam, then uses that knowledge to automatically classify new emails.'},
      ];

      // Count only user messages (input tokens)
      final userTokens = TokenCounter.countUserMessageTokens(conversationMessages);
      
      // Count all messages
      final allTokens = TokenCounter.countMultipleMessageTokens(conversationMessages);
      
      // User tokens should be significantly less than all tokens
      expect(userTokens, lessThan(allTokens));
      
      // Verify we're only counting the user messages
      final expectedUserTokens = TokenCounter.countTokens('What is machine learning?') +
                                 TokenCounter.countTokens('Can you give me an example?');
      expect(userTokens, equals(expectedUserTokens));
    });
  });
}