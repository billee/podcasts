import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for monthly token usage history for reporting
/// Collection: token_usage_history
/// Document ID: {userId}_{year}_{month} (e.g., "user123_2024_01")
class TokenUsageHistory {
  final String userId;
  final int year;
  final int month;
  final Map<String, int> dailyUsage; // date -> tokens used (e.g., "01" -> 150)
  final int totalMonthlyTokens;
  final double averageDailyUsage;
  final String peakUsageDate; // Date with highest usage (DD format)
  final int peakUsageTokens; // Token count for peak day
  final String userType; // 'trial' or 'subscribed'
  final DateTime createdAt;
  final DateTime updatedAt;

  TokenUsageHistory({
    required this.userId,
    required this.year,
    required this.month,
    required this.dailyUsage,
    required this.totalMonthlyTokens,
    required this.averageDailyUsage,
    required this.peakUsageDate,
    required this.peakUsageTokens,
    required this.userType,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory TokenUsageHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TokenUsageHistory(
      userId: data['userId'] as String,
      year: data['year'] as int,
      month: data['month'] as int,
      dailyUsage: Map<String, int>.from(data['dailyUsage'] as Map),
      totalMonthlyTokens: data['totalMonthlyTokens'] as int,
      averageDailyUsage: (data['averageDailyUsage'] as num).toDouble(),
      peakUsageDate: data['peakUsageDate'] as String,
      peakUsageTokens: data['peakUsageTokens'] as int,
      userType: data['userType'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'year': year,
      'month': month,
      'dailyUsage': dailyUsage,
      'totalMonthlyTokens': totalMonthlyTokens,
      'averageDailyUsage': averageDailyUsage,
      'peakUsageDate': peakUsageDate,
      'peakUsageTokens': peakUsageTokens,
      'userType': userType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create document ID for this history record
  String get documentId => '${userId}_${year}_${month.toString().padLeft(2, '0')}';

  /// Get month name for display
  String get monthName {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  /// Get formatted month/year for display
  String get displayPeriod => '$monthName $year';

  /// Get number of active days (days with usage > 0)
  int get activeDays => dailyUsage.values.where((usage) => usage > 0).length;

  /// Get days in month (approximate, for percentage calculations)
  int get daysInMonth {
    final date = DateTime(year, month + 1, 0);
    return date.day;
  }

  /// Get usage percentage for the month (based on days used)
  double get monthlyUsagePercentage => daysInMonth > 0 ? activeDays / daysInMonth : 0.0;

  /// Create from daily usage records
  factory TokenUsageHistory.fromDailyRecords({
    required String userId,
    required int year,
    required int month,
    required List<Map<String, dynamic>> dailyRecords,
    required String userType,
  }) {
    final Map<String, int> dailyUsage = {};
    int totalTokens = 0;
    int peakTokens = 0;
    String peakDate = '01';

    for (final record in dailyRecords) {
      final date = record['date'] as String; // YYYY-MM-DD
      final tokens = record['tokensUsed'] as int;
      final day = date.split('-')[2]; // Extract DD part
      
      dailyUsage[day] = tokens;
      totalTokens += tokens;
      
      if (tokens > peakTokens) {
        peakTokens = tokens;
        peakDate = day;
      }
    }

    final averageDaily = dailyRecords.isNotEmpty ? totalTokens / dailyRecords.length : 0.0;
    final now = DateTime.now();

    return TokenUsageHistory(
      userId: userId,
      year: year,
      month: month,
      dailyUsage: dailyUsage,
      totalMonthlyTokens: totalTokens,
      averageDailyUsage: averageDaily,
      peakUsageDate: peakDate,
      peakUsageTokens: peakTokens,
      userType: userType,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Copy with updated values
  TokenUsageHistory copyWith({
    String? userId,
    int? year,
    int? month,
    Map<String, int>? dailyUsage,
    int? totalMonthlyTokens,
    double? averageDailyUsage,
    String? peakUsageDate,
    int? peakUsageTokens,
    String? userType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TokenUsageHistory(
      userId: userId ?? this.userId,
      year: year ?? this.year,
      month: month ?? this.month,
      dailyUsage: dailyUsage ?? this.dailyUsage,
      totalMonthlyTokens: totalMonthlyTokens ?? this.totalMonthlyTokens,
      averageDailyUsage: averageDailyUsage ?? this.averageDailyUsage,
      peakUsageDate: peakUsageDate ?? this.peakUsageDate,
      peakUsageTokens: peakUsageTokens ?? this.peakUsageTokens,
      userType: userType ?? this.userType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'TokenUsageHistory(userId: $userId, period: $displayPeriod, totalTokens: $totalMonthlyTokens, userType: $userType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TokenUsageHistory &&
        other.userId == userId &&
        other.year == year &&
        other.month == month &&
        other.userType == userType;
  }

  @override
  int get hashCode {
    return userId.hashCode ^ year.hashCode ^ month.hashCode ^ userType.hashCode;
  }
}