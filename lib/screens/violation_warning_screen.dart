// lib/screens/violation_warning_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/core/config.dart';

class ViolationWarningScreen extends StatelessWidget {
  final String userId;
  final VoidCallback onContinue;
  
  const ViolationWarningScreen({
    super.key,
    required this.userId,
    required this.onContinue,
  });

  static final Logger _logger = Logger('ViolationWarningScreen');

  Future<void> _markWarningAsShown() async {
    try {
      // Query for unresolved violations by this user that don't have showed_at field
      final violationQuery = await FirebaseFirestore.instance
          .collection('user_violations')
          .where('userId', isEqualTo: userId)
          .where('resolved', isEqualTo: false)
          .get();

      // Update all violations that don't have showed_at field
      final batch = FirebaseFirestore.instance.batch();
      int updatedCount = 0;
      
      for (final doc in violationQuery.docs) {
        final data = doc.data();
        if (!data.containsKey('showed_at')) {
          batch.update(doc.reference, {
            'showed_at': FieldValue.serverTimestamp(),
          });
          updatedCount++;
        }
      }
      
      if (updatedCount > 0) {
        await batch.commit();
        _logger.info('Marked $updatedCount violation warnings as shown for user: $userId');
      } else {
        _logger.info('No violations to mark as shown for user: $userId');
      }

      // Check if user has 3 or more violations and ban from renewals
      await _checkAndBanFromRenewals();
    } catch (e) {
      _logger.severe('Error marking warning as shown: $e');
    }
  }

  Future<void> _checkAndBanFromRenewals() async {
    try {
      // Get total violation count for this user
      final allViolationsQuery = await FirebaseFirestore.instance
          .collection('user_violations')
          .where('userId', isEqualTo: userId)
          .where('resolved', isEqualTo: false)
          .get();

      final violationCount = allViolationsQuery.docs.length;
      _logger.info('User $userId has $violationCount total violations');

      if (violationCount >= AppConfig.violationThresholdForBan) {
        // Ban user from renewals by adding banned_at field to their subscription
        final subscriptionQuery = await FirebaseFirestore.instance
            .collection('subscriptions')
            .where('userId', isEqualTo: userId)
            .get();

        if (subscriptionQuery.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          
          for (final subscriptionDoc in subscriptionQuery.docs) {
            final data = subscriptionDoc.data();
            // Only add banned_at if it doesn't already exist
            if (!data.containsKey('banned_at')) {
              batch.update(subscriptionDoc.reference, {
                'banned_at': FieldValue.serverTimestamp(),
              });
            }
          }
          
          await batch.commit();
          _logger.warning('User $userId banned from renewals due to $violationCount violations');
        } else {
          _logger.info('No subscription found for user $userId to ban');
        }
      }
    } catch (e) {
      _logger.severe('Error checking and banning user from renewals: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[900],
      body: SafeArea(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewportConstraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewportConstraints.maxHeight,
              ),
              child: IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Warning Icon
              Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: Colors.yellow[300],
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Terms and Conditions Violation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Warning Message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red[800],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[600]!, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      'You have violated our Terms and Conditions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please correct your behavior and ensure all future conversations remain respectful and appropriate.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[700],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.yellow[300],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Important: If you violate our terms ${AppConfig.violationThresholdForBan} times, you will not be able to renew future subscriptions.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _markWarningAsShown();
                    onContinue();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red[900],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'I Understand - Continue to Chat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Terms reminder
              Text(
                'By continuing, you agree to follow our Terms and Conditions',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}