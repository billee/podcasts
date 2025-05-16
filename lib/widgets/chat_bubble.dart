import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isLlama;

  const ChatBubble({
    super.key,
    required this.text,
    this.isUser = false,
    this.isLlama = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser
            ? Colors.blue[100]
            : (isLlama ? Colors.grey[200] : Colors.green[100]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}