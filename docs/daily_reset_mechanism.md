# Daily Reset Mechanism Documentation

## Overview

The daily reset mechanism automatically resets token limits for all users at a configured time each day. This ensures users get a fresh start with their daily token allowance and prevents token usage from carrying over between days.

## Components

### 1. DailyResetService

The core service that handles automated daily resets:

- **Location**: `lib/services/daily_reset_service.dart`
- **Purpose**: Manages scheduled daily resets and manual reset operations
- **Key Features**:
  - Timezone-aware reset scheduling
  - Automatic service lifecycle management
  - Comprehensive error handling and logging
  - Reset metadata tracking for monitoring

### 2. Configuration

Reset timing is configured in `lib/core/config.dart`:

```dart
// Daily reset configuration
static const String resetTimezone = 'UTC'; // Timezone for daily resets
static const int resetHour = 0; // Hour of day for reset (0-23)
static const int resetMinute = 0; // Minute of hour for reset (0-59)
```

### 3. Database Collections

#### daily_token_usage
Stores current day usage for each user:
- `userId`: User identifier
- `date`: Date in YYYY-MM-DD format (UTC)
- `tokensUsed`: Current token usage
- `tokenLimit`: Daily token limit
- `userType`: 'trial' or 'subscribed'
- `lastUpdated`: Last update timestamp
- `resetAt`: Next scheduled reset time

#### daily_reset_logs
Tracks reset operations for monitoring:
- `resetDate`: Date of reset (YYYY-MM-DD)
- `resetTimestamp`: Exact time of reset
- `processedUsers`: Number of users processed
- `newRecords`: Number of new records created
- `errors`: Number of errors encountered
- `timezone`: Timezone used for reset
- `resetHour`/`resetMinute`: Configured reset time
- `nextScheduledReset`: Next scheduled reset timestamp

## How It Works

### 1. Service Initialization

The service starts automatically when the app launches (configured in `main.dart`):

```dart
// Initialize DailyResetService for token limit management
DailyResetService.startService();
```

### 2. Reset Scheduling

- Calculates next reset time based on UTC timezone
- Uses `Timer` to schedule the reset operation
- Automatically reschedules after each reset completes

### 3. Reset Process

1. **Query Yesterday's Usage**: Finds all users who had token usage yesterday
2. **Process Each User**:
   - Determine current user type (trial/subscribed)
   - Get appropriate token limit
   - Create new daily usage record with zero tokens
   - Set next reset timestamp
3. **Handle Today's Records**: Reset any existing today records that are older than reset time
4. **Log Results**: Store comprehensive metadata about the reset operation

### 4. Error Handling

- Individual user failures don't stop the overall reset process
- Comprehensive logging for debugging
- Graceful degradation when services are unavailable
- Automatic retry scheduling if reset fails

## Timezone Handling

All date calculations use UTC to ensure consistency:

- Date strings are in YYYY-MM-DD format using UTC
- Reset times are calculated in UTC
- Database timestamps use UTC
- Prevents issues with daylight saving time changes

## Manual Reset

For testing or emergency situations, manual resets can be triggered:

```dart
await DailyResetService.performManualReset();
```

## Monitoring

Reset operations are logged in the `daily_reset_logs` collection with:
- Success/failure metrics
- Processing statistics
- Error counts
- Timing information

## Integration with TokenLimitService

The reset mechanism works seamlessly with the existing token limit system:

- Uses same date calculation methods
- Respects user subscription types
- Maintains token limit configurations
- Preserves existing usage tracking logic

## Testing

Comprehensive test coverage includes:

- Service lifecycle management
- Reset scheduling logic
- Database operations
- Error handling scenarios
- Timezone calculations
- Integration with token limit service

Test files:
- `test/unit/services/daily_reset_service_test.dart`
- `test/integration/daily_reset_integration_test.dart`

## Configuration Changes

To modify reset timing:

1. Update constants in `lib/core/config.dart`
2. Restart the application
3. Service will automatically use new timing for next reset

Example - Reset at 2:30 AM UTC:
```dart
static const int resetHour = 2;
static const int resetMinute = 30;
```

## Troubleshooting

### Service Not Running
Check logs for initialization errors in `main.dart`

### Reset Not Occurring
- Verify service is running: `DailyResetService.isRunning`
- Check reset logs collection for error details
- Ensure Firestore connectivity

### Incorrect Reset Times
- Verify timezone configuration
- Check system clock accuracy
- Review reset log timestamps

### Database Issues
- Monitor Firestore security rules
- Check collection permissions
- Verify document structure matches expected schema