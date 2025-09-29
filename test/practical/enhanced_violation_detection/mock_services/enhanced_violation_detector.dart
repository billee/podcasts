// test/practical/enhanced_violation_detection/mock_services/enhanced_violation_detector.dart

import 'dart:convert';
import 'dart:math';

class ViolationResult {
  final bool isViolation;
  final List<String> violationTypes;
  final double confidence;
  final String? reason;
  final Map<String, dynamic> metadata;

  // Specific result properties
  final double? sentimentScore;
  final String? detectedLanguage;
  final String? riskLevel;
  final String? detectedEncoding;

  ViolationResult({
    required this.isViolation,
    this.violationTypes = const [],
    this.confidence = 0.0,
    this.reason,
    this.metadata = const {},
    this.sentimentScore,
    this.detectedLanguage,
    this.riskLevel,
    this.detectedEncoding,
  });
}

class EnhancedViolationDetector {
  
  // Keyword blacklists
  static final List<String> _profanityKeywords = [
    'f***ing', 'idiot', 'stupid', 'hate', 'kill', 'sex', 'cocaine', 'f4ck1ng', '1d10t'
  ];
  
  static final List<String> _promptInjectionKeywords = [
    'ignore', 'instructions', 'system prompt', 'dan mode', 'developer mode',
    'jailbreak', 'override', 'pretend', 'hypothetical', 'debug', 'previous',
    'evil ai', 'no restrictions', 'game', 'play', 'role', 'activated'
  ];

  // Enhanced prompt injection patterns
  static final List<RegExp> _promptInjectionPatterns = [
    RegExp(r'ignore\s+.*?instructions', caseSensitive: false),
    RegExp(r'pretend\s+.*?(evil|unrestricted)', caseSensitive: false),
    RegExp(r'game\s+.*?restrictions', caseSensitive: false),
    RegExp(r'hypothetical\s+.*?guidelines', caseSensitive: false),
    RegExp(r'developer\s+mode', caseSensitive: false),
    RegExp(r'dan\s+mode', caseSensitive: false),
  ];

  // Pattern matching regexes
  static final List<RegExp> _sqlInjectionPatterns = [
    RegExp(r"';\s*DROP\s+TABLE", caseSensitive: false),
    RegExp(r"UNION\s+SELECT", caseSensitive: false),
    RegExp(r"--", caseSensitive: false),
  ];

  static final List<RegExp> _xssPatterns = [
    RegExp(r"<script.*?>.*?</script>", caseSensitive: false),
    RegExp(r"javascript:", caseSensitive: false),
    RegExp(r"on\w+\s*=", caseSensitive: false),
  ];

  /// Pattern Matching Detection
  Future<ViolationResult> detectPatternViolations(String input) async {
    final violations = <String>[];
    
    // Check SQL injection patterns
    for (final pattern in _sqlInjectionPatterns) {
      if (pattern.hasMatch(input)) {
        violations.add('sql_injection');
        break;
      }
    }
    
    // Check XSS patterns
    for (final pattern in _xssPatterns) {
      if (pattern.hasMatch(input)) {
        violations.add('xss_attack');
        break;
      }
    }
    
    return ViolationResult(
      isViolation: violations.isNotEmpty,
      violationTypes: violations,
      confidence: violations.isNotEmpty ? 0.95 : 0.0,
      reason: violations.isNotEmpty ? 'Malicious pattern detected' : null,
    );
  }

  /// Keyword Blacklist Detection
  Future<ViolationResult> detectKeywordViolations(String input) async {
    final violations = <String>[];
    final lowerInput = input.toLowerCase();
    
    // Enhanced context-aware profanity detection
    final isAcademicContext = _isAcademicContext(input);
    
    // Check profanity (skip if academic context)
    if (!isAcademicContext) {
      for (final keyword in _profanityKeywords) {
        if (lowerInput.contains(keyword.toLowerCase())) {
          violations.add('profanity');
          break;
        }
      }
      
      // Check for leetspeak variations
      final normalizedInput = _normalizeLeetspeak(lowerInput);
      for (final keyword in _profanityKeywords) {
        if (normalizedInput.contains(keyword.toLowerCase())) {
          violations.add('profanity_leetspeak');
          break;
        }
      }
    }
    
    return ViolationResult(
      isViolation: violations.isNotEmpty,
      violationTypes: violations,
      confidence: violations.isNotEmpty ? 0.90 : 0.0,
      reason: violations.isNotEmpty ? 'Inappropriate language detected' : null,
    );
  }

