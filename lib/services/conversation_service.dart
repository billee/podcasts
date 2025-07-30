// lib/services/conversation_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';

/// Service for managing conversation summarization and state preservation
class ConversationService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Set custom Firestore instance for testing
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  static final Logger _logger = Logger('ConversationService');
  
  // Configuration constants - TEMPORARILY SET TO 6 FOR MANUAL TESTING
  static const int _summaryThreshold10 = 6;  // Changed from 10 to 6 for testing
  static const int _summaryThreshold20 = 6;  // Changed from 20 to 6 for testing
  static const int _maxMessagesAfterSummary = 20;
  static const String _summariesCollection = 'chatSummaries';
  static const String _latestSummaryDoc = 'latest';
  
  // Cache keys for state preservation
  static const String _messagesKey = 'conversation_messages';
  static const String _summaryKey = 'conversation_summary';
  static const String _conversationPairsKey = 'conversation_pairs';
  static const String _messageInputKey = 'message_input_text';
  static const String _scrollPositionKey = 'scroll_position';
  
  /// Load the latest conversation summary for a user
  static Future<ConversationSummary?> loadLatestSummary(String userId) async {
    try {
      _logger.info('Loading latest summary for user: $userId');
      
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(_summariesCollection)
          .doc(_latestSummaryDoc)
          .get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final summary = ConversationSummary.fromFirestore(data);
        _logger.info('Successfully loaded summary with ${summary.conversationPairs} pairs');
        return summary;
      }
      
      _logger.info('No latest summary found for user: $userId');
      return null;
    } catch (e) {
      _logger.severe('Error loading latest summary: $e');
      return null;
    }
  }
  
  /// Save conversation summary to Firestore
  static Future<bool> saveSummary(String userId, ConversationSummary summary) async {
    try {
      _logger.info('Saving summary for user $userId with ${summary.conversationPairs} pairs');
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(_summariesCollection)
          .doc(_latestSummaryDoc)
          .set(summary.toFirestore(), SetOptions(merge: true));
      
      _logger.info('Summary saved successfully');
      return true;
    } catch (e) {
      _logger.severe('Error saving summary: $e');
      return false;
    }
  }
  
  /// Generate conversation summary using LLM
  static Future<String?> generateSummary(List<Map<String, dynamic>> messages) async {
    if (messages.isEmpty) {
      _logger.info('No messages to summarize');
      return null;
    }
    
    try {
      _logger.info('Generating summary for ${messages.length} messages');
      
      final response = await http
          .post(
            Uri.parse('${AppConfig.backendBaseUrl}/summarize_chat'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'messages': messages}),
          )
          .timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final summary = data['summary'] as String;
        _logger.info('Summary generated successfully');
        return summary;
      } else {
        _logger.severe('Failed to generate summary: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.severe('Error generating summary: $e');
      return null;
    }
  }
  
  /// Check if conversation should be summarized based on pair count
  static bool shouldSummarize(int conversationPairs, {int threshold = _summaryThreshold10}) {
    return conversationPairs >= threshold;
  }
  
  /// Trim messages after summarization to keep only recent ones
  static List<Map<String, dynamic>> trimMessagesAfterSummarization(
    List<Map<String, dynamic>> messages,
    {int maxMessages = _maxMessagesAfterSummary}
  ) {
    if (messages.length <= maxMessages + 1) return messages;
    
    // Find system message with summary
    int systemMessageIndex = messages.indexWhere((msg) =>
        msg['role'] == 'system' &&
        (msg['content'] as String).startsWith('Continuing from our last conversation:'));
    
    if (systemMessageIndex != -1) {
      // Get only user and assistant messages
      List<Map<String, dynamic>> conversationMessages = messages
          .where((msg) => msg['role'] == 'user' || msg['role'] == 'assistant')
          .toList();
      
      if (conversationMessages.length > maxMessages) {
        // Keep only recent messages
        List<Map<String, dynamic>> recentConversation =
            conversationMessages.sublist(conversationMessages.length - maxMessages);
        
        // Return system message + recent conversation
        return [messages[systemMessageIndex], ...recentConversation];
      }
    }
    
    return messages;
  }
  
  /// Save conversation state to local storage for app switching
  static Future<bool> saveConversationState({
    required List<Map<String, dynamic>> messages,
    String? summary,
    int conversationPairs = 0,
    String? messageInputText,
    double? scrollPosition,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save messages as JSON strings
      final messagesJson = messages.map((msg) => json.encode(msg)).toList();
      await prefs.setStringList(_messagesKey, messagesJson);
      
      // Save other state
      if (summary != null) {
        await prefs.setString(_summaryKey, summary);
      }
      await prefs.setInt(_conversationPairsKey, conversationPairs);
      
      if (messageInputText != null) {
        await prefs.setString(_messageInputKey, messageInputText);
      }
      
      if (scrollPosition != null) {
        await prefs.setDouble(_scrollPositionKey, scrollPosition);
      }
      
      _logger.info('Conversation state saved successfully');
      return true;
    } catch (e) {
      _logger.severe('Error saving conversation state: $e');
      return false;
    }
  }
  
  /// Load conversation state from local storage
  static Future<ConversationState?> loadConversationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load messages
      final messagesJson = prefs.getStringList(_messagesKey);
      List<Map<String, dynamic>> messages = [];
      
      if (messagesJson != null) {
        messages = messagesJson
            .map((msgJson) => Map<String, dynamic>.from(json.decode(msgJson)))
            .toList();
      }
      
      // Load other state
      final summary = prefs.getString(_summaryKey);
      final conversationPairs = prefs.getInt(_conversationPairsKey) ?? 0;
      final messageInputText = prefs.getString(_messageInputKey);
      final scrollPosition = prefs.getDouble(_scrollPositionKey);
      
      _logger.info('Conversation state loaded with ${messages.length} messages');
      
      return ConversationState(
        messages: messages,
        summary: summary,
        conversationPairs: conversationPairs,
        messageInputText: messageInputText,
        scrollPosition: scrollPosition,
      );
    } catch (e) {
      _logger.severe('Error loading conversation state: $e');
      return null;
    }
  }
  
  /// Clear conversation state from local storage
  static Future<bool> clearConversationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove(_messagesKey);
      await prefs.remove(_summaryKey);
      await prefs.remove(_conversationPairsKey);
      await prefs.remove(_messageInputKey);
      await prefs.remove(_scrollPositionKey);
      
      _logger.info('Conversation state cleared');
      return true;
    } catch (e) {
      _logger.severe('Error clearing conversation state: $e');
      return false;
    }
  }
  
  /// Delete conversation summary from Firestore
  static Future<bool> deleteSummary(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(_summariesCollection)
          .doc(_latestSummaryDoc)
          .delete();
      
      _logger.info('Conversation summary deleted for user: $userId');
      return true;
    } catch (e) {
      _logger.severe('Error deleting summary: $e');
      return false;
    }
  }
  
  /// Create system message from summary for conversation continuity
  static Map<String, dynamic> createSummarySystemMessage(String summary, String assistantName) {
    return {
      "role": "system",
      "content": "Continuing from our last conversation: $summary",
      "senderName": assistantName,
    };
  }
  
  /// Retry summarization with exponential backoff
  static Future<String?> retrySummarization(
    List<Map<String, dynamic>> messages,
    {int maxRetries = 3}
  ) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final summary = await generateSummary(messages);
        if (summary != null) {
          return summary;
        }
      } catch (e) {
        _logger.warning('Summarization attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          // Exponential backoff: 2^attempt seconds
          await Future.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
    
    _logger.severe('All summarization attempts failed');
    return null;
  }
}

/// Data model for conversation summary
class ConversationSummary {
  final String summary;
  final DateTime timestamp;
  final int conversationPairs;
  final int lastMessagesCount;
  
  ConversationSummary({
    required this.summary,
    required this.timestamp,
    required this.conversationPairs,
    required this.lastMessagesCount,
  });
  
  factory ConversationSummary.fromFirestore(Map<String, dynamic> data) {
    return ConversationSummary(
      summary: data['summary'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      conversationPairs: data['conversationPairs'] ?? 0,
      lastMessagesCount: data['lastMessagesCount'] ?? 0,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'summary': summary,
      'timestamp': FieldValue.serverTimestamp(),
      'conversationPairs': conversationPairs,
      'lastMessagesCount': lastMessagesCount,
    };
  }
}

/// Data model for conversation state
class ConversationState {
  final List<Map<String, dynamic>> messages;
  final String? summary;
  final int conversationPairs;
  final String? messageInputText;
  final double? scrollPosition;
  
  ConversationState({
    required this.messages,
    this.summary,
    required this.conversationPairs,
    this.messageInputText,
    this.scrollPosition,
  });
}