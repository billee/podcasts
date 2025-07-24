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
    final subscription = Subscription(
      isTrialActive: true,
      trialStartDate: DateTime.now(),
      plan: 'trial',
      gptQueriesUsed: 0,
      videoMinutesUsed: 0,
      lastResetDate: DateTime.now(),
    );

    await _firestore.collection('users').doc(userId).set({
      ...userProfile,
      'subscription': subscription.toFirestore(),
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