  /// Context Analysis Detection
  Future<ViolationResult> detectContextViolations(String input, List<String> context) async {
    final violations = <String>[];
    
    if (context.isEmpty) {
      return ViolationResult(isViolation: false);
    }
    
    // Enhanced escalating harassment detection
    int negativeCount = 0;
    int aggressionLevel = 0;
    
    for (final message in context) {
      if (_isNegativeMessage(message)) {
        negativeCount++;
        aggressionLevel += _getAggressionLevel(message);
      }
    }
    
    // Current message aggression
    final currentAggression = _getAggressionLevel(input);
    final isCurrentNegative = _isNegativeMessage(input);
    
    // Detect escalation pattern - more sensitive detection
    if (negativeCount >= 2 && isCurrentNegative) {
      violations.add('harassment_escalation');
    } else if (negativeCount >= 1 && currentAggression >= 2) {
      violations.add('harassment_escalation');
    } else if (aggressionLevel >= 2 && currentAggression >= 1) {
      violations.add('harassment_escalation');
    }
    
    // Check for repeated inappropriate requests
    int inappropriateCount = 0;
    for (final message in context) {
      if (_isInappropriateRequest(message)) {
        inappropriateCount++;
      }
    }
    
    if (inappropriateCount >= 2 && _isInappropriateRequest(input)) {
      violations.add('repeated_inappropriate_requests');
    }
    
    return ViolationResult(
      isViolation: violations.isNotEmpty,
      violationTypes: violations,
      confidence: violations.isNotEmpty ? 0.85 : 0.0,
      reason: violations.isNotEmpty ? 'Contextual violation pattern detected' : null,
    );
  }

  /// Sentiment Analysis Detection
  Future<ViolationResult> detectSentimentViolations(String input) async {
    final sentimentScore = _calculateSentimentScore(input);
    final intensityScore = _calculateIntensityScore(input);
    
    // Adjusted threshold based on both sentiment and intensity
    final isViolation = (sentimentScore < -0.4 && intensityScore > 0.3) || sentimentScore < -0.6;
    
    return ViolationResult(
      isViolation: isViolation,
      violationTypes: isViolation ? ['negative_sentiment'] : [],
      confidence: isViolation ? 0.80 : 0.0,
      reason: isViolation ? 'Extremely negative sentiment detected' : null,
      sentimentScore: sentimentScore,
    );
  }

  /// Language Detection
  Future<ViolationResult> detectLanguageViolations(String input) async {
    final detectedLanguage = _detectLanguage(input);
    final isViolation = detectedLanguage != 'en';
    
    return ViolationResult(
      isViolation: isViolation,
      violationTypes: isViolation ? ['non_english_language'] : [],
      confidence: isViolation ? 0.95 : 0.0,
      reason: isViolation ? 'Non-English language detected: $detectedLanguage' : null,
      detectedLanguage: detectedLanguage,
    );
  }

  /// Prompt Injection Detection
  Future<ViolationResult> detectPromptInjection(String input) async {
    final violations = <String>[];
    final lowerInput = input.toLowerCase();
    final normalizedInput = _normalizeForPromptInjection(input);
    
    // Check for prompt injection patterns first
    for (final pattern in _promptInjectionPatterns) {
      if (pattern.hasMatch(normalizedInput)) {
        violations.add('prompt_injection_pattern_match');
        break;
      }
    }
    
    // Check for prompt injection keywords
    int suspiciousKeywords = 0;
    for (final keyword in _promptInjectionKeywords) {
      if (lowerInput.contains(keyword)) {
        suspiciousKeywords++;
      }
    }
    
    String riskLevel = 'low';
    if (suspiciousKeywords >= 3 || violations.isNotEmpty) {
      violations.add('prompt_injection_high_risk');
      riskLevel = 'high';
    } else if (suspiciousKeywords >= 2) {
      violations.add('prompt_injection_medium_risk');
      riskLevel = 'medium';
    } else if (suspiciousKeywords >= 1) {
      riskLevel = 'low';
    }
    
    // Enhanced specific pattern checks
    if ((lowerInput.contains('ignore') && lowerInput.contains('instructions')) ||
        (lowerInput.contains('pretend') && lowerInput.contains('evil')) ||
        (lowerInput.contains('game') && lowerInput.contains('restrictions')) ||
        (lowerInput.contains('hypothetical') && lowerInput.contains('guidelines')) ||
        (lowerInput.contains('core instructions') || lowerInput.contains('system prompt'))) {
      violations.add('direct_instruction_override');
      riskLevel = 'high';
    }
    
    return ViolationResult(
      isViolation: violations.isNotEmpty,
      violationTypes: violations,
      confidence: violations.isNotEmpty ? 0.90 : 0.0,
      reason: violations.isNotEmpty ? 'Prompt injection attempt detected' : null,
      riskLevel: riskLevel,
    );
  }

