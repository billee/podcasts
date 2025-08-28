# 🛡️ Practical Security Tests

This folder contains **organized security test suites** for different security features in your chat application. Each subfolder focuses on specific security implementations with comprehensive test coverage.

## 📁 Test Organization

### 🛡️ **Input Validation & Sanitization/**
**Complete security test suite** for input validation and sanitization features:

- ✅ **Message Length Limits** (2000 character max)
- ✅ **HTML/Script Injection Protection** 
- ✅ **SQL Injection Protection**
- ✅ **Character Filtering** (suspicious patterns)
- ✅ **Rate Limiting** (spam prevention)
- ✅ **Input Type Validation** (sanitization)
- ✅ **Prompt Injection Protection** (LLM manipulation)
- ✅ **Complex Attack Scenarios** (multi-vector attacks)
- ✅ **Valid Message Acceptance** (normal conversation)

**Files:**
- `security_status_test.dart` - **Quick assessment (RECOMMENDED)**
- `input_validation_security_test.dart` - Comprehensive test suite
- `working_security_test.dart` - Shows what's working
- `run_security_assessment.bat/.sh` - Easy runners
- `README.md` - Complete documentation

## 🚀 How to Run Tests

### **🌟 Quick Security Assessment (RECOMMENDED):**
```bash
# Windows
"test/practical/Input Validation & Sanitization/run_security_assessment.bat"

# Linux/Mac  
bash "test/practical/Input Validation & Sanitization/run_security_assessment.sh"

# Direct Flutter command
flutter test "test/practical/Input Validation & Sanitization/security_status_test.dart" --reporter=expanded
```

### **📋 Comprehensive Test Suite:**
```bash
flutter test "test/practical/Input Validation & Sanitization/input_validation_security_test.dart" --reporter=expanded
```

### **🔍 Working Features Test:**
```bash
flutter test "test/practical/Input Validation & Sanitization/working_security_test.dart" --reporter=expanded
```

## 📊 Understanding Test Results

### ✅ **SUCCESS - All Tests Pass**
```
🎉 ALL SECURITY TESTS PASSED!
✅ Your Input Validation & Sanitization is WORKING CORRECTLY
🛡️  Your chat application is PROTECTED against:
   • XSS (Cross-Site Scripting) attacks
   • SQL injection attempts  
   • Script injection attacks
   • Prompt injection attacks
   • Rate limiting abuse (spam/DoS)
   • Data corruption attempts
   • Malicious character patterns
   • Complex multi-vector attacks

✨ SECURITY STATUS: FULLY PROTECTED ✅
```

### ❌ **FAILURE - Security Issues Detected**
```
❌ SOME SECURITY TESTS FAILED!
⚠️  SECURITY VULNERABILITIES DETECTED!
🔧 Please review the test output above and fix the issues.
🚨 DO NOT deploy to production until all tests pass!
```

## 🧪 Test Examples

### XSS Attack Test
```dart
// Test Input: '<script>alert("XSS")</script>'
// Expected: BLOCKED ❌
// Result: ✅ Blocked HTML/Script: "<script>alert("XSS")</script>"
// Status: 🛡️ XSS PROTECTION: ACTIVE ✅
```

### SQL Injection Test  
```dart
// Test Input: "'; DROP TABLE users; --"
// Expected: BLOCKED ❌
// Result: ✅ Blocked SQL Injection: "'; DROP TABLE users; --"
// Status: 🛡️ SQL INJECTION PROTECTION: ACTIVE ✅
```

### Valid Message Test
```dart
// Test Input: "Hello, how are you?"
// Expected: ALLOWED ✅
// Result: ✅ Valid message accepted: "Hello, how are you?"
// Status: 🛡️ LEGITIMATE CONVERSATION: WORKING ✅
```

### Rate Limiting Test
```dart
// Test: Send 11 messages rapidly
// Messages 1-10: ✅ ALLOWED
// Message 11: ❌ BLOCKED - "Rate limit exceeded"
// Status: 🛡️ RATE LIMITING PROTECTION: ACTIVE ✅
```

