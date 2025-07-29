// lib/services/enhanced_suggestion_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

/// Enhanced suggestion service that supports contextual filtering,
/// multi-language content, and offline caching
class EnhancedSuggestionService {
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Set custom Firestore instance for testing
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  static const String _collectionName = 'suggestions';
  static const String _userPreferencesCollection = 'user_suggestion_preferences';
  static const String _analyticsCollection = 'suggestion_analytics';
  static final Logger _logger = Logger('EnhancedSuggestionService');
  
  // Cache configuration
  static const String _cacheKey = 'cached_suggestions';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const Duration _cacheExpiration = Duration(hours: 24);
  
  /// Get suggestions with contextual filtering and caching
  static Future<List<SuggestionModel>> getSuggestions({
    String? userId,
    String userStatus = 'all',
    String language = 'en',
    int limit = 10,
    bool useCache = true,
  }) async {
    try {
      // Try to get from cache first if enabled
      if (useCache) {
        final cachedSuggestions = await _getCachedSuggestions();
        if (cachedSuggestions.isNotEmpty && !await _isCacheExpired()) {
          final filtered = _filterSuggestions(cachedSuggestions, userStatus, language);
          if (filtered.isNotEmpty) {
            return _randomizeSelection(filtered, limit);
          }
        }
      }
      
      // Fetch from Firestore
      final suggestions = await _fetchSuggestionsFromFirestore(userStatus, language, limit * 2);
      
      // If no suggestions found, return defaults
      if (suggestions.isEmpty) {
        return _getDefaultSuggestions(language, limit);
      }
      
      // Cache the results
      if (useCache && suggestions.isNotEmpty) {
        await _cacheSuggestions(suggestions);
      }
      
      // Track analytics if user is provided
      if (userId != null && suggestions.isNotEmpty) {
        await _trackSuggestionViews(userId, suggestions, userStatus);
      }
      
      return _randomizeSelection(suggestions, limit);
      
    } catch (e) {
      _logger.warning('Error fetching suggestions: $e');
      
      // Try cache as fallback
      final cachedSuggestions = await _getCachedSuggestions();
      if (cachedSuggestions.isNotEmpty) {
        final filtered = _filterSuggestions(cachedSuggestions, userStatus, language);
        return _randomizeSelection(filtered, limit);
      }
      
      // Return default suggestions as last resort
      return _getDefaultSuggestions(language, limit);
    }
  }
  
  /// Fetch suggestions from Firestore with filtering
  static Future<List<SuggestionModel>> _fetchSuggestionsFromFirestore(
    String userStatus, 
    String language, 
    int limit
  ) async {
    Query query = _firestore.collection(_collectionName)
        .where('isActive', isEqualTo: true);
    
    // Add language filter
    if (language != 'all') {
      query = query.where('language', whereIn: [language, 'all']);
    }
    
    // Add user status filter
    if (userStatus != 'all') {
      query = query.where('targetAudience', whereIn: [userStatus, 'all']);
    }
    
    query = query.orderBy('priority', descending: true).limit(limit);
    
    final querySnapshot = await query.get();
    
    return querySnapshot.docs
        .map((doc) => SuggestionModel.fromFirestore(doc))
        .where((suggestion) => suggestion.title.isNotEmpty)
        .toList();
  }
  
  /// Filter suggestions based on criteria
  static List<SuggestionModel> _filterSuggestions(
    List<SuggestionModel> suggestions,
    String userStatus,
    String language,
  ) {
    return suggestions.where((suggestion) {
      // Filter by user status
      if (userStatus != 'all' && 
          suggestion.targetAudience != 'all' && 
          suggestion.targetAudience != userStatus) {
        return false;
      }
      
      // Filter by language
      if (language != 'all' && 
          suggestion.language != 'all' && 
          suggestion.language != language) {
        return false;
      }
      
      // Filter active suggestions only
      return suggestion.isActive;
    }).toList();
  }
  
