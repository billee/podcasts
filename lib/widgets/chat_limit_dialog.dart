import 'package:flutter/material.dart';
import '../models/token_usage_info.dart';

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
      barrierDismissible: false,
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
            'Daily Token Limit Reached',
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
          
          // Encouragement message
          _buildEncouragementMessage(),
          
          // Upgrade prompt for trial users
          if (usageInfo.userType == 'trial') ...[
            const SizedBox(height: 16),
            _buildUpgradePrompt(),
          ],
        ],
      ),
      actions: [
        // Upgrade button for trial users
        if (usageInfo.userType == 'trial' && onUpgradePressed != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onUpgradePressed!();
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Upgrade Now'),
          ),
        
        // OK button
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
          ),
          child: const Text('OK'),
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
    final resetTime = usageInfo.resetTime;
    final now = DateTime.now();
    final timeUntilReset = resetTime.difference(now);
    
    String resetMessage;
    if (timeUntilReset.inHours > 0) {
      final hours = timeUntilReset.inHours;
      final minutes = timeUntilReset.inMinutes % 60;
      resetMessage = 'Your tokens will reset in ${hours}h ${minutes}m';
    } else if (timeUntilReset.inMinutes > 0) {
      resetMessage = 'Your tokens will reset in ${timeUntilReset.inMinutes} minutes';
    } else {
      resetMessage = 'Your tokens will reset very soon!';
    }

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
                const SizedBox(height: 2),
                Text(
                  'Reset time: ${_formatResetTime(resetTime)}',
                  style: TextStyle(
                    color: Colors.green[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncouragementMessage() {
    return Text(
      'Come back tomorrow to continue chatting! Your token count will be fully restored.',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 14,
        height: 1.4,
      ),
    );
  }

  Widget _buildUpgradePrompt() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[700]!.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.star_rounded,
            color: Colors.blue[400],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Upgrade to get more tokens daily and continue longer conversations!',
              style: TextStyle(
                color: Colors.blue[300],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
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