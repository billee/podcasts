// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kapwa_companion_basic/models/subscription.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUserProfile({
    required String userId,
    required String email,
    required Map<String, dynamic> userProfile,
  }) async {
    // No longer creating subscription data in user profile
    // Subscription data will be handled separately after email verification
    await _firestore.collection('users').doc(userId).update({
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<Subscription?> getSubscription(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return Subscription.fromMap(doc.data()!['subscription']);
    }
    return null;
  }
}
