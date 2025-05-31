// lib/services/suggestion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SuggestionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'ofw_suggestions';

  // Get all suggestions from Firestore
  static Future<List<String>> getSuggestions() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collectionName)
      //.orderBy('order') // Optional: if you want to maintain a specific order
          .get();

      // Safely map and filter out any entries where 'suggestion' might be null
      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .where((data) => data['suggestion'] != null) // Corrected field name: 'suggestion'
          .map((data) => data['suggestion'] as String) // Corrected field name: 'suggestion'
          .toList();
    } catch (e) {
      print('Error fetching suggestions: $e');
      // Return default suggestions as fallback
      return [
        "How are you feeling?",
        "Share your thoughts",
        "Today's highlights?",
        "Any challenges?",
        "Need support?",
        "What are you grateful for?",
        "Recent accomplishments?",
        "Something bothering you?",
      ];
    }
  }

  // Add a new suggestion to Firestore
  static Future<void> addSuggestion(String text, int order) async {
    try {
      await _firestore.collection(_collectionName).add({
        'suggestion': text, // Corrected field name: 'suggestion'
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding suggestion: $e');
    }
  }

  // Initialize default suggestions (call this once to populate the database)
  static Future<void> initializeDefaultSuggestions() async {
    try {
      // Check if suggestions already exist
      QuerySnapshot existingSuggestions = await _firestore
          .collection(_collectionName)
          .limit(1)
          .get();

      if (existingSuggestions.docs.isEmpty) {
        List<String> defaultSuggestions = [
          "How are you feeling?",
          "Share your thoughts",
          "Today's highlights?",
          "Any challenges?",
          "Need support?",
          "What are you grateful for?",
          "Recent accomplishments?",
          "Something bothering you?",
        ];

        // Add each suggestion with an order
        for (int i = 0; i < defaultSuggestions.length; i++) {
          await addSuggestion(defaultSuggestions[i], i);
        }
        print('Default suggestions initialized in Firestore');
      }
    } catch (e) {
      print('Error initializing default suggestions: $e');
    }
  }
}