// lib/screens/video_screen_web.dart

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'dart:async';
import 'dart:math' as math;

// Conditional imports - only import web libraries when building for web
import 'video_screen_web_stub.dart'
    if (dart.library.html) 'video_screen_web_impl.dart' as web_impl;

class VideoScreenWeb extends StatefulWidget {
  final String videoUrl;

  const VideoScreenWeb({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VideoScreenWeb> createState() => _VideoScreenWebState();
}

class _VideoScreenWebState extends State<VideoScreenWeb> {
  final Logger _logger = Logger('VideoScreenWeb');
  late String _iframeId;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _loadingTimeout;
  Timer? _initialLoadCheck;
  bool _iframeRegistered = false;

  @override
  void initState() {
    super.initState();
    // Generate unique iframe ID
    _iframeId = 'daily-iframe-${math.Random().nextInt(999999)}';
    _logger.info('VideoScreenWeb initialized with URL: ${widget.videoUrl}');
    _logger.info('Using iframe ID: $_iframeId');

    _setupDailyIframe();

    // Set a longer timeout for loading (Daily.co can take time)
    _loadingTimeout = Timer(const Duration(seconds: 20), () {
      if (_isLoading && mounted) {
        _logger.warning('Loading timeout reached after 20 seconds');
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Loading timeout - Daily.co room may be taking longer than expected';
        });
      }
    });

    // Quick check to see if we should stop showing loading after a reasonable time
    _initialLoadCheck = Timer(const Duration(seconds: 3), () {
      if (_isLoading && mounted && _iframeRegistered) {
        _logger.info('Initial load check - assuming iframe is working');
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    });
  }

  void _setupDailyIframe() {
    try {
      _logger.info('Setting up iframe for URL: ${widget.videoUrl}');

      web_impl.setupIframe(
        iframeId: _iframeId,
        videoUrl: widget.videoUrl,
        onLoad: () {
          _logger.info('Daily.co iframe onLoad event fired');
          _loadingTimeout?.cancel();
          _initialLoadCheck?.cancel();
          if (mounted) {
            // Add a small delay to ensure Daily.co UI is fully loaded
            Timer(const Duration(milliseconds: 1000), () {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = null;
                });
              }
            });
          }
        },
        onError: (error) {
          _logger.severe('Daily.co iframe onError event fired: $error');
          _loadingTimeout?.cancel();
          _initialLoadCheck?.cancel();
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Failed to load Daily.co video room';
            });
          }
        },
      );

      _iframeRegistered = true;
      _logger.info('Daily.co iframe setup completed with ID: $_iframeId');
    } catch (e) {
      _logger.severe('Error setting up Daily.co iframe: $e');
      _loadingTimeout?.cancel();
      _initialLoadCheck?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error setting up video room: $e';
        });
      }
    }
  }

  void _openInNewTab() {
    _logger.info('Opening Daily.co room in new tab: ${widget.videoUrl}');
    web_impl.openInNewTab(widget.videoUrl);
  }

  void _retry() {
    _logger.info('Retrying iframe setup');
    _loadingTimeout?.cancel();
    _initialLoadCheck?.cancel();

    // Generate new iframe ID for retry
    _iframeId = 'daily-iframe-${math.Random().nextInt(999999)}';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _iframeRegistered = false;
    });

    _setupDailyIframe();

    // Reset timers
    _loadingTimeout = Timer(const Duration(seconds: 20), () {
      if (_isLoading && mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Loading timeout after retry - Daily.co room may not be available';
        });
      }
    });

    _initialLoadCheck = Timer(const Duration(seconds: 3), () {
      if (_isLoading && mounted && _iframeRegistered) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    });
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
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading video room...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connecting to Daily.co',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openInNewTab,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in New Tab'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _logger.info('User cancelled loading, opening in new tab');
                _openInNewTab();
              },
              child: const Text(
                'Taking too long? Click here to open in browser',
                style: TextStyle(color: Colors.blue, fontSize: 13),
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_off,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 24),
              const Text(
                'Video Room Unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Unknown error occurred',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.link,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Daily.co Room URL:',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      widget.videoUrl,
                      style: TextStyle(
                        color: Colors.grey[200],
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openInNewTab,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open in Browser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
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
        backgroundColor: Colors.black87,
        elevation: 0,
        title: Row(
          children: [
            Icon(
              Icons.videocam,
              color: Colors.green[400],
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Video Call',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: _openInNewTab,
            tooltip: 'Open in New Tab',
            splashRadius: 20,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _retry,
            tooltip: 'Refresh Video Room',
            splashRadius: 20,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Daily.co room info bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey[900],
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Room: ${Uri.parse(widget.videoUrl).pathSegments.last}',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  'Daily.co',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Main video iframe area
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: _iframeRegistered
                  ? web_impl.buildHtmlElementView(_iframeId)
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_call,
                            color: Colors.grey,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Preparing video room...',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Bottom help bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey[900],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 14,
                  color: Colors.amber[600],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'If the video doesn\'t load properly, try opening in a new browser tab',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _logger.info(
        'Building VideoScreenWeb - Loading: $_isLoading, Error: $_errorMessage != null, IframeRegistered: $_iframeRegistered');

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
    _logger.info('VideoScreenWeb disposed');
    _loadingTimeout?.cancel();
    _initialLoadCheck?.cancel();
    super.dispose();
  }
}