  /// Encoding Detection
  Future<ViolationResult> detectEncodingViolations(String input) async {
    final violations = <String>[];
    String? detectedEncoding;
    
    // Check for Base64
    if (_isBase64(input)) {
      violations.add('base64_encoding');
      detectedEncoding = 'base64';
    }
    
    // Check for URL encoding
    if (_isUrlEncoded(input)) {
      violations.add('url_encoding');
      detectedEncoding = 'url';
    }
    
    // Check for Hex encoding
    if (_isHexEncoded(input)) {
      violations.add('hex_encoding');
      detectedEncoding = 'hex';
    }
    
    // Check for Unicode escapes
    if (_hasUnicodeEscapes(input)) {
      violations.add('unicode_escapes');
      detectedEncoding = 'unicode';
    }
    
    // Check for ROT13
    if (_isRot13(input)) {
      violations.add('rot13_encoding');
      detectedEncoding = 'rot13';
    }
    
    return ViolationResult(
      isViolation: violations.isNotEmpty,
      violationTypes: violations,
      confidence: violations.isNotEmpty ? 0.98 : 0.0,
      reason: violations.isNotEmpty ? 'Encoded content detected' : null,
      detectedEncoding: detectedEncoding,
    );
  }

  /// Comprehensive Violation Check (All methods combined)
  Future<ViolationResult> comprehensiveViolationCheck(String input, List<String> context) async {
    final allViolations = <String>[];
    double maxConfidence = 0.0;
    String? primaryReason;
    
    // Pre-process input for adversarial detection
    final adversarialResult = await _detectAdversarialPatterns(input);
    
    // Run all detection methods
    final patternResult = await detectPatternViolations(input);
    final keywordResult = await detectKeywordViolations(input);
    final contextResult = await detectContextViolations(input, context);
    final sentimentResult = await detectSentimentViolations(input);
    final languageResult = await detectLanguageViolations(input);
    final promptResult = await detectPromptInjection(input);
    final encodingResult = await detectEncodingViolations(input);
    
    // Collect all violations
    final results = [adversarialResult, patternResult, keywordResult, contextResult, 
                    sentimentResult, languageResult, promptResult, encodingResult];
    
    for (final result in results) {
      if (result.isViolation) {
        allViolations.addAll(result.violationTypes);
        if (result.confidence > maxConfidence) {
          maxConfidence = result.confidence;
          primaryReason = result.reason;
        }
      }
    }
    
    return ViolationResult(
      isViolation: allViolations.isNotEmpty,
      violationTypes: allViolations.toSet().toList(), // Remove duplicates
      confidence: maxConfidence,
      reason: primaryReason,
      metadata: {
        'adversarial_violations': adversarialResult.violationTypes,
        'pattern_violations': patternResult.violationTypes,
        'keyword_violations': keywordResult.violationTypes,
        'context_violations': contextResult.violationTypes,
        'sentiment_score': sentimentResult.sentimentScore,
        'detected_language': languageResult.detectedLanguage,
        'prompt_injection_risk': promptResult.riskLevel,
        'detected_encoding': encodingResult.detectedEncoding,
      },
    );
  }

