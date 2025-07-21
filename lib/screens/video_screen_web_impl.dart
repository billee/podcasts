// lib/screens/video_screen_web_impl.dart
// Web implementation with actual web functionality

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web show platformViewRegistry;

void setupIframe({
  required String iframeId,
  required String videoUrl,
  required VoidCallback onLoad,
  required Function(dynamic) onError,
}) {
  // Create iframe element for Daily.co
  final iframe = web.HTMLIFrameElement()
    ..src = videoUrl
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.backgroundColor = '#000000'
    ..allowFullscreen = true
    ..setAttribute('allow',
        'camera; microphone; display-capture; autoplay; fullscreen; clipboard-write')
    ..setAttribute('referrerpolicy', 'no-referrer-when-downgrade')
    ..setAttribute('sandbox',
        'allow-same-origin allow-scripts allow-popups allow-forms allow-modals allow-orientation-lock allow-pointer-lock allow-presentation allow-top-navigation-by-user-activation');

  // Add loading event listeners
  iframe.onLoad.listen((_) {
    onLoad();
  });

  // Add error event listener
  iframe.onError.listen((error) {
    onError(error);
  });

  // Register the iframe element with the unique ID
  ui_web.platformViewRegistry.registerViewFactory(
    iframeId,
    (int viewId) {
      return iframe;
    },
  );
}

void openInNewTab(String url) {
  web.window.open(url, '_blank');
}

Widget buildHtmlElementView(String viewType) {
  return HtmlElementView(viewType: viewType);
}
