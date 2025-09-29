# 🎯 Code Coverage Guide for Enhanced Violation Detection

## 📊 Current Test Coverage Status

### ✅ **What's Currently Covered**
- **Mock Enhanced Violation Detector** (100% coverage)
- **Test Data & Attack Scenarios** (45+ test cases)
- **Detection Algorithms** (All security layers tested)
- **Performance Benchmarks** (Speed & accuracy metrics)

### ❌ **What's NOT Currently Covered**
- **Your actual production services**
- **Real Firebase/Firestore integration**
- **Chat screen violation flow**
- **End-to-end user experience**

## 🔧 How to Achieve Full Code Coverage

### **Step 1: Replace Mock with Real Implementation**

```dart
// In your test files, replace:
import 'mock_services/enhanced_violation_detector.dart';

// With your actual services:
import 'package:kapwa_companion_basic/services/violation_check_service.dart';
import 'package:kapwa_companion_basic/services/violation_logging_service.dart';
```

### **Step 2: Test Your Actual ViolationCheckService**

```dart
test('Real ViolationCheckService Coverage', () async {
  // Test all methods in your actual service
  final result = await ViolationCheckService.shouldShowViolationWarning('user123');
  expect(result, isA<bool>());
  
  // Test edge cases
  await ViolationCheckService.markAllExistingViolationsAsShown('user123');
  
  // Test error handling
  expect(() => ViolationCheckService.shouldShowViolationWarning(''), 
         throwsA(isA<Exception>()));
});
```

### **Step 3: Test Your Chat Screen Integration**

```dart
testWidgets('Chat Screen Violation Flow Coverage', (tester) async {
  // Test violation warning display
  await tester.pumpWidget(ChatScreen(userId: 'test_user'));
  
  // Test message input validation
  await tester.enterText(find.byType(TextField), "malicious input");
  await tester.tap(find.byIcon(Icons.send));
  
  // Verify violation handling
  expect(find.text('Message blocked'), findsOneWidget);
});
```

## 📈 Coverage Metrics to Track

### **Service Coverage**
- [ ] `ViolationCheckService.shouldShowViolationWarning()`
- [ ] `ViolationCheckService.markAllExistingViolationsAsShown()`
- [ ] `ViolationLoggingService.logViolation()`
- [ ] `ViolationLoggingService.getUserViolationCount()`

### **Chat Screen Coverage**
- [ ] Violation warning display logic
- [ ] Message input validation
- [ ] Violation logging on send
- [ ] User feedback on blocked messages

### **Error Handling Coverage**
- [ ] Network failures
- [ ] Firestore connection issues
- [ ] Invalid user IDs
- [ ] Malformed violation data

## 🚀 Running Coverage Analysis

### **Generate Coverage Report**
```bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open coverage report
open coverage/html/index.html
```

### **Target Coverage Metrics**
- **Line Coverage**: >90%
- **Function Coverage**: >95%
- **Branch Coverage**: >85%

## 🔍 What Changes Will Be Covered

### **If You Modify ViolationCheckService:**
```dart
// Your changes to this method will be tested:
static Future<bool> shouldShowViolationWarning(String userId) async {
  // Any modifications here will be caught by tests
  // if you have proper integration tests
}
```

### **If You Modify Chat Screen:**
```dart
// Your changes to violation handling will be tested:
Future<void> _sendMessage() async {
  // Enhanced detection logic changes
  final isViolation = await detectViolations(message);
  if (isViolation) {
    // This flow will be tested
  }
}
```

### **If You Add New Detection Methods:**
```dart
// Add corresponding test cases:
test('New Detection Method', () async {
  final result = await yourNewDetectionMethod('test input');
  expect(result.isViolation, true);
});
```

## 📋 Coverage Checklist

### **Before Making Code Changes:**
- [ ] Run existing tests to establish baseline
- [ ] Check current coverage percentage
- [ ] Identify which files will be modified

### **After Making Code Changes:**
- [ ] Run all tests to ensure they still pass
- [ ] Check if coverage percentage decreased
- [ ] Add new tests for new functionality
- [ ] Update test cases if behavior changed

### **For New Features:**
- [ ] Add test cases to `violation_test_cases.dart`
- [ ] Create integration tests for new services
- [ ] Test error conditions and edge cases
- [ ] Verify performance impact

## 🛡️ Continuous Coverage Monitoring

### **Set Up Pre-commit Hooks**
```bash
# .git/hooks/pre-commit
#!/bin/sh
flutter test --coverage
if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi
```

### **CI/CD Integration**
```yaml
# .github/workflows/test.yml
- name: Run Tests with Coverage
  run: flutter test --coverage
  
- name: Upload Coverage
  uses: codecov/codecov-action@v1
  with:
    file: coverage/lcov.info
```

## 🎯 Specific Areas to Test When You Modify Code

### **ViolationCheckService Changes:**
- Test all public methods
- Test with various user IDs
- Test error conditions
- Test Firestore integration

### **Chat Screen Changes:**
- Test violation warning display
- Test message input handling
- Test user interactions
- Test state management

### **New Detection Logic:**
- Add to `ViolationTestCases`
- Test with attack vectors
- Test with legitimate content
- Measure performance impact

## 📊 Coverage Report Example

```
File                           Lines    Functions    Branches    Coverage
violation_check_service.dart   45/50    8/10        12/15       85%
violation_logging_service.dart 38/40    6/6         10/12       92%
chat_screen.dart              120/150   15/18       25/30       78%
enhanced_violation_detector.dart 200/200 20/20      40/40       100%
```

## 🚨 Red Flags (Low Coverage Areas)

If you see coverage below 80% in these areas, add more tests:
- Error handling paths
- Edge case conditions
- User interaction flows
- Network failure scenarios

## ✅ Best Practices

1. **Test Before You Code**: Write tests for new features first
2. **Test After You Code**: Ensure changes don't break existing tests
3. **Test Edge Cases**: Don't just test the happy path
4. **Test Performance**: Ensure changes don't slow down detection
5. **Test Integration**: Verify services work together correctly

With proper integration of these tests with your actual code, you'll have comprehensive coverage that catches regressions and ensures your security enhancements work as expected!