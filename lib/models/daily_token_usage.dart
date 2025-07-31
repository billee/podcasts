import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for daily token usage tracking
/// Collection: daily_token_usage
/// Document ID: {userId}_{date} (e.g., "user123_2024-01-15")
class DailyTokenUsage {
  final String userId;
  final String date; // YYYY-MM-DD format
  final int tokensUsed;
  final int tokenLimit;
  final String userType; // 'trial' or 'subscribed'
  final DateTime lastUpdated;
  final DateTime resetAt;

  DailyTokenUsage({
    required this.userId,
    required this.date,
    required this.tokensUsed,
    required this.tokenLimit,
    required this.userType,
    required this.lastUpdated,
    required this.resetAt,
  });

  /// Create from Firestore document
  factory DailyTokenUsage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyTokenUsage(
      userId: data['userId'] as String,
      date: data['date'] as String,
      tokensUsed: data['tokensUsed'] as int,
      tokenLimit: data['tokenLimit'] as int,
      userType: data['userType'] as String,
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      resetAt: (data['resetAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': date,
      'tokensUsed': tokensUsed,
      'tokenLimit': tokenLimit,
      'userType': userType,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'resetAt': Timestamp.fromDate(resetAt),
    };
  }

  /// Create document ID for this usage record
  String get documentId => '${userId}_$date';

  /// Check if usage has reached the limit
  bool get isLimitReached => tokensUsed >= tokenLimit;

  /// Get remaining tokens
  int get remainingTokens => (tokenLimit - tokensUsed).clamp(0, tokenLimit);

  /// Get usage percentage (0.0 to 1.0)
  double get usagePercentage => tokenLimit > 0 ? tokensUsed / tokenLimit : 0.0;

  /// Check if user is in warning threshold (< 10% remaining)
  bool get isWarningThreshold => usagePercentage > 0.9;

  /// Copy with updated values
  DailyTokenUsage copyWith({
    String? userId,
    String? date,
    int? tokensUsed,
    int? tokenLimit,
    String? userType,
    DateTime? lastUpdated,
    DateTime? resetAt,
  }) {
    return DailyTokenUsage(
      userId: userId ?? this.userId,
      date: date ?? this.date,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      tokenLimit: tokenLimit ?? this.tokenLimit,
      userType: userType ?? this.userType,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      resetAt: resetAt ?? this.resetAt,
    );
  }

  @override
  String toString() {
    return 'DailyTokenUsage(userId: $userId, date: $date, tokensUsed: $tokensUsed, tokenLimit: $tokenLimit, userType: $userType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyTokenUsage &&
        other.userId == userId &&
        other.date == date &&
        other.tokensUsed == tokensUsed &&
        other.tokenLimit == tokenLimit &&
        other.userType == userType;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
        date.hashCode ^
        tokensUsed.hashCode ^
        tokenLimit.hashCode ^
        userType.hashCode;
  }
}