import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import '../models/daily_token_usage.dart';
import '../models/token_usage_history.dart';
import '../core/config.dart';

/// Service for managing historical token usage tracking and aggregation
/// Handles monthly usage aggregation, data migration, and historical reporting
class HistoricalUsageService {
  static final Logger _logger = Logger('HistoricalUsageService');
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // For testing purposes - allow dependency injection
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }

  /// Aggregate daily usage data into monthly history for a specific user and month
  /// This method should be called at the end of each month or when historical data is needed
  static Future<TokenUsageHistory?> aggregateMonthlyUsage({
    required String userId,
    required int year,
    required int month,
  }) async {
    try {
      _logger.info('Starting monthly aggregation for user $userId, $year-$month');

      // Get all daily usage records for the specified month
      final dailyRecords = await _getDailyUsageForMonth(userId, year, month);
      
      if (dailyRecords.isEmpty) {
        _logger.info('No daily usage records found for user $userId in $year-$month');
        return null;
      }

      // Get user type from the most recent record
      final userType = dailyRecords.isNotEmpty ? dailyRecords.first.userType : 'trial';

      // Convert daily records to the format expected by TokenUsageHistory
      final dailyRecordMaps = dailyRecords.map((record) => {
        'date': record.date,
        'tokensUsed': record.tokensUsed,
      }).toList();

      // Create historical record from daily data
      final history = TokenUsageHistory.fromDailyRecords(
        userId: userId,
        year: year,
        month: month,
        dailyRecords: dailyRecordMaps,
        userType: userType,
      );

      // Save to historical collection
      await _saveHistoricalRecord(history);

      _logger.info('Monthly aggregation completed for user $userId: ${history.totalMonthlyTokens} tokens');
      return history;
    } catch (e) {
      _logger.severe('Error aggregating monthly usage for user $userId: $e');
      return null;
    }
  }

  /// Migrate daily usage data to historical collection for all users for a specific month
  /// This is useful for batch processing and ensuring all users have historical data
  static Future<int> migrateMonthlyDataForAllUsers({
    required int year,
    required int month,
  }) async {
    try {
      _logger.info('Starting monthly data migration for all users: $year-$month');

      // Get all unique user IDs from daily usage for the specified month
      final userIds = await _getUserIdsForMonth(year, month);
      
      int successCount = 0;
      int errorCount = 0;

      for (final userId in userIds) {
        try {
          final history = await aggregateMonthlyUsage(
            userId: userId,
            year: year,
            month: month,
          );
          
          if (history != null) {
            successCount++;
          }
        } catch (e) {
          _logger.warning('Error migrating data for user $userId: $e');
          errorCount++;
        }
      }

      _logger.info('Monthly migration completed: $successCount successful, $errorCount errors');
      return successCount;
    } catch (e) {
      _logger.severe('Error during monthly data migration: $e');
      return 0;
    }
  }

  /// Get monthly usage history for a specific user
  /// Returns historical data ordered by year and month (most recent first)
  static Future<List<TokenUsageHistory>> getUserHistoricalUsage({
    required String userId,
    int? limitMonths,
  }) async {
    try {
      Query query = _firestore
          .collection('token_usage_history')
          .where('userId', isEqualTo: userId)
          .orderBy('year', descending: true)
          .orderBy('month', descending: true);

      if (limitMonths != null) {
        query = query.limit(limitMonths);
      }

      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => TokenUsageHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.severe('Error getting user historical usage for $userId: $e');
      return [];
    }
  }

  /// Get monthly usage totals for all users for a specific month
  /// Useful for admin dashboard reporting
  static Future<List<TokenUsageHistory>> getMonthlyUsageForAllUsers({
    required int year,
    required int month,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('token_usage_history')
          .where('year', isEqualTo: year)
          .where('month', isEqualTo: month)
          .orderBy('totalMonthlyTokens', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TokenUsageHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.severe('Error getting monthly usage for all users: $e');
      return [];
    }
  }

  /// Calculate monthly totals and averages for a specific month across all users
  /// Returns aggregated statistics for admin reporting
  static Future<Map<String, dynamic>> calculateMonthlyStatistics({
    required int year,
    required int month,
  }) async {
    try {
      final allUsersData = await getMonthlyUsageForAllUsers(year: year, month: month);
      
      if (allUsersData.isEmpty) {
        return {
          'totalUsers': 0,
          'totalTokens': 0,
          'averageTokensPerUser': 0.0,
          'trialUsers': 0,
          'subscribedUsers': 0,
          'trialTokens': 0,
          'subscribedTokens': 0,
          'peakUsageUser': null,
          'peakUsageTokens': 0,
        };
      }

      int totalTokens = 0;
      int trialUsers = 0;
      int subscribedUsers = 0;
      int trialTokens = 0;
      int subscribedTokens = 0;
      
      TokenUsageHistory? peakUser;
      int peakTokens = 0;

      for (final userData in allUsersData) {
        totalTokens += userData.totalMonthlyTokens;
        
        if (userData.userType == 'trial') {
          trialUsers++;
          trialTokens += userData.totalMonthlyTokens;
        } else {
          subscribedUsers++;
          subscribedTokens += userData.totalMonthlyTokens;
        }

        if (userData.totalMonthlyTokens > peakTokens) {
          peakTokens = userData.totalMonthlyTokens;
          peakUser = userData;
        }
      }

      final averageTokensPerUser = allUsersData.isNotEmpty 
          ? totalTokens / allUsersData.length 
          : 0.0;

      return {
        'totalUsers': allUsersData.length,
        'totalTokens': totalTokens,
        'averageTokensPerUser': averageTokensPerUser,
        'trialUsers': trialUsers,
        'subscribedUsers': subscribedUsers,
        'trialTokens': trialTokens,
        'subscribedTokens': subscribedTokens,
        'peakUsageUser': peakUser?.userId,
        'peakUsageTokens': peakTokens,
      };
    } catch (e) {
      _logger.severe('Error calculating monthly statistics: $e');
      return {};
    }
  }

  /// Get historical usage data for admin dashboard with filtering options
  /// Returns paginated results with optional filtering by user type and date range
  static Future<Map<String, dynamic>> getHistoricalDataForAdmin({
    String? userType,
    int? startYear,
    int? startMonth,
    int? endYear,
    int? endMonth,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore.collection('token_usage_history');

      // Apply filters
      if (userType != null) {
        query = query.where('userType', isEqualTo: userType);
      }

      if (startYear != null) {
        query = query.where('year', isGreaterThanOrEqualTo: startYear);
      }

      if (endYear != null) {
        query = query.where('year', isLessThanOrEqualTo: endYear);
      }

      // Order by year and month (most recent first)
      query = query.orderBy('year', descending: true)
                  .orderBy('month', descending: true)
                  .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final records = snapshot.docs
          .map((doc) => TokenUsageHistory.fromFirestore(doc))
          .toList();

      // Apply month filtering (Firestore doesn't support range queries on multiple fields efficiently)
      List<TokenUsageHistory> filteredRecords = records;
      if (startMonth != null || endMonth != null) {
        filteredRecords = records.where((record) {
          if (startYear != null && startMonth != null) {
            final recordDate = DateTime(record.year, record.month);
            final startDate = DateTime(startYear, startMonth);
            if (recordDate.isBefore(startDate)) return false;
          }
          
          if (endYear != null && endMonth != null) {
            final recordDate = DateTime(record.year, record.month);
            final endDate = DateTime(endYear, endMonth);
            if (recordDate.isAfter(endDate)) return false;
          }
          
          return true;
        }).toList();
      }

      return {
        'records': filteredRecords,
        'hasMore': snapshot.docs.length == limit,
        'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        'totalReturned': filteredRecords.length,
      };
    } catch (e) {
      _logger.severe('Error getting historical data for admin: $e');
      return {
        'records': <TokenUsageHistory>[],
        'hasMore': false,
        'lastDocument': null,
        'totalReturned': 0,
      };
    }
  }

  /// Generate usage report for a specific user over a date range
  /// Useful for detailed user analysis in admin dashboard
  static Future<Map<String, dynamic>> generateUserUsageReport({
    required String userId,
    int? startYear,
    int? startMonth,
    int? endYear,
    int? endMonth,
  }) async {
    try {
      // Get user's historical data
      final userHistory = await getUserHistoricalUsage(userId: userId);
      
      // Filter by date range if specified
      List<TokenUsageHistory> filteredHistory = userHistory;
      if (startYear != null || endYear != null) {
        filteredHistory = userHistory.where((record) {
          if (startYear != null && startMonth != null) {
            final recordDate = DateTime(record.year, record.month);
            final startDate = DateTime(startYear, startMonth);
            if (recordDate.isBefore(startDate)) return false;
          }
          
          if (endYear != null && endMonth != null) {
            final recordDate = DateTime(record.year, record.month);
            final endDate = DateTime(endYear, endMonth);
            if (recordDate.isAfter(endDate)) return false;
          }
          
          return true;
        }).toList();
      }

      if (filteredHistory.isEmpty) {
        return {
          'userId': userId,
          'totalMonths': 0,
          'totalTokens': 0,
          'averageMonthlyTokens': 0.0,
          'peakMonth': null,
          'peakMonthTokens': 0,
          'userType': 'unknown',
          'monthlyBreakdown': <Map<String, dynamic>>[],
        };
      }

      // Calculate summary statistics
      final totalTokens = filteredHistory.fold(0, (sum, record) => sum + record.totalMonthlyTokens);
      final averageMonthlyTokens = totalTokens / filteredHistory.length;
      
      // Find peak month
      final peakRecord = filteredHistory.reduce((a, b) => 
          a.totalMonthlyTokens > b.totalMonthlyTokens ? a : b);

      // Create monthly breakdown
      final monthlyBreakdown = filteredHistory.map((record) => {
        'year': record.year,
        'month': record.month,
        'monthName': record.monthName,
        'totalTokens': record.totalMonthlyTokens,
        'averageDailyTokens': record.averageDailyUsage,
        'activeDays': record.activeDays,
        'peakDayTokens': record.peakUsageTokens,
        'peakDate': record.peakUsageDate,
        'userType': record.userType,
      }).toList();

      return {
        'userId': userId,
        'totalMonths': filteredHistory.length,
        'totalTokens': totalTokens,
        'averageMonthlyTokens': averageMonthlyTokens,
        'peakMonth': '${peakRecord.monthName} ${peakRecord.year}',
        'peakMonthTokens': peakRecord.totalMonthlyTokens,
        'userType': filteredHistory.first.userType,
        'monthlyBreakdown': monthlyBreakdown,
        'reportGeneratedAt': AppConfig.currentDateTime.toIso8601String(),
      };
    } catch (e) {
      _logger.severe('Error generating user usage report for $userId: $e');
      return {
        'userId': userId,
        'error': e.toString(),
        'reportGeneratedAt': AppConfig.currentDateTime.toIso8601String(),
      };
    }
  }

  /// Get top users by token usage for a specific month
  /// Useful for identifying heavy users and usage patterns
  static Future<List<Map<String, dynamic>>> getTopUsersByUsage({
    required int year,
    required int month,
    int limit = 10,
    String? userType,
  }) async {
    try {
      Query query = _firestore
          .collection('token_usage_history')
          .where('year', isEqualTo: year)
          .where('month', isEqualTo: month);

      if (userType != null) {
        query = query.where('userType', isEqualTo: userType);
      }

      query = query.orderBy('totalMonthlyTokens', descending: true).limit(limit);

      final snapshot = await query.get();
      final records = snapshot.docs
          .map((doc) => TokenUsageHistory.fromFirestore(doc))
          .toList();

      return records.map((record) => {
        'userId': record.userId,
        'totalTokens': record.totalMonthlyTokens,
        'averageDailyTokens': record.averageDailyUsage,
        'activeDays': record.activeDays,
        'peakDayTokens': record.peakUsageTokens,
        'userType': record.userType,
        'rank': records.indexOf(record) + 1,
      }).toList();
    } catch (e) {
      _logger.severe('Error getting top users by usage: $e');
      return [];
    }
  }

  /// Clean up old historical data beyond the retention period (12 months)
  /// This helps maintain database performance and comply with data retention policies
  static Future<int> cleanupOldHistoricalData({
    int retentionMonths = 12,
  }) async {
    try {
      final cutoffDate = AppConfig.currentDateTime.subtract(Duration(days: retentionMonths * 30));
      final cutoffYear = cutoffDate.year;
      final cutoffMonth = cutoffDate.month;

      _logger.info('Cleaning up historical data older than $cutoffYear-$cutoffMonth');

      // Query for old records
      final oldRecords = await _firestore
          .collection('token_usage_history')
          .where('year', isLessThan: cutoffYear)
          .get();

      // Also get records from the cutoff year that are older than cutoff month
      final cutoffYearOldRecords = await _firestore
          .collection('token_usage_history')
          .where('year', isEqualTo: cutoffYear)
          .where('month', isLessThan: cutoffMonth)
          .get();

      final allOldRecords = [...oldRecords.docs, ...cutoffYearOldRecords.docs];
      
      int deletedCount = 0;
      
      // Delete old records in batches
      const batchSize = 500;
      for (int i = 0; i < allOldRecords.length; i += batchSize) {
        final batch = _firestore.batch();
        final endIndex = (i + batchSize < allOldRecords.length) 
            ? i + batchSize 
            : allOldRecords.length;
        
        for (int j = i; j < endIndex; j++) {
          batch.delete(allOldRecords[j].reference);
          deletedCount++;
        }
        
        await batch.commit();
      }

      _logger.info('Cleanup completed: $deletedCount old historical records deleted');
      return deletedCount;
    } catch (e) {
      _logger.severe('Error during historical data cleanup: $e');
      return 0;
    }
  }

  /// Update or create historical record for current month when daily usage changes
  /// This ensures historical data is kept up-to-date in real-time
  static Future<void> updateCurrentMonthHistory({
    required String userId,
    required DailyTokenUsage dailyUsage,
  }) async {
    try {
      final date = DateTime.parse(dailyUsage.date);
      final year = date.year;
      final month = date.month;

      // Check if we're updating the current month or a past month
      final now = AppConfig.currentDateTime;
      final isCurrentMonth = year == now.year && month == now.month;

      if (!isCurrentMonth) {
        // For past months, we should aggregate the complete month
        await aggregateMonthlyUsage(userId: userId, year: year, month: month);
        return;
      }

      // For current month, update the running total
      final historyDocId = '${userId}_${year}_${month.toString().padLeft(2, '0')}';
      final historyRef = _firestore.collection('token_usage_history').doc(historyDocId);

      // Get existing history or create new one
      final existingDoc = await historyRef.get();
      
      if (existingDoc.exists) {
        // Update existing record
        await _updateExistingHistoryRecord(historyRef, dailyUsage);
      } else {
        // Create new record for current month
        await _createNewHistoryRecord(historyRef, userId, year, month, dailyUsage);
      }

    } catch (e) {
      _logger.severe('Error updating current month history: $e');
    }
  }

  // Private helper methods

  /// Get all daily usage records for a specific user and month
  static Future<List<DailyTokenUsage>> _getDailyUsageForMonth(
    String userId, 
    int year, 
    int month,
  ) async {
    final startDate = '${year}-${month.toString().padLeft(2, '0')}-01';
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final endDate = '${nextYear}-${nextMonth.toString().padLeft(2, '0')}-01';

    final snapshot = await _firestore
        .collection('daily_token_usage')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThan: endDate)
        .orderBy('date')
        .get();

    return snapshot.docs
        .map((doc) => DailyTokenUsage.fromFirestore(doc))
        .toList();
  }

  /// Get all unique user IDs that have usage data for a specific month
  static Future<List<String>> _getUserIdsForMonth(int year, int month) async {
    final startDate = '${year}-${month.toString().padLeft(2, '0')}-01';
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final endDate = '${nextYear}-${nextMonth.toString().padLeft(2, '0')}-01';

    final snapshot = await _firestore
        .collection('daily_token_usage')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThan: endDate)
        .get();

    final userIds = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      userIds.add(data['userId'] as String);
    }

    return userIds.toList();
  }

  /// Save historical record to Firestore
  static Future<void> _saveHistoricalRecord(TokenUsageHistory history) async {
    await _firestore
        .collection('token_usage_history')
        .doc(history.documentId)
        .set(history.toFirestore());
  }

  /// Update existing historical record with new daily usage
  static Future<void> _updateExistingHistoryRecord(
    DocumentReference historyRef,
    DailyTokenUsage dailyUsage,
  ) async {
    final existingDoc = await historyRef.get();
    final existingHistory = TokenUsageHistory.fromFirestore(existingDoc);
    
    // Update daily usage map
    final date = DateTime.parse(dailyUsage.date);
    final dayKey = date.day.toString().padLeft(2, '0');
    final updatedDailyUsage = Map<String, int>.from(existingHistory.dailyUsage);
    updatedDailyUsage[dayKey] = dailyUsage.tokensUsed;

    // Recalculate totals and averages
    final totalTokens = updatedDailyUsage.values.fold(0, (sum, tokens) => sum + tokens);
    final activeDays = updatedDailyUsage.values.where((tokens) => tokens > 0).length;
    final averageDaily = activeDays > 0 ? totalTokens / activeDays : 0.0;

    // Find peak usage
    String peakDate = '01';
    int peakTokens = 0;
    updatedDailyUsage.forEach((day, tokens) {
      if (tokens > peakTokens) {
        peakTokens = tokens;
        peakDate = day;
      }
    });

    // Update the record
    await historyRef.update({
      'dailyUsage': updatedDailyUsage,
      'totalMonthlyTokens': totalTokens,
      'averageDailyUsage': averageDaily,
      'peakUsageDate': peakDate,
      'peakUsageTokens': peakTokens,
      'userType': dailyUsage.userType,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Create new historical record for current month
  static Future<void> _createNewHistoryRecord(
    DocumentReference historyRef,
    String userId,
    int year,
    int month,
    DailyTokenUsage dailyUsage,
  ) async {
    final date = DateTime.parse(dailyUsage.date);
    final dayKey = date.day.toString().padLeft(2, '0');
    
    final dailyUsageMap = <String, int>{dayKey: dailyUsage.tokensUsed};
    
    final history = TokenUsageHistory(
      userId: userId,
      year: year,
      month: month,
      dailyUsage: dailyUsageMap,
      totalMonthlyTokens: dailyUsage.tokensUsed,
      averageDailyUsage: dailyUsage.tokensUsed.toDouble(),
      peakUsageDate: dayKey,
      peakUsageTokens: dailyUsage.tokensUsed,
      userType: dailyUsage.userType,
      createdAt: AppConfig.currentDateTime,
      updatedAt: AppConfig.currentDateTime,
    );

    await historyRef.set(history.toFirestore());
  }
}