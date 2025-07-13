// lib/screens/views/chat_screen_view.dart

import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/widgets/typing_indicator.dart';

// This is a stateless widget that takes the necessary data and callbacks
// from the _ChatScreenState to build the UI.
class ChatScreenView extends StatelessWidget {
  final TextEditingController messageController;
  final ScrollController scrollController;
  final List<Map<String, dynamic>> messages;
  final bool isTyping;
  final List<String> currentSuggestions;
  final bool suggestionsLoading;
  final Function(String) onSendMessage;
  final Function() onClearChat;
  final int conversationPairs;
  final String assistantName;
  final String? username; // Pass username to ChatBubble if needed
  final Function(String) onSuggestionSelected; // <--- ADD THIS LINE

  const ChatScreenView({
    super.key,
    required this.messageController,
    required this.scrollController,
    required this.messages,
    required this.isTyping,
    required this.currentSuggestions,
    required this.suggestionsLoading,
    required this.onSendMessage,
    required this.onClearChat,
    required this.conversationPairs,
    required this.assistantName,
    this.username,
    required this.onSuggestionSelected, // <--- ADD THIS LINE to the constructor
  });

  Widget _buildSuggestionChips() {
    if (suggestionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (currentSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: currentSuggestions.map((suggestion) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ActionChip(
              label: Text(suggestion),
              onPressed: () {
                onSuggestionSelected(
                    suggestion); // <--- ENSURE THIS CALLS THE PASSED FUNCTION
              },
              backgroundColor: Colors.blue[700],
              labelStyle: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat'),
            if (conversationPairs > 0)
              Text(
                'Conversations: $conversationPairs/10',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: onClearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                if (message['role'] == 'user' ||
                    message['role'] == 'assistant') {
                  return ChatBubble(
                    message: message['content'],
                    isUser: message['role'] == 'user',
                    senderName:
                        message['role'] == 'user' ? username : assistantName,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          _buildSuggestionChips(),
          isTyping ? const TypingIndicator() : const SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                    ),
                    onSubmitted: (value) => onSendMessage(value),
                  ),
                ),
                const SizedBox(width: 8.0),
                FloatingActionButton(
                  onPressed: () => onSendMessage(messageController.text),
                  backgroundColor: Colors.blue[800],
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final String? senderName;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.senderName,
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
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (senderName != null && !isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  senderName!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.0,
                    color: Colors.white70,
                  ),
                ),
              ),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16.0),
            ),
          ],
        ),
      ),
    );
  }
}
