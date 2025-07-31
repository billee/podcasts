import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/subscription_service.dart';

/// Widget that displays subscription status in the app bar
/// Shows trial days remaining or subscription status with appropriate icons
class SubscriptionStatusIndicator extends StatefulWidget {
  const SubscriptionStatusIndicator({super.key});

  @override
  State<SubscriptionStatusIndicator> createState() => _SubscriptionStatusIndicatorState();
}

class _SubscriptionStatusIndicatorState extends State<SubscriptionStatusIndicator> {
  SubscriptionStatus? _status;
  int _trialDaysLeft = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final status = await SubscriptionService.getSubscriptionStatus(user.uid);
      final trialDays = await SubscriptionService.getTrialDaysRemaining(user.uid);
      
      if (mounted) {
        setState(() {
          _status = status;
          _trialDaysLeft = trialDays;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
        ),
      );
    }

    if (_status == null) {
      return const SizedBox.shrink();
    }

    return _buildStatusIndicator();
  }

  Widget _buildStatusIndicator() {
    switch (_status!) {
      case SubscriptionStatus.trial:
        return _buildTrialIndicator();
      case SubscriptionStatus.active:
        return _buildActiveSubscriptionIndicator();
      case SubscriptionStatus.cancelled:
        return _buildCancelledSubscriptionIndicator();
      case SubscriptionStatus.expired:
      case SubscriptionStatus.trialExpired:
        return _buildExpiredIndicator();
    }
  }

  Widget _buildTrialIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _trialDaysLeft <= 1 ? Colors.red[700] : Colors.orange[700],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            '${_trialDaysLeft}d',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSubscriptionIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green[700],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            'PRO',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledSubscriptionIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[700],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond_outlined,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            'ENDING',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block,
            size: 16,
            color: Colors.white70,
          ),
          const SizedBox(width: 4),
          Text(
            'EXPIRED',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}