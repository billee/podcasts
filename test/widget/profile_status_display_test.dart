import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
import 'package:kapwa_companion_basic/services/subscription_service.dart';

import '../base/base_test.dart';
import '../utils/test_helpers.dart';
import '../mocks/firebase_mocks.dart';

// Mock subscription status widget for testing display logic
class MockSubscriptionStatusWidget extends StatelessWidget {
  final SubscriptionStatus status;
  final Map<String, dynamic>? details;

  const MockSubscriptionStatusWidget({
    super.key,
    required this.status,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getStatusIcon()),
                const SizedBox(width: 10),
                Text(
                  'SUBSCRIPTION STATUS',
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusInfo(),
            const SizedBox(height: 16),
            if (_shouldShowUpgradeButton()) _buildUpgradeButton(),
            if (_shouldShowCancelButton()) _buildCancelButton(),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (status) {
      case SubscriptionStatus.trial:
        return Icons.access_time;
      case SubscriptionStatus.active:
        return Icons.check_circle;
      case SubscriptionStatus.trialExpired:
      case SubscriptionStatus.expired:
        return Icons.error;
      case SubscriptionStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case SubscriptionStatus.trial:
        return Colors.orange;
      case SubscriptionStatus.active:
        return Colors.green;
      case SubscriptionStatus.trialExpired:
      case SubscriptionStatus.expired:
        return Colors.red;
      case SubscriptionStatus.cancelled:
        return Colors.grey;
    }
  }

  Widget _buildStatusInfo() {
    if (details == null) {
      return const Text('No subscription information available');
    }

    switch (status) {
      case SubscriptionStatus.trial:
        final daysLeft = details!['trialDaysLeft'] as int? ?? 0;
        return Column(
          children: [
            _buildInfoRow('Status:', 'TRIAL ACTIVE'),
            _buildInfoRow('Plan:', 'TRIAL'),
            _buildInfoRow('Trial Days Left:', '$daysLeft'),
          ],
        );
      case SubscriptionStatus.active:
        final price = details!['price'] as double? ?? 0.0;
        return Column(
          children: [
            _buildInfoRow('Status:', 'PREMIUM ACTIVE'),
            _buildInfoRow('Plan:', 'MONTHLY'),
            _buildInfoRow('Price:', '\$$price/month'),
            if (details!['nextBillingDate'] != null)
              _buildInfoRow('Next Billing:', _formatDate(details!['nextBillingDate'])),
          ],
        );
      case SubscriptionStatus.cancelled:
        return Column(
          children: [
            _buildInfoRow('Status:', 'CANCELLED'),
            _buildInfoRow('Status:', 'CANCELLED - Access until end of billing period'),
            if (details!['willExpireAt'] != null)
              _buildInfoRow('Access Until:', _formatDate(details!['willExpireAt'])),
          ],
        );
      default:
        return _buildInfoRow('Status:', 'EXPIRED');
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = timestamp.toDate();
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  bool _shouldShowUpgradeButton() {
    return status == SubscriptionStatus.trial ||
           status == SubscriptionStatus.trialExpired ||
           status == SubscriptionStatus.expired;
  }

  bool _shouldShowCancelButton() {
    return status == SubscriptionStatus.active;
  }

  Widget _buildUpgradeButton() {
    String buttonText;
    switch (status) {
      case SubscriptionStatus.trial:
        buttonText = 'Upgrade to Premium';
        break;
      case SubscriptionStatus.trialExpired:
        buttonText = 'Subscribe Now';
        break;
      case SubscriptionStatus.expired:
        buttonText = 'Renew Subscription';
        break;
      default:
        buttonText = 'Subscribe';
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.upgrade, size: 18),
        label: Text(buttonText),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.cancel_outlined, size: 18),
        label: const Text('Cancel Subscription'),
      ),
    );
  }
}

// Mock subscription status banner for testing
class MockSubscriptionStatusBanner extends StatelessWidget {
  final SubscriptionStatus status;
  final Map<String, dynamic>? details;

