// lib/screens/video_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VideoScreen extends StatefulWidget {
  final String? roomUrl;

  const VideoScreen({super.key, this.roomUrl});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _isLoading = false),
      ));

    if (widget.roomUrl != null) {
      _loadVideoCall();
    }
  }

  void _loadVideoCall() {
    final htmlContent = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Kapwa Video Call</title>
        <style>
          body, html { margin: 0; padding: 0; height: 100%; overflow: hidden; }
          #daily-container { width: 100%; height: 100vh; }
        </style>
      </head>
      <body>
        <div id="daily-container"></div>
        <script src="https://unpkg.com/@daily-co/daily-js"></script>
        <script>
          const container = document.getElementById('daily-container');
          const callFrame = window.DailyIframe.createFrame(container, {
            showLeaveButton: true,
            iframeStyle: { position: 'fixed', top: 0, left: 0, width: '100%', height: '100%', border: '0' }
          });
          callFrame.join({ url: '${widget.roomUrl}' }).catch(err => {
            console.error('Join error:', err);
          });
        </script>
      </body>
      </html>
    ''';
    _controller.loadHtmlString(htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roomUrl == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Preparing video room...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