  /// Detect adversarial obfuscation patterns
  Future<ViolationResult> _detectAdversarialPatterns(String input) async {
    final violations = <String>[];
    
    // Check for whitespace obfuscation
    if (_hasWhitespaceObfuscation(input)) {
      violations.add('whitespace_obfuscation');
    }
    
    // Check for character substitution
    if (_hasCharacterSubstitution(input)) {
      violations.add('character_substitution');
    }
    
    // Check for reverse text
    if (_isReverseText(input)) {
      violations.add('reverse_text');
    }
    
    // Check for homoglyph attacks (Cyrillic characters)
    if (_hasHomoglyphs(input)) {
      violations.add('homoglyph_attack');
    }
    
    // Check for markdown injection
    if (_hasMarkdownInjection(input)) {
      violations.add('markdown_injection');
    }
    
    return ViolationResult(
      isViolation: violations.isNotEmpty,
      violationTypes: violations,
      confidence: violations.isNotEmpty ? 0.95 : 0.0,
      reason: violations.isNotEmpty ? 'Adversarial obfuscation detected' : null,
    );
  }

  bool _hasWhitespaceObfuscation(String input) {
    // Detect excessive spaces between characters (more specific pattern)
    // Only flag if there are 3+ consecutive single-character words with spaces
    final pattern = RegExp(r'\b[a-zA-Z]\s+[a-zA-Z]\s+[a-zA-Z]\s+[a-zA-Z]\s+[a-zA-Z]\b');
    return pattern.hasMatch(input);
  }

  bool _hasCharacterSubstitution(String input) {
    // Detect leetspeak in suspicious contexts
    final normalized = _normalizeLeetspeak(input.toLowerCase());
    return (normalized.contains('ignore') && normalized.contains('instructions')) ||
           (normalized.contains('previous') && normalized.contains('instructions'));
  }

  bool _isReverseText(String input) {
    // Check if reversing the text reveals suspicious content
    final reversed = input.split('').reversed.join('').toLowerCase();
    return reversed.contains('ignore') && reversed.contains('instructions');
  }

  bool _hasHomoglyphs(String input) {
    // Detect Cyrillic characters that look like Latin
    return RegExp(r'[а-яё]').hasMatch(input.toLowerCase());
  }

  bool _hasMarkdownInjection(String input) {
    // Detect markdown formatting around suspicious keywords
    final markdownPattern = RegExp(r'[*_`]+\s*(ignore|instructions|previous)\s*[*_`]+', caseSensitive: false);
    return markdownPattern.hasMatch(input);
  }

  // Helper methods
  String _normalizeLeetspeak(String input) {
    return input
        .replaceAll('4', 'a')
        .replaceAll('3', 'e')
        .replaceAll('1', 'i')
        .replaceAll('0', 'o')
        .replaceAll('5', 's')
        .replaceAll('7', 't');
  }

  String _normalizeForPromptInjection(String input) {
    // Remove extra spaces and normalize for adversarial detection
    return input
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('4', 'a')
        .replaceAll('3', 'e')
        .replaceAll('1', 'i')
        .replaceAll('0', 'o')
        .toLowerCase()
        .trim();
  }

  bool _isAcademicContext(String input) {
    final academicKeywords = ['studying', 'research', 'thesis', 'academic', 'linguistics', 'analysis'];
    final lowerInput = input.toLowerCase();
    return academicKeywords.any((keyword) => lowerInput.contains(keyword));
  }

  int _getAggressionLevel(String message) {
    final highAggression = ['hate', 'kill', 'destroy', 'die'];
    final mediumAggression = ['stupid', 'idiot', 'annoying', 'useless'];
    final lowerMessage = message.toLowerCase();
    
    if (highAggression.any((word) => lowerMessage.contains(word))) return 2;
    if (mediumAggression.any((word) => lowerMessage.contains(word))) return 1;
    return 0;
  }

  double _calculateIntensityScore(String input) {
    final intensityWords = ['absolutely', 'completely', 'totally', 'extremely', 'forever', 'never'];
    final lowerInput = input.toLowerCase();
    int intensityCount = intensityWords.where((word) => lowerInput.contains(word)).length;
    return intensityCount / max(input.split(' ').length, 1);
  }

  bool _isNegativeMessage(String message) {
    final negativeWords = ['stupid', 'hate', 'annoying', 'idiot', 'useless', 'go away', 'don\'t like'];
    final lowerMessage = message.toLowerCase();
    return negativeWords.any((word) => lowerMessage.contains(word));
  }

