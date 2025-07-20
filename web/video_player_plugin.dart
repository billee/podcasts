// web/video_player_plugin.dart

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class VideoPlayerPlugin {
  static void registerWith(Registrar registrar) {
    final factory = VideoPlayerPlatformViewFactory();
    registrar.registerViewFactory('video-player', factory);
  }
}

class VideoPlayerPlatformViewFactory extends PlatformViewFactory {
  VideoPlayerPlatformViewFactory() : super(createPlatformView);

  static html.IFrameElement createPlatformView(Object args) {
    return VideoPlayerPlatformView(args as String? ?? '');
  }
}

class VideoPlayerPlatformView extends html.IFrameElement {
  VideoPlayerPlatformView(String videoUrl) {
    style.border = 'none';
    allowFullscreen = true;
    style.width = '100%';
    style.height = '100%';
    src = videoUrl;
  }
}
