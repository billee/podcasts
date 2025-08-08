# Historical Usage Service Usage Guide

This document provides examples and usage patterns for the Historical Usage Service and Monthly Aggregation Service.

## Overview

The Historical Usage Service provides functionality for:
- Aggregating daily token usage into monthly historical records
- Migrating data from daily usage to historical collections
- Calculating monthly statistics and reports
- Managing data retention and cleanup

## Basic Usage Examples

### 1. Aggregate Monthly Usage for a Specific User

```dart
import 'package:kapwa_companion_basic/services/historical_usage_service.dart';

// Aggregate usage for a specific user and month
final history = await HistoricalUsageService.aggregateMonthlyUsage(
  userId: 'user123',
  year: 2024,
  month: 1,
);

if (history != null) {
  print('Total tokens used: ${history.totalMonthlyTokens}');
  print('Average daily usage: ${history.averageDailyUsage}');
  print('Peak usage day: ${history.peakUsageDate}');
}
```

### 2. Get User's Historical Usage

```dart
// Get all historical data for a user
final userHistory = await HistoricalUsageService.getUserHistoricalUsage(
  userId: 'user123',
);

// Get limited historical data (last 6 months)
final recentHistory = await HistoricalUsageService.getUserHistoricalUsage(
  userId: 'user123',
  limitMonths: 6,
);

for (final record in recentHistory) {
  print('${record.displayPeriod}: ${record.totalMonthlyTokens} tokens');
}
```

### 3. Calculate Monthly Statistics

```dart
// Get statistics for all users in a specific month
final stats = await HistoricalUsageService.calculateMonthlyStatistics(
  year: 2024,
  month: 1,
);

print('Total users: ${stats['totalUsers']}');
print('Total tokens: ${stats['totalTokens']}');
print('Average tokens per user: ${stats['averageTokensPerUser']}');
print('Trial users: ${stats['trialUsers']}');
print('Subscribed users: ${stats['subscribedUsers']}');
```

### 4. Generate User Usage Report

```dart
// Generate detailed report for a specific user
final report = await HistoricalUsageService.generateUserUsageReport(
  userId: 'user123',
  startYear: 2024,
  startMonth: 1,
  endYear: 2024,
  endMonth: 6,
);

print('User: ${report['userId']}');
print('Total months: ${report['totalMonths']}');
print('Total tokens: ${report['totalTokens']}');
print('Peak month: ${report['peakMonth']} (${report['peakMonthTokens']} tokens)');

// Access monthly breakdown
final breakdown = report['monthlyBreakdown'] as List<Map<String, dynamic>>;
for (final month in breakdown) {
  print('${month['monthName']} ${month['year']}: ${month['totalTokens']} tokens');
}
```

## Monthly Aggregation Service

### 1. Perform Monthly Aggregation

```dart
import 'package:kapwa_companion_basic/services/monthly_aggregation_service.dart';

// Aggregate data for the previous month (typically run monthly)
final result = await MonthlyAggregationService.performMonthlyAggregation();

if (result['success']) {
  print('Aggregation completed: ${result['migratedUsers']} users processed');
  print('Statistics: ${result['statistics']}');
} else {
  print('Aggregation failed: ${result['error']}');
}
```

### 2. Aggregate Specific Month

```dart
// Aggregate data for a specific month (useful for backfilling)
final result = await MonthlyAggregationService.performAggregationForMonth(
  year: 2024,
  month: 1,
);

print('Processed ${result['migratedUsers']} users for January 2024');
```

### 3. Backfill Historical Data

```dart
// Backfill historical data for the last 12 months
final results = await MonthlyAggregationService.backfillHistoricalData(
  months: 12,
);

int totalUsers = 0;
for (final result in results) {
  if (result['success']) {
    totalUsers += result['migratedUsers'] as int;
  }
}

print('Backfill completed: $totalUsers total user-months processed');
```

### 4. Check Aggregation Status

