import 'package:flutter/material.dart';

enum LoadingType {
  circular,
  linear,
  dots,
  skeleton,
}

class LoadingStateWidget extends StatefulWidget {
  final LoadingType type;
  final String? message;
  final Color? color;
  final double? size;
  final bool showMessage;

  const LoadingStateWidget({
    super.key,
    this.type = LoadingType.circular,
    this.message,
    this.color,
    this.size,
    this.showMessage = true,
  });

  @override
  State<LoadingStateWidget> createState() => _LoadingStateWidgetState();
}

class _LoadingStateWidgetState extends State<LoadingStateWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).primaryColor;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLoadingIndicator(color),
        if (widget.showMessage && widget.message != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.message!,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingIndicator(Color color) {
    switch (widget.type) {
      case LoadingType.circular:
        return SizedBox(
          width: widget.size ?? 40,
          height: widget.size ?? 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );
      
      case LoadingType.linear:
        return SizedBox(
          width: widget.size ?? 200,
          child: LinearProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(color),
            backgroundColor: color.withOpacity(0.3),
          ),
        );
      
      case LoadingType.dots:
        return _buildDotsIndicator(color);
      
      case LoadingType.skeleton:
        return _buildSkeletonIndicator();
    }
  }

  Widget _buildDotsIndicator(Color color) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animationValue = (_animation.value - delay).clamp(0.0, 1.0);
            final scale = 0.5 + (0.5 * (1 - (animationValue - 0.5).abs() * 2).clamp(0.0, 1.0));
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size ?? 8,
                  height: widget.size ?? 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSkeletonIndicator() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size ?? 200,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              colors: [
                Colors.grey[700]!,
                Colors.grey[600]!,
                Colors.grey[700]!,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}

class LoadingButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final Color? loadingColor;
  final String? loadingText;

  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.loadingColor,
    this.loadingText,
  });

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: widget.isLoading ? null : widget.onPressed,
      child: widget.isLoading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.loadingColor ?? Colors.white,
                    ),
                  ),
                ),
                if (widget.loadingText != null) ...[
                  const SizedBox(width: 8),
                  Text(widget.loadingText!),
                ],
              ],
            )
          : widget.child,
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? loadingMessage;
  final Color? overlayColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.loadingMessage,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: (overlayColor ?? Colors.black).withOpacity(0.5),
            child: Center(
              child: LoadingStateWidget(
                message: loadingMessage ?? 'Loading...',
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}