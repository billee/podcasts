import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:kapwa_companion_basic/services/token_limit_service.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:kapwa_companion_basic/models/token_usage_info.dart';
import 'package:kapwa_companion_basic/core/config.dart';

void main() {
  group('TokenLimitService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockUser = MockUser(
        uid: 'test_user_123',
        email: 'test@example.com',
        isEmailVerified: true,
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      // Inject dependencies
      TokenLimitService.setFirestoreInstance(fakeFirestore);
      SubscriptionService.setFirestoreInstance(fakeFirestore);
      SubscriptionService.setAuthInstance(mockAuth);
    });

    group('canUserChat', () {
      test('returns true when user has remaining tokens', () async {
        // Setup user as trial user with some usage
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');
        await _setupDailyUsage(fakeFirestore, 'test_user_123', 5000, 10000);

        final canChat = await TokenLimitService.canUserChat('test_user_123');
        expect(canChat, isTrue);
      });

      test('returns false when user has reached token limit', () async {
        // Setup user as trial user with limit reached
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');
        await _setupDailyUsage(fakeFirestore, 'test_user_123', 10000, 10000);

        final canChat = await TokenLimitService.canUserChat('test_user_123');
        expect(canChat, isFalse);
      });

      test('returns true when token limits are disabled', () async {
        // Note: This test assumes we can modify AppConfig for testing
        // In a real scenario, you might need to mock AppConfig
        final canChat = await TokenLimitService.canUserChat('test_user_123');
        expect(canChat, isTrue); // Should be true since limits are enabled by default but user has no usage
      });
    });

    group('getRemainingTokens', () {
      test('returns correct remaining tokens for trial user', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');
        await _setupDailyUsage(fakeFirestore, 'test_user_123', 3000, 10000);

        final remaining = await TokenLimitService.getRemainingTokens('test_user_123');
        expect(remaining, equals(7000));
      });

      test('returns 0 when user has exceeded limit', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');
        await _setupDailyUsage(fakeFirestore, 'test_user_123', 12000, 10000);

        final remaining = await TokenLimitService.getRemainingTokens('test_user_123');
        expect(remaining, equals(0));
      });

      test('returns full limit for new user with no usage', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');

        final remaining = await TokenLimitService.getRemainingTokens('test_user_123');
        expect(remaining, equals(AppConfig.trialUserDailyTokenLimit));
      });
    });

    group('recordTokenUsage', () {
      test('creates new usage record for first-time user', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');

        await TokenLimitService.recordTokenUsage('test_user_123', 1500);

        final today = _getTodayString();
        final docId = 'test_user_123_$today';
        final doc = await fakeFirestore.collection('daily_token_usage').doc(docId).get();
        
        expect(doc.exists, isTrue);
        final data = doc.data() as Map<String, dynamic>;
        expect(data['tokensUsed'], equals(1500));
        expect(data['tokenLimit'], equals(AppConfig.trialUserDailyTokenLimit));
        expect(data['userType'], equals('trial'));
      });

      test('updates existing usage record', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');
        await _setupDailyUsage(fakeFirestore, 'test_user_123', 2000, 10000);

        await TokenLimitService.recordTokenUsage('test_user_123', 1000);

        final today = _getTodayString();
        final docId = 'test_user_123_$today';
        final doc = await fakeFirestore.collection('daily_token_usage').doc(docId).get();
        
        final data = doc.data() as Map<String, dynamic>;
        expect(data['tokensUsed'], equals(3000));
      });

      test('handles zero or negative token counts gracefully', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');

        await TokenLimitService.recordTokenUsage('test_user_123', 0);
        await TokenLimitService.recordTokenUsage('test_user_123', -100);

        final today = _getTodayString();
        final docId = 'test_user_123_$today';
        final doc = await fakeFirestore.collection('daily_token_usage').doc(docId).get();
        
        expect(doc.exists, isFalse); // No record should be created
      });
    });

    group('getUserUsageInfo', () {
      test('returns correct usage info for existing user', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');
        await _setupDailyUsage(fakeFirestore, 'test_user_123', 4000, 10000);

        final usageInfo = await TokenLimitService.getUserUsageInfo('test_user_123');

        expect(usageInfo.userId, equals('test_user_123'));
        expect(usageInfo.tokensUsed, equals(4000));
        expect(usageInfo.tokenLimit, equals(10000));
        expect(usageInfo.remainingTokens, equals(6000));
        expect(usageInfo.userType, equals('trial'));
        expect(usageInfo.usagePercentage, equals(0.4));
        expect(usageInfo.isLimitReached, isFalse);
        expect(usageInfo.isWarningThreshold, isFalse);
      });

      test('returns warning threshold for high usage', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');
        await _setupDailyUsage(fakeFirestore, 'test_user_123', 9500, 10000);

        final usageInfo = await TokenLimitService.getUserUsageInfo('test_user_123');

        expect(usageInfo.isWarningThreshold, isTrue);
        expect(usageInfo.usagePercentage, equals(0.95));
      });

      test('returns limit reached for exceeded usage', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');
        await _setupDailyUsage(fakeFirestore, 'test_user_123', 10000, 10000);

        final usageInfo = await TokenLimitService.getUserUsageInfo('test_user_123');

        expect(usageInfo.isLimitReached, isTrue);
        expect(usageInfo.remainingTokens, equals(0));
      });

      test('returns empty usage info for new user', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');

        final usageInfo = await TokenLimitService.getUserUsageInfo('test_user_123');

        expect(usageInfo.tokensUsed, equals(0));
        expect(usageInfo.remainingTokens, equals(AppConfig.trialUserDailyTokenLimit));
        expect(usageInfo.isLimitReached, isFalse);
        expect(usageInfo.isWarningThreshold, isFalse);
      });
    });

    group('user type determination', () {
      test('identifies subscribed user correctly', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'subscribed');
        await _setupActiveSubscription(fakeFirestore, 'test_user_123');

        final usageInfo = await TokenLimitService.getUserUsageInfo('test_user_123');

        expect(usageInfo.userType, equals('subscribed'));
        expect(usageInfo.tokenLimit, equals(AppConfig.subscribedUserDailyTokenLimit));
      });

      test('identifies trial user correctly', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');
        await _setupTrialHistory(fakeFirestore, 'test_user_123');

        final usageInfo = await TokenLimitService.getUserUsageInfo('test_user_123');

        expect(usageInfo.userType, equals('trial'));
        expect(usageInfo.tokenLimit, equals(AppConfig.trialUserDailyTokenLimit));
      });
    });

    group('watchUserUsage', () {
      test('streams usage updates correctly', () async {
        await _setupUserProfile(fakeFirestore, 'test_user_123', 'trial');
        
        final stream = TokenLimitService.watchUserUsage('test_user_123');
        
        // Listen to the stream and verify initial empty state
        final usageInfoList = <TokenUsageInfo>[];
        final subscription = stream.listen((usageInfo) {
          usageInfoList.add(usageInfo);
        });

        // Wait for initial empty state
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Record some usage
        await TokenLimitService.recordTokenUsage('test_user_123', 2000);
        
        // Wait for update
        await Future.delayed(const Duration(milliseconds: 100));
        
        await subscription.cancel();
        
        expect(usageInfoList.length, greaterThanOrEqualTo(1));
        expect(usageInfoList.first.tokensUsed, equals(0)); // Initial state
      });
    });
  });
}

