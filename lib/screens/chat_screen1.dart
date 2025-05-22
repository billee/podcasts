// chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Import for TimeoutException


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; // Stores messages for display
  final List<String> _allSuggestions = [
    "How are you feeling?",
    "Share your thoughts",
    "Today's highlights?",
    "Any challenges?",
    "Need support?",
    "What are you grateful for?",
    "Recent accomplishments?",
    "Something bothering you?",
  ];
  List<String> _currentSuggestions = [];

  // Stores chat history for LLM context, including system messages
  final List<Map<String, String>> _chatHistory = [];

  static final String _ragServerUrl = dotenv.env['LLAMA_RAG_SERVER_URL'] ?? 'http://localhost:5000/query';

  @override
  void initState() {
    super.initState();
    _refreshSuggestions();
    // Add initial system message to chat history for LLM context
    final String initialSystemMessage = dotenv.env['INITIAL_SYSTEM_MESSAGE'] ??
        "You are a helpful assistant for Overseas Filipino Workers (OFWs), providing culturally appropriate advice in everyday spoken English.. Your goal is to provide empathetic and informative responses based on the provided context.";

    _chatHistory.add({
      "role": "system",
      "content": initialSystemMessage,
    });
  }

  void _refreshSuggestions() {
    _allSuggestions.shuffle();
    _currentSuggestions = _allSuggestions.sublist(0, 3);
  }

  // sending message from the chat UI
  void _sendMessage(String message) async {
    if (message.isEmpty) return;

    // Add user message to display and chat history
    setState(() {
      _messages.add({"role": "user", "content": message});
      _chatHistory.add({"role": "user", "content": message});
      _messageController.clear();
      _refreshSuggestions(); // Refresh suggestions after sending a message
    });

    // Add a loading message to display
    setState(() {
      _messages.add({"role": "assistant", "content": "Generating response..."});
    });

    try {
      print("ChatScreen: Calling RAG server at $_ragServerUrl with query: $message");
      //go to chromadb for retrieval
      final http.Response response = await http.post(
        Uri.parse(_ragServerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': message,
          'chat_history': _chatHistory,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        // The RAG server is expected to return results in the format:
        // {"results": [{"content": "...", "score": ..., "source": "..."}]}
        final List<dynamic> results = data['results'];

        // Added check for empty results list before accessing index 0
        if (results.isNotEmpty && results[0].containsKey('content')) {
          aiResponseContent = results[0]['content'];
        } else {
          print('ChatScreen: RAG server response missing expected content: $data');
          aiResponseContent = "Sorry, the RAG server didn't provide a complete answer.";
        }
      } else {
        print('ChatScreen: RAG Server error ${response.statusCode}: ${response.body}');
        // Attempt to parse server's error message if available
        String errorMessage = "Unknown server error.";
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          // Improved parsing for various error response formats
          if (errorData.containsKey('results') && errorData['results'] is List && errorData['results'].isNotEmpty && errorData['results'][0].containsKey('content')) {
            errorMessage = errorData['results'][0]['content'];
          } else if (errorData.containsKey('error')) {
            errorMessage = errorData['error'];
          } else if (errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          print("ChatScreen: Could not parse RAG server error response: $e");
        }
        aiResponseContent = "Sorry, there was an error from the RAG server (${response.statusCode}): $errorMessage. Please try again.";
      }

      print('screen display result..........');
      print(aiResponseContent);


      // Remove loading message and add AI response to display and chat history
      setState(() {
        _messages.removeLast(); // Remove loading message
        _messages.add({"role": "assistant", "content": aiResponseContent});
        _chatHistory.add({"role": "assistant", "content": aiResponseContent});
      });
    } on TimeoutException catch (e) { // Catch specific TimeoutException
      print("Timeout Error in _sendMessage: $e");
      setState(() {
        _messages.removeLast();
        _messages.add({"role": "assistant", "content": "Sorry, the server took too long to respond."});
      });
    } catch (e) {
      print("Fatal Error in _sendMessage: $e");
      setState(() {
        _messages.removeLast(); // Remove loading message
        // Display a user-friendly error message
        _messages.add({"role": "assistant", "content": "Sorry, there was a problem getting the answer."});
      });
    }
  }

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
            _buildSuggestionChips(), // Display suggestions below the chat messages
            _buildMessageInput(), // Input field at the bottom
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Wrap(
        spacing: 8.0, // horizontal space between chips
        runSpacing: 4.0, // vertical space between lines of chips
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
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              style: const TextStyle(color: Colors.white),
              onSubmitted: _sendMessage, // Allow sending message on Enter key
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: () => _sendMessage(_messageController.text),
            backgroundColor: Colors.blue[800],
            mini: true,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
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

class SuggestionItem extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const SuggestionItem({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[700]!),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}