// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
//import 'package:flutter_dotenv/flutter_dotenv.dart'; // Keep if you use other .env vars
import 'package:http/http.dart' as http;
import 'package:kapwa_companion_basic/screens/video_conference_screen.dart';
import 'dart:convert';
import 'dart:async'; // Import for TimeoutException
import 'package:kapwa_companion_basic/services/suggestion_service.dart'; // Keep this import!
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/widgets/audio_player_widget.dart';
import 'package:kapwa_companion_basic/services/audio_service.dart';
import 'package:kapwa_companion_basic/screens/contacts_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final Logger _logger = Logger('ChatScreen');
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages =
      []; // Stores messages for display

  // Keep suggestion-related fields:
  List<String> _allSuggestions = [];
  List<String> _currentSuggestions = [];
  bool _suggestionsLoading = true;

  // final List<Map<String, String>> _chatHistory = [];
  // static const String _ragServerUrl = 'http://localhost:5000/query';

  @override
  void initState() {
    super.initState();
    // Keep suggestion loading:
    _loadSuggestions();
    AudioService().initialize();
  }

  // Keep suggestion loading method:
  Future<void> _loadSuggestions() async {
    try {
      setState(() {
        _suggestionsLoading = true;
      });

      List<String> suggestions = await SuggestionService.getSuggestions();
      _logger.info('suggestions: $suggestions');

      // IMPORTANT: Filter out any null or non-string suggestions, and ensure they are Strings
      final List<String> cleanSuggestions = suggestions
          // ignore: unnecessary_null_comparison
          .where((s) => s != null && s.isNotEmpty)
          .map((s) => s)
          .toList();

      setState(() {
        _allSuggestions = cleanSuggestions; // Use the cleaned list
        _suggestionsLoading = false;
        _refreshSuggestions(); // Refresh initial suggestions
      });
    } catch (e) {
      _logger.info('Error loading suggestions: $e');
      setState(() {
        _suggestionsLoading = false;
        // Use fallback suggestions if Firebase fails (or keep _allSuggestions empty)
        _allSuggestions = [
          "How are you feeling?",
          "Share your thoughts",
          "Today's highlights?",
          "Any challenges?",
          "Need support?",
          "What are you grateful for?",
          "Recent accomplishments?",
          "Something bothering you?",
        ];
        _refreshSuggestions();
      });
    }
  }

  // Keep suggestion refresh method:
  void _refreshSuggestions() {
    if (_allSuggestions.isNotEmpty) {
      _allSuggestions.shuffle();
      _currentSuggestions = _allSuggestions.length >= 3
          ? _allSuggestions.sublist(0, 3)
          : _allSuggestions;
    } else {
      _currentSuggestions =
          []; // Ensure it's empty if no suggestions are loaded
    }
  }

  // sending message from the chat UI
  void _sendMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "content": message});
      _messages.add({"role": "assistant", "content": "Generating response..."});
      _messageController.clear();
      // Keep suggestion refresh:
      // _refreshSuggestions(); // Refresh suggestions after sending a message
    });

    final llmResponse = await _callLLM(message);

    // Add a loading message to display
    setState(() {
      _messages.removeLast();
      _messages.add({"role": "assistant", "content": llmResponse});
    });
  }

  Future<String> _callLLM(String message) async {
    // Implement direct API call to OpenAI/SealLM
    // Example using OpenAI:
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer YOUR_OPENAI_KEY',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        "model": "gpt-4o-nano",
        "messages": [{"role": "user", "content": message}]
      }),
    );
    return jsonDecode(response.body)['choices'][0]['message']['content'];
  }

  // String aiResponseContent;

  //   try {
  //     _logger.info(
  //         "ChatScreen: Calling RAG server at $_ragServerUrl with query: $message");
  //     final http.Response response = await http
  //         .post(
  //           Uri.parse(_ragServerUrl),
  //           headers: {'Content-Type': 'application/json'},
  //           body: jsonEncode({
  //             'query': message, // Use the current message as the query
  //             'chat_history': _chatHistory, // Pass the entire chat history
  //           }),
  //         )
  //         .timeout(const Duration(
  //             seconds:
  //                 120)); // Set a reasonable timeout for the entire RAG + LLM process

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(utf8.decode(response.bodyBytes));
  //       final List<dynamic> results = data['results'];

  //       if (results.isNotEmpty && results[0].containsKey('content')) {
  //         aiResponseContent = results[0]['content'];
  //       } else {
  //         _logger.info(
  //             'ChatScreen: RAG server response missing expected content: $data');
  //         aiResponseContent =
  //             "Sorry, bro. The RAG server didn't provide a complete answer.";
  //       }

  //       if (data.containsKey('updated_chat_history') &&
  //           data['updated_chat_history'] is List) {
  //         // IMPORTANT: Replace the entire _chatHistory with the one provided by the server
  //         _chatHistory.clear(); // Clear existing history
  //         for (var item in data['updated_chat_history']) {
  //           if (item is Map<String, dynamic> &&
  //               item.containsKey('role') &&
  //               item.containsKey('content')) {
  //             _chatHistory.add({
  //               "role": item['role'] as String,
  //               "content": item['content'] as String
  //             });
  //           }
  //         }
  //         _logger
  //             .info("ChatScreen: _chatHistory updated from server response.");
  //       } else {
  //         _logger.info(
  //             "ChatScreen: Server did not return 'updated_chat_history'. Appending only AI response to local history.");
  //         _chatHistory.add({
  //           "role": "user",
  //           "content": message
  //         }); // Re-add user message if history not returned
  //         _chatHistory.add({"role": "assistant", "content": aiResponseContent});
  //       }
  //     } else {
  //       _logger.info(
  //           'ChatScreen: RAG Server error ${response.statusCode}: ${response.body}');
  //       String errorMessage = "Unknown server error.";
  //       try {
  //         final errorData = jsonDecode(utf8.decode(response.bodyBytes));
  //         if (errorData.containsKey('results') &&
  //             errorData['results'] is List &&
  //             errorData['results'].isNotEmpty &&
  //             errorData['results'][0].containsKey('content')) {
  //           errorMessage = errorData['results'][0]['content'];
  //         } else if (errorData.containsKey('error')) {
  //           errorMessage = errorData['error'];
  //         } else if (errorData.containsKey('message')) {
  //           errorMessage = errorData['message'];
  //         }
  //       } catch (e) {
  //         _logger.info(
  //             "ChatScreen: Could not parse RAG server error response: $e");
  //       }
  //       aiResponseContent =
  //           "Sorry, bro. There was an error from the RAG server (${response.statusCode}): $errorMessage. Please try again.";
  //     }

  //     // Remove loading message and add AI response to display and chat history
  //     setState(() {
  //       _messages.removeLast(); // Remove loading message
  //       _messages.add({"role": "assistant", "content": aiResponseContent});
  //       //_chatHistory.add({"role": "assistant", "content": aiResponseContent});
  //     });
  //   } on TimeoutException {
  //     _logger.info("ChatScreen: Request to RAG server timed out.");
  //     setState(() {
  //       _messages.removeLast();
  //       _messages.add({
  //         "role": "assistant",
  //         "content":
  //             "Sorry, bro. The server took too long to respond. Please try again later."
  //       });
  //     });
  //   } catch (e) {
  //     _logger.info(
  //         "ChatScreen: Fatal error when generating response from RAG server: $e");
  //     setState(() {
  //       _messages.removeLast(); // Remove loading message
  //       _messages.add({
  //         "role": "assistant",
  //         "content":
  //             "Sorry, bro. There was a problem getting the answer. Please check your connection or server status."
  //       });
  //     });
  //   }
  // }

  // Restore suggestion tap handler:
  void _handleSuggestionTap(String suggestion) {
    _sendMessage(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kapwa Companion'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.contacts),
            tooltip: 'OFW',
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[850], // Dark background for the chat screen
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return ChatBubble(
                    message: message["content"]!,
                    isUser: message["role"] == "user",
                  );
                },
              ),
            ),
            // Restore _buildSuggestionChips() here:
            _buildSuggestionChips(), // Display suggestions below the chat messages
            const AudioPlayerWidget(),
            _buildMessageInput(), // Input field at the bottom
            _buildDisclaimer(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    AudioService().dispose();
    super.dispose();
  }

  // Restore _buildSuggestionChips() widget definition:
  Widget _buildSuggestionChips() {
    if (_suggestionsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: _currentSuggestions.map((suggestion) {
          return ActionChip(
            label: Text(
              suggestion,
              style: const TextStyle(color: Colors.white70),
            ),
            onPressed: () => _handleSuggestionTap(suggestion),
            backgroundColor: Colors.grey[700],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey[600]!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              // *** IMPORTANT: Add these properties to disable browser's autofill/autocomplete ***
              autofillHints: null, // Disables platform-specific autofill hints
              autocorrect: false, // Disables auto-correction
              enableSuggestions: false, // Disables text input suggestions

              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              style: const TextStyle(color: Colors.white),
              onSubmitted: _sendMessage, // Allow sending message on Enter key
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            // Fixed RenderFlex overflow with explicit size
            width: 48, // Standard FAB size
            height: 48, // Standard FAB size
            child: FloatingActionButton(
              onPressed: () => _sendMessage(_messageController.text),
              backgroundColor: Colors.blue[800],
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: const Text(
        'I can make mistakes, please double check.',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 12.0,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[800] : Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
