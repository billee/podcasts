// lib/widgets/typing_indicator.dart

import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<int> _dotAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _dotAnimation = IntTween(begin: 0, end: 3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _dotAnimation,
      builder: (context, child) {
        return Text(
          '.' * (_dotAnimation.value + 1),
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.white70,
            fontSize: 16,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kapwa Companion is typing',
              style:
                  TextStyle(fontStyle: FontStyle.italic, color: Colors.white70),
            ),
            const SizedBox(width: 8),
            // Replace the animated dots with a GIF
            Image.asset(
              'assets/images/typing_dots.gif',
              width: 30,
              height: 20,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to animated dots if GIF fails to load
                return _buildAnimatedDots();
              },
            ),
          ],
        ),
      ),
    );
  }
}
