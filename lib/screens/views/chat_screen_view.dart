// lib/screens/views/chat_screen_view.dart

import 'package:flutter/material.dart';
import 'package:kapwa_companion_basic/widgets/typing_indicator.dart';
import 'package:kapwa_companion_basic/widgets/token_usage_widget.dart';

// This is a stateless widget that takes the necessary data and callbacks
// from the _ChatScreenState to build the UI.
class ChatScreenView extends StatelessWidget {
  final TextEditingController messageController;
  final ScrollController scrollController;
  final List<Map<String, dynamic>> messages;
  final bool isTyping;
  final Function(String) onSendMessage;
  final Function() onClearChat;
  final int conversationPairs;
  final String assistantName;
  final String? username;
  final int lastExchangeTokens;
  final String? userId;

  const ChatScreenView({
    super.key,
    required this.messageController,
    required this.scrollController,
    required this.messages,
    required this.isTyping,
    required this.onSendMessage,
    required this.onClearChat,
    required this.conversationPairs,
    required this.assistantName,
    this.username,
    this.userId,
    required this.lastExchangeTokens,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removed AppBar completely to maximize chat space
      body: SafeArea(
        child: Column(
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
            // Typing indicator
            isTyping ? const TypingIndicator() : const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
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
                          onSubmitted: (value) {
                            // Dismiss keyboard when user presses enter
                            FocusScope.of(context).unfocus();
                            onSendMessage(value);
                          },
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      FloatingActionButton(
                        onPressed: () {
                          // Dismiss keyboard when user taps send button
                          FocusScope.of(context).unfocus();
                          onSendMessage(messageController.text);
                        },
                        backgroundColor: Colors.blue[800],
                        mini: true,
                        child: const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                  // Token usage widget underneath the chatbox
                  TokenUsageWidget(
                    userId: userId,
                    lastExchangeTokens: lastExchangeTokens,
                  ),
                ],
              ),
            ),
          ],
        ),
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
