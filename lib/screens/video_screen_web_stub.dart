// lib/screens/video_screen_web_stub.dart
// Stub implementation for non-web platforms

import 'package:flutter/material.dart';

void setupIframe({
  required String iframeId,
  required String videoUrl,
  required VoidCallback onLoad,
  required Function(dynamic) onError,
}) {
  // Stub implementation - does nothing on non-web platforms
  throw UnsupportedError('Web functionality not supported on this platform');
}

void openInNewTab(String url) {
  // Stub implementation - does nothing on non-web platforms
  throw UnsupportedError('Opening new tab not supported on this platform');
}

Widget buildHtmlElementView(String viewType) {
  // Return a fallback widget for non-web platforms
  return const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.web_asset_off,
          color: Colors.grey,
          size: 48,
        ),
        SizedBox(height: 16),
        Text(
          'Web view not supported on this platform',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Please use the web version for video calls',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}
