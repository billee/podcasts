// llama_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class LlamaService {
  // IMPORTANT: This should be the URL of your local LLM inference server
  // For example, if you're running Ollama, it might be 'http://localhost:11434/api/generate'
  // Or if you have a custom server for Llama, provide that URL.
  // Make sure this URL is accessible from your Flutter app (e.g., 10.0.2.2 for Android emulator).
  static const String _llamaApiUrl = 'http://localhost:11434/api/generate'; // Placeholder for your actual LLM endpoint

  static Future<String> generateResponse(String query, List<dynamic> ragResults) async  {
    final prompt = _buildPrompt(query, ragResults);
    try {
      final response = await http.post(
        Uri.parse(_llamaApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'llama3.2:latest',
          'prompt': prompt,
          'stream': false, // Set to true if your LLM API supports streaming and you want to handle it
          'temperature': 0.7,
          'top_p': 0.9,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] as String;
      } else {
        print('Error calling LLM API: ${response.statusCode} - ${response.body}');
        // Fallback to a simpler response if LLM API fails
        if (ragResults.isNotEmpty && ragResults.first['content'] != null) {
          return ragResults.first['content'] + "\n(Paumanhin, hindi na-generate ang kumpletong sagot mula sa AI)";
        }
        throw Exception('Failed to get response from LLM API: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during LLM generation HTTP call: $e');
      // If LLM call fails, use the first RAG result as a direct fallback
      if (ragResults.isNotEmpty && ragResults.first['content'] != null) {
        return ragResults.first['content'] + "\n(Paumanhin, hindi na-generate ang kumpletong sagot mula sa AI. Narito ang direktang impormasyon na nakuha.)";
      }
      return "Pasensya na, kapatid. May problema sa pagkuha ng sagot. Pwede mo ba ulitin ng mas malinaw?"; // Generic fallback
    }
  }

  static String _buildPrompt(String query, List<dynamic> context) {
    String contextText = "No relevant context found.";
    if (context != null && context.isNotEmpty) {
      // Join the content of all retrieved documents to form the context
      contextText = context.map((c) => c['content']).join('\n---\n');


      // Refined RAG prompt
      return '''You are a helpful assistant for Overseas Filipino Workers (OFWs), providing culturally appropriate advice in everyday spoken English.
Your response should be based ONLY on the following context. If the context does not provide enough information to answer the question, state that you cannot answer based on the provided information and offer to search for other information.
Do not invent information.
User Query: $query
Related Context:
$contextText
Please provide a concise and helpful response in everyday spoken English:''';
    }else{
      return '''You are a helpful assistant for Overseas Filipino Workers (OFWs), providing culturally appropriate advice in everyday spoken English.
Your response should answer the query.
User Query: $query
Please provide a concise and helpful response in everyday spoken English:''';
    }
  }
}
