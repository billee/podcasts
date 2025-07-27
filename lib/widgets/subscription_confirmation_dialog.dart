import 'package:flutter/material.dart';

class SubscriptionConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final List<String> details;
  final String confirmButtonText;
  final String cancelButtonText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const SubscriptionConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.details,
    required this.confirmButtonText,
    this.cancelButtonText = 'Cancel',
    required this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[800],
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Details:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...details.map((detail) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Expanded(
                    child: Text(
                      detail,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.pop(context),
          child: Text(
            cancelButtonText,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? Colors.red : Colors.blue[800],
            foregroundColor: Colors.white,
          ),
          child: Text(confirmButtonText),
        ),
      ],
    );
  }

  static Future<void> showCancellationDialog({
    required BuildContext context,
    required String endDate,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (context) => SubscriptionConfirmationDialog(
        title: 'Cancel Subscription',
        message: 'Are you sure you want to cancel your subscription?',
        details: [
          'You will keep access until $endDate',
          'No refund for the current billing period',
          'You can resubscribe anytime',
          'No more trial period after cancellation',
        ],
        confirmButtonText: 'Cancel Subscription',
        cancelButtonText: 'Keep Subscription',
        onConfirm: onConfirm,
        isDestructive: true,
      ),
    );
  }

  static Future<void> showUpgradeDialog({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (context) => SubscriptionConfirmationDialog(
        title: 'Upgrade to Premium',
        message: 'Ready to unlock all premium features?',
        details: [
          'Unlimited AI Chat',
          'Access to All Stories',
          'Premium Podcast Content',
          'Priority Support',
          'No Ads',
          'Offline Content Access',
        ],
        confirmButtonText: 'Upgrade Now',
        onConfirm: onConfirm,
      ),
    );
  }

  static Future<void> showReactivationDialog({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (context) => SubscriptionConfirmationDialog(
        title: 'Reactivate Subscription',
        message: 'Reactivate your premium subscription?',
        details: [
          'Immediate access to all premium features',
          'Monthly billing at \$3/month',
          'Cancel anytime',
        ],
        confirmButtonText: 'Reactivate',
        onConfirm: onConfirm,
      ),
    );
  }
}