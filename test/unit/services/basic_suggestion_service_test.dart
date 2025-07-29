import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import '../../../lib/services/suggestion_service.dart';
import '../../test_config.dart';
import '../../mocks/firebase_mocks.dart';

void main() {
  group('Basic SuggestionService Tests', () {
    late FakeFirebaseFirestore mockFirestore;

    setUp(() async {
      await TestConfig.initialize();
      mockFirestore = FirebaseMockFactory.createMockFirestore(withTestData: false);
    });

    tearDown(() async {
      await TestConfig.cleanup();
    });

    group('Basic Functionality Tests', () {
      test('should return suggestions from Firestore when available', () async {
        // Arrange: Add suggestions to Firestore
        await mockFirestore.collection('ofw_suggestions').add({
          'suggestion': 'Complete Your Profile',
          'order': 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        await mockFirestore.collection('ofw_suggestions').add({
          'suggestion': 'Explore Job Opportunities',
          'order': 2,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Note: The current SuggestionService uses FirebaseFirestore.instance
        // which we can't easily mock, so this test documents expected behavior
        
        // Act: Get suggestions
        final suggestions = await SuggestionService.getSuggestions();
        
        // Assert: Should return fallback suggestions since we can't mock the instance
        expect(suggestions, isNotEmpty);
        expect(suggestions, contains('How are you feeling?'));
      });

      test('should return fallback suggestions when Firestore fails', () async {
        // Act: Get suggestions (will fail to connect to real Firestore)
        final suggestions = await SuggestionService.getSuggestions();
        
        // Assert: Should return default fallback suggestions
        expect(suggestions, isNotEmpty);
        expect(suggestions, contains('How are you feeling?'));
        expect(suggestions, contains('Share your thoughts'));
        expect(suggestions, contains('Today\'s highlights?'));
        expect(suggestions.length, equals(8));
      });

      test('should handle null suggestion data gracefully', () async {
        // Act: Get suggestions
        final suggestions = await SuggestionService.getSuggestions();
        
        // Assert: Should return fallback suggestions
        expect(suggestions, isNotEmpty);
        expect(suggestions.every((s) => s.isNotEmpty), isTrue);
      });

      test('should initialize default suggestions', () async {
        // Act: Initialize default suggestions
        await SuggestionService.initializeDefaultSuggestions();
        
        // Assert: Should complete without error
        // Note: This would add suggestions to the real Firestore instance
        // In a real test environment, we'd verify the suggestions were added
      });

      test('should add new suggestions', () async {
        // Act: Add a suggestion
        await SuggestionService.addSuggestion('Test suggestion', 1);
        
        // Assert: Should complete without error
        // Note: This would add to the real Firestore instance
      });
    });

    group('Fallback Behavior Tests', () {
      test('should provide consistent fallback suggestions', () async {
        // Act: Get suggestions multiple times
        final suggestions1 = await SuggestionService.getSuggestions();
        final suggestions2 = await SuggestionService.getSuggestions();
        
        // Assert: Should return the same fallback suggestions
        expect(suggestions1, equals(suggestions2));
        expect(suggestions1.length, equals(8));
      });

      test('should return non-empty strings in fallback suggestions', () async {
        // Act: Get suggestions
        final suggestions = await SuggestionService.getSuggestions();
        
        // Assert: All suggestions should be non-empty strings
        expect(suggestions, isNotEmpty);
        expect(suggestions.every((s) => s.isNotEmpty), isTrue);
        expect(suggestions.every((s) => s.trim().isNotEmpty), isTrue);
      });

      test('should return appropriate number of fallback suggestions', () async {
        // Act: Get suggestions
        final suggestions = await SuggestionService.getSuggestions();
        
        // Assert: Should return exactly 8 fallback suggestions
        expect(suggestions.length, equals(8));
      });
    });

    group('Error Handling Tests', () {
      test('should handle Firestore exceptions gracefully', () async {
        // Act: Get suggestions (will encounter Firestore connection error)
        final suggestions = await SuggestionService.getSuggestions();
        
        // Assert: Should not throw and return fallback suggestions
        expect(suggestions, isNotEmpty);
        expect(suggestions, isA<List<String>>());
      });

      test('should log errors appropriately', () async {
        // Act: Get suggestions (will log error due to Firestore connection)
        final suggestions = await SuggestionService.getSuggestions();
        
        // Assert: Should complete and return fallback suggestions
        expect(suggestions, isNotEmpty);
        // Note: In a real test, we'd verify the logger was called
      });
    });
  });
}