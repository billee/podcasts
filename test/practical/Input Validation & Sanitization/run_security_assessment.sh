#!/bin/bash
echo "🛡️ Running Input Validation & Sanitization Security Assessment..."
echo
flutter test "test/practical/Input Validation & Sanitization/security_status_test.dart" --reporter=expanded
echo
echo "🎯 Security assessment complete!"