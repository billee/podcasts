import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class RAGService {
  static Future<List<String>> query(String question) async {
    // Call Python Cloud Function
    final response = await http.post(
        Uri.parse('https://your-region-your-project.cloudfunctions.net/query_chroma'),
        body: jsonEncode({'query': question}),
        headers: {'Content-Type': 'application/json'}
    );

    final data = jsonDecode(response.body);
    return data['results'].map((r) => r['content']).toList();
  }

  static Future<void> addKnowledge(String content) async {
    await FirebaseFirestore.instance.collection('knowledge_base').add({
      'content': content,
      'timestamp': FieldValue.serverTimestamp()
    });
  }
}