#!/usr/bin/env dart

/// Script to run integration tests for the user management system
/// This script provides a convenient way to run all integration tests
/// with proper setup and reporting.

import 'dart:io';

void main(List<String> args) async {
  print('🚀 Starting User Management System Integration Tests...\n');

  // Set up test environment
  final testFiles = [
    'test/integration/user_journey_test.dart',
  ];

  var allTestsPassed = true;
  var totalTests = 0;
  var passedTests = 0;

  for (final testFile in testFiles) {
    print('📋 Running tests in: $testFile');
    
    final result = await Process.run(
      'flutter',
      ['test', testFile, '--reporter=expanded'],
      runInShell: true,
    );

    if (result.exitCode == 0) {
      print('✅ Tests passed in $testFile\n');
      // Parse output to count tests (simplified)
      final output = result.stdout.toString();
      final matches = RegExp(r'\+(\d+):').allMatches(output);
      if (matches.isNotEmpty) {
        final testCount = int.parse(matches.last.group(1) ?? '0');
        totalTests += testCount;
        passedTests += testCount;
      }
    } else {
      print('❌ Tests failed in $testFile');
      print('Error output:');
      print(result.stderr);
      print('Standard output:');
      print(result.stdout);
      allTestsPassed = false;
    }
  }

  // Print summary
  print('📊 Integration Test Summary:');
  print('   Total Tests: $totalTests');
  print('   Passed: $passedTests');
  print('   Failed: ${totalTests - passedTests}');
  
  if (allTestsPassed) {
    print('🎉 All integration tests passed successfully!');
    exit(0);
  } else {
    print('💥 Some integration tests failed.');
    exit(1);
  }
}