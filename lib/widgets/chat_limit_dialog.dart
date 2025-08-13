import 'package:flutter/material.dart';
import '../models/token_usage_info.dart';
import '../core/config.dart';

/// Dialog shown when users reach their daily token limit
/// Displays limit information and exact reset time
class ChatLimitDialog extends StatelessWidget {
  final TokenUsageInfo usageInfo;
  final VoidCallback? onUpgradePressed;

  const ChatLimitDialog({
    super.key,
    required this.usageInfo,
    this.onUpgradePressed,
  });

  /// Show the dialog with token usage information
  static Future<void> show(
    BuildContext context,
    TokenUsageInfo usageInfo, {
    VoidCallback? onUpgradePressed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return ChatLimitDialog(
          usageInfo: usageInfo,
          onUpgradePressed: onUpgradePressed,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            color: Colors.orange[400],
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text(
            'Daily Token Limits',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Usage summary
          _buildUsageSummary(),
          const SizedBox(height: 16),
          
          // Reset time information
          _buildResetTimeInfo(),
          const SizedBox(height: 16),
          

        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue[400],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text(
            'OK',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: Colors.blue[400],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You have used all ${usageInfo.tokenLimit} tokens for today.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetTimeInfo() {
    // Always show fixed reset time at 24:00 (midnight)
    const resetMessage = 'Your tokens will reset at 24:00';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[700]!.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.refresh_rounded,
            color: Colors.green[400],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resetMessage,
                  style: TextStyle(
                    color: Colors.green[300],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  String _formatResetTime(DateTime resetTime) {
    final localTime = resetTime.toLocal();
    final hour = localTime.hour;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$displayHour:$minute $period';
  }
}