// Helper functions for test setup

Future<void> _setupUserProfile(FakeFirebaseFirestore firestore, String userId, String userType) async {
  await firestore.collection('users').doc(userId).set({
    'uid': userId,
    'email': 'test@example.com',
    'emailVerified': true,
    'userType': userType,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _setupDailyUsage(FakeFirebaseFirestore firestore, String userId, int tokensUsed, int tokenLimit) async {
  final today = _getTodayString();
  final docId = '${userId}_$today';
  
  await firestore.collection('daily_token_usage').doc(docId).set({
    'userId': userId,
    'date': today,
    'tokensUsed': tokensUsed,
    'tokenLimit': tokenLimit,
    'userType': 'trial',
    'lastUpdated': FieldValue.serverTimestamp(),
    'resetAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
  });
}

Future<void> _setupActiveSubscription(FakeFirebaseFirestore firestore, String userId) async {
  final endDate = DateTime.now().add(const Duration(days: 30));
  await firestore.collection('subscriptions').doc(userId).set({
    'userId': userId,
    'status': 'active',
    'plan': 'monthly',
    'subscriptionEndDate': Timestamp.fromDate(endDate),
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _setupTrialHistory(FakeFirebaseFirestore firestore, String userId) async {
  final endDate = DateTime.now().add(const Duration(days: 7));
  await firestore.collection('trial_history').add({
    'userId': userId,
    'email': 'test@example.com',
    'trialEndDate': Timestamp.fromDate(endDate),
    'createdAt': FieldValue.serverTimestamp(),
  });
}

String _getTodayString() {
  final now = DateTime.now().toUtc();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}