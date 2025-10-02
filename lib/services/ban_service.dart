import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

class BanService {
  static final Logger _logger = Logger('BanService');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if a user is banned
  static Future<bool> isUserBanned(String userId) async {
    try {
      final doc = await _firestore.collection('banned_users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      _logger.severe('Error checking if user is banned: $e');
      return false;
    }
  }

  /// Get ban details for a user
  static Future<Map<String, dynamic>?> getBanDetails(String userId) async {
    try {
      final doc = await _firestore.collection('banned_users').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      _logger.severe('Error getting ban details: $e');
      return null;
    }
  }

  /// Ban a user
  static Future<void> banUser({
    required String userId,
    required String reason,
    String? adminId,
  }) async {
    try {
      await _firestore.collection('banned_users').doc(userId).set({
        'userId': userId,
        'reason': reason,
        'bannedAt': FieldValue.serverTimestamp(),
        'bannedBy': adminId,
      });
      _logger.info('User $userId banned successfully');
    } catch (e) {
      _logger.severe('Error banning user: $e');
      rethrow;
    }
  }

  /// Unban a user
  static Future<void> unbanUser(String userId) async {
    try {
      await _firestore.collection('banned_users').doc(userId).delete();
      _logger.info('User $userId unbanned successfully');
    } catch (e) {
      _logger.severe('Error unbanning user: $e');
      rethrow;
    }
  }
}