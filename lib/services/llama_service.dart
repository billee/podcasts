import '../constants.dart';

class LlamaService {
  static Future<String> generateResponse(String query, List<dynamic> ragResults) async  {
    // Construct prompt with cultural context
    final prompt = _buildPrompt(query, ragResults);

    // Real implementation would call actual LLM API
    return _simulateCulturalResponse(prompt);
  }

  static String _buildPrompt(String query, List<dynamic> context) {
    final contextText = context.map((c) => c['content']).join('\n---\n');
    return '''
User Query: $query
Related Context:
$contextText

Generate a culturally appropriate response in Taglish:''';
  }


  static String _simulateCulturalResponse(String prompt) {
    // Check both prompt and cached results
    if (prompt.contains('homesick') ||
        prompt.contains('malayo sa pamilya')) {
      return '💙 Alam kong mahirap malayo sa pamilya. Kaya mo yan, kabayan!';
    }
    return 'Pasensya na, kapatid. Pwede mo ba ulitin ng mas malinaw?';
  }
}