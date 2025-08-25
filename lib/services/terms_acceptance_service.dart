// lib/services/terms_acceptance_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

class TermsAcceptanceService {
  static final Logger _logger = Logger('TermsAcceptanceService');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if user has accepted terms and conditions
  static Future<bool> hasAcceptedTerms(String userId) async {
    try {
      _logger.info('Checking terms acceptance for user: $userId');
      
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        _logger.info('User document not found for: $userId');
        return false;
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final hasAccepted = data.containsKey('accept_trial_terms_conditions');
      
      _logger.info('User $userId terms acceptance status: $hasAccepted');
      return hasAccepted;
    } catch (e) {
      _logger.severe('Error checking terms acceptance for user $userId: $e');
      return false; // Default to not accepted on error
    }
  }

  /// Mark user as having accepted terms and conditions
  static Future<void> acceptTerms(String userId) async {
    try {
      _logger.info('Marking terms as accepted for user: $userId');
      
      await _firestore
          .collection('users')
          .doc(userId)
          .set({
        'accept_trial_terms_conditions': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _logger.info('Terms acceptance recorded for user: $userId');
    } catch (e) {
      _logger.severe('Error recording terms acceptance for user $userId: $e');
      throw e;
    }
  }
}