// lib/widgets/placeholder_widget.dart
import 'package:flutter/material.dart';

class PlaceholderWidget extends StatelessWidget {
  final String message;

  const PlaceholderWidget({
    super.key,
    this.message = 'Content not available',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(message),
      ),
    );
  }
}
