import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'subscription_service.dart';
import '../core/config.dart';

enum UserStatus {
  unverified,
  trialUser,
  trialExpired,
  premiumSubscriber,
  cancelledSubscriber,
  freeUser
}

class UserStatusService {
  static final Logger _logger = Logger('UserStatusService');
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static FirebaseAuth _auth = FirebaseAuth.instance;

  // For testing purposes - allow dependency injection
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }

  static void setAuthInstance(FirebaseAuth auth) {
    _auth = auth;
  }

  /// Get current user status based on email verification, trial, and subscription state
  static Future<UserStatus> getUserStatus(String userId) async {
    try {
      // Get user document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return UserStatus.unverified;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final emailVerified = userData['emailVerified'] as bool? ?? false;
      final userEmail = userData['email'] as String?;

      // If email is not verified, user is unverified
      if (!emailVerified || userEmail == null) {
        return UserStatus.unverified;
      }

      // Check subscription status
      final subscriptionStatus = await SubscriptionService.getSubscriptionStatus(userId);
      
      switch (subscriptionStatus) {
        case SubscriptionStatus.active:
          return UserStatus.premiumSubscriber;
        case SubscriptionStatus.cancelled:
          return UserStatus.cancelledSubscriber;
        case SubscriptionStatus.trial:
          return UserStatus.trialUser;
        case SubscriptionStatus.trialExpired:
          return UserStatus.trialExpired;
        case SubscriptionStatus.expired:
          // Check if user had a subscription before
          final subscriptionDoc = await _firestore.collection('subscriptions').doc(userId).get();
          if (subscriptionDoc.exists) {
            final subscription = subscriptionDoc.data() as Map<String, dynamic>;
            final status = subscription['status'] as String?;
            if (status == 'cancelled' || status == 'expired') {
              return UserStatus.freeUser;
            }
          }
          return UserStatus.trialExpired;
      }
    } catch (e) {
      _logger.severe('Error getting user status: $e');
      return UserStatus.unverified;
    }
  }

  /// Update user status in Firestore
  static Future<void> updateUserStatus(String userId, UserStatus status) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': _statusToString(status),
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _logger.info('Updated user status for $userId to ${_statusToString(status)}');
    } catch (e) {
      _logger.severe('Error updating user status: $e');
    }
  }

  /// Handle status transition from unverified to trial user
  static Future<void> transitionToTrialUser(String userId) async {
    try {
      // Update email verification status and user status
      await _firestore.collection('users').doc(userId).update({
        'emailVerified': true,
        'emailVerifiedAt': FieldValue.serverTimestamp(),
        'status': 'Trial User',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      _logger.info('Transitioned user $userId from Unverified to Trial User');
    } catch (e) {
      _logger.severe('Error transitioning to trial user: $e');
    }
  }

  /// Handle status transition from trial to premium subscriber
  static Future<void> transitionToPremiumSubscriber(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'Premium Subscriber',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      _logger.info('Transitioned user $userId from Trial to Premium Subscriber');
    } catch (e) {
      _logger.severe('Error transitioning to premium subscriber: $e');
    }
  }

  /// Handle status transition when subscription is cancelled
  static Future<void> transitionToCancelledSubscriber(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'Cancelled Subscriber',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      _logger.info('Transitioned user $userId to Cancelled Subscriber');
    } catch (e) {
      _logger.severe('Error transitioning to cancelled subscriber: $e');
    }
  }

  /// Handle status transition when cancelled subscription expires
  static Future<void> transitionToFreeUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'Free User',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      _logger.info('Transitioned user $userId to Free User');
    } catch (e) {
      _logger.severe('Error transitioning to free user: $e');
    }
  }

  /// Handle status transition when trial expires without subscription
  static Future<void> transitionToTrialExpired(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'Trial Expired',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      _logger.info('Transitioned user $userId to Trial Expired');
    } catch (e) {
      _logger.severe('Error transitioning to trial expired: $e');
    }
  }

  /// Get user status display string
  static String getStatusDisplayString(UserStatus status) {
    switch (status) {
      case UserStatus.unverified:
        return 'Unverified';
      case UserStatus.trialUser:
        return 'Trial User';
      case UserStatus.trialExpired:
        return 'Trial Expired';
      case UserStatus.premiumSubscriber:
        return 'Premium Subscriber';
      case UserStatus.cancelledSubscriber:
        return 'Cancelled Subscriber';
      case UserStatus.freeUser:
        return 'Free User';
    }
  }

  /// Convert status enum to string
  static String _statusToString(UserStatus status) {
    switch (status) {
      case UserStatus.unverified:
        return 'Unverified';
      case UserStatus.trialUser:
        return 'Trial User';
      case UserStatus.trialExpired:
        return 'Trial Expired';
      case UserStatus.premiumSubscriber:
        return 'Premium Subscriber';
      case UserStatus.cancelledSubscriber:
        return 'Cancelled Subscriber';
      case UserStatus.freeUser:
        return 'Free User';
    }
  }

  /// Convert string to status enum
  static UserStatus _stringToStatus(String statusString) {
    switch (statusString) {
      case 'Unverified':
        return UserStatus.unverified;
      case 'Trial User':
        return UserStatus.trialUser;
      case 'Trial Expired':
        return UserStatus.trialExpired;
      case 'Premium Subscriber':
        return UserStatus.premiumSubscriber;
      case 'Cancelled Subscriber':
        return UserStatus.cancelledSubscriber;
      case 'Free User':
        return UserStatus.freeUser;
      default:
        return UserStatus.unverified;
    }
  }

  /// Check if user has premium access based on status
  static bool hasPremiumAccess(UserStatus status) {
    return status == UserStatus.trialUser || 
           status == UserStatus.premiumSubscriber ||
           status == UserStatus.cancelledSubscriber; // Cancelled users keep access until expiration
  }

  /// Get status progression for a user (for testing and analytics)
  static Future<List<Map<String, dynamic>>> getStatusHistory(String userId) async {
    try {
      // This would require a status_history collection in a real implementation
      // For now, we'll return the current status
      final currentStatus = await getUserStatus(userId);
      return [
        {
          'status': _statusToString(currentStatus),
          'timestamp': AppConfig.currentDateTime,
          'userId': userId,
        }
      ];
    } catch (e) {
      _logger.severe('Error getting status history: $e');
      return [];
    }
  }
}