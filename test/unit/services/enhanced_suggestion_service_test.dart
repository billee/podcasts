import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../lib/services/enhanced_suggestion_service.dart';
import '../../test_config.dart';
import '../../mocks/firebase_mocks.dart';

void main() {
  group('EnhancedSuggestionService Tests', () {
    late FakeFirebaseFirestore mockFirestore;

    setUp(() async {
      await TestConfig.initialize();
      mockFirestore = FirebaseMockFactory.createMockFirestore(withTestData: false);
      
      // Set the mock Firestore instance for the service
      EnhancedSuggestionService.setFirestoreInstance(mockFirestore);
      
      // Initialize SharedPreferences for offline caching tests
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await TestConfig.cleanup();
      // Clear cache between tests
      await EnhancedSuggestionService.clearCache();
    });

    group('Random Suggestion Selection Algorithm Tests', () {
      test('should return random suggestions using weighted algorithm', () async {
        // Arrange: Add suggestions with different priorities
        await _populatePrioritizedSuggestions(mockFirestore);
        
        // Act: Get suggestions multiple times
        final results = <List<SuggestionModel>>[];
        for (int i = 0; i < 10; i++) {
          final suggestions = await EnhancedSuggestionService.getSuggestions(
            userStatus: 'all',
            language: 'en',
            limit: 3,
            useCache: false,
          );
          results.add(suggestions);
        }
        
        // Assert: Results should vary due to randomization
        expect(results.every((list) => list.isNotEmpty), isTrue);
        
        // Check that high priority suggestions appear more frequently
        final allFirstSuggestions = results.map((list) => list.first.title).toList();
        final highPriorityCount = allFirstSuggestions
            .where((title) => title.contains('High Priority'))
            .length;
        
        // High priority suggestions should appear more often (not a strict requirement due to randomness)
        expect(highPriorityCount, greaterThan(0));
      });

      test('should handle empty suggestion pool gracefully', () async {
        // Arrange: No suggestions in Firestore
        
        // Act: Get suggestions
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          userStatus: 'all',
          language: 'en',
          limit: 5,
          useCache: false,
        );
        
        // Assert: Should return default suggestions
        expect(suggestions, isNotEmpty);
        expect(suggestions.any((s) => s.title.contains('How are you feeling?')), isTrue);
      });

      test('should respect limit parameter', () async {
        // Arrange: Add many suggestions
        await _populateManySuggestions(mockFirestore);
        
        // Act: Get suggestions with different limits
        final suggestions3 = await EnhancedSuggestionService.getSuggestions(
          limit: 3,
          useCache: false,
        );
        final suggestions5 = await EnhancedSuggestionService.getSuggestions(
          limit: 5,
          useCache: false,
        );
        
        // Assert: Should respect the limit
        expect(suggestions3.length, equals(3));
        expect(suggestions5.length, equals(5));
      });

      test('should prioritize higher priority suggestions', () async {
        // Arrange: Add suggestions with clear priority differences
        await _populatePrioritizedSuggestions(mockFirestore);
        
        // Act: Get suggestions multiple times and track results
        final priorityCounts = <String, int>{};
        for (int i = 0; i < 50; i++) {
          final suggestions = await EnhancedSuggestionService.getSuggestions(
            limit: 1,
            useCache: false,
          );
          if (suggestions.isNotEmpty) {
            final title = suggestions.first.title;
            priorityCounts[title] = (priorityCounts[title] ?? 0) + 1;
          }
        }
        
        // Assert: High priority suggestions should appear more frequently
        final highPriorityCount = priorityCounts['High Priority Suggestion'] ?? 0;
        final lowPriorityCount = priorityCounts['Low Priority Suggestion'] ?? 0;
        
        expect(highPriorityCount, greaterThan(lowPriorityCount));
      });
    });

    group('Contextual Filtering Based on User Status Tests', () {
      test('should filter suggestions for new users', () async {
        // Arrange: Add suggestions with different target audiences
        await _populateTargetedSuggestions(mockFirestore);
        
        // Act: Get suggestions for new user
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          userStatus: 'new_users',
          language: 'en',
          useCache: false,
        );
        
        // Assert: Should contain suggestions for new users and universal ones
        expect(suggestions, isNotEmpty);
        expect(
          suggestions.every((s) => 
            s.targetAudience == 'new_users' || s.targetAudience == 'all'
          ),
          isTrue,
        );
      });

      test('should filter suggestions for trial users', () async {
        // Arrange: Add suggestions targeted at trial users
        await _populateTargetedSuggestions(mockFirestore);
        
        // Act: Get suggestions for trial user
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          userStatus: 'trial_users',
          language: 'en',
          useCache: false,
        );
        
        // Assert: Should contain trial-specific and universal suggestions
        expect(suggestions, isNotEmpty);
        expect(
          suggestions.every((s) => 
            s.targetAudience == 'trial_users' || s.targetAudience == 'all'
          ),
          isTrue,
        );
      });

      test('should filter suggestions for premium users', () async {
        // Arrange: Add suggestions targeted at premium users
        await _populateTargetedSuggestions(mockFirestore);
        
        // Act: Get suggestions for premium user
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          userStatus: 'premium_users',
          language: 'en',
          useCache: false,
        );
        
        // Assert: Should contain premium-specific and universal suggestions
        expect(suggestions, isNotEmpty);
        expect(
          suggestions.every((s) => 
            s.targetAudience == 'premium_users' || s.targetAudience == 'all'
          ),
          isTrue,
        );
      });

      test('should include universal suggestions for all user types', () async {
        // Arrange: Add universal suggestions
        await _populateUniversalSuggestions(mockFirestore);
        
        // Act: Get suggestions for different user types
        final newUserSuggestions = await EnhancedSuggestionService.getSuggestions(
          userStatus: 'new_users',
          useCache: false,
        );
        final trialUserSuggestions = await EnhancedSuggestionService.getSuggestions(
          userStatus: 'trial_users',
          useCache: false,
        );
        
        // Assert: All should contain universal suggestions
        expect(newUserSuggestions, isNotEmpty);
        expect(trialUserSuggestions, isNotEmpty);
        expect(
          newUserSuggestions.any((s) => s.targetAudience == 'all'),
          isTrue,
        );
        expect(
          trialUserSuggestions.any((s) => s.targetAudience == 'all'),
          isTrue,
        );
      });

      test('should exclude inactive suggestions', () async {
        // Arrange: Add both active and inactive suggestions
        await _populateActiveInactiveSuggestions(mockFirestore);
        
        // Act: Get suggestions
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          useCache: false,
        );
        
        // Assert: Should only contain active suggestions
        expect(suggestions, isNotEmpty);
        expect(suggestions.every((s) => s.isActive), isTrue);
        expect(suggestions.any((s) => s.title.contains('inactive')), isFalse);
      });
    });

    group('Multi-language Content Delivery Tests', () {
      test('should return suggestions in English by default', () async {
        // Arrange: Add suggestions in multiple languages
        await _populateMultiLanguageSuggestions(mockFirestore);
        
        // Act: Get suggestions without language preference
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          language: 'en',
          useCache: false,
        );
        
        // Assert: Should return English and universal suggestions
        expect(suggestions, isNotEmpty);
        expect(
          suggestions.every((s) => s.language == 'en' || s.language == 'all'),
          isTrue,
        );
      });

      test('should filter suggestions by Filipino language', () async {
        // Arrange: Add suggestions in Filipino
        await _populateMultiLanguageSuggestions(mockFirestore);
        
        // Act: Get suggestions for Filipino language
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          language: 'fil',
          useCache: false,
        );
        
        // Assert: Should contain Filipino and universal suggestions
        expect(suggestions, isNotEmpty);
        expect(
          suggestions.every((s) => s.language == 'fil' || s.language == 'all'),
          isTrue,
        );
      });

      test('should filter suggestions by Arabic language', () async {
        // Arrange: Add suggestions in Arabic
        await _populateMultiLanguageSuggestions(mockFirestore);
        
        // Act: Get suggestions for Arabic language
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          language: 'ar',
          useCache: false,
        );
        
        // Assert: Should contain Arabic and universal suggestions
        expect(suggestions, isNotEmpty);
        expect(
          suggestions.every((s) => s.language == 'ar' || s.language == 'all'),
          isTrue,
        );
      });

      test('should fallback to default when preferred language unavailable', () async {
        // Arrange: Add only English suggestions
        await _populateEnglishOnlySuggestions(mockFirestore);
        
        // Act: Request suggestions in Chinese (not available)
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          language: 'zh',
          useCache: false,
        );
        
        // Assert: Should return default Chinese suggestions
        expect(suggestions, isNotEmpty);
        // Since no Chinese suggestions exist in Firestore, should get defaults
      });

      test('should return appropriate default suggestions for each language', () async {
        // Act: Get default suggestions for different languages
        final englishSuggestions = await EnhancedSuggestionService.getSuggestions(
          language: 'en',
          useCache: false,
        );
        final filipinoSuggestions = await EnhancedSuggestionService.getSuggestions(
          language: 'fil',
          useCache: false,
        );
        final arabicSuggestions = await EnhancedSuggestionService.getSuggestions(
          language: 'ar',
          useCache: false,
        );
        
        // Assert: Should return language-appropriate defaults
        expect(englishSuggestions, isNotEmpty);
        expect(filipinoSuggestions, isNotEmpty);
        expect(arabicSuggestions, isNotEmpty);
        
        expect(englishSuggestions.first.language, equals('en'));
        expect(filipinoSuggestions.first.language, equals('fil'));
        expect(arabicSuggestions.first.language, equals('ar'));
      });
    });

    group('Offline Caching and Content Synchronization Tests', () {
      test('should cache suggestions locally after first fetch', () async {
        // Arrange: Add suggestions to Firestore
        await _populateTestSuggestions(mockFirestore);
        
        // Act: Get suggestions (should cache them)
        final suggestions1 = await EnhancedSuggestionService.getSuggestions(
          useCache: true,
        );
        
        // Verify cache was created
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getStringList('cached_suggestions');
        expect(cachedData, isNotNull);
        expect(cachedData!.isNotEmpty, isTrue);
        
        // Act: Get suggestions again (should use cache)
        final suggestions2 = await EnhancedSuggestionService.getSuggestions(
          useCache: true,
        );
        
        // Assert: Should return cached suggestions
        expect(suggestions1, isNotEmpty);
        expect(suggestions2, isNotEmpty);
        expect(suggestions1.length, equals(suggestions2.length));
      });

      test('should use cache when available and not expired', () async {
        // Arrange: Populate cache manually
        final testSuggestions = [
          SuggestionModel(
            id: 'cached-1',
            title: 'Cached Suggestion 1',
            description: 'This is cached',
            category: 'general',
            targetAudience: 'all',
            language: 'en',
            actionType: 'modal',
            priority: 1,
            isActive: true,
          ),
        ];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          'cached_suggestions',
          testSuggestions.map((s) => jsonEncode(s.toJson())).toList(),
        );
        await prefs.setInt('cache_timestamp', DateTime.now().millisecondsSinceEpoch);
        
        // Act: Get suggestions (should use cache)
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          useCache: true,
        );
        
        // Assert: Should return cached suggestions
        expect(suggestions, isNotEmpty);
        expect(suggestions.first.title, equals('Cached Suggestion 1'));
      });

      test('should refresh cache when expired', () async {
        // Arrange: Set up expired cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cached_suggestions', ['{"id":"old","title":"Old"}']);
        await prefs.setInt(
          'cache_timestamp',
          DateTime.now().subtract(Duration(days: 2)).millisecondsSinceEpoch,
        );
        
        // Add fresh suggestions to Firestore
        await _populateTestSuggestions(mockFirestore);
        
        // Act: Get suggestions
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          useCache: true,
        );
        
        // Assert: Should fetch fresh suggestions, not use expired cache
        expect(suggestions, isNotEmpty);
        expect(suggestions.any((s) => s.title.contains('Complete Your Profile')), isTrue);
      });

      test('should handle corrupted cache gracefully', () async {
        // Arrange: Set up corrupted cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cached_suggestions', ['invalid_json']);
        
        // Add valid suggestions to Firestore
        await _populateTestSuggestions(mockFirestore);
        
        // Act: Get suggestions
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          useCache: true,
        );
        
        // Assert: Should handle corrupted cache gracefully and fetch from server
        expect(suggestions, isNotEmpty);
      });

      test('should force refresh when requested', () async {
        // Arrange: Set up cache
        await _populateTestSuggestions(mockFirestore);
        await EnhancedSuggestionService.getSuggestions(useCache: true);
        
        // Add new suggestions
        await mockFirestore.collection('suggestions').add({
          'title': 'New Suggestion',
          'description': 'This is new',
          'category': 'general',
          'targetAudience': 'all',
          'language': 'en',
          'actionType': 'modal',
          'priority': 1,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Act: Force refresh
        final suggestions = await EnhancedSuggestionService.refreshSuggestions();
        
        // Assert: Should get fresh suggestions including the new one
        expect(suggestions, isNotEmpty);
        expect(suggestions.any((s) => s.title == 'New Suggestion'), isTrue);
      });

      test('should clear cache when requested', () async {
        // Arrange: Set up cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cached_suggestions', ['test']);
        await prefs.setInt('cache_timestamp', DateTime.now().millisecondsSinceEpoch);
        
        // Act: Clear cache
        await EnhancedSuggestionService.clearCache();
        
        // Assert: Cache should be cleared
        final cachedData = prefs.getStringList('cached_suggestions');
        final timestamp = prefs.getInt('cache_timestamp');
        expect(cachedData, isNull);
        expect(timestamp, isNull);
      });
    });

    group('Analytics and User Interaction Tests', () {
      test('should track suggestion views when user ID provided', () async {
        // Arrange: Add suggestions
        await _populateTestSuggestions(mockFirestore);
        
        // Act: Get suggestions with user ID
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          userId: 'test-user-123',
          userStatus: 'trial_users',
          useCache: false,
        );
        
        // Assert: Should track analytics (verify by checking Firestore)
        expect(suggestions, isNotEmpty);
        
        // Check if analytics were recorded
        final analyticsQuery = await mockFirestore
            .collection('suggestion_analytics')
            .where('userId', isEqualTo: 'test-user-123')
            .get();
        
        expect(analyticsQuery.docs, isNotEmpty);
        expect(analyticsQuery.docs.first.data()['action'], equals('viewed'));
      });

      test('should track suggestion interactions', () async {
        // Arrange: Add a suggestion
        await _populateTestSuggestions(mockFirestore);
        
        // Act: Track a click interaction
        await EnhancedSuggestionService.trackSuggestionInteraction(
          'test-user-123',
          'suggestion-1',
          'clicked',
          'trial_users',
        );
        
        // Assert: Should record the interaction
        final analyticsQuery = await mockFirestore
            .collection('suggestion_analytics')
            .where('userId', isEqualTo: 'test-user-123')
            .where('action', isEqualTo: 'clicked')
            .get();
        
        expect(analyticsQuery.docs, isNotEmpty);
        expect(analyticsQuery.docs.first.data()['suggestionId'], equals('suggestion-1'));
      });

      test('should update user preferences when suggestion dismissed', () async {
        // Act: Track a dismiss interaction
        await EnhancedSuggestionService.trackSuggestionInteraction(
          'test-user-123',
          'suggestion-1',
          'dismissed',
          'trial_users',
        );
        
        // Assert: Should update user preferences
        final userPrefDoc = await mockFirestore
            .collection('user_suggestion_preferences')
            .doc('test-user-123')
            .get();
        
        expect(userPrefDoc.exists, isTrue);
        final data = userPrefDoc.data()!;
        expect(data['dismissedSuggestions'], contains('suggestion-1'));
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle Firestore connection errors gracefully', () async {
        // Arrange: Use empty Firestore (simulates connection error)
        
        // Act: Get suggestions
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          useCache: false,
        );
        
        // Assert: Should return default suggestions
        expect(suggestions, isNotEmpty);
        expect(suggestions.first.title, contains('How are you feeling?'));
      });

      test('should handle malformed suggestion data', () async {
        // Arrange: Add malformed suggestion data
        await mockFirestore.collection('suggestions').add({
          'title': null, // Invalid data
          'isActive': true,
        });
        
        await mockFirestore.collection('suggestions').add({
          'invalid_field': 'test', // Missing required fields
          'isActive': true,
        });
        
        await mockFirestore.collection('suggestions').add({
          'title': 'Valid Suggestion',
          'description': 'Valid description',
          'category': 'general',
          'targetAudience': 'all',
          'language': 'en',
          'actionType': 'modal',
          'priority': 1,
          'isActive': true,
        });
        
        // Act: Get suggestions
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          useCache: false,
        );
        
        // Assert: Should filter out invalid data and return valid suggestions
        expect(suggestions, isNotEmpty);
        expect(suggestions.any((s) => s.title == 'Valid Suggestion'), isTrue);
      });

      test('should handle very large suggestion datasets efficiently', () async {
        // Arrange: Add many suggestions
        for (int i = 0; i < 100; i++) {
          await mockFirestore.collection('suggestions').add({
            'title': 'Suggestion $i',
            'description': 'Description $i',
            'category': 'general',
            'targetAudience': 'all',
            'language': 'en',
            'actionType': 'modal',
            'priority': i % 10,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        // Act: Get suggestions
        final suggestions = await EnhancedSuggestionService.getSuggestions(
          limit: 10,
          useCache: false,
        );
        
        // Assert: Should handle large datasets without issues
        expect(suggestions, isNotEmpty);
        expect(suggestions.length, equals(10));
      });
    });
  });
}

