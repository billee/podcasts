// lib/services/violation_logging_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import '../core/config.dart';

/// Service for logging user boundary violations and safety concerns
class ViolationLoggingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Logger _logger = Logger('ViolationLoggingService');

  /// Log a boundary violation to Firestore
  static Future<void> logViolation({
    required String userId,
    required String violationType,
    required String userMessage,
    required String llmResponse,
  }) async {
    try {
      final violation = {
        'userId': userId,
        'violationType': violationType,
        'userMessage': userMessage,
        'llmResponse': llmResponse,
        'timestamp': FieldValue.serverTimestamp(),
        'date': _getTodayString(),
        'resolved': false,
      };

      await _firestore
          .collection('user_violations')
          .add(violation);

      _logger.warning('Logged violation for user $userId: $violationType');
    } catch (e) {
      _logger.severe('Error logging violation: $e');
    }
  }

  /// Check if user has multiple violations (for potential blocking)
  static Future<int> getUserViolationCount(String userId) async {
    try {
      final query = await _firestore
          .collection('user_violations')
          .where('userId', isEqualTo: userId)
          .where('resolved', isEqualTo: false)
          .get();

      return query.docs.length;
    } catch (e) {
      _logger.severe('Error getting violation count: $e');
      return 0;
    }
  }

  /// Mark violation as resolved (for admin use)
  static Future<void> resolveViolation(String violationId) async {
    try {
      await _firestore
          .collection('user_violations')
          .doc(violationId)
          .update({'resolved': true, 'resolvedAt': FieldValue.serverTimestamp()});

      _logger.info('Violation $violationId marked as resolved');
    } catch (e) {
      _logger.severe('Error resolving violation: $e');
    }
  }

  /// Get today's date string in YYYY-MM-DD format
  static String _getTodayString() {
    final now = AppConfig.currentDateTime;
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}