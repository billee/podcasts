import 'package:flutter/material.dart';
import '../models/token_usage_info.dart';
import '../services/token_limit_service.dart';

/// Widget to display remaining tokens in chat interface
/// Shows real-time token counter with warnings when running low
class TokenUsageWidget extends StatelessWidget {
  final String? userId;
  final bool showWarnings;
  final int? lastExchangeTokens; // Tokens used in the most recent exchange

  const TokenUsageWidget({
    super.key,
    required this.userId,
    this.showWarnings = true,
    this.lastExchangeTokens,
  });

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<TokenUsageInfo>(
      stream: TokenLimitService.watchUserUsage(userId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final usageInfo = snapshot.data!;
        
        // Don't show widget if token limits are disabled
        if (usageInfo.tokenLimit == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Column(
            children: [
              // Token counter display
              _buildTokenCounter(usageInfo),
              
              // Warning message if tokens are running low
              if (showWarnings && usageInfo.isWarningThreshold && !usageInfo.isLimitReached)
                _buildWarningMessage(usageInfo),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTokenCounter(TokenUsageInfo usageInfo) {
    final percentage = usageInfo.usagePercentage;
    Color progressColor;
    
    if (percentage >= 0.9) {
      progressColor = Colors.red;
    } else if (percentage >= 0.7) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress indicator
        SizedBox(
          width: 60,
          height: 4,
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
        const SizedBox(width: 8),
        
        // Token count text
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${usageInfo.remainingTokens} tokens left',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
            // Show tokens used from the most recent exchange
            if ((lastExchangeTokens ?? 0) > 0)
              Text(
                '${lastExchangeTokens} tokens used',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white54,
                  fontWeight: FontWeight.w300,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWarningMessage(TokenUsageInfo usageInfo) {
    return Container(
      margin: const EdgeInsets.only(top: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: Colors.orange[300],
          ),
          const SizedBox(width: 4),
          Text(
            'Running low on tokens!',
            style: TextStyle(
              fontSize: 10,
              color: Colors.orange[300],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}