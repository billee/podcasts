// lib/services/violation_check_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/core/config.dart';

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
      
      int unshownCount = 0;
      
      // Check if any violation doesn't have 'shown_at' field (corrected field name)
      for (final doc in violationQuery.docs) {
        final data = doc.data();
        final shownAt = data['shown_at'];
        final violationType = data['violationType'] ?? 'unknown';
        final timestamp = data['timestamp'];
        
        _logger.info('Violation ${doc.id}: type=$violationType, shown_at=$shownAt, timestamp=$timestamp');
        
        // Check if shown_at field is missing or null
        if (shownAt == null) {
          unshownCount++;
          _logger.warning('User $userId has unshown violation ${doc.id} (type: $violationType)');
        }
      }
      
      if (unshownCount > 0) {
        _logger.warning('User $userId has $unshownCount unshown violations - warning needed');
        return true;
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
      return violationCount >= AppConfig.violationThresholdForBan;
    } catch (e) {
      _logger.severe('Error checking renewal ban status for user $userId: $e');
      return false;
    }
  }

  /// One-time fix method to mark all existing violations as shown for a specific user
  /// This fixes violations that were created before the shown_at field was added
  static Future<void> markAllExistingViolationsAsShown(String userId) async {
    try {
      _logger.info('Marking all existing violations as shown for user: $userId');
      
      final violationQuery = await _firestore
          .collection('user_violations')
          .where('userId', isEqualTo: userId)
          .get();

      if (violationQuery.docs.isEmpty) {
        _logger.info('No violations found for user: $userId');
        return;
      }

      final batch = _firestore.batch();
      int updatedCount = 0;

      for (final doc in violationQuery.docs) {
        final data = doc.data();
        final shownAt = data['shown_at'];
        
        // Only update if shown_at is missing or null
        if (shownAt == null) {
          batch.update(doc.reference, {
            'shown_at': FieldValue.serverTimestamp(),
          });
          updatedCount++;
          _logger.info('Marking violation ${doc.id} as shown');
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        _logger.info('Successfully marked $updatedCount violations as shown for user: $userId');
      } else {
        _logger.info('All violations already have shown_at timestamp for user: $userId');
      }
    } catch (e) {
      _logger.severe('Error marking existing violations as shown for user $userId: $e');
    }
  }

  /// System-wide fix method to mark ALL existing violations as shown
  /// Use this if the issue affects multiple users
  static Future<void> fixAllExistingViolations() async {
    try {
      _logger.info('Starting system-wide violation fix...');
      
      // Get all violations that don't have shown_at field
      final violationQuery = await _firestore
          .collection('user_violations')
          .get();

      if (violationQuery.docs.isEmpty) {
        _logger.info('No violations found in system');
        return;
      }

      final batch = _firestore.batch();
      int updatedCount = 0;
      int totalCount = 0;

      for (final doc in violationQuery.docs) {
        totalCount++;
        final data = doc.data();
        final shownAt = data['shown_at'];
        
        // Only update if shown_at is missing or null
        if (shownAt == null) {
          batch.update(doc.reference, {
            'shown_at': FieldValue.serverTimestamp(),
          });
          updatedCount++;
          
          // Commit in batches of 500 (Firestore limit)
          if (updatedCount % 500 == 0) {
            await batch.commit();
            _logger.info('Committed batch of 500 updates. Total updated so far: $updatedCount');
          }
        }
      }

      // Commit any remaining updates
      if (updatedCount % 500 != 0) {
        await batch.commit();
      }

      _logger.info('System-wide fix complete. Updated $updatedCount out of $totalCount total violations');
    } catch (e) {
      _logger.severe('Error in system-wide violation fix: $e');
    }
  }
}