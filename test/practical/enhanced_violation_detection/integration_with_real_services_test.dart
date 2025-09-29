// test/practical/enhanced_violation_detection/integration_with_real_services_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

// Import your actual services
import 'package:kapwa_companion_basic/services/violation_check_service.dart';
import 'package:kapwa_companion_basic/services/violation_logging_service.dart';

// Import test data
import 'test_data/violation_test_cases.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late Logger logger;

  setUpAll(() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
    
    logger = Logger('RealServiceIntegrationTest');
  });

  setUp(() {
    // Use fake Firestore for testing
    fakeFirestore = FakeFirebaseFirestore();
    ViolationCheckService.setFirestoreInstance(fakeFirestore);
  });

  group('Real Service Integration Tests', () {
    
    test('ViolationCheckService Integration', () async {
      logger.info('🧪 Testing Real ViolationCheckService');
      
      const userId = 'test_user_123';
      
      // Test 1: No violations initially
      bool shouldShow = await ViolationCheckService.shouldShowViolationWarning(userId);
      expect(shouldShow, false, reason: 'No violations should exist initially');
      
      // Test 2: Add a violation and test detection
      await fakeFirestore.collection('user_violations').add({
        'userId': userId,
        'violationType': 'profanity',
        'userMessage': 'Test violation message',
        'llmResponse': 'Message blocked',
        'timestamp': FieldValue.serverTimestamp(),
        'resolved': false,
        // Note: no 'shown_at' field - should trigger warning
      });
      
      shouldShow = await ViolationCheckService.shouldShowViolationWarning(userId);
      expect(shouldShow, true, reason: 'Unshown violation should trigger warning');
      
      // Test 3: Mark violation as shown
      final violations = await fakeFirestore
          .collection('user_violations')
          .where('userId', isEqualTo: userId)
          .get();
      
      await violations.docs.first.reference.update({
        'shown_at': FieldValue.serverTimestamp(),
      });
      
      shouldShow = await ViolationCheckService.shouldShowViolationWarning(userId);
      expect(shouldShow, false, reason: 'Shown violation should not trigger warning');
      
      logger.info('✅ ViolationCheckService integration test passed');
    });

    test('Enhanced Detection with Real ViolationLoggingService', () async {
      logger.info('🧪 Testing Enhanced Detection with Real ViolationLoggingService');
      
      const userId = 'test_user_456';
      int violationsLogged = 0;
      
      // Test various attack vectors from our test cases
      final attackCases = [
        ...ViolationTestCases.patternMatchingCases.where((c) => c.shouldBeBlocked),
        ...ViolationTestCases.keywordBlacklistCases.where((c) => c.shouldBeBlocked),
        ...ViolationTestCases.promptInjectionCases.where((c) => c.shouldBeBlocked),
      ];
      
      for (final testCase in attackCases.take(5)) { // Test first 5 attacks
        // Simulate your enhanced detection logic here
        final isViolation = await _simulateEnhancedDetection(testCase.input);
        
        if (isViolation) {
          // Use your ACTUAL ViolationLoggingService
          await ViolationLoggingService.logViolation(
            userId: userId,
            violationType: testCase.category,
            userMessage: testCase.input,
            llmResponse: 'Message blocked by enhanced detection',
          );
          violationsLogged++;
        }
        
        expect(isViolation, testCase.shouldBeBlocked, 
               reason: 'Detection failed for: ${testCase.description}');
      }
      
      logger.info('✅ Logged $violationsLogged violations using real ViolationLoggingService');
      
      // Test your ACTUAL ViolationLoggingService.getUserViolationCount
      final violationCount = await ViolationLoggingService.getUserViolationCount(userId);
      expect(violationCount, violationsLogged);
      
      logger.info('✅ Real ViolationLoggingService integration test passed');
    });

    test('Performance Test with Real Services', () async {
      logger.info('🧪 Testing Performance with Real Services');
      
      const testMessage = "This is a test message for performance testing";
      const iterations = 50;
      
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < iterations; i++) {
        await ViolationCheckService.shouldShowViolationWarning('user_$i');
      }
      
      stopwatch.stop();
      
      final avgTimeMs = stopwatch.elapsedMilliseconds / iterations;
      logger.info('📊 Average real service time: ${avgTimeMs.toStringAsFixed(2)}ms');
      
      expect(avgTimeMs, lessThan(100), 
             reason: 'Real service should complete in <100ms');
      
      logger.info('✅ Performance test passed');
    });
  });
}

// Helper function to simulate your enhanced detection logic
Future<bool> _simulateEnhancedDetection(String input) async {
  // This is where you'd integrate your actual enhanced detection
  // For now, simulate with basic pattern matching
  
  final sqlPatterns = [
    RegExp(r"';\s*DROP\s+TABLE", caseSensitive: false),
    RegExp(r"<script.*?>", caseSensitive: false),
    RegExp(r"javascript:", caseSensitive: false),
  ];
  
  final profanityWords = ['f***ing', 'idiot', 'hate', 'kill'];
  final lowerInput = input.toLowerCase();
  
  // Check patterns
  for (final pattern in sqlPatterns) {
    if (pattern.hasMatch(input)) return true;
  }
  
  // Check profanity
  for (final word in profanityWords) {
    if (lowerInput.contains(word)) return true;
  }
  
  return false;
}

// Helper function to simulate enhanced detection (you'll replace this with your actual logic)
Future<bool> _simulateEnhancedDetection(String input) async {
  // TODO: Replace this with your actual enhanced detection implementation
  // This is where you'd integrate your real enhanced violation detection
  
  final sqlPatterns = [
    RegExp(r"';\s*DROP\s+TABLE", caseSensitive: false),
    RegExp(r"<script.*?>", caseSensitive: false),
    RegExp(r"javascript:", caseSensitive: false),
  ];
  
  final profanityWords = ['f***ing', 'idiot', 'hate', 'kill'];
  final promptInjectionWords = ['ignore', 'instructions', 'system prompt'];
  final lowerInput = input.toLowerCase();
  
  // Check patterns
  for (final pattern in sqlPatterns) {
    if (pattern.hasMatch(input)) return true;
  }
  
  // Check profanity
  for (final word in profanityWords) {
    if (lowerInput.contains(word)) return true;
  }
  
  // Check prompt injection
  for (final word in promptInjectionWords) {
    if (lowerInput.contains(word)) return true;
  }
  
  return false;
}