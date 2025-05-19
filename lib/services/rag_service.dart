import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class RAGService {
  static const String _serverUrl = 'http://localhost:5000/query'; // Or your server IP

  static Future<List<Map<String, dynamic>>> query(String message) async {
    try {
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': message}),
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Validate response structure
        if (data['results'] is List && data['results'].isNotEmpty) {
          return List<Map<String, dynamic>>.from(data['results']);
        }
        throw Exception('Invalid response format');
      }
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      print('RAG Query Error: $e');
      rethrow;
    }
  }

  static Future<void> addKnowledge(String content) async {
    await FirebaseFirestore.instance.collection('knowledge_base').add({
      'content': content,
      'timestamp': FieldValue.serverTimestamp()
    });
  }
}