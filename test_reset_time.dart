import 'lib/core/config.dart';

void main() {
  // Test reset time calculation
  print('Reset configuration:');
  print('Reset Hour: ${AppConfig.resetHour}');
  print('Reset Minute: ${AppConfig.resetMinute}');
  print('Reset Timezone: ${AppConfig.resetTimezone}');
  
  // Simulate current time
  final now = DateTime.now().toUtc();
  print('\nCurrent time (UTC): $now');
  
  // Calculate next reset time
  var nextReset = DateTime.utc(
    now.year,
    now.month,
    now.day,
    AppConfig.resetHour,
    AppConfig.resetMinute,
  );
  
  // If the reset time for today has already passed, schedule for tomorrow
  if (nextReset.isBefore(now) || nextReset.isAtSameMomentAs(now)) {
    nextReset = nextReset.add(const Duration(days: 1));
  }
  
  print('Next reset time (UTC): $nextReset');
  print('Next reset time (Local): ${nextReset.toLocal()}');
  
  // Show what this looks like in different timezones
  print('\nReset time in different timezones:');
  print('UTC: ${nextReset.toUtc()}');
  print('Local: ${nextReset.toLocal()}');
  
  // Verify it's midnight UTC
  print('\nVerification:');
  print('Hour: ${nextReset.hour} (should be 0 for midnight)');
  print('Minute: ${nextReset.minute} (should be 0)');
}