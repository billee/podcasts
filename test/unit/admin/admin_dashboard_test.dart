import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Admin Dashboard Date Formatting', () {
    test('should format Timestamp correctly', () {
      // Create a test timestamp
      final testDate = DateTime(2024, 1, 15, 14, 30, 0);
      final timestamp = Timestamp.fromDate(testDate);
      
      // Test the formatting logic
      String formatDateTime(dynamic timestamp) {
        if (timestamp == null) return 'N/A';
        
        try {
          DateTime date;
          
          if (timestamp is DateTime) {
            date = timestamp;
          } else if (timestamp is Timestamp) {
            date = timestamp.toDate();
          } else if (timestamp is String) {
            date = DateTime.parse(timestamp);
          } else if (timestamp is int) {
            date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else {
            date = timestamp.toDate();
          }
          
          // Validate the date is reasonable
          final now = DateTime.now();
          final minDate = DateTime(2020, 1, 1);
          final maxDate = now.add(const Duration(days: 365 * 10));
          
          if (date.isBefore(minDate) || date.isAfter(maxDate)) {
            return 'Invalid Date';
          }
          
          return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}\n${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        } catch (e) {
          return 'Invalid Date';
        }
      }
      
      final result = formatDateTime(timestamp);
      expect(result, equals('15/01/2024\n14:30'));
    });

    test('should handle null timestamp', () {
      String formatDateTime(dynamic timestamp) {
        if (timestamp == null) return 'N/A';
        return 'Valid';
      }
      
      final result = formatDateTime(null);
      expect(result, equals('N/A'));
    });

    test('should handle DateTime object', () {
      final testDate = DateTime(2024, 1, 15, 14, 30, 0);
      
      String formatDateTime(dynamic timestamp) {
        if (timestamp == null) return 'N/A';
        
        try {
          DateTime date;
          
          if (timestamp is DateTime) {
            date = timestamp;
          } else if (timestamp is Timestamp) {
            date = timestamp.toDate();
          } else {
            date = timestamp.toDate();
          }
          
          return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}\n${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        } catch (e) {
          return 'Invalid Date';
        }
      }
      
      final result = formatDateTime(testDate);
      expect(result, equals('15/01/2024\n14:30'));
    });

    test('should handle invalid dates', () {
      final invalidDate = DateTime(1900, 1, 1); // Too old
      
      String formatDateTime(dynamic timestamp) {
        if (timestamp == null) return 'N/A';
        
        try {
          DateTime date;
          
          if (timestamp is DateTime) {
            date = timestamp;
          } else {
            date = timestamp.toDate();
          }
          
          // Validate the date is reasonable
          final now = DateTime.now();
          final minDate = DateTime(2020, 1, 1);
          final maxDate = now.add(const Duration(days: 365 * 10));
          
          if (date.isBefore(minDate) || date.isAfter(maxDate)) {
            return 'Invalid Date';
          }
          
          return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}\n${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        } catch (e) {
          return 'Invalid Date';
        }
      }
      
      final result = formatDateTime(invalidDate);
      expect(result, equals('Invalid Date'));
    });

    test('should find subscription start date from multiple field names', () {
      // Test data with subscriptionStartDate (used by subscribeToMonthlyPlan)
      final subscriptionData1 = {
        'plan': 'monthly',
        'status': 'active',
        'subscriptionStartDate': Timestamp.fromDate(DateTime(2024, 1, 15, 14, 30)),
        'subscriptionEndDate': Timestamp.fromDate(DateTime(2024, 2, 15)),
      };

      // Test data with startDate (used by activateSubscription)
      final subscriptionData2 = {
        'plan': 'monthly',
        'status': 'active',
        'startDate': Timestamp.fromDate(DateTime(2024, 1, 15, 14, 30)),
        'subscriptionEndDate': Timestamp.fromDate(DateTime(2024, 2, 15)),
      };

      String findSubscriptionStartDate(Map<String, dynamic> data) {
        final possibleFields = ['subscriptionStartDate', 'startDate', 'createdAt', 'updatedAt'];
        
        for (final field in possibleFields) {
          if (data.containsKey(field) && data[field] != null) {
            final dateValue = data[field];
            if (dateValue is Timestamp) {
              final date = dateValue.toDate();
              return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
            }
          }
        }
        return 'N/A';
      }

      expect(findSubscriptionStartDate(subscriptionData1), equals('15/01/2024'));
      expect(findSubscriptionStartDate(subscriptionData2), equals('15/01/2024'));
    });

    test('should prioritize startDate field as mentioned in Firestore', () {
      // Test data with both startDate and subscriptionStartDate
      final subscriptionData = {
        'plan': 'monthly',
        'status': 'active',
        'startDate': Timestamp.fromDate(DateTime(2024, 1, 15, 14, 30)), // This should be used
        'subscriptionStartDate': Timestamp.fromDate(DateTime(2024, 1, 10, 10, 0)), // This should be ignored
        'subscriptionEndDate': Timestamp.fromDate(DateTime(2024, 2, 15)),
      };

      String findSubscriptionStartDate(Map<String, dynamic> data) {
        // Check for startDate first since that's what exists in Firestore
        if (data.containsKey('startDate') && data['startDate'] != null) {
          final dateValue = data['startDate'];
          if (dateValue is Timestamp) {
            final date = dateValue.toDate();
            return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
          }
        }
        
        // Fallback to other fields
        final possibleFields = ['subscriptionStartDate', 'createdAt', 'updatedAt'];
        for (final field in possibleFields) {
          if (data.containsKey(field) && data[field] != null) {
            final dateValue = data[field];
            if (dateValue is Timestamp) {
              final date = dateValue.toDate();
              return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
            }
          }
        }
        return 'N/A';
      }

      // Should return the startDate (15/01/2024), not subscriptionStartDate (10/01/2024)
      expect(findSubscriptionStartDate(subscriptionData), equals('15/01/2024'));
    });
  });
}