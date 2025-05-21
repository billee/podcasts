// chat_screen.dart
import 'package:flutter/material.dart';
import 'package:kapwa_companion/services/rag_service.dart';
import 'package:kapwa_companion/services/llama_service.dart';


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
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

  @override
  void initState() {
    super.initState();
    _refreshSuggestions();
    // Add initial system message to chat history for LLM context
    _chatHistory.add({"role": "system", "content": "You are a helpful assistant for Overseas Filipino Workers (OFWs), providing culturally appropriate advice in everyday spoken English.. Your goal is to provide empathetic and informative responses based on the provided context."});
  }

  void _refreshSuggestions() {
    _allSuggestions.shuffle();
    _currentSuggestions = _allSuggestions.sublist(0, 3);
  }

  void _sendMessage(String message) async {
    if (message.isEmpty) return;

    // Add user message to UI immediately
    setState(() {
      _messages.insert(0, {'text': message, 'isUser': true});
    });
    _clearInput();

    // Add user message to chat history
    _chatHistory.add({"role": "user", "content": message});

    try {
      _addTempMessage("Processing your message..."); // Add "thinking" message
      print('Sending query to RAG server: $message');

      // 1. Call RAG Service to get relevant documents from ChromaDB
      final ragResults = await RAGService.query(message);
      print('RAG Results from server: $ragResults');

      // 2. Pass query and RAG results to Llama Service for generation
      String botResponse;
      try {
        // LlamaService.generateResponse will construct the prompt and call your LLM
        botResponse = await LlamaService.generateResponse(message, ragResults, _chatHistory);
        print('Generated LLM Response: $botResponse');
      } catch (e) {
        // Fallback if LLM generation fails (e.g., network issues to LLM API)
        // LlamaService already handles giving a fallback from RAG if possible,
        // so this catch block is for unhandled exceptions from LlamaService itself.
        print('Error during LLM generation: $e');
        botResponse = "Paumanhin, kapatid. May problema sa pagkuha ng sagot mula sa AI. Subukan ulit mamaya.";
      }

      // 3. Display the final bot response in the UI
      _replaceTempMessage(botResponse);
      // Add bot response to chat history
      _chatHistory.add({"role": "assistant", "content": botResponse});

      // Optional: Prune chat history to prevent it from growing too large
      // Keep only the last N turns + the initial system message
      final int maxTurns = 10; // For example, keep the last 5 user/assistant pairs
      if (_chatHistory.length > maxTurns * 2 + 1) { // +1 for the system message
        _chatHistory.removeRange(1, _chatHistory.length - (maxTurns * 2)); // Keep system + last N pairs
      }

    } catch (e, stack) {
      print('Fatal Error in _sendMessage: $e\nStack: $stack'); // Detailed error logging
      _replaceTempMessage("May problema sa pagkuha ng impormasyon. Pakisubukan ulit mamaya.");
    }
  }

  // Simplified fallback response now that LlamaService handles most fallbacks
  String _getFallbackResponse(String input) {
    return 'Ay may problema, try ulit mamaya...';
  }

  void _addTempMessage(String text) {
    setState(() {
      _messages.insert(0, {'text': text, 'isTemp': true, 'isUser': false}); // isUser: false for bot message
    });
  }

  void _replaceTempMessage(String newText) {
    setState(() {
      if (_messages.isNotEmpty && (_messages[0]['isTemp'] ?? false)) {
        _messages.removeAt(0); // Remove loading message
      }
      _messages.insert(0, {'text': newText, 'isUser': false}); // isUser: false for bot message
    });
    _refreshSuggestions();
  }

  void _clearInput() {
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Kapwa Companion',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble( // Using the existing MessageBubble
                  message: message['text'],
                  isUser: message['isUser'] ?? false,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[800]!),
                bottom: BorderSide(color: Colors.grey[800]!),
              ),
            ),
            child: Column(
              children: _currentSuggestions
                  .map(
                    (suggestion) => SuggestionItem(
                  text: suggestion,
                  onTap: () => _sendMessage(suggestion),
                ),
              )
                  .toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            color: Colors.black,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () => _sendMessage(_messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const MessageBubble({
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
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14),
        ),
      ),
    );
  }
}