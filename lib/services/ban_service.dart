// lib/services/ban_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';

class BanService {
  static final Logger _logger = Logger('BanService');
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static FirebaseAuth _auth = FirebaseAuth.instance;

  // For testing purposes - allow dependency injection
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }

  static void setAuthInstance(FirebaseAuth auth) {
    _auth = auth;
  }

  /// Check if the current user is banned
  static Future<bool> isCurrentUserBanned() async {
    final user = _auth.currentUser;
    if (user == null) {
      _logger.info('No current user, not banned');
      return false;
    }
    
    return await isUserBanned(user.uid);
  }

  /// Check if a specific user is banned
  static Future<bool> isUserBanned(String userId) async {
    try {
      _logger.info('Checking ban status for user: $userId');
      
      // First check if user document has banned_at field
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData.containsKey('banned_at')) {
          final bannedAt = userData['banned_at'];
          _logger.warning('User $userId is banned (banned_at field found). Banned at: $bannedAt');
          return true;
        }
      }
      
      // Check if user has a ban record in user_bans collection
      final banQuery = await _firestore
          .collection('user_bans')
          .where('userId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (banQuery.docs.isNotEmpty) {
        final banData = banQuery.docs.first.data();
        final bannedAt = banData['banned_at'] as Timestamp?;
        final reason = banData['reason'] as String?;
        
        _logger.warning('User $userId is banned (user_bans collection). Banned at: $bannedAt, Reason: $reason');
        return true;
      }

      // Also check if user has 3+ violations (legacy ban check)
      final violationsQuery = await _firestore
          .collection('user_violations')
          .where('userId', isEqualTo: userId)
          .where('resolved', isEqualTo: false)
          .get();

      final violationCount = violationsQuery.docs.length;
      if (violationCount >= 3) {
        _logger.warning('User $userId has $violationCount violations, treating as banned');
        
        // Create a ban record for this user
        await _createBanRecord(userId, 'Automatic ban due to $violationCount violations');
        return true;
      }

      _logger.info('User $userId is not banned');
      return false;
    } catch (e) {
      _logger.severe('Error checking ban status for user $userId: $e');
      // On error, assume not banned to avoid false positives
      return false;
    }
  }

  /// Get ban details for a user
  static Future<Map<String, dynamic>?> getBanDetails(String userId) async {
    try {
      // First check user document for banned_at field
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData.containsKey('banned_at')) {
          return {
            'userId': userId,
            'banned_at': userData['banned_at'],
            'reason': userData['ban_reason'] ?? 'Paglabag sa mga tuntunin at kondisyon',
            'source': 'user_document'
          };
        }
      }
      
      // Check user_bans collection
      final banQuery = await _firestore
          .collection('user_bans')
          .where('userId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (banQuery.docs.isNotEmpty) {
        final banData = banQuery.docs.first.data();
        banData['source'] = 'user_bans_collection';
        return banData;
      }
      
      return null;
    } catch (e) {
      _logger.severe('Error getting ban details for user $userId: $e');
      return null;
    }
  }

  /// Create a ban record for a user
  static Future<void> _createBanRecord(String userId, String reason) async {
    try {
      await _firestore.collection('user_bans').add({
        'userId': userId,
        'reason': reason,
        'banned_at': FieldValue.serverTimestamp(),
        'active': true,
        'created_by': 'system',
      });
      
      _logger.info('Created ban record for user $userId with reason: $reason');
    } catch (e) {
      _logger.severe('Error creating ban record for user $userId: $e');
    }
  }

  /// Ban a user (admin function)
  static Future<void> banUser(String userId, String reason, {String? adminId}) async {
    try {
      await _firestore.collection('user_bans').add({
        'userId': userId,
        'reason': reason,
        'banned_at': FieldValue.serverTimestamp(),
        'active': true,
        'created_by': adminId ?? 'admin',
      });
      
      _logger.info('User $userId banned by ${adminId ?? 'admin'} with reason: $reason');
    } catch (e) {
      _logger.severe('Error banning user $userId: $e');
      rethrow;
    }
  }

  /// Unban a user (admin function)
  static Future<void> unbanUser(String userId, {String? adminId}) async {
    try {
      final banQuery = await _firestore
          .collection('user_bans')
          .where('userId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in banQuery.docs) {
        batch.update(doc.reference, {
          'active': false,
          'unbanned_at': FieldValue.serverTimestamp(),
          'unbanned_by': adminId ?? 'admin',
        });
      }
      
      await batch.commit();
      _logger.info('User $userId unbanned by ${adminId ?? 'admin'}');
    } catch (e) {
      _logger.severe('Error unbanning user $userId: $e');
      rethrow;
    }
  }
}