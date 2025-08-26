// openai_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Import for TimeoutException
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';

class OpenAIService {
  // Replace with your actual OpenAI API Key
  static final String _openAIApiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _openAICompletionsUrl =
      'https://api.openai.com/v1/chat/completions';
  static final Logger _logger = Logger('OpenAIService');

  /// Enhanced method that accepts full message list including system prompts
  static Future<String> generateResponseWithMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    if (_openAIApiKey.isEmpty) {
      _logger.info('Error: OpenAI API Key not found in .env file.');
      return "Sorry, the OpenAI API key is not configured.";
    }

    try {
      // Convert dynamic messages to the format OpenAI expects
      List<Map<String, String>> messagesToSend = messages.map((msg) => {
        'role': msg['role'] as String,
        'content': msg['content'] as String,
      }).toList();

      _logger.info('messagesToSend (with system prompts).............................');
      _logger.info(messagesToSend);

      final response = await http
          .post(
            Uri.parse(_openAICompletionsUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_openAIApiKey',
            },
            body: jsonEncode({
              'model': 'gpt-4o-mini', // Specify the model
              'messages': messagesToSend,
              'max_tokens': 500, // Adjust as needed for desired response length
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          //////////////////////////////// output
          _logger.info('OpenAI response (with system prompts).......................................');
          _logger.info(data['choices'][0]['message']['content']);
          return data['choices'][0]['message']['content'] as String;
        } else {
          _logger.info('OpenAI API returned no choices or empty response.');
          return "Sorry, I didn't get a response from OpenAI. Please try again.";
        }
      } else {
        _logger.info(
            'Error calling OpenAI API: ${response.statusCode} - ${response.body}');
        return "Sorry, there is a problem retrieving the answer from OpenAI. Please try again later.";
      }
    } on TimeoutException catch (e) {
      _logger.info('OpenAI Query Error (Timeout): $e');
      return "Sorry, the OpenAI service is taking a while to load. Try again or maybe change your question.";
    } catch (e) {
      _logger.info('Network or parsing error with OpenAI API: $e');
      return "Sorry, the OpenAI service is currently unavailable. Try again later.";
    }
  }

  // Keep the original method for backward compatibility
  static Future<String> generateResponse(
    String query,
    List<Map<String, String>> chatHistory,
  ) async {
    if (_openAIApiKey.isEmpty) {
      _logger.info('Error: OpenAI API Key not found in .env file.');
      return "Sorry, the OpenAI API key is not configured.";
    }

    try {
      List<Map<String, String>> messagesToSend = List.from(chatHistory);

      _logger.info('messagesToSend (legacy method).............................');
      _logger.info(messagesToSend);

      final response = await http
          .post(
            Uri.parse(_openAICompletionsUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_openAIApiKey',
            },
            body: jsonEncode({
              'model': 'gpt-4o-mini', // Specify the model
              'messages': messagesToSend,
              //'temperature': 0.2, // Adjust as needed for creativity vs. consistency
              'max_tokens': 500, // Adjust as needed for desired response length
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          //////////////////////////////// output
          _logger.info('response.......................................');
          _logger.info(data['choices'][0]['message']['content']);
          return data['choices'][0]['message']['content'] as String;
        } else {
          _logger.info('OpenAI API returned no choices or empty response.');
          return "Sorry, I didn't get a response from OpenAI. Please try again.";
        }
      } else {
        _logger.info(
            'Error calling OpenAI API: ${response.statusCode} - ${response.body}');
        return "Sorry, there is a problem retrieving the answer from OpenAI. Please try again later.";
      }
    } on TimeoutException catch (e) {
      _logger.info('OpenAI Query Error (Timeout): $e');
      return "Sorry, the OpenAI service is taking a while to load. Try again or maybe change your question.";
    } catch (e) {
      _logger.info('Network or parsing error with OpenAI API: $e');
      return "Sorry, the OpenAI service is currently unavailable. Try again later.";
    }
  }
}