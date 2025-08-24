// lib/services/violation_check_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

class ViolationCheckService {
  static final Logger _logger = Logger('ViolationCheckService');
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Set custom Firestore instance for testing
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }

  /// Check if user has unacknowledged violations
  /// Returns true if warning should be shown, false otherwise
  static Future<bool> shouldShowViolationWarning(String userId) async {
    try {
      _logger.info('Checking violation status for user: $userId');
      
      // Query for violations by this user
      final violationQuery = await _firestore
          .collection('user_violations')
          .where('userId', isEqualTo: userId)
          .where('resolved', isEqualTo: false)
          .get();

      if (violationQuery.docs.isEmpty) {
        _logger.info('No unresolved violations found for user: $userId');
        return false; // No violations, no warning needed
      }

      _logger.info('Found ${violationQuery.docs.length} unresolved violations for user: $userId');
      
      // Check if any violation doesn't have 'showed_at' field
      for (final doc in violationQuery.docs) {
        final data = doc.data();
        _logger.info('Violation document ${doc.id} data keys: ${data.keys.toList()}');
        
        if (!data.containsKey('showed_at')) {
          _logger.warning('User $userId has violation ${doc.id} without showed_at field - warning needed');
          return true; // Has violations but warning not shown yet (field doesn't exist)
        }
      }
      
      _logger.info('All violations for user $userId have been shown already');
      return false; // All violations have been shown
    } catch (e) {
      _logger.severe('Error checking violation status for user $userId: $e');
      return false; // On error, don't show warning to avoid blocking user
    }
  }

  /// Get violation count for a user (for future use)
  static Future<int> getViolationCount(String userId) async {
    try {
      final violationDoc = await _firestore
          .collection('user_violations')
          .doc(userId)
          .get();

      if (!violationDoc.exists) {
        return 0;
      }

      final data = violationDoc.data() as Map<String, dynamic>;
      final violations = data['violations'] as List<dynamic>? ?? [];
      return violations.length;
    } catch (e) {
      _logger.severe('Error getting violation count for user $userId: $e');
      return 0;
    }
  }

  /// Check if user is banned from renewals (3+ violations)
  static Future<bool> isBannedFromRenewals(String userId) async {
    try {
      final violationCount = await getViolationCount(userId);
      return violationCount >= 3;
    } catch (e) {
      _logger.severe('Error checking renewal ban status for user $userId: $e');
      return false;
    }
  }
}