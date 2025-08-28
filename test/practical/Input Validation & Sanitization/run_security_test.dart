#!/usr/bin/env dart

/// Security Test Runner
/// Executes the input validation security tests and shows protection status
/// 
/// Usage: dart test/practical/Input\ Validation\ \&\ Sanitization/run_security_test.dart
/// Or: flutter test "test/practical/Input Validation & Sanitization/input_validation_security_test.dart"

import 'dart:io';

void main() async {
  print('🚀 Starting Input Validation & Sanitization Security Test...');
  print('=' * 70);
  
  try {
    // Run the Flutter test
    final result = await Process.run(
      'flutter',
      ['test', 'test/practical/Input Validation & Sanitization/input_validation_security_test.dart', '--reporter=expanded'],
      workingDirectory: Directory.current.path,
    );
    
    print('📋 TEST OUTPUT:');
    print('-' * 40);
    print(result.stdout);
    
    if (result.stderr.isNotEmpty) {
      print('⚠️  STDERR:');
      print(result.stderr);
    }
    
    print('\n' + '=' * 70);
    
    if (result.exitCode == 0) {
      print('🎉 ALL SECURITY TESTS PASSED!');
      print('✅ Your Input Validation & Sanitization is WORKING CORRECTLY');
      print('🛡️  Your chat application is PROTECTED against:');
      print('   • XSS (Cross-Site Scripting) attacks');
      print('   • SQL injection attempts');
      print('   • Script injection attacks');
      print('   • Prompt injection attacks');
      print('   • Rate limiting abuse (spam/DoS)');
      print('   • Data corruption attempts');
      print('   • Malicious character patterns');
      print('   • Complex multi-vector attacks');
      print('\n✨ SECURITY STATUS: FULLY PROTECTED ✅');
    } else {
      print('❌ SOME SECURITY TESTS FAILED!');
      print('⚠️  SECURITY VULNERABILITIES DETECTED!');
      print('🔧 Please review the test output above and fix the issues.');
      print('🚨 DO NOT deploy to production until all tests pass!');
    }
    
    print('=' * 70);
    exit(result.exitCode);
    
  } catch (e) {
    print('❌ Error running security tests: $e');
    print('💡 Make sure Flutter is installed and you\'re in the project root');
    print('💡 Try running: flutter test "test/practical/Input Validation & Sanitization/input_validation_security_test.dart"');
    exit(1);
  }
}