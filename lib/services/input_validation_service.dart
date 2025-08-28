// lib/services/input_validation_service.dart

import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/core/config.dart';

/// Service for validating and sanitizing user input in the chat
class InputValidationService {
  static final Logger _logger = Logger('InputValidationService');
  
  // Import configuration from AppConfig
  static int get maxMessageLength => AppConfig.maxMessageLength;
  static int get minMessageLength => AppConfig.minMessageLength;
  static int get maxMessagesPerMinute => AppConfig.maxMessagesPerMinute;
  static Duration get rateLimitWindow => AppConfig.rateLimitWindow;
  
  // Suspicious patterns to detect
  static final List<RegExp> _suspiciousPatterns = [
    // HTML/Script injection
    RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false),
    RegExp(r'<iframe[^>]*>.*?</iframe>', caseSensitive: false),
    RegExp(r'javascript:', caseSensitive: false),
    RegExp(r'vbscript:', caseSensitive: false),
    RegExp(r'onload\s*=', caseSensitive: false),
    RegExp(r'onerror\s*=', caseSensitive: false),
    
    // SQL injection patterns
    RegExp(r'(union\s+select|drop\s+table|delete\s+from)', caseSensitive: false),
    RegExp(r'(insert\s+into|update\s+set|alter\s+table)', caseSensitive: false),
    
    // Prompt injection attempts
    RegExp(r'ignore\s+(previous|all)\s+instructions?', caseSensitive: false),
    RegExp(r'system\s*:\s*you\s+are', caseSensitive: false),
    RegExp(r'forget\s+(everything|all|your\s+role)', caseSensitive: false),
    RegExp(r'act\s+as\s+(if\s+you\s+are|a)', caseSensitive: false),
    
