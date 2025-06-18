// llama_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Import for TimeoutException
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';

class LlamaService {
  // For web (Edge), desktop, or iOS simulator, use 'http://localhost:5000/query'.
  // For Android emulator, use 'http://10.0.2.2:5000/query'.
  // For physical Android device, use your machine's actual local IP (e.g., 'http://192.168.1.X:5000/query').
  static const String _ragServerUrl =
      'http://localhost:5000/query'; // Set this for Edge
  static final Logger _logger = Logger('LlamaService');
  static Future<String> generateResponse(
      String query,
      List<Map<String, String>>
          chatHistory // Only query and chat history needed for server
      ) async {
    if (_ragServerUrl.isEmpty) {
      _logger.info('Error: Llama RAG Server URL not found.');
      return "Sorry, the Llama RAG server URL is not configured.";
    }
    try {
      final response = await http
          .post(
            Uri.parse(_ragServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'chat_history': chatHistory,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> results = data['results'];
        if (results.isNotEmpty && results[0]['content'] != null) {
          ////////////////////// The RAG server should return the final LLM-generated answer.
          return results[0]['content'] as String;
        } else {
          _logger.info('RAG server returned no content or empty results.');
          return "Sorry, I didn't find a sufficient answer. You can try again or ask something else.";
        }
      } else {
        _logger.info(
            'Error calling RAG server: ${response.statusCode} - ${response.body}');
        return "Sorry, there is a problem retrieving the answer from the server. Please try again later.";
      }
    } on TimeoutException catch (e) {
      _logger.info('RAG Query Error (Timeout): $e');
      return "Sorry, the answer is taking a while to load. Try again or maybe change your question.";
    } catch (e) {
      _logger.info('Network or parsing error with RAG server: $e');
      return "Sorry, the service is down. Try again later.";
    }
  }
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