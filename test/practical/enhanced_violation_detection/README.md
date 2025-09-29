# Enhanced Violation Detection Test Suite

This directory contains comprehensive tests for the enhanced violation detection system that implements multi-layered security checks before and after LLM processing.

## Test Structure

- `enhanced_violation_detection_test.dart` - Main test file with automated test cases
- `test_data/` - Directory containing test data and examples
- `mock_services/` - Mock implementations for testing
- `results/` - Test results and reports

## Test Categories

1. **Pre-LLM Filtering Tests**
   - Pattern matching
   - Keyword blacklists
   - Context analysis
   - Input sanitization

2. **Advanced Detection Tests**
   - Sentiment analysis
   - Language detection
   - Prompt injection detection
   - Encoding detection

3. **Integration Tests**
   - End-to-end violation detection
   - Performance benchmarks
   - False positive/negative analysis

## Running Tests

```bash
flutter test test/practical/enhanced_violation_detection/
```

## Expected Results

The tests will show:
- ✅ Protected messages that are correctly blocked
- ❌ Vulnerabilities that need attention
- 📊 Performance metrics
- 📈 Detection accuracy rates



# Run all tests
flutter test test/practical/enhanced_violation_detection/

# Run with detailed output
flutter test test/practical/enhanced_violation_detection/ --reporter=expanded

# Run standalone
dart run test/practical/enhanced_violation_detection/run_tests.dart