```dart
// Check which months have been aggregated
final status = await MonthlyAggregationService.getAggregationStatus(
  months: 6,
);

for (final monthStatus in status) {
  final hasData = monthStatus['hasData'] as bool;
  final monthName = monthStatus['monthName'] as String;
  final year = monthStatus['year'] as int;
  
  if (hasData) {
    print('$monthName $year: ${monthStatus['userCount']} users, ${monthStatus['totalTokens']} tokens');
  } else {
    print('$monthName $year: No data');
  }
}
```

## Admin Dashboard Integration

### 1. Get Historical Data with Filtering

```dart
// Get historical data for admin dashboard with filtering
final adminData = await HistoricalUsageService.getHistoricalDataForAdmin(
  userType: 'trial', // Filter by user type
  startYear: 2024,
  startMonth: 1,
  endYear: 2024,
  endMonth: 6,
  limit: 100,
);

final records = adminData['records'] as List<TokenUsageHistory>;
final hasMore = adminData['hasMore'] as bool;

print('Retrieved ${records.length} records');
if (hasMore) {
  print('More records available');
}
```

### 2. Get Top Users by Usage

```dart
// Get top 10 users by token usage for a specific month
final topUsers = await HistoricalUsageService.getTopUsersByUsage(
  year: 2024,
  month: 1,
  limit: 10,
  userType: 'subscribed', // Optional filter
);

for (final user in topUsers) {
  print('Rank ${user['rank']}: ${user['userId']} - ${user['totalTokens']} tokens');
}
```

## Data Maintenance

### 1. Clean Up Old Data

```dart
// Clean up historical data older than 12 months
final deletedCount = await HistoricalUsageService.cleanupOldHistoricalData(
  retentionMonths: 12,
);

print('Cleaned up $deletedCount old historical records');
```

### 2. Real-time Updates

The service automatically updates historical data when daily usage changes through the `updateCurrentMonthHistory` method, which is called from `TokenLimitService.recordTokenUsage()`.

```dart
// This is called automatically when recording token usage
await HistoricalUsageService.updateCurrentMonthHistory(
  userId: userId,
  dailyUsage: dailyUsageRecord,
);
```

## Scheduled Tasks

For production use, you should set up scheduled tasks to:

1. **Monthly Aggregation**: Run `performMonthlyAggregation()` at the beginning of each month
2. **Data Cleanup**: Run `cleanupOldHistoricalData()` monthly to maintain database performance
3. **Status Monitoring**: Periodically check `getAggregationStatus()` to ensure data integrity

### Example Cron Schedule

```bash
# Run monthly aggregation on the 1st of each month at 2 AM
0 2 1 * * /path/to/monthly_aggregation_script

# Run data cleanup on the 15th of each month at 3 AM
0 3 15 * * /path/to/cleanup_script
```

## Error Handling

All service methods include comprehensive error handling and logging. They return sensible defaults on errors to prevent breaking the application:

```dart
try {
  final history = await HistoricalUsageService.getUserHistoricalUsage(
    userId: userId,
  );
  // Process history data
} catch (e) {
  // Service methods handle errors internally and return empty results
  // Additional error handling can be added here if needed
  print('Error getting user history: $e');
}
```

## Performance Considerations

1. **Batch Processing**: Use `migrateMonthlyDataForAllUsers()` for batch processing rather than individual user aggregation
2. **Pagination**: Use the `limit` and `startAfter` parameters in admin queries for large datasets
3. **Indexing**: Ensure proper Firestore indexes are configured (see `firestore.indexes.json`)
4. **Caching**: Consider caching frequently accessed historical data in your application layer

## Requirements Satisfied

This implementation satisfies the following requirements:

- **6.2**: Monthly usage aggregation system for historical data ✅
- **6.5**: Data migration from daily usage to monthly history ✅  
- **6.6**: Historical data storage for at least 12 months ✅

The service provides comprehensive functionality for managing historical token usage data, supporting both real-time updates and batch processing for admin reporting and analytics.