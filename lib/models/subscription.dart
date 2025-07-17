import 'package:cloud_firestore/cloud_firestore.dart';

class Subscription {
  final bool isTrialActive;
  final DateTime trialStartDate;
  final String plan; // 'trial', 'basic', 'premium'
  final int gptQueriesUsed;
  final int videoMinutesUsed;
  final DateTime lastResetDate;

  Subscription({
    required this.isTrialActive,
    required this.trialStartDate,
    required this.plan,
    required this.gptQueriesUsed,
    required this.videoMinutesUsed,
    required this.lastResetDate,
  });

  factory Subscription.fromMap(Map<String, dynamic> data) {
    return Subscription(
      isTrialActive: data['isTrialActive'] ?? false,
      trialStartDate: (data['trialStartDate'] as Timestamp).toDate(),
      plan: data['plan'] ?? 'trial',
      gptQueriesUsed: data['gptQueriesUsed'] ?? 0,
      videoMinutesUsed: data['videoMinutesUsed'] ?? 0,
      lastResetDate: (data['lastResetDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'isTrialActive': isTrialActive,
      'trialStartDate': Timestamp.fromDate(trialStartDate),
      'plan': plan,
      'gptQueriesUsed': gptQueriesUsed,
      'videoMinutesUsed': videoMinutesUsed,
      'lastResetDate': Timestamp.fromDate(lastResetDate),
    };
  }
}
