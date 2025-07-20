// web/video_player_channel.dart

import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter/services.dart';

class VideoPlayerChannel {
  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'video_player_channel',
      const StandardMethodCodec(),
      registrar.messenger,
    );

    final instance = VideoPlayerChannel();
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'registerViewFactory':
        final videoUrl = call.arguments['videoUrl'] as String? ?? '';
        _registerViewFactory(videoUrl);
        return true;
      default:
        throw PlatformException(
          code: 'not_implemented',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  void _registerViewFactory(String videoUrl) {
    js.context.callMethod('videoPlayerHandler.registerViewFactory', [videoUrl]);

    // Register the view factory with Flutter
    html.window.dispatchEvent(html.CustomEvent('register-view', detail: {
      'viewType': 'video-player',
      'factory': () {
        return html.window.createVideoPlayer();
      }
    }));
  }
}
