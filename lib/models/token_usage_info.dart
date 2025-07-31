/// Model for comprehensive token usage information
/// Used by TokenLimitService to provide real-time usage data
class TokenUsageInfo {
  final String userId;
  final int tokensUsed;
  final int tokenLimit;
  final int remainingTokens;
  final DateTime resetTime;
  final String userType;
  final double usagePercentage;
  final bool isLimitReached;
  final bool isWarningThreshold; // < 10% remaining

  TokenUsageInfo({
    required this.userId,
    required this.tokensUsed,
    required this.tokenLimit,
    required this.remainingTokens,
    required this.resetTime,
    required this.userType,
    required this.usagePercentage,
    required this.isLimitReached,
    required this.isWarningThreshold,
  });

  /// Create from DailyTokenUsage model
  factory TokenUsageInfo.fromDailyUsage({
    required String userId,
    required int tokensUsed,
    required int tokenLimit,
    required String userType,
    required DateTime resetTime,
  }) {
    final remaining = (tokenLimit - tokensUsed).clamp(0, tokenLimit);
    final percentage = tokenLimit > 0 ? tokensUsed / tokenLimit : 0.0;
    
    return TokenUsageInfo(
      userId: userId,
      tokensUsed: tokensUsed,
      tokenLimit: tokenLimit,
      remainingTokens: remaining,
      resetTime: resetTime,
      userType: userType,
      usagePercentage: percentage,
      isLimitReached: tokensUsed >= tokenLimit,
      isWarningThreshold: percentage > 0.9,
    );
  }

  /// Create empty usage info for new users
  factory TokenUsageInfo.empty({
    required String userId,
    required int tokenLimit,
    required String userType,
    required DateTime resetTime,
  }) {
    return TokenUsageInfo(
      userId: userId,
      tokensUsed: 0,
      tokenLimit: tokenLimit,
      remainingTokens: tokenLimit,
      resetTime: resetTime,
      userType: userType,
      usagePercentage: 0.0,
      isLimitReached: false,
      isWarningThreshold: false,
    );
  }

  /// Copy with updated values - recalculates derived values
  TokenUsageInfo copyWith({
    String? userId,
    int? tokensUsed,
    int? tokenLimit,
    DateTime? resetTime,
    String? userType,
  }) {
    final newTokensUsed = tokensUsed ?? this.tokensUsed;
    final newTokenLimit = tokenLimit ?? this.tokenLimit;
    
    return TokenUsageInfo.fromDailyUsage(
      userId: userId ?? this.userId,
      tokensUsed: newTokensUsed,
      tokenLimit: newTokenLimit,
      userType: userType ?? this.userType,
      resetTime: resetTime ?? this.resetTime,
    );
  }

  @override
  String toString() {
    return 'TokenUsageInfo(userId: $userId, tokensUsed: $tokensUsed, tokenLimit: $tokenLimit, remainingTokens: $remainingTokens, userType: $userType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TokenUsageInfo &&
        other.userId == userId &&
        other.tokensUsed == tokensUsed &&
        other.tokenLimit == tokenLimit &&
        other.userType == userType;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
        tokensUsed.hashCode ^
        tokenLimit.hashCode ^
        userType.hashCode;
  }
}