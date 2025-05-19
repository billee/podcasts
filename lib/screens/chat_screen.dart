import 'package:flutter/material.dart';
import 'package:kapwa_companion/services/firebase_service.dart';
import 'package:kapwa_companion/services/rag_service.dart';
import 'package:kapwa_companion/services/llama_service.dart';
import 'package:kapwa_companion/constants.dart';
import 'dart:io';

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
  }

  void _refreshSuggestions() {
    _allSuggestions.shuffle();
    _currentSuggestions = _allSuggestions.sublist(0, 3);
  }

  void _sendMessage(String message) async {
    if (message.isEmpty) return;

    // Add user message
    setState(() {
      _messages.insert(0, {'text': message, 'isUser': true});
    });
    _clearInput();

    try {
      _addTempMessage("Processing your message...");
      print('Sending query: $message');

      final ragResults = await RAGService.query(message);
      print('RAG Results: $ragResults');

      String botResponse;
      try {
        botResponse = await LlamaService.generateResponse(message, ragResults);
      } catch (e) {
        botResponse = ragResults.first['content']; // Use direct RAG result
      }

      print('Generated Response: $botResponse');

      print('...........................');
      exit(0);


      _replaceTempMessage(botResponse);

    } catch (e, stack) {
      print('Error: $e\nStack: $stack'); // Detailed error logging
      _replaceTempMessage(_getFallbackResponse(message));
    }
  }

  String _getFallbackResponse(String input) {
    if (input.toLowerCase().contains('oec')) {
      return 'Para sa OEC renewal, bisitahin ang DMW website';
    }
    return 'Ay may problema, try ulit mamaya...';
  }

  void _addTempMessage(String text) {
    setState(() {
      _messages.insert(0, {'text': text, 'isTemp': true});
    });
  }

  void _replaceTempMessage(String newText) {
    setState(() {
      _messages.removeAt(0); // Remove loading message
      _messages.insert(0, {'text': newText, 'isUser': false});
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
                return MessageBubble(
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