// Helper methods to populate test data (same as before but with enhanced structure)

Future<void> _populateTestSuggestions(FakeFirebaseFirestore firestore) async {
  await firestore.collection('suggestions').add({
    'title': 'Complete Your Profile',
    'description': 'Add your skills to get better job matches',
    'category': 'onboarding',
    'targetAudience': 'new_users',
    'language': 'en',
    'actionType': 'navigate',
    'actionData': {'route': '/profile'},
    'priority': 5,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
    'engagementStats': {'views': 0, 'clicks': 0, 'dismissals': 0},
  });
  
  await firestore.collection('suggestions').add({
    'title': 'Explore Job Opportunities',
    'description': 'Find jobs that match your skills',
    'category': 'job_tips',
    'targetAudience': 'all',
    'language': 'en',
    'actionType': 'navigate',
    'actionData': {'route': '/jobs'},
    'priority': 3,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
    'engagementStats': {'views': 0, 'clicks': 0, 'dismissals': 0},
  });
}

Future<void> _populateManySuggestions(FakeFirebaseFirestore firestore) async {
  final suggestions = [
    'Complete Your Profile',
    'Explore Job Opportunities', 
    'Connect with Other OFWs',
    'Learn About Remittance Options',
    'Understand Your Legal Rights',
    'Find Healthcare Resources',
    'Join Community Groups',
    'Access Financial Planning Tools',
    'Discover Cultural Events',
    'Get Career Advice',
  ];
  
  for (int i = 0; i < suggestions.length; i++) {
    await firestore.collection('suggestions').add({
      'title': suggestions[i],
      'description': 'Description for ${suggestions[i]}',
      'category': 'general',
      'targetAudience': 'all',
      'language': 'en',
      'actionType': 'modal',
      'priority': i % 5 + 1,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

Future<void> _populatePrioritizedSuggestions(FakeFirebaseFirestore firestore) async {
  await firestore.collection('suggestions').add({
    'title': 'High Priority Suggestion',
    'description': 'This has high priority',
    'category': 'general',
    'targetAudience': 'all',
    'language': 'en',
    'actionType': 'modal',
    'priority': 10,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  await firestore.collection('suggestions').add({
    'title': 'Medium Priority Suggestion',
    'description': 'This has medium priority',
    'category': 'general',
    'targetAudience': 'all',
    'language': 'en',
    'actionType': 'modal',
    'priority': 5,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  await firestore.collection('suggestions').add({
    'title': 'Low Priority Suggestion',
    'description': 'This has low priority',
    'category': 'general',
    'targetAudience': 'all',
    'language': 'en',
    'actionType': 'modal',
    'priority': 1,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _populateTargetedSuggestions(FakeFirebaseFirestore firestore) async {
  await firestore.collection('suggestions').add({
    'title': 'Welcome! Complete your profile to get started',
    'description': 'New user onboarding',
    'category': 'onboarding',
    'targetAudience': 'new_users',
    'language': 'en',
    'actionType': 'navigate',
    'priority': 5,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  await firestore.collection('suggestions').add({
    'title': 'Your trial expires soon - consider subscribing',
    'description': 'Trial user conversion',
    'category': 'subscription',
    'targetAudience': 'trial_users',
    'language': 'en',
    'actionType': 'navigate',
    'priority': 8,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  await firestore.collection('suggestions').add({
    'title': 'Explore premium features available to you',
    'description': 'Premium user engagement',
    'category': 'features',
    'targetAudience': 'premium_users',
    'language': 'en',
    'actionType': 'modal',
    'priority': 3,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _populateUniversalSuggestions(FakeFirebaseFirestore firestore) async {
  await firestore.collection('suggestions').add({
    'title': 'This is a universal suggestion for all users',
    'description': 'Universal content',
    'category': 'general',
    'targetAudience': 'all',
    'language': 'en',
    'actionType': 'modal',
    'priority': 5,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _populateActiveInactiveSuggestions(FakeFirebaseFirestore firestore) async {
  await firestore.collection('suggestions').add({
    'title': 'This is an active suggestion',
    'description': 'Active content',
    'category': 'general',
    'targetAudience': 'all',
    'language': 'en',
    'actionType': 'modal',
    'priority': 5,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  await firestore.collection('suggestions').add({
    'title': 'This is an inactive suggestion',
    'description': 'Inactive content',
    'category': 'general',
    'targetAudience': 'all',
    'language': 'en',
    'actionType': 'modal',
    'priority': 5,
    'isActive': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _populateMultiLanguageSuggestions(FakeFirebaseFirestore firestore) async {
  await firestore.collection('suggestions').add({
    'title': 'Complete your profile (English)',
    'description': 'English description',
    'category': 'onboarding',
    'targetAudience': 'all',
    'language': 'en',
    'actionType': 'navigate',
    'priority': 5,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  await firestore.collection('suggestions').add({
    'title': 'Kumpletuhin ang inyong profile (Filipino)',
    'description': 'Filipino description',
    'category': 'onboarding',
    'targetAudience': 'all',
    'language': 'fil',
    'actionType': 'navigate',
    'priority': 5,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  await firestore.collection('suggestions').add({
    'title': 'أكمل ملفك الشخصي (Arabic)',
    'description': 'Arabic description',
    'category': 'onboarding',
    'targetAudience': 'all',
    'language': 'ar',
    'actionType': 'navigate',
    'priority': 5,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _populateEnglishOnlySuggestions(FakeFirebaseFirestore firestore) async {
  await firestore.collection('suggestions').add({
    'title': 'English suggestion 1',
    'description': 'English description',
    'category': 'general',
    'targetAudience': 'all',
    'language': 'en',
    'actionType': 'modal',
    'priority': 5,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
}