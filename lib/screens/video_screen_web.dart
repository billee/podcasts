import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class VideoScreenWeb extends StatefulWidget {
  final String videoUrl;

  const VideoScreenWeb({super.key, required this.videoUrl});

  @override
  State<VideoScreenWeb> createState() => _VideoScreenWebState();
}

class _VideoScreenWebState extends State<VideoScreenWeb> {
  late Widget _webView;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      // Create a platform view for web
      _webView = HtmlElementView(
        viewType: 'video-player',
        key: UniqueKey(),
      );

      // Register the view factory
      _registerViewFactory();
    } else {
      _webView =
          const Center(child: Text('Video player only available on web'));
    }
  }

  void _registerViewFactory() {
    // This needs to be called in a web context
    // We'll use a platform channel to register the view factory
    const platform = MethodChannel('video_player_channel');
    platform.invokeMethod('registerViewFactory', {'videoUrl': widget.videoUrl});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Player'),
      ),
      body: _webView,
    );
  }
}
