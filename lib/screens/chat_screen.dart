// chat_screen.dart
import 'package:flutter/material.dart';
import 'package:kapwa_companion/services/llama_service.dart'; // Keep this import

// REMOVE THIS IMPORT:
// import 'package:kapwa_companion/services/rag_service.dart';


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

  @override
  void initState() {
    super.initState();
    _refreshSuggestions();
    // Add initial system message to chat history for LLM context
    _chatHistory.add({
      "role": "system",
      "content": "You are a helpful assistant for Overseas Filipino Workers (OFWs), providing culturally appropriate advice in everyday spoken English.. Your goal is to provide empathetic and informative responses based on the provided context."
    });
  }

  void _refreshSuggestions() {
    _allSuggestions.shuffle();
    _currentSuggestions = _allSuggestions.sublist(0, 3);
  }

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
      // Print chat history before sending to RAG server for debugging
      // const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      // print("Sending Chat History to RAG server:\n${encoder.convert(_chatHistory)}");

      // Call LlamaService to get the AI response (which now handles RAG server interaction)
      final aiResponse = await LlamaService.generateResponse(message, _chatHistory);

      // Remove loading message and add AI response to display and chat history
      setState(() {
        _messages.removeLast(); // Remove loading message
        _messages.add({"role": "assistant", "content": aiResponse});
        _chatHistory.add({"role": "assistant", "content": aiResponse});
      });
    } catch (e) {
      print("Fatal Error in _sendMessage: $e");
      setState(() {
        _messages.removeLast(); // Remove loading message
        // Display a user-friendly error message
        _messages.add({"role": "assistant", "content": "Paumanhin, kapatid. Nagkaroon ng problema sa pagkuha ng sagot."});
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