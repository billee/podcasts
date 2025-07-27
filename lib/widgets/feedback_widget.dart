import 'package:flutter/material.dart';

enum FeedbackType {
  success,
  error,
  warning,
  info,
}

class FeedbackWidget extends StatefulWidget {
  final FeedbackType type;
  final String message;
  final String? title;
  final VoidCallback? onDismiss;
  final Duration? duration;
  final bool showIcon;
  final bool isDismissible;

  const FeedbackWidget({
    super.key,
    required this.type,
    required this.message,
    this.title,
    this.onDismiss,
    this.duration,
    this.showIcon = true,
    this.isDismissible = true,
  });

  @override
  State<FeedbackWidget> createState() => _FeedbackWidgetState();
}

class _FeedbackWidgetState extends State<FeedbackWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // Auto-dismiss after duration
    if (widget.duration != null) {
      Future.delayed(widget.duration!, () {
        if (mounted) {
          _dismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      if (widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getBackgroundColor().withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getBackgroundColor().withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  if (widget.showIcon) ...[
                    Icon(
                      _getIcon(),
                      color: _getBackgroundColor(),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.title != null) ...[
                          Text(
                            widget.title!,
                            style: TextStyle(
                              color: _getBackgroundColor(),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          widget.message,
                          style: TextStyle(
                            color: _getBackgroundColor().withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isDismissible) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _dismiss,
                      icon: Icon(
                        Icons.close,
                        color: _getBackgroundColor(),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case FeedbackType.success:
        return Colors.green;
      case FeedbackType.error:
        return Colors.red;
      case FeedbackType.warning:
        return Colors.orange;
      case FeedbackType.info:
        return Colors.blue;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case FeedbackType.success:
        return Icons.check_circle;
      case FeedbackType.error:
        return Icons.error;
      case FeedbackType.warning:
        return Icons.warning;
      case FeedbackType.info:
        return Icons.info;
    }
  }
}

class FeedbackManager {
  static void showSuccess(
    BuildContext context, {
    required String message,
    String? title,
    Duration? duration = const Duration(seconds: 3),
  }) {
    _showFeedback(
      context,
      type: FeedbackType.success,
      message: message,
      title: title,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    String? title,
    Duration? duration = const Duration(seconds: 4),
  }) {
    _showFeedback(
      context,
      type: FeedbackType.error,
      message: message,
      title: title,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context, {
    required String message,
    String? title,
    Duration? duration = const Duration(seconds: 3),
  }) {
    _showFeedback(
      context,
      type: FeedbackType.warning,
      message: message,
      title: title,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    String? title,
    Duration? duration = const Duration(seconds: 3),
  }) {
    _showFeedback(
      context,
      type: FeedbackType.info,
      message: message,
      title: title,
      duration: duration,
    );
  }

  static void _showFeedback(
    BuildContext context, {
    required FeedbackType type,
    required String message,
    String? title,
    Duration? duration,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: FeedbackWidget(
            type: type,
            message: message,
            title: title,
            duration: duration,
            onDismiss: () {
              overlayEntry.remove();
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }

  static void showSnackBar(
    BuildContext context, {
    required String message,
    FeedbackType type = FeedbackType.info,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final color = _getSnackBarColor(type);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getSnackBarIcon(type),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static Color _getSnackBarColor(FeedbackType type) {
    switch (type) {
      case FeedbackType.success:
        return Colors.green;
      case FeedbackType.error:
        return Colors.red;
      case FeedbackType.warning:
        return Colors.orange;
      case FeedbackType.info:
        return Colors.blue;
    }
  }

  static IconData _getSnackBarIcon(FeedbackType type) {
    switch (type) {
      case FeedbackType.success:
        return Icons.check_circle;
      case FeedbackType.error:
        return Icons.error;
      case FeedbackType.warning:
        return Icons.warning;
      case FeedbackType.info:
        return Icons.info;
    }
  }
}