import 'package:logging/logging.dart';

/// Utility class for counting tokens in text messages
/// Provides approximate token counting for OpenAI-style tokenization
class TokenCounter {
  static final Logger _logger = Logger('TokenCounter');
  
  /// Approximate tokens per word ratio for English text
  /// Based on OpenAI's tokenization where 1 token ≈ 0.75 words
  static const double _tokensPerWord = 1.33;
  
  /// Count tokens in a text message
  /// Uses word-based approximation for token counting
  /// Returns the estimated number of tokens
  static int countTokens(String text) {
    try {
      if (text.trim().isEmpty) {
        return 0;
      }
      
      // Remove extra whitespace and split into words
      final cleanText = text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final words = cleanText.split(' ');
      
      // Calculate approximate token count
      final approximateTokens = (words.length * _tokensPerWord).ceil();
      
      _logger.fine('Token count for text (${words.length} words): $approximateTokens tokens');
      
      return approximateTokens;
    } catch (e) {
      _logger.warning('Error counting tokens: $e');
      // Return conservative estimate on error
      return text.length ~/ 4; // Fallback: ~4 characters per token
    }
  }
  
  /// Count tokens for a chat message
  /// Handles different message formats and extracts content
  static int countMessageTokens(Map<String, dynamic> message) {
    try {
      final content = message['content'] as String? ?? '';
      return countTokens(content);
    } catch (e) {
      _logger.warning('Error counting message tokens: $e');
      return 0;
    }
  }
  
  /// Count tokens for multiple messages
  /// Returns total token count across all messages
  static int countMultipleMessageTokens(List<Map<String, dynamic>> messages) {
    try {
      int totalTokens = 0;
      for (final message in messages) {
        totalTokens += countMessageTokens(message);
      }
      return totalTokens;
    } catch (e) {
      _logger.warning('Error counting multiple message tokens: $e');
      return 0;
    }
  }
  
  /// Count tokens for user input only
  /// Filters messages to only count user messages
  static int countUserMessageTokens(List<Map<String, dynamic>> messages) {
    try {
      final userMessages = messages.where((msg) => msg['role'] == 'user').toList();
      return countMultipleMessageTokens(userMessages);
    } catch (e) {
      _logger.warning('Error counting user message tokens: $e');
      return 0;
    }
  }
  
  /// Count REAL total tokens sent to OpenAI API (input tokens)
  /// This includes system prompts, conversation history, and user message
  static int countRealInputTokens(List<Map<String, dynamic>> messagesForLLM) {
    try {
      return countMultipleMessageTokens(messagesForLLM);
    } catch (e) {
      _logger.warning('Error counting real input tokens: $e');
      return 0;
    }
  }
  
  /// Count tokens for LLM response (output tokens)
  static int countOutputTokens(String response) {
    try {
      return countTokens(response);
    } catch (e) {
      _logger.warning('Error counting output tokens: $e');
      return 0;
    }
  }
}