## 🛡️ Security Features Tested

### **Frontend (Flutter) Protection**
- **Message Length Limits**: Prevents buffer overflow attacks
- **Input Sanitization**: Strips dangerous HTML/script tags
- **Character Filtering**: Blocks suspicious patterns like `javascript:`
- **Rate Limiting**: Prevents spam and DoS attacks
- **Input Type Validation**: Ensures clean text input only

### **Attack Vectors Tested**
- **XSS Attacks**: `<script>`, `javascript:`, `onload=`, etc.
- **SQL Injection**: `UNION SELECT`, `DROP TABLE`, `'OR'1'='1`, etc.
- **Prompt Injection**: "ignore instructions", "act as", etc.
- **Character Abuse**: Excessive `<>`, `%`, `&` patterns
- **Complex Attacks**: Multi-vector combinations

### **Data Integrity Validation**
- **HTML Entity Escaping**: `<` → `&lt;`, `&` → `&amp;`
- **Control Character Removal**: Strips `\x00`, `\x01`, etc.
- **Whitespace Normalization**: Cleans excessive spaces/newlines
- **Size Enforcement**: Respects character limits

## 🔧 Troubleshooting

### Common Issues

1. **Tests fail to run**
   ```bash
   # Make sure you're in the project root
   cd /path/to/your/flutter/project
   
   # Install dependencies
   flutter pub get
   
   # Run tests
   flutter test test/practical/input_validation_security_test.dart
   ```

2. **Import errors**
   - Ensure `input_validation_service.dart` exists in `lib/services/`
   - Ensure `config.dart` exists in `lib/core/`
   - Check that all imports are correct

3. **Rate limiting tests fail**
   - Ensure `cleanupRateLimitData()` method exists
   - Check that rate limiting is properly implemented
   - Verify user ID handling is working

4. **Validation tests fail**
   - Check that validation patterns are correctly implemented
   - Ensure error messages match expected strings
   - Verify sanitization functions are working

### Debug Mode
To see detailed validation logs, add this to your service:
```dart
print('Validating: $message');
print('Result: $isValid, Error: $errorMessage');
```

## 📈 Expected Test Flow

1. **Setup**: Clean rate limit data
2. **Length Tests**: Empty, oversized, valid messages
3. **Sanitization Tests**: HTML tags, SQL patterns
4. **Character Tests**: Suspicious patterns, excessive chars
5. **Rate Limiting**: Spam prevention validation
6. **Type Validation**: Character sanitization
7. **Prompt Injection**: LLM manipulation attempts
8. **Complex Attacks**: Multi-vector scenarios
9. **Valid Messages**: Normal conversation acceptance
10. **Statistics**: Monitoring functionality
11. **Summary**: Overall protection assessment

## 🎯 Security Checklist

Before deploying, ensure these tests show:

- [ ] ✅ Message length limits enforced
- [ ] ✅ XSS attacks blocked
- [ ] ✅ SQL injection blocked  
- [ ] ✅ Script injection blocked
- [ ] ✅ Prompt injection blocked
- [ ] ✅ Rate limiting working
- [ ] ✅ Character sanitization active
- [ ] ✅ Valid messages accepted
- [ ] ✅ Error messages informative
- [ ] ✅ Statistics monitoring working

## 🚨 Security Warning

**DO NOT skip these tests!** 

- These tests validate **real security threats**
- Failing tests mean **your app is vulnerable**
- **Never deploy** with failing security tests
- Run tests **before every deployment**

## 📞 Need Help?

If tests fail or you need assistance:

1. **Check the detailed test output** for specific failures
2. **Review your `input_validation_service.dart`** implementation
3. **Ensure all security patterns** are properly implemented
4. **Verify configuration values** in `config.dart`
5. **Test individual components** if needed

Remember: **Security is not optional** - these tests ensure your users are protected!