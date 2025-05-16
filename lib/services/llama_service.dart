class LlamaService {
  static Future<String> getResponse(String query) async {
    // Implement actual API calls here
    await Future.delayed(const Duration(seconds: 2));
    return 'Sample response from Llama';
  }
}