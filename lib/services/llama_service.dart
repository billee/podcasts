// llama_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Import for TimeoutException

class LlamaService {
  // IMPORTANT: This should be the URL of your Flask RAG server.
  // For web (Edge), desktop, or iOS simulator, use 'http://localhost:5000/query'.
  // For Android emulator, use 'http://10.0.2.2:5000/query'.
  // For physical Android device, use your machine's actual local IP (e.g., 'http://192.168.1.X:5000/query').
  static const String _ragServerUrl = 'http://localhost:5000/query'; // Set this for Edge

  static Future<String> generateResponse(
      String query,
      List<Map<String, String>> chatHistory // Only query and chat history needed for server
      ) async {
    try {
      final response = await http.post(
        Uri.parse(_ragServerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          // The RAG server now handles finding rag_results internally,
          // so we don't need to pass them from Flutter.
          'chat_history': chatHistory,
        }),
      ).timeout(const Duration(seconds: 120)); // Increased timeout (e.g., 2 minutes)

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> results = data['results'];
        if (results.isNotEmpty && results[0]['content'] != null) {
          // The RAG server should return the final LLM-generated answer.
          return results[0]['content'] as String;
        } else {
          print('RAG server returned no content or empty results.');
          return "Pasensya na, kapatid. Wala akong nakitang sapat na sagot. Pwede mong subukan ulit o magtanong ng iba.";
        }
      } else {
        print('Error calling RAG server: ${response.statusCode} - ${response.body}');
        return "Paumanhin, kapatid. May problema sa pagkuha ng sagot mula sa server. Subukan ulit mamaya.";
      }
    } on TimeoutException catch (e) {
      print('RAG Query Error (Timeout): $e');
      return "Paumanhin, kapatid. Matagal mag-load ang sagot. Subukan ulit o kaya baguhin ang tanong mo.";
    } catch (e) {
      print('Network or parsing error with RAG server: $e');
      return "Paumanhin, kapatid. Hindi maabot ang serbisyo. Subukan ulit mamaya.";
    }
  }

// The _buildPrompt function is no longer needed in Flutter
// as the RAG server is now responsible for building the prompt.
}


// napkin.ai
// lovable, Rork, Grok
// manus
// donotpay
// google ai studio
//
//
// Relevance ai, make, n8n
// heyGen
// unstructured