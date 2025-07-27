import 'package:flutter/material.dart';

class SubscriptionPlanComparison extends StatelessWidget {
  final String? currentPlan;
  final VoidCallback? onUpgradePressed;
  final bool isLoading;

  const SubscriptionPlanComparison({
    super.key,
    this.currentPlan,
    this.onUpgradePressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plan Comparison',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildFreePlan()),
                const SizedBox(width: 16),
                Expanded(child: _buildPremiumPlan()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreePlan() {
    final isCurrentPlan = currentPlan == 'trial' || currentPlan == null;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlan ? Colors.orange : Colors.grey[600]!,
          width: isCurrentPlan ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Free Trial',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '7 Days',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 16),
          ..._buildFeatureList([
            'Limited AI Chat',
            'Basic Stories Access',
            'Standard Podcast Content',
            'Community Support',
          ], isIncluded: true),
          const SizedBox(height: 8),
          ..._buildFeatureList([
            'Unlimited AI Chat',
            'Premium Content',
            'Priority Support',
            'Offline Access',
          ], isIncluded: false),
          const SizedBox(height: 16),
          if (isCurrentPlan)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'CURRENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumPlan() {
    final isCurrentPlan = currentPlan == 'monthly' || currentPlan == 'premium';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlan ? Colors.green : Colors.blue[800]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.diamond,
                color: Colors.blue[800],
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Premium',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$3',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              Text(
                '/month',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._buildFeatureList([
            'Unlimited AI Chat',
            'Access to All Stories',
            'Premium Podcast Content',
            'Priority Support',
            'No Ads',
            'Offline Content Access',
            'Advanced Features',
            'Early Access to New Features',
          ], isIncluded: true),
          const SizedBox(height: 16),
          if (isCurrentPlan)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'CURRENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (onUpgradePressed != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onUpgradePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Upgrade',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFeatureList(List<String> features, {required bool isIncluded}) {
    return features.map((feature) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isIncluded ? Icons.check_circle : Icons.cancel,
            color: isIncluded ? Colors.green[400] : Colors.red[400],
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                color: isIncluded ? Colors.white70 : Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    )).toList();
  }
}