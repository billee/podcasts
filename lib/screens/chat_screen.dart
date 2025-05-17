import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];
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

  void _sendMessage(String message) {
    if (message.isEmpty) return;

    // Separate message handling
    _addMessages(message);
    _clearInput();
  }

  // New method for message handling
  void _addMessages(String userMessage) {
    setState(() {
      _messages.add(userMessage);
      _messages.add(_getBotResponse(userMessage));
      _refreshSuggestions();
    });
  }

// New method for input cleanup
  void _clearInput() {
    _messageController.clear();
  }

  String _getBotResponse(String userMessage) {
    final responses = [
      "That's interesting. Can you tell me more about that?",
      "Thank you for sharing. How did that make you feel?",
      "I appreciate you opening up about this. Let's explore that further.",
      "That sounds important. What would you like to do next?",
      "I'm here to listen. Please continue when you're ready.",
    ];
    return responses[_messages.length % responses.length];
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
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                return MessageBubble(
                  message: message,
                  isUser: index % 2 == 0,
                );
              },
            ),
          ),
          // Suggestions Container
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
                  .map((suggestion) => SuggestionItem(
                text: suggestion,
                onTap: () => _sendMessage(suggestion),
              ))
                  .toList(),
            ),
          ),
          // Input Container
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