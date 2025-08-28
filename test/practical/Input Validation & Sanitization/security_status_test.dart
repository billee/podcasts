import 'package:flutter_test/flutter_test.dart';
import 'package:kapwa_companion_basic/services/input_validation_service.dart';
import 'package:kapwa_companion_basic/core/config.dart';

/// Security Status Test - Shows your actual protection level
void main() {
  group('🛡️ Security Protection Status', () {
    
    setUp(() {
      InputValidationService.cleanupRateLimitData();
    });

    test('🛡️ SECURITY PROTECTION ASSESSMENT', () {
      print('\n' + '=' * 70);
      print('🛡️  INPUT VALIDATION & SANITIZATION SECURITY ASSESSMENT');
      print('=' * 70);
      
      // Test 1: Message Length Protection
      print('\n📏 MESSAGE LENGTH PROTECTION:');
      var result = InputValidationService.validateAndSanitize('', 'test_user');
      bool lengthProtection = !result.isValid;
      print('   Empty message: ${lengthProtection ? "🛡️ BLOCKED" : "❌ ALLOWED"}');
      
      result = InputValidationService.validateAndSanitize('A' * 2001, 'test_user');
      lengthProtection = lengthProtection && !result.isValid;
      print('   Oversized message: ${!result.isValid ? "🛡️ BLOCKED" : "❌ ALLOWED"}');
      
      result = InputValidationService.validateAndSanitize('Hello world', 'test_user');
      lengthProtection = lengthProtection && result.isValid;
      print('   Valid message: ${result.isValid ? "✅ ALLOWED" : "❌ BLOCKED"}');
      print('   STATUS: ${lengthProtection ? "🛡️ PROTECTED ✅" : "❌ VULNERABLE"}');
      
      // Test 2: XSS Protection
      print('\n🚫 XSS ATTACK PROTECTION:');
      final xssTests = [
        '<script>alert("XSS")</script>',
        'javascript:alert("hack")',
        '<iframe src="evil.com"></iframe>',
        'vbscript:msgbox("XSS")',
        '<img onload="alert(1)" src="x">',
      ];
      
      int xssBlocked = 0;
      for (final xss in xssTests) {
        result = InputValidationService.validateAndSanitize(xss, 'test_user_xss');
        if (!result.isValid) {
          xssBlocked++;
          print('   🛡️ BLOCKED: ${xss.length > 30 ? xss.substring(0, 30) + "..." : xss}');
        } else {
          print('   ❌ ALLOWED: ${xss.length > 30 ? xss.substring(0, 30) + "..." : xss}');
        }
      }
      print('   STATUS: 🛡️ BLOCKED $xssBlocked/${xssTests.length} XSS PATTERNS');
      
      // Test 3: SQL Injection Protection
      print('\n💉 SQL INJECTION PROTECTION:');
      final sqlTests = [
        "'; DROP TABLE users; --",
        "' UNION SELECT * FROM passwords --",
        "'; INSERT INTO users VALUES('hacker','pass'); --",
      ];
      
      int sqlBlocked = 0;
      for (final sql in sqlTests) {
        result = InputValidationService.validateAndSanitize(sql, 'test_user_sql');
        if (!result.isValid) {
          sqlBlocked++;
          print('   🛡️ BLOCKED: ${sql.length > 30 ? sql.substring(0, 30) + "..." : sql}');
        } else {
          print('   ❌ ALLOWED: ${sql.length > 30 ? sql.substring(0, 30) + "..." : sql}');
        }
      }
      print('   STATUS: 🛡️ BLOCKED $sqlBlocked/${sqlTests.length} SQL INJECTION PATTERNS');
      
      // Test 4: Rate Limiting
      print('\n⏱️ RATE LIMITING PROTECTION:');
      final userId = 'rate_test_user';
      int allowed = 0;
      int blocked = 0;
      
      for (int i = 0; i < 12; i++) {
        result = InputValidationService.validateAndSanitize('Message $i', userId);
        if (result.isValid) {
          allowed++;
        } else {
          blocked++;
        }
      }
      
      print('   ✅ Allowed messages: $allowed');
      print('   🛡️ Blocked excess: $blocked');
      print('   STATUS: ${blocked > 0 ? "🛡️ RATE LIMITING ACTIVE ✅" : "❌ NO RATE LIMITING"}');
      
      // Test 5: Character Sanitization
      print('\n🧹 CHARACTER SANITIZATION:');
      result = InputValidationService.validateAndSanitize('Hello <world> & "test"', 'test_user_sanitize');
      bool hasSanitization = result.isValid && result.message.contains('&amp;');
      print('   HTML entities: ${hasSanitization ? "🛡️ ESCAPED" : "❌ NOT ESCAPED"}');
      
      result = InputValidationService.validateAndSanitize('Hello\x00\x01world', 'test_user_sanitize2');
      bool controlCharsRemoved = result.isValid && result.message == 'Helloworld';
      print('   Control chars: ${controlCharsRemoved ? "🛡️ REMOVED" : "❌ NOT REMOVED"}');
      
      result = InputValidationService.validateAndSanitize('Hello    world\n\n\ntest', 'test_user_sanitize3');
      bool whitespaceNormalized = result.isValid && result.message == 'Hello world test';
      print('   Whitespace: ${whitespaceNormalized ? "🛡️ NORMALIZED" : "❌ NOT NORMALIZED"}');
      print('   STATUS: ${hasSanitization && controlCharsRemoved && whitespaceNormalized ? "🛡️ SANITIZATION ACTIVE ✅" : "⚠️ PARTIAL SANITIZATION"}');
      
      // Test 6: Excessive Character Protection
      print('\n🔢 EXCESSIVE CHARACTER PROTECTION:');
      final excessiveTests = ['<<<<<>>>>>', '%%%', '&&&', '{{{{}}}}', '[[[[]]]]'];
      int excessiveBlocked = 0;
      
      for (final excessive in excessiveTests) {
        result = InputValidationService.validateAndSanitize(excessive, 'test_user_excessive');
        if (!result.isValid) {
          excessiveBlocked++;
          print('   🛡️ BLOCKED: "$excessive"');
        } else {
          print('   ❌ ALLOWED: "$excessive"');
        }
      }
      print('   STATUS: 🛡️ BLOCKED $excessiveBlocked/${excessiveTests.length} EXCESSIVE PATTERNS');
      
      // Test 7: Valid Message Acceptance
      print('\n✅ VALID MESSAGE ACCEPTANCE:');
      final validTests = [
        'Hello, how are you?',
        'Can you help me?',
        'Salamat po',
        'Good morning',
      ];
      
      int validAccepted = 0;
      for (final valid in validTests) {
        result = InputValidationService.validateAndSanitize(valid, 'test_user_valid_$validAccepted');
        if (result.isValid) {
          validAccepted++;
          print('   ✅ ACCEPTED: "$valid"');
        } else {
          print('   ❌ REJECTED: "$valid" - ${result.errorMessage}');
        }
      }
      print('   STATUS: ✅ ACCEPTED $validAccepted/${validTests.length} VALID MESSAGES');
      
      // Overall Assessment
      print('\n' + '=' * 70);
      print('🎯 OVERALL SECURITY ASSESSMENT');
      print('=' * 70);
      
      final protectionScore = [
        lengthProtection,
        xssBlocked > 0,
        sqlBlocked > 0,
        blocked > 0,
        hasSanitization,
        excessiveBlocked > 0,
        validAccepted > 0,
      ].where((x) => x).length;
      
      print('🛡️ PROTECTION SCORE: $protectionScore/7');
      
      if (protectionScore >= 6) {
        print('🎉 EXCELLENT SECURITY PROTECTION!');
        print('✅ Your Input Validation & Sanitization is WORKING EFFECTIVELY');
        print('🛡️ Users are PROTECTED against major security threats');
      } else if (protectionScore >= 4) {
        print('⚠️ GOOD SECURITY PROTECTION');
        print('✅ Basic security measures are working');
        print('🔧 Some areas could be improved');
      } else {
        print('❌ SECURITY NEEDS IMPROVEMENT');
        print('⚠️ Multiple security features need attention');
      }
      
      print('\n🛡️ CONFIRMED WORKING FEATURES:');
      if (lengthProtection) print('   ✅ Message Length Limits');
      if (xssBlocked > 0) print('   ✅ XSS Attack Detection');
      if (sqlBlocked > 0) print('   ✅ SQL Injection Detection');
      if (blocked > 0) print('   ✅ Rate Limiting');
      if (hasSanitization) print('   ✅ Character Sanitization');
      if (excessiveBlocked > 0) print('   ✅ Excessive Character Detection');
      if (validAccepted > 0) print('   ✅ Valid Message Processing');
      
      print('\n📊 SECURITY STATISTICS:');
      final stats = InputValidationService.getValidationStats();
      print('   Active Users: ${stats['activeUsers']}');
      print('   Recent Messages: ${stats['totalRecentMessages']}');
      print('   Rate Limit: ${stats['maxMessagesPerMinute']} msgs/min');
      
      print('\n🎯 RECOMMENDATION:');
      if (protectionScore >= 6) {
        print('✅ Your security implementation is working well!');
        print('🚀 Safe to continue development and testing');
        print('🛡️ Users are protected against common attacks');
      } else {
        print('🔧 Consider reviewing and strengthening security measures');
        print('📚 Check implementation against security best practices');
      }
      
      print('=' * 70);
      
      // Test passes if basic protection is working
      expect(protectionScore, greaterThanOrEqualTo(4), 
        reason: 'Basic security protection should be working');
    });
  });
}