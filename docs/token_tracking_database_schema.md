# Token Tracking Database Schema

This document describes the Firestore database schema for the daily token limits feature.

## Collections Overview

### 1. daily_token_usage Collection

**Purpose**: Track real-time daily token usage for each user.

**Document ID Format**: `{userId}_{date}` (e.g., `user123_2024-01-15`)

**Schema**:
```json
{
  "userId": "string",           // Firebase Auth user ID
  "date": "string",             // YYYY-MM-DD format
  "tokensUsed": "number",       // Current tokens used today
  "tokenLimit": "number",       // Daily limit for this user type
  "userType": "string",         // 'trial' or 'subscribed'
  "lastUpdated": "timestamp",   // Last time usage was updated
  "resetAt": "timestamp"        // When this day's limit will reset
}
```

**Example Document**:
```json
{
  "userId": "abc123def456",
  "date": "2024-01-15",
  "tokensUsed": 1250,
  "tokenLimit": 10000,
  "userType": "trial",
  "lastUpdated": "2024-01-15T14:30:00Z",
  "resetAt": "2024-01-16T00:00:00Z"
}
```

**Key Features**:
- One document per user per day
- Real-time updates as users send messages
- Automatic cleanup after daily reset
- Efficient queries by user and date

### 2. token_usage_history Collection

**Purpose**: Store monthly aggregated usage data for reporting and analytics.

**Document ID Format**: `{userId}_{year}_{month}` (e.g., `user123_2024_01`)

**Schema**:
```json
{
  "userId": "string",                    // Firebase Auth user ID
  "year": "number",                      // Year (e.g., 2024)
  "month": "number",                     // Month 1-12
  "dailyUsage": "map",                   // Day -> tokens used
  "totalMonthlyTokens": "number",        // Sum of all daily usage
  "averageDailyUsage": "number",         // Average tokens per day
  "peakUsageDate": "string",             // Day with highest usage (DD format)
  "peakUsageTokens": "number",           // Token count for peak day
  "userType": "string",                  // 'trial' or 'subscribed'
  "createdAt": "timestamp",              // When record was created
  "updatedAt": "timestamp"               // Last update time
}
```

**Example Document**:
```json
{
  "userId": "abc123def456",
  "year": 2024,
  "month": 1,
  "dailyUsage": {
    "01": 850,
    "02": 1200,
    "03": 0,
    "04": 2100,
    "05": 1750
  },
  "totalMonthlyTokens": 5900,
  "averageDailyUsage": 1180.0,
  "peakUsageDate": "04",
  "peakUsageTokens": 2100,
  "userType": "trial",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-05T23:59:59Z"
}
```

**Key Features**:
- One document per user per month
- Aggregated from daily usage records
- Supports 12+ months of historical data
- Optimized for admin dashboard queries

## Security Rules

### Daily Token Usage Rules
- Users can only read/write their own usage data
- Document ID must match user ID pattern
- Data validation ensures proper structure
- Admin users can read all usage data

### Token Usage History Rules
- Users can only read their own historical data
- Write access restricted to system/admin operations
- Prevents direct client manipulation of historical data
- Admin users have full read/write access

## Database Indexes

### Daily Token Usage Indexes
1. **userId + date (desc)**: Get recent usage for a user
2. **userId + lastUpdated (desc)**: Get latest updates for a user
3. **userType + date (desc)**: Admin queries by user type
4. **date + tokensUsed (desc)**: Find high usage days

### Token Usage History Indexes
1. **userId + year (desc) + month (desc)**: Get user's historical data
2. **userType + year (desc) + month (desc)**: Admin queries by user type
3. **year (desc) + month (desc) + totalMonthlyTokens (desc)**: Top usage reports
4. **userId + updatedAt (desc)**: Get latest updates for a user

## Query Patterns

### Common User Queries
```dart
// Get today's usage for a user
await firestore
  .collection('daily_token_usage')
  .doc('${userId}_${today}')
  .get();

// Get user's last 3 months of history
await firestore
  .collection('token_usage_history')
  .where('userId', isEqualTo: userId)
  .orderBy('year', descending: true)
  .orderBy('month', descending: true)
  .limit(3)
  .get();
```

### Common Admin Queries
```dart
// Get all users' usage for a specific date
await firestore
  .collection('daily_token_usage')
  .where('date', isEqualTo: '2024-01-15')
  .orderBy('tokensUsed', descending: true)
  .get();

// Get monthly usage by user type
await firestore
  .collection('token_usage_history')
  .where('userType', isEqualTo: 'trial')
  .where('year', isEqualTo: 2024)
  .where('month', isEqualTo: 1)
  .get();
```

## Data Lifecycle

### Daily Usage Lifecycle
1. **Creation**: When user sends first message of the day
2. **Updates**: Real-time updates as user sends messages
3. **Reset**: Daily reset creates new document for next day
4. **Cleanup**: Old daily records archived to history collection

### Historical Data Lifecycle
1. **Creation**: Monthly aggregation from daily records
2. **Updates**: Updated as month progresses
3. **Retention**: Maintained for 12+ months
4. **Archival**: Older data can be moved to cold storage

## Performance Considerations

### Write Optimization
- Use transactions for atomic updates
- Batch writes when possible
- Implement retry logic for failed writes

### Read Optimization
- Use document listeners for real-time updates
- Cache frequently accessed data
- Implement pagination for large result sets

### Cost Optimization
- Minimize document reads with efficient queries
- Use composite indexes to avoid multiple queries
- Implement data retention policies

## Migration Strategy

### Initial Setup
1. Deploy security rules
2. Create database indexes
3. Initialize user documents as needed

### Data Migration
1. Existing users get default usage documents
2. Historical data can be backfilled if needed
3. Gradual rollout with feature flags

## Monitoring and Alerts

### Key Metrics
- Daily active users with token usage
- Average tokens per user per day
- Peak usage times and patterns
- Error rates for token tracking operations

### Alerts
- High error rates in token tracking
- Unusual usage patterns
- Database performance issues
- Security rule violations

## Backup and Recovery

### Backup Strategy
- Daily automated backups of both collections
- Point-in-time recovery capability
- Cross-region replication for disaster recovery

### Recovery Procedures
- Restore from backup if data corruption occurs
- Rebuild historical data from daily records if needed
- Implement data validation checks after recovery