  const MockSubscriptionStatusBanner({
    super.key,
    required this.status,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    // Only show banner for trial status
    if (status != SubscriptionStatus.trial) {
      return const SizedBox.shrink();
    }

    final daysLeft = details?['trialDaysLeft'] as int? ?? 0;
    final hoursLeft = details?['trialHoursLeft'] as int? ?? 0;
    
    String timeLeftText;
    if (daysLeft > 0) {
      timeLeftText = 'Trial: $daysLeft Day${daysLeft == 1 ? '' : 's'} Left';
    } else if (hoursLeft > 0) {
      timeLeftText = 'Trial: $hoursLeft Hour${hoursLeft == 1 ? '' : 's'} Left';
    } else {
      timeLeftText = 'Trial: Ending Soon';
    }

    Color bannerColor = daysLeft <= 1 ? Colors.red : (daysLeft <= 3 ? Colors.orange : Colors.blue);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor.withOpacity(0.5), width: 2),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: bannerColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              timeLeftText,
              style: TextStyle(
                color: bannerColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          if (daysLeft <= 3)
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                backgroundColor: bannerColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  TestGroups.uiTests('Profile Page Status Display Components', () {
    group('Subscription Service Tests', () {
      late FakeFirebaseFirestore mockFirestore;
      late auth_mocks.MockFirebaseAuth mockAuth;
      late auth_mocks.MockUser mockUser;

      setUp(() {
        mockFirestore = FakeFirebaseFirestore();
        mockUser = FirebaseMockFactory.createMockUser(
          uid: 'test-uid-123',
          email: 'test@example.com',
          isEmailVerified: true,
        );
        mockAuth = FirebaseMockFactory.createMockAuth(currentUser: mockUser);
        
        // Set up service dependencies
        SubscriptionService.setFirestoreInstance(mockFirestore);
        SubscriptionService.setAuthInstance(mockAuth);
      });

      test('returns trial status with correct days remaining', () async {
        // Set up trial data
        final now = DateTime.now();
        final trialEndDate = now.add(const Duration(days: 5));
        
        await mockFirestore.collection('users').doc('test-uid-123').set({
          'uid': 'test-uid-123',
          'email': 'test@example.com',
          'emailVerified': true,
        });

        await mockFirestore.collection('trial_history').doc('test-trial').set({
          'userId': 'test-uid-123',
          'email': 'test@example.com',
          'trialStartDate': Timestamp.fromDate(now),
          'trialEndDate': Timestamp.fromDate(trialEndDate),
          'createdAt': Timestamp.fromDate(now),
        });

        // Test subscription service
        final status = await SubscriptionService.getSubscriptionStatus('test-uid-123');
        final details = await SubscriptionService.getSubscriptionDetails('test-uid-123');

        expect(status, SubscriptionStatus.trial);
        expect(details?['trialDaysLeft'], greaterThanOrEqualTo(4));
        expect(details?['trialDaysLeft'], lessThanOrEqualTo(5));
      });

      test('returns active status for premium subscribers', () async {
        // Set up subscription data
        final now = DateTime.now();
        final subscriptionEndDate = now.add(const Duration(days: 30));
        
        await mockFirestore.collection('users').doc('test-uid-123').set({
          'uid': 'test-uid-123',
          'email': 'test@example.com',
          'emailVerified': true,
        });

        await mockFirestore.collection('subscriptions').doc('test-uid-123').set({
          'userId': 'test-uid-123',
          'email': 'test@example.com',
          'status': 'active',
          'plan': 'monthly',
          'price': 3.0,
          'subscriptionStartDate': Timestamp.fromDate(now),
          'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
          'nextBillingDate': Timestamp.fromDate(subscriptionEndDate),
          'createdAt': Timestamp.fromDate(now),
        });

        final status = await SubscriptionService.getSubscriptionStatus('test-uid-123');
        final details = await SubscriptionService.getSubscriptionDetails('test-uid-123');

        expect(status, SubscriptionStatus.active);
        expect(details?['status'], 'active');
        expect(details?['price'], 3.0);
      });

      test('returns cancelled status with expiration date', () async {
        // Set up cancelled subscription data
        final now = DateTime.now();
        final willExpireAt = now.add(const Duration(days: 15));
        
        await mockFirestore.collection('users').doc('test-uid-123').set({
          'uid': 'test-uid-123',
          'email': 'test@example.com',
          'emailVerified': true,
        });

        await mockFirestore.collection('subscriptions').doc('test-uid-123').set({
          'userId': 'test-uid-123',
          'email': 'test@example.com',
          'status': 'cancelled',
          'plan': 'monthly',
          'price': 3.0,
          'subscriptionStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 15))),
          'subscriptionEndDate': Timestamp.fromDate(willExpireAt),
          'willExpireAt': Timestamp.fromDate(willExpireAt),
          'cancelledAt': Timestamp.fromDate(now.subtract(const Duration(days: 5))),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 15))),
        });

        final status = await SubscriptionService.getSubscriptionStatus('test-uid-123');
        final details = await SubscriptionService.getSubscriptionDetails('test-uid-123');

        expect(status, SubscriptionStatus.cancelled);
        expect(details?['status'], 'cancelled');
        expect(details?['willExpireAt'], isNotNull);
      });

      test('returns expired status for expired trials', () async {
        // Set up expired trial data
        final now = DateTime.now();
        final trialEndDate = now.subtract(const Duration(days: 2));
        
        await mockFirestore.collection('users').doc('test-uid-123').set({
          'uid': 'test-uid-123',
          'email': 'test@example.com',
          'emailVerified': true,
        });

        await mockFirestore.collection('trial_history').doc('test-trial').set({
          'userId': 'test-uid-123',
          'email': 'test@example.com',
          'trialStartDate': Timestamp.fromDate(now.subtract(const Duration(days: 9))),
          'trialEndDate': Timestamp.fromDate(trialEndDate),
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 9))),
        });

        final status = await SubscriptionService.getSubscriptionStatus('test-uid-123');

        expect(status, SubscriptionStatus.trialExpired);
      });
    });

    group('Subscription Status Widget Display Tests', () {
      testWidgets('displays trial status with countdown', (WidgetTester tester) async {
        final details = {
          'status': 'trial',
          'plan': 'trial',
          'trialDaysLeft': 5,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusWidget(
                status: SubscriptionStatus.trial,
                details: details,
              ),
            ),
          ),
        );

        // Should display trial status
        expect(find.text('SUBSCRIPTION STATUS'), findsOneWidget);
        expect(find.text('TRIAL ACTIVE'), findsOneWidget);
        expect(find.text('Status:'), findsOneWidget);
        expect(find.text('Plan:'), findsOneWidget);
        expect(find.text('Trial Days Left:'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsOneWidget);
        expect(find.text('Upgrade to Premium'), findsOneWidget);
      });

      testWidgets('displays premium subscription status', (WidgetTester tester) async {
        final details = {
          'status': 'active',
          'plan': 'monthly',
          'price': 3.0,
          'nextBillingDate': DateTime(2024, 4, 15),
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusWidget(
                status: SubscriptionStatus.active,
                details: details,
              ),
            ),
          ),
        );

        // Should display premium status
        expect(find.text('SUBSCRIPTION STATUS'), findsOneWidget);
        expect(find.text('PREMIUM ACTIVE'), findsOneWidget);
        expect(find.text('MONTHLY'), findsOneWidget);
        expect(find.text('Price:'), findsOneWidget);
        expect(find.text('\$3.0/month'), findsOneWidget);
        expect(find.text('Next Billing:'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text('Cancel Subscription'), findsOneWidget);
      });

      testWidgets('displays cancelled subscription status', (WidgetTester tester) async {
        final details = {
          'status': 'cancelled',
          'plan': 'monthly',
          'willExpireAt': DateTime(2024, 4, 15),
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusWidget(
                status: SubscriptionStatus.cancelled,
                details: details,
              ),
            ),
          ),
        );

        // Should display cancelled status
        expect(find.text('SUBSCRIPTION STATUS'), findsOneWidget);
        expect(find.text('CANCELLED'), findsOneWidget);
        expect(find.text('CANCELLED - Access until end of billing period'), findsOneWidget);
        expect(find.text('Access Until:'), findsOneWidget);
        expect(find.byIcon(Icons.cancel), findsOneWidget);
      });

      testWidgets('shows upgrade button for trial users', (WidgetTester tester) async {
        final details = {
          'status': 'trial',
          'trialDaysLeft': 3,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusWidget(
                status: SubscriptionStatus.trial,
                details: details,
              ),
            ),
          ),
        );

        // Should show upgrade button
        final upgradeButton = find.text('Upgrade to Premium');
        expect(upgradeButton, findsOneWidget);
        expect(find.byIcon(Icons.upgrade), findsOneWidget);

        // Button should be tappable
        await tester.tap(upgradeButton);
        await tester.pumpAndSettle();
      });

      testWidgets('shows cancel button for active subscribers', (WidgetTester tester) async {
        final details = {
          'status': 'active',
          'plan': 'monthly',
          'price': 3.0,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusWidget(
                status: SubscriptionStatus.active,
                details: details,
              ),
            ),
          ),
        );

        // Should show cancel button
        expect(find.text('Cancel Subscription'), findsOneWidget);
        expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
      });

      testWidgets('displays no subscription information when data is null', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusWidget(
                status: SubscriptionStatus.expired,
                details: null,
              ),
            ),
          ),
        );

        // Should show no subscription information
        expect(find.text('No subscription information available'), findsOneWidget);
      });

      testWidgets('formats dates correctly', (WidgetTester tester) async {
        final details = {
          'status': 'active',
          'plan': 'monthly',
          'price': 3.0,
          'nextBillingDate': DateTime(2024, 4, 15),
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusWidget(
                status: SubscriptionStatus.active,
                details: details,
              ),
            ),
          ),
        );

        // Should format dates as DD/MM/YYYY
        expect(find.text('15/4/2024'), findsOneWidget);
      });
    });

    group('Subscription Status Banner Display Tests', () {
      testWidgets('displays trial countdown banner with days remaining', (WidgetTester tester) async {
        final details = {
          'trialDaysLeft': 5,
          'trialHoursLeft': 120,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusBanner(
                status: SubscriptionStatus.trial,
                details: details,
              ),
            ),
          ),
        );

        // Should display trial banner with days remaining
        expect(find.text('Trial: 5 Days Left'), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsOneWidget);
        
        // Should not show upgrade button for more than 3 days
        expect(find.text('Upgrade'), findsNothing);
      });

      testWidgets('displays trial countdown banner with hours remaining', (WidgetTester tester) async {
        final details = {
          'trialDaysLeft': 0,
          'trialHoursLeft': 8,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusBanner(
                status: SubscriptionStatus.trial,
                details: details,
              ),
            ),
          ),
        );

        // Should display trial banner with hours remaining
        expect(find.text('Trial: 8 Hours Left'), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsOneWidget);
      });

      testWidgets('displays urgent trial banner with upgrade button for 3 days or less', (WidgetTester tester) async {
        final details = {
          'trialDaysLeft': 2,
          'trialHoursLeft': 48,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusBanner(
                status: SubscriptionStatus.trial,
                details: details,
              ),
            ),
          ),
        );

        // Should display trial banner with upgrade button
        expect(find.text('Trial: 2 Days Left'), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsOneWidget);
        expect(find.text('Upgrade'), findsOneWidget);
        
        // Button should be tappable
        await tester.tap(find.text('Upgrade'));
        await tester.pumpAndSettle();
      });

      testWidgets('displays critical trial banner with red color for 1 day or less', (WidgetTester tester) async {
        final details = {
          'trialDaysLeft': 1,
          'trialHoursLeft': 24,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusBanner(
                status: SubscriptionStatus.trial,
                details: details,
              ),
            ),
          ),
        );

        // Should display critical trial banner
        expect(find.text('Trial: 1 Day Left'), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsOneWidget);
        expect(find.text('Upgrade'), findsOneWidget);
        
        // Should use red color for critical state (tested through widget properties)
        final container = tester.widget<Container>(find.byType(Container).first);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, Colors.red.withOpacity(0.15));
      });

      testWidgets('displays ending soon banner when trial is about to expire', (WidgetTester tester) async {
        final details = {
          'trialDaysLeft': 0,
          'trialHoursLeft': 0,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusBanner(
                status: SubscriptionStatus.trial,
                details: details,
              ),
            ),
          ),
        );

        // Should display ending soon banner
        expect(find.text('Trial: Ending Soon'), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsOneWidget);
        expect(find.text('Upgrade'), findsOneWidget);
      });

      testWidgets('hides banner for premium subscribers', (WidgetTester tester) async {
        final details = {
          'status': 'active',
          'plan': 'monthly',
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusBanner(
                status: SubscriptionStatus.active,
                details: details,
              ),
            ),
          ),
        );

        // Should not display any banner for premium subscribers
        expect(find.text('Trial:'), findsNothing);
        expect(find.byIcon(Icons.access_time), findsNothing);
      });

      testWidgets('hides banner for expired users', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MockSubscriptionStatusBanner(
                status: SubscriptionStatus.expired,
                details: null,
              ),
            ),
          ),
        );

        // Should not display any banner for expired users
        expect(find.text('Trial:'), findsNothing);
        expect(find.byIcon(Icons.access_time), findsNothing);
      });
    });
  });
}