    // Excessive special characters (potential encoding attacks)
    RegExp(r'[<>{}[\]\\]{5,}'),
    RegExp(r'[%]{3,}'),
    RegExp(r'[&]{3,}'),
  ];
  
  // Characters to remove/replace
  static final Map<String, String> _characterReplacements = {
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#x27;',
    '&': '&amp;',
  };
  
  // Rate limiting storage (in production, use Redis or database)
  static final Map<String, List<DateTime>> _userMessageTimes = {};

  /// Validates and sanitizes user input
  /// Returns ValidationResult with sanitized message or error
  static ValidationResult validateAndSanitize(String message, String userId) {
    try {
      _logger.info('Validating message from user: $userId');
      
      // 1. Check rate limiting
      final rateLimitResult = _checkRateLimit(userId);
      if (!rateLimitResult.isValid) {
        return rateLimitResult;
      }
      
      // 2. Check message length
      final lengthResult = _validateLength(message);
      if (!lengthResult.isValid) {
        return lengthResult;
      }
      
      // 3. Check for suspicious patterns
      final patternResult = _checkSuspiciousPatterns(message);
      if (!patternResult.isValid) {
        return patternResult;
      }
      
      // 4. Sanitize the message
      final sanitizedMessage = _sanitizeMessage(message);
      
      // 5. Record message time for rate limiting
      _recordMessageTime(userId);
      
      _logger.info('Message validation successful for user: $userId');
      return ValidationResult.success(sanitizedMessage);
      
    } catch (e) {
      _logger.severe('Error during input validation: $e');
      return ValidationResult.error('Message validation failed. Please try again.');
    }
  }
  
  /// Check rate limiting for user
  static ValidationResult _checkRateLimit(String userId) {
    final now = DateTime.now();
    final userTimes = _userMessageTimes[userId] ?? [];
    
    // Remove old timestamps outside the rate limit window
    userTimes.removeWhere((time) => now.difference(time) > rateLimitWindow);
    
    if (userTimes.length >= maxMessagesPerMinute) {
      _logger.warning('Rate limit exceeded for user: $userId');
      return ValidationResult.error(
        'You are sending messages too quickly. Please wait a moment before sending another message.'
      );
    }
    
    return ValidationResult.success('');
  }
  
  /// Validate message length
  static ValidationResult _validateLength(String message) {
    final trimmedMessage = message.trim();
    
    if (trimmedMessage.isEmpty || trimmedMessage.length < minMessageLength) {
      return ValidationResult.error('Message cannot be empty.');
    }
    
    if (trimmedMessage.length > maxMessageLength) {
      _logger.warning('Message too long: ${trimmedMessage.length} characters');
      return ValidationResult.error(
        'Message is too long. Maximum length is $maxMessageLength characters.'
      );
    }
    
    return ValidationResult.success(trimmedMessage);
  }
  
  /// Check for suspicious patterns in the message
  static ValidationResult _checkSuspiciousPatterns(String message) {
    for (final pattern in _suspiciousPatterns) {
      if (pattern.hasMatch(message)) {
        _logger.warning('Suspicious pattern detected in message: ${pattern.pattern}');
        return ValidationResult.error(
          'Your message contains content that is not allowed. Please rephrase your message.'
        );
      }
    }
    
    return ValidationResult.success(message);
  }
  
  /// Sanitize message by escaping dangerous characters
  static String _sanitizeMessage(String message) {
    String sanitized = message;
    
    // Replace dangerous characters
    _characterReplacements.forEach((char, replacement) {
      sanitized = sanitized.replaceAll(char, replacement);
    });
    
    // Remove null bytes and other control characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    
    // Normalize whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return sanitized;
  }
  
  /// Record message time for rate limiting
  static void _recordMessageTime(String userId) {
    final now = DateTime.now();
    _userMessageTimes[userId] ??= [];
    _userMessageTimes[userId]!.add(now);
  }
  
  /// Clear old rate limit data (call periodically to prevent memory leaks)
  static void cleanupRateLimitData() {
    final now = DateTime.now();
    _userMessageTimes.removeWhere((userId, times) {
      times.removeWhere((time) => now.difference(time) > rateLimitWindow);
      return times.isEmpty;
    });
    _logger.info('Rate limit data cleanup completed. Active users: ${_userMessageTimes.length}');
  }
  
  /// Initialize periodic cleanup (call once at app startup)
  static void initializePeriodicCleanup() {
    // Clean up every 5 minutes
    Stream.periodic(Duration(minutes: 5)).listen((_) {
      cleanupRateLimitData();
    });
  }
  
  /// Check if a message contains potential encoding attacks
  static bool _containsEncodingAttack(String message) {
    // Check for base64 patterns
    if (RegExp(r'^[A-Za-z0-9+/]{20,}={0,2}$').hasMatch(message.replaceAll(' ', ''))) {
      return true;
    }
    
    // Check for URL encoding patterns
    if (RegExp(r'%[0-9A-Fa-f]{2}').allMatches(message).length > 5) {
      return true;
    }
    
    // Check for Unicode escape sequences
    if (RegExp(r'\\u[0-9A-Fa-f]{4}').allMatches(message).length > 3) {
      return true;
    }
    
    return false;
  }
  
  /// Get validation statistics for monitoring
  static Map<String, dynamic> getValidationStats() {
    final now = DateTime.now();
    int activeUsers = 0;
    int totalRecentMessages = 0;
    
    _userMessageTimes.forEach((userId, times) {
      final recentMessages = times.where((time) => 
        now.difference(time) <= rateLimitWindow
      ).length;
      
      if (recentMessages > 0) {
        activeUsers++;
        totalRecentMessages += recentMessages;
      }
    });
    
    return {
      'activeUsers': activeUsers,
      'totalRecentMessages': totalRecentMessages,
      'rateLimitWindow': rateLimitWindow.inMinutes,
      'maxMessagesPerMinute': maxMessagesPerMinute,
    };
  }
}

/// Result of input validation
class ValidationResult {
  final bool isValid;
  final String message;
  final String? errorMessage;
  
  const ValidationResult._({
    required this.isValid,
    required this.message,
    this.errorMessage,
  });
  
  factory ValidationResult.success(String sanitizedMessage) {
    return ValidationResult._(
      isValid: true,
      message: sanitizedMessage,
    );
  }
  
  factory ValidationResult.error(String errorMessage) {
    return ValidationResult._(
      isValid: false,
      message: '',
      errorMessage: errorMessage,
    );
  }
}