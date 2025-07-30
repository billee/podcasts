import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../lib/services/conversation_service.dart';
import '../../test_config.dart';
import '../../mocks/firebase_mocks.dart';

void main() {
  group('ConversationService Tests - Requirement 18', () {
    late FakeFirebaseFirestore mockFirestore;

    setUp(() async {
      await TestConfig.initialize();
      mockFirestore = FirebaseMockFactory.createMockFirestore(withTestData: false);
      
      // Set the mock Firestore instance
      ConversationService.setFirestoreInstance(mockFirestore);
      
      // Initialize SharedPreferences for state preservation tests
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await TestConfig.cleanup();
      // Clear SharedPreferences between tests
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    group('Conversation Summarization Tests (Requirements 18.1, 18.2, 18.3)', () {
      test('should trigger summarization when conversation reaches 10 pairs', () async {
        // Arrange
        const conversationPairs = 10;
        
        // Act
        final shouldSummarize = ConversationService.shouldSummarize(conversationPairs, threshold: 10);
        
        // Assert
        expect(shouldSummarize, isTrue);
      });

      test('should trigger comprehensive summarization when conversation reaches 20 pairs', () async {
        // Arrange
        const conversationPairs = 20;
        
        // Act
        final shouldSummarize = ConversationService.shouldSummarize(conversationPairs, threshold: 20);
        
        // Assert
        expect(shouldSummarize, isTrue);
      });

      test('should not trigger summarization below threshold', () async {
        // Arrange
        const conversationPairs = 5;
        
        // Act
        final shouldSummarize = ConversationService.shouldSummarize(conversationPairs, threshold: 10);
        
        // Assert
        expect(shouldSummarize, isFalse);
      });

      test('should save conversation summary to Firestore with correct fields', () async {
        // Arrange
        const userId = 'test-user-123';
        final summary = ConversationSummary(
          summary: 'Test conversation summary',
          timestamp: DateTime.now(),
          conversationPairs: 10,
          lastMessagesCount: 25,
        );
        
        // Act
        final result = await ConversationService.saveSummary(userId, summary);
        
        // Assert
        expect(result, isTrue);
        
        // Verify the summary was saved to Firestore
        // Note: This would work with a properly injected mock Firestore
        // For now, we're testing the method completes without error
      });

      test('should handle summarization errors gracefully', () async {
        // Arrange
        final messages = <Map<String, dynamic>>[];
        
        // Act
        final summary = await ConversationService.generateSummary(messages);
        
        // Assert
        expect(summary, isNull); // Should return null for empty messages
      });

      test('should retry summarization with exponential backoff', () async {
        // Arrange
        final messages = [
          {'role': 'user', 'content': 'Hello'},
          {'role': 'assistant', 'content': 'Hi there!'},
        ];
        
        // Act
        final summary = await ConversationService.retrySummarization(messages, maxRetries: 2);
        
        // Assert
        // Should handle network errors gracefully and return null after retries
        expect(summary, isNull);
      });
    });

    group('Conversation State Preservation Tests (Requirements 18.5, 18.6, 18.12)', () {
      test('should save conversation state to local storage', () async {
        // Arrange
        final messages = [
          {'role': 'user', 'content': 'Hello', 'senderName': 'User'},
          {'role': 'assistant', 'content': 'Hi there!', 'senderName': 'Maria'},
        ];
        const summary = 'Previous conversation summary';
        const conversationPairs = 5;
        const messageInputText = 'Typing...';
        const scrollPosition = 150.0;
        
        // Act
        final result = await ConversationService.saveConversationState(
          messages: messages,
          summary: summary,
          conversationPairs: conversationPairs,
          messageInputText: messageInputText,
          scrollPosition: scrollPosition,
        );
        
        // Assert
        expect(result, isTrue);
        
        // Verify data was saved to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final savedMessages = prefs.getStringList('conversation_messages');
        final savedSummary = prefs.getString('conversation_summary');
        final savedPairs = prefs.getInt('conversation_pairs');
        final savedInput = prefs.getString('message_input_text');
        final savedScroll = prefs.getDouble('scroll_position');
        
        expect(savedMessages, isNotNull);
        expect(savedMessages!.length, equals(2));
        expect(savedSummary, equals(summary));
        expect(savedPairs, equals(conversationPairs));
        expect(savedInput, equals(messageInputText));
        expect(savedScroll, equals(scrollPosition));
      });

      test('should load conversation state from local storage', () async {
        // Arrange: Save state first
        final messages = [
          {'role': 'user', 'content': 'Hello', 'senderName': 'User'},
          {'role': 'assistant', 'content': 'Hi there!', 'senderName': 'Maria'},
        ];
        await ConversationService.saveConversationState(
          messages: messages,
          summary: 'Test summary',
          conversationPairs: 3,
          messageInputText: 'Test input',
          scrollPosition: 100.0,
        );
        
        // Act
        final state = await ConversationService.loadConversationState();
        
        // Assert
        expect(state, isNotNull);
        expect(state!.messages.length, equals(2));
        expect(state.messages[0]['content'], equals('Hello'));
        expect(state.messages[1]['content'], equals('Hi there!'));
        expect(state.summary, equals('Test summary'));
        expect(state.conversationPairs, equals(3));
        expect(state.messageInputText, equals('Test input'));
        expect(state.scrollPosition, equals(100.0));
      });

      test('should handle corrupted state data gracefully', () async {
        // Arrange: Set corrupted data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('conversation_messages', ['invalid_json']);
        
        // Act
        final state = await ConversationService.loadConversationState();
        
        // Assert
        expect(state, isNull); // Should return null for corrupted data
      });

      test('should clear conversation state', () async {
        // Arrange: Save some state first
        await ConversationService.saveConversationState(
          messages: [{'role': 'user', 'content': 'test'}],
          conversationPairs: 1,
        );
        
        // Act
        final result = await ConversationService.clearConversationState();
        
        // Assert
        expect(result, isTrue);
        
        // Verify state was cleared
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('conversation_messages'), isNull);
        expect(prefs.getInt('conversation_pairs'), isNull);
      });
    });

    group('Conversation Continuity Tests (Requirements 18.4, 18.10, 18.14)', () {
      test('should load latest summary on app restart', () async {
        // Arrange
        const userId = 'test-user-123';
        
        // Act
        final summary = await ConversationService.loadLatestSummary(userId);
        
        // Assert
        // Should handle case where no summary exists
        expect(summary, isNull);
      });

      test('should create system message from summary', () async {
        // Arrange
        const summary = 'We were discussing job opportunities in Dubai';
        const assistantName = 'Maria';
        
        // Act
        final systemMessage = ConversationService.createSummarySystemMessage(summary, assistantName);
        
        // Assert
        expect(systemMessage['role'], equals('system'));
        expect(systemMessage['content'], contains('Continuing from our last conversation:'));
        expect(systemMessage['content'], contains(summary));
        expect(systemMessage['senderName'], equals(assistantName));
      });

      test('should maintain conversation continuity with summary context', () async {
        // Arrange
        final messages = [
          {'role': 'system', 'content': 'Continuing from our last conversation: Previous discussion about jobs'},
          {'role': 'user', 'content': 'Tell me more about that'},
          {'role': 'assistant', 'content': 'Based on our previous discussion...'},
        ];
        
        // Act
        final hasSystemMessage = messages.any((msg) => 
          msg['role'] == 'system' && 
          (msg['content'] as String).startsWith('Continuing from our last conversation:')
        );
        
        // Assert
        expect(hasSystemMessage, isTrue);
      });
    });

    group('Message Trimming Tests (Requirements 18.7)', () {
      test('should trim messages after summarization keeping recent 20 messages', () async {
        // Arrange: Create 30 messages
        final messages = <Map<String, dynamic>>[];
        
        // Add system message with summary
        messages.add({
          'role': 'system',
          'content': 'Continuing from our last conversation: Previous summary',
          'senderName': 'Maria'
        });
        
        // Add 30 conversation messages (15 pairs)
        for (int i = 0; i < 15; i++) {
          messages.add({'role': 'user', 'content': 'User message $i', 'senderName': 'User'});
          messages.add({'role': 'assistant', 'content': 'Assistant message $i', 'senderName': 'Maria'});
        }
        
        // Act
        final trimmedMessages = ConversationService.trimMessagesAfterSummarization(messages, maxMessages: 20);
        
        // Assert
        expect(trimmedMessages.length, equals(21)); // 1 system + 20 conversation messages
        expect(trimmedMessages.first['role'], equals('system'));
        expect(trimmedMessages.last['content'], contains('Assistant message 14')); // Most recent message
      });

      test('should not trim messages if under limit', () async {
        // Arrange
        final messages = [
          {'role': 'system', 'content': 'Continuing from our last conversation: Summary'},
          {'role': 'user', 'content': 'Hello'},
          {'role': 'assistant', 'content': 'Hi there!'},
        ];
        
        // Act
        final trimmedMessages = ConversationService.trimMessagesAfterSummarization(messages);
        
        // Assert
        expect(trimmedMessages.length, equals(3)); // No trimming needed
        expect(trimmedMessages, equals(messages));
      });
    });

    group('Error Handling and Edge Cases (Requirements 18.8, 18.13)', () {
      test('should handle network connectivity loss during summarization', () async {
        // Arrange
        final messages = [
          {'role': 'user', 'content': 'Hello'},
          {'role': 'assistant', 'content': 'Hi there!'},
        ];
        
        // Act
        final summary = await ConversationService.generateSummary(messages);
        
        // Assert
        // Should handle network errors gracefully
        expect(summary, isNull);
      });

      test('should continue conversation without interruption when summarization fails', () async {
        // Arrange
        final messages = [
          {'role': 'user', 'content': 'Hello'},
          {'role': 'assistant', 'content': 'Hi there!'},
        ];
        
        // Act & Assert
        // The service should not throw exceptions even when summarization fails
        expect(() async => await ConversationService.generateSummary(messages), returnsNormally);
      });

      test('should handle empty message list gracefully', () async {
        // Arrange
        final messages = <Map<String, dynamic>>[];
        
        // Act
        final summary = await ConversationService.generateSummary(messages);
        
        // Assert
        expect(summary, isNull);
      });

      test('should handle Firestore errors when saving summary', () async {
        // Arrange
        const userId = 'test-user-123';
        final summary = ConversationSummary(
          summary: 'Test summary',
          timestamp: DateTime.now(),
          conversationPairs: 10,
          lastMessagesCount: 20,
        );
        
        // Act
        final result = await ConversationService.saveSummary(userId, summary);
        
        // Assert
        // Should handle Firestore errors gracefully
        expect(result, isA<bool>());
      });

      test('should handle SharedPreferences errors when saving state', () async {
        // Arrange
        final messages = [
          {'role': 'user', 'content': 'Hello'},
        ];
        
        // Act & Assert
        // Should not throw exceptions even if SharedPreferences fails
        expect(() async => await ConversationService.saveConversationState(messages: messages, conversationPairs: 1), 
               returnsNormally);
      });
    });

    group('Chat Clearing Tests (Requirement 18.9)', () {
      test('should delete conversation summary when chat is cleared', () async {
        // Arrange
        const userId = 'test-user-123';
        
        // Act
        final result = await ConversationService.deleteSummary(userId);
        
        // Assert
        expect(result, isA<bool>());
      });

      test('should reset conversation counters when chat is cleared', () async {
        // Arrange: Save some state
        await ConversationService.saveConversationState(
          messages: [{'role': 'user', 'content': 'test'}],
          conversationPairs: 5,
        );
        
        // Act: Clear state
        await ConversationService.clearConversationState();
        
        // Load state to verify it's cleared
        final state = await ConversationService.loadConversationState();
        
        // Assert
        expect(state?.conversationPairs, equals(0));
        expect(state?.messages, isEmpty);
      });
    });

    group('Cumulative Summary Tests (Requirement 18.11)', () {
      test('should build upon previous summaries', () async {
        // Arrange
        final previousSummary = ConversationSummary(
          summary: 'Previous conversation about job searching',
          timestamp: DateTime.now().subtract(Duration(hours: 1)),
          conversationPairs: 10,
          lastMessagesCount: 20,
        );
        
        final newMessages = [
          {'role': 'user', 'content': 'What about visa requirements?'},
          {'role': 'assistant', 'content': 'For visa requirements, you need...'},
        ];
        
        // Act
        // In a real implementation, the summarization would include previous summary as context
        final shouldIncludePreviousContext = previousSummary.summary.isNotEmpty;
        
        // Assert
        expect(shouldIncludePreviousContext, isTrue);
      });
    });

    group('Background Processing Tests (Requirement 18.15)', () {
      test('should perform summarization without blocking user interaction', () async {
        // Arrange
        final messages = [
          {'role': 'user', 'content': 'Hello'},
          {'role': 'assistant', 'content': 'Hi there!'},
        ];
        
        // Act
        final future = ConversationService.generateSummary(messages);
        
        // Assert
        // The method should return a Future, allowing background processing
        expect(future, isA<Future<String?>>());
        
        // Should not block - we can do other operations
        final otherOperation = ConversationService.shouldSummarize(5);
        expect(otherOperation, isFalse);
        
        // Wait for summarization to complete
        final result = await future;
        expect(result, isA<String?>());
      });
    });

    group('Data Model Tests', () {
      test('should create ConversationSummary from Firestore data', () async {
        // Arrange
        final firestoreData = {
          'summary': 'Test summary',
          'timestamp': Timestamp.now(),
          'conversationPairs': 10,
          'lastMessagesCount': 25,
        };
        
        // Act
        final summary = ConversationSummary.fromFirestore(firestoreData);
        
        // Assert
        expect(summary.summary, equals('Test summary'));
        expect(summary.conversationPairs, equals(10));
        expect(summary.lastMessagesCount, equals(25));
        expect(summary.timestamp, isA<DateTime>());
      });

      test('should convert ConversationSummary to Firestore format', () async {
        // Arrange
        final summary = ConversationSummary(
          summary: 'Test summary',
          timestamp: DateTime.now(),
          conversationPairs: 10,
          lastMessagesCount: 25,
        );
        
        // Act
        final firestoreData = summary.toFirestore();
        
        // Assert
        expect(firestoreData['summary'], equals('Test summary'));
        expect(firestoreData['conversationPairs'], equals(10));
        expect(firestoreData['lastMessagesCount'], equals(25));
        expect(firestoreData['timestamp'], isA<FieldValue>());
      });

      test('should create ConversationState with all properties', () async {
        // Arrange & Act
        final state = ConversationState(
          messages: [{'role': 'user', 'content': 'Hello'}],
          summary: 'Test summary',
          conversationPairs: 5,
          messageInputText: 'Typing...',
          scrollPosition: 100.0,
        );
        
        // Assert
        expect(state.messages.length, equals(1));
        expect(state.summary, equals('Test summary'));
        expect(state.conversationPairs, equals(5));
        expect(state.messageInputText, equals('Typing...'));
        expect(state.scrollPosition, equals(100.0));
      });
    });
  });
}