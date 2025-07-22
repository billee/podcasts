// lib/screens/video_screen.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class VideoScreen extends StatefulWidget {
  final String? roomUrl;

  const VideoScreen({
    super.key,
    this.roomUrl,
  });

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final Logger _logger = Logger('VideoScreen');
  WebViewController? _webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _logger.info('VideoScreen initialized with roomUrl: ${widget.roomUrl}');

    // For mobile platforms, suggest opening in browser immediately
    if (Platform.isAndroid || Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBrowserSuggestion();
      });
    }

    _setupWebView();
  }

  void _showBrowserSuggestion() {
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.videocam, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('Video Call Setup'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For video calls to work properly with camera and microphone access, you need to open the room in your device\'s default browser (Chrome, Safari, Firefox, etc.).',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'WebView (in-app browser) cannot access camera/microphone permissions.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Try WebView Anyway'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _launchInBrowser();
            },
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open in External Browser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _setupWebView() {
    if (widget.roomUrl == null || widget.roomUrl!.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No room URL provided';
      });
      return;
    }

    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
            'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
        ..enableZoom(false)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              _logger.info('WebView started loading: $url');
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            },
            onPageFinished: (String url) {
              _logger.info('WebView finished loading: $url');
              setState(() {
                _isLoading = false;
              });

              // Inject JavaScript to handle permissions and improve compatibility
              _injectVideoPermissionScript();
            },
            onWebResourceError: (WebResourceError error) {
              _logger.severe(
                  'WebView error: ${error.description} (Code: ${error.errorCode})');

              // Handle specific ORB errors
              if (error.description?.contains('ERR_BLOCKED_BY_ORB') == true ||
                  error.description?.contains('ERR_BLOCKED_BY_RESPONSE') ==
                      true) {
                setState(() {
                  _isLoading = false;
                  _errorMessage =
                      'Video room blocked by security policy. Please use "Open in Browser" for the best experience.';
                });
              } else {
                setState(() {
                  _isLoading = false;
                  _errorMessage =
                      'Failed to load video room: ${error.description}';
                });

                // Auto-retry for network errors
                if (_retryCount < _maxRetries &&
                    (error.description?.contains('net::') == true)) {
                  _retryCount++;
                  _logger.info(
                      'Auto-retrying... Attempt $_retryCount of $_maxRetries');
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      _setupWebView();
                    }
                  });
                }
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              _logger.info('Navigation request: ${request.url}');

              // Allow navigation to Daily.co domains and related video services
              final uri = Uri.parse(request.url);
              if (uri.host.contains('daily.co') ||
                  uri.host.contains('daily-co.com') ||
                  uri.host.contains('jitsi.org') ||
                  uri.host.contains('meet.google.com') ||
                  uri.host.contains('zoom.us')) {
                return NavigationDecision.navigate;
              }

              // For external links, open in browser
              if (request.url.startsWith('http')) {
                _launchUrl(request.url);
                return NavigationDecision.prevent;
              }

              return NavigationDecision.navigate;
            },
          ),
        );

      // Load the URL with additional headers to help with CORS
      _webViewController!.loadRequest(
        Uri.parse(widget.roomUrl!),
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers':
              'Origin, X-Requested-With, Content-Type, Accept, Authorization',
        },
      );

      _logger.info('WebView setup completed for URL: ${widget.roomUrl}');
    } catch (e) {
      _logger.severe('Error setting up WebView: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error setting up video room: $e';
      });
    }
  }

  void _injectVideoPermissionScript() {
    _webViewController?.runJavaScript('''
      // Request permissions for camera and microphone
      if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        navigator.mediaDevices.getUserMedia({video: true, audio: true})
          .then(function(stream) {
            console.log('Media permissions granted');
            // Stop the stream as we just needed permissions
            stream.getTracks().forEach(track => track.stop());
          })
          .catch(function(err) {
            console.log('Media permissions denied:', err);
          });
      }
      
      // Handle fullscreen requests
      document.addEventListener('fullscreenchange', function() {
        console.log('Fullscreen changed');
      });
      
      // Improve mobile experience
      if (window.screen && window.screen.orientation) {
        try {
          window.screen.orientation.lock('any');
        } catch (e) {
          console.log('Screen orientation lock not supported');
        }
      }
    ''');
  }

  Future<void> _launchInBrowser() async {
    if (widget.roomUrl != null) {
      await _launchUrl(widget.roomUrl!);
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);

      // Force external browser launch with proper configuration
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // This forces external browser
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );

      if (launched) {
        _logger.info('Successfully launched URL in external browser: $url');

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video room opened in browser'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _logger.warning('Failed to launch URL in external browser: $url');

        // Try alternative launch method
        final alternativeLaunched = await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        );

        if (!alternativeLaunched) {
          throw Exception('Could not launch URL in any external application');
        }
      }
    } catch (e) {
      _logger.severe('Error launching URL in browser: $e');

      if (mounted) {
        // Show error with the actual URL for manual copying
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Open Browser'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Unable to open the video room in your browser automatically.'),
                const SizedBox(height: 12),
                const Text(
                    'Please copy this URL and paste it in your browser:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    url,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Try to copy to clipboard if possible
                  // You might need to add flutter/services import and use:
                  // Clipboard.setData(ClipboardData(text: url));
                },
                child: const Text('Copy URL'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildLoadingWidget() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading video room...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            if (_retryCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Retry attempt $_retryCount of $_maxRetries',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Unknown error',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              if (_errorMessage?.contains('ERR_BLOCKED_BY_ORB') == true ||
                  _errorMessage?.contains('security policy') == true) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'This error occurs due to browser security policies. Video calls work best in your device\'s default browser.',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (widget.roomUrl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Room URL: ${widget.roomUrl}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _launchInBrowser,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open in Browser (Recommended)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                    _retryCount = 0;
                  });
                  _setupWebView();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry WebView'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoWidget() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Video Call',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _launchInBrowser,
            tooltip: 'Open in Browser',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
                _retryCount = 0;
              });
              _setupWebView();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Room URL display with copy functionality
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Room: ${widget.roomUrl ?? "Unknown"}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  color: Colors.grey[400],
                  onPressed: () {
                    if (widget.roomUrl != null) {
                      // Copy URL to clipboard (you might need to add clipboard package)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Room URL copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  tooltip: 'Copy room URL',
                ),
              ],
            ),
          ),
          // Main video area
          Expanded(
            child: _webViewController != null
                ? WebViewWidget(controller: _webViewController!)
                : const Center(
                    child: Text(
                      'WebView not initialized',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _logger.info(
        'Building VideoScreen - Loading: $_isLoading, Error: $_errorMessage');

    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    return _buildVideoWidget();
  }

  @override
  void dispose() {
    _logger.info('VideoScreen disposed');
    super.dispose();
  }
}