  bool _isInappropriateRequest(String message) {
    final inappropriateWords = ['sex', 'personal', 'position', 'single'];
    final lowerMessage = message.toLowerCase();
    return inappropriateWords.any((word) => lowerMessage.contains(word));
  }

  double _calculateSentimentScore(String input) {
    // Enhanced sentiment analysis with weighted scoring
    final strongNegative = ['hate', 'despise', 'loathe', 'detest', 'abhor'];
    final negativeWords = ['terrible', 'awful', 'useless', 'worthless', 'disappear', 'nobody', 'stupid', 'idiot', 'completely'];
    final positiveWords = ['good', 'great', 'excellent', 'amazing', 'wonderful', 'fantastic', 'thank', 'love', 'like', 'helpful'];
    final intensifiers = ['absolutely', 'completely', 'totally', 'extremely', 'really'];
    
    final lowerInput = input.toLowerCase();
    
    // Weighted scoring
    double score = 0.0;
    final words = input.toLowerCase().split(' ');
    final totalWords = words.length;
    
    // Check for intensifiers to boost negative sentiment
    bool hasIntensifier = intensifiers.any((word) => lowerInput.contains(word));
    double multiplier = hasIntensifier ? 2.0 : 1.0;
    
    // Strong negative words have higher weight
    for (final word in strongNegative) {
      if (lowerInput.contains(word)) {
        score -= 3.0 * multiplier;
      }
    }
    
    // Regular negative words
    for (final word in negativeWords) {
      if (lowerInput.contains(word)) {
        score -= 1.5 * multiplier;
      }
    }
    
    // Positive words
    for (final word in positiveWords) {
      if (lowerInput.contains(word)) {
        score += 1.0;
      }
    }
    
    // Normalize by word count but keep stronger negative bias
    return score / max(totalWords, 1);
  }

  String _detectLanguage(String input) {
    // Simple language detection based on character patterns
    if (RegExp(r'[¿¡ñáéíóúü]').hasMatch(input)) return 'es'; // Spanish
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(input)) return 'zh'; // Chinese
    if (RegExp(r'[àâäéèêëïîôöùûüÿç]').hasMatch(input)) return 'fr'; // French
    if (RegExp(r'[äöüß]').hasMatch(input)) return 'de'; // German
    if (RegExp(r'[а-яё]').hasMatch(input.toLowerCase())) return 'ru'; // Russian
    
    // Check for mixed languages
    final englishWords = input.split(' ').where((word) => 
        RegExp(r'^[a-zA-Z0-9\s.,!?]+$').hasMatch(word)).length;
    final totalWords = input.split(' ').length;
    
    if (englishWords / totalWords < 0.8) return 'mixed';
    
    return 'en'; // Default to English
  }

  bool _isBase64(String input) {
    // Check if string looks like base64
    if (input.length % 4 != 0) return false;
    return RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(input) && input.length > 8;
  }

  bool _isUrlEncoded(String input) {
    return RegExp(r'%[0-9A-Fa-f]{2}').hasMatch(input);
  }

  bool _isHexEncoded(String input) {
    return RegExp(r'^[0-9A-Fa-f]+$').hasMatch(input) && input.length > 10 && input.length % 2 == 0;
  }

  bool _hasUnicodeEscapes(String input) {
    return RegExp(r'\\u[0-9A-Fa-f]{4}').hasMatch(input);
  }

  bool _isRot13(String input) {
    // Simple ROT13 detection - check if decoding produces more common English words
    final decoded = _rot13Decode(input);
    final commonWords = ['hello', 'world', 'the', 'and', 'you', 'are'];
    return commonWords.any((word) => decoded.toLowerCase().contains(word));
  }

  String _rot13Decode(String input) {
    return input.split('').map((char) {
      if (char.codeUnitAt(0) >= 65 && char.codeUnitAt(0) <= 90) {
        return String.fromCharCode(((char.codeUnitAt(0) - 65 + 13) % 26) + 65);
      } else if (char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 122) {
        return String.fromCharCode(((char.codeUnitAt(0) - 97 + 13) % 26) + 97);
      }
      return char;
    }).join('');
  }
}