  /// Randomize suggestion selection using weighted algorithm
  static List<SuggestionModel> _randomizeSelection(List<SuggestionModel> suggestions, int limit) {
    if (suggestions.isEmpty) return [];
    
    final random = Random();
    final selected = <SuggestionModel>[];
    final available = List<SuggestionModel>.from(suggestions);
    
    // Sort by priority first
    available.sort((a, b) => b.priority.compareTo(a.priority));
    
    // Use weighted random selection
    while (selected.length < limit && available.isNotEmpty) {
      final weights = available.map((s) => s.priority + 1).toList();
      final totalWeight = weights.reduce((a, b) => a + b);
      final randomValue = random.nextInt(totalWeight);
      
      int currentWeight = 0;
      for (int i = 0; i < available.length; i++) {
        currentWeight += weights[i];
        if (randomValue < currentWeight) {
          selected.add(available.removeAt(i));
          break;
        }
      }
    }
    
    return selected;
  }
  
  /// Get cached suggestions
  static Future<List<SuggestionModel>> _getCachedSuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getStringList(_cacheKey);
      
      if (cachedJson == null || cachedJson.isEmpty) {
        return [];
      }
      
      return cachedJson
          .map((json) => SuggestionModel.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      _logger.warning('Error reading cached suggestions: $e');
      return [];
    }
  }
  
  /// Cache suggestions locally
  static Future<void> _cacheSuggestions(List<SuggestionModel> suggestions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = suggestions
          .map((suggestion) => jsonEncode(suggestion.toJson()))
          .toList();
      
      await prefs.setStringList(_cacheKey, jsonList);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      _logger.warning('Error caching suggestions: $e');
    }
  }
  
  /// Check if cache is expired
  static Future<bool> _isCacheExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      
      if (timestamp == null) return true;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now().difference(cacheTime) > _cacheExpiration;
    } catch (e) {
      return true;
    }
  }
  
  /// Track suggestion views for analytics
  static Future<void> _trackSuggestionViews(
    String userId,
    List<SuggestionModel> suggestions,
    String userStatus,
  ) async {
    try {
      final batch = _firestore.batch();
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      for (final suggestion in suggestions) {
        final analyticsRef = _firestore.collection(_analyticsCollection).doc();
        batch.set(analyticsRef, {
          'suggestionId': suggestion.id,
          'userId': userId,
          'action': 'viewed',
          'timestamp': FieldValue.serverTimestamp(),
          'userStatus': userStatus,
          'sessionId': sessionId,
        });
      }
      
      await batch.commit();
    } catch (e) {
      _logger.warning('Error tracking suggestion views: $e');
    }
  }
  
  /// Get default fallback suggestions
  static List<SuggestionModel> _getDefaultSuggestions(String language, int limit) {
    final defaultSuggestions = <SuggestionModel>[];
    
    switch (language) {
      case 'fil':
        defaultSuggestions.addAll([
          SuggestionModel(
            id: 'default-fil-1',
            title: 'Kumusta ka?',
            description: 'Ibahagi ang inyong mga saloobin',
            category: 'general',
            targetAudience: 'all',
            language: 'fil',
            actionType: 'modal',
            priority: 1,
            isActive: true,
          ),
          SuggestionModel(
            id: 'default-fil-2',
            title: 'Ano ang mga highlight ngayong araw?',
            description: 'Magbahagi ng mga magagandang nangyari',
            category: 'general',
            targetAudience: 'all',
            language: 'fil',
            actionType: 'modal',
            priority: 1,
            isActive: true,
          ),
        ]);
        break;
      case 'ar':
        defaultSuggestions.addAll([
          SuggestionModel(
            id: 'default-ar-1',
            title: 'كيف حالك؟',
            description: 'شارك أفكارك',
            category: 'general',
            targetAudience: 'all',
            language: 'ar',
            actionType: 'modal',
            priority: 1,
            isActive: true,
          ),
          SuggestionModel(
            id: 'default-ar-2',
            title: 'ما هي أبرز أحداث اليوم؟',
            description: 'شارك الأحداث الجيدة',
            category: 'general',
            targetAudience: 'all',
            language: 'ar',
            actionType: 'modal',
            priority: 1,
            isActive: true,
          ),
        ]);
        break;
      default: // English
        defaultSuggestions.addAll([
          SuggestionModel(
            id: 'default-en-1',
            title: 'How are you feeling?',
            description: 'Share your thoughts and emotions',
            category: 'general',
            targetAudience: 'all',
            language: 'en',
            actionType: 'modal',
            priority: 1,
            isActive: true,
          ),
          SuggestionModel(
            id: 'default-en-2',
            title: 'Share your thoughts',
            description: 'Tell us what\'s on your mind',
            category: 'general',
            targetAudience: 'all',
            language: 'en',
            actionType: 'modal',
            priority: 1,
            isActive: true,
          ),
          SuggestionModel(
            id: 'default-en-3',
            title: 'Today\'s highlights?',
            description: 'What went well today?',
            category: 'general',
            targetAudience: 'all',
            language: 'en',
            actionType: 'modal',
            priority: 1,
            isActive: true,
          ),
        ]);
    }
    
    return defaultSuggestions.take(limit).toList();
  }
  
  /// Track suggestion interaction (click, dismiss)
  static Future<void> trackSuggestionInteraction(
    String userId,
    String suggestionId,
    String action, // 'clicked' or 'dismissed'
    String userStatus,
  ) async {
    try {
      await _firestore.collection(_analyticsCollection).add({
        'suggestionId': suggestionId,
        'userId': userId,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
        'userStatus': userStatus,
        'sessionId': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      
      // Update user preferences if dismissed
      if (action == 'dismissed') {
        await _updateUserPreferences(userId, suggestionId, action);
      }
    } catch (e) {
      _logger.warning('Error tracking suggestion interaction: $e');
    }
  }
  
  /// Update user preferences
  static Future<void> _updateUserPreferences(
    String userId,
    String suggestionId,
    String action,
  ) async {
    try {
      final userPrefRef = _firestore.collection(_userPreferencesCollection).doc(userId);
      
      await userPrefRef.set({
        'dismissedSuggestions': FieldValue.arrayUnion([suggestionId]),
        'engagementHistory.$suggestionId.${action}At': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _logger.warning('Error updating user preferences: $e');
    }
  }
  
  /// Clear cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (e) {
      _logger.warning('Error clearing cache: $e');
    }
  }
  
  /// Force refresh from server
  static Future<List<SuggestionModel>> refreshSuggestions({
    String? userId,
    String userStatus = 'all',
    String language = 'en',
    int limit = 10,
  }) async {
    await clearCache();
    return getSuggestions(
      userId: userId,
      userStatus: userStatus,
      language: language,
      limit: limit,
      useCache: false,
    );
  }
}

/// Suggestion model class
class SuggestionModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String targetAudience;
  final String language;
  final String actionType;
  final Map<String, dynamic> actionData;
  final int priority;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, int> engagementStats;
  
  SuggestionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetAudience,
    required this.language,
    required this.actionType,
    this.actionData = const {},
    required this.priority,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.engagementStats = const {},
  });
  
  factory SuggestionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SuggestionModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'general',
      targetAudience: data['targetAudience'] ?? 'all',
      language: data['language'] ?? 'en',
      actionType: data['actionType'] ?? 'modal',
      actionData: Map<String, dynamic>.from(data['actionData'] ?? {}),
      priority: data['priority'] ?? 1,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      engagementStats: Map<String, int>.from(data['engagementStats'] ?? {}),
    );
  }
  
  factory SuggestionModel.fromJson(Map<String, dynamic> json) {
    return SuggestionModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      targetAudience: json['targetAudience'] ?? 'all',
      language: json['language'] ?? 'en',
      actionType: json['actionType'] ?? 'modal',
      actionData: Map<String, dynamic>.from(json['actionData'] ?? {}),
      priority: json['priority'] ?? 1,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      engagementStats: Map<String, int>.from(json['engagementStats'] ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'targetAudience': targetAudience,
      'language': language,
      'actionType': actionType,
      'actionData': actionData,
      'priority': priority,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'engagementStats': engagementStats,
    };
  }
  
  @override
  String toString() => title;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuggestionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}