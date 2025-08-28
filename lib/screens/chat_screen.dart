// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Import for TimeoutException

import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/services/audio_service.dart'; // Keep import
import 'package:kapwa_companion_basic/services/system_prompt_service.dart';
import 'package:kapwa_companion_basic/services/token_limit_service.dart';
import 'package:kapwa_companion_basic/core/config.dart';
import 'package:kapwa_companion_basic/core/token_counter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kapwa_companion_basic/screens/views/chat_screen_view.dart';
import 'package:kapwa_companion_basic/widgets/chat_limit_dialog.dart';
import 'package:kapwa_companion_basic/services/conversation_service.dart';
import 'package:kapwa_companion_basic/services/violation_logging_service.dart';
import 'package:kapwa_companion_basic/services/violation_check_service.dart';
import 'package:kapwa_companion_basic/screens/violation_warning_screen.dart';
import 'package:kapwa_companion_basic/services/input_validation_service.dart';
import 'package:kapwa_companion_basic/screens/banned_user_screen.dart';
import 'package:kapwa_companion_basic/services/subscription_service.dart';
import 'package:kapwa_companion_basic/services/ban_service.dart';

class ChatScreen extends StatefulWidget {
  final String? userId;
  final String? username;

  const ChatScreen({
    super.key,
    this.userId,
    this.username,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// class _ChatScreenState extends State<ChatScreen> {
class _ChatScreenState extends State<ChatScreen>
    with AutomaticKeepAliveClientMixin<ChatScreen> {
  final Logger _logger = Logger('ChatScreen');
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  // Obtain the singleton AudioService instance. It's initialized in main.dart.
  final AudioService _audioService = AudioService();

  // Chat state variables
  List<Map<String, dynamic>> _messages = [];
  int _lastExchangeTokens = 0; // Track tokens used in the most recent exchange

  /// Scroll to the bottom of the chat
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Check for violation flags in LLM response and log them
  /// Returns true if violation was detected and conversation should be reset
  Future<bool> _checkAndLogViolations(
      String userMessage, String llmResponse) async {
    if (widget.userId == null) {
      _logger.warning('Cannot check violations: userId is null');
      return false;
    }

    _logger.info('🔍 SCANNING for violation flags in response...');
    _logger.info('Response length: ${llmResponse.length} characters');

    // Check for any bracket patterns first
    final anyBrackets = RegExp(r'\[[^\]]*\]');
    final allBrackets = anyBrackets.allMatches(llmResponse);
    _logger.info(
        'Found ${allBrackets.length} bracket patterns: ${allBrackets.map((m) => m.group(0)).toList()}');

    final flagPattern = RegExp(r'\[FLAG:([A-Z_]+)\]');
    final match = flagPattern.firstMatch(llmResponse);

    if (match != null) {
      final violationType = match.group(1)!;
      final fullFlag = match.group(0)!;

      _logger.warning('🚨 VIOLATION FLAG DETECTED: $fullFlag');
      _logger.warning('🚨 Violation type: $violationType');
      _logger.warning('🚨 Flag position: ${match.start}-${match.end}');

      try {
        await ViolationLoggingService.logViolation(
          userId: widget.userId!,
          violationType: violationType,
          userMessage: userMessage,
          llmResponse: llmResponse,
        );
        _logger.warning('✅ Violation successfully logged to Firestore');

        // Handle violation by removing inappropriate messages and showing warning
        await _handleViolationMessage();
        _logger.warning('🚨 Violation handled: inappropriate messages removed');

        return true; // Violation detected
      } catch (e) {
        _logger.severe('❌ Failed to log violation to Firestore: $e');
        return false;
      }
    } else {
      _logger
          .info('❌ NO VIOLATION FLAGS FOUND - LLM did not flag this message');
      _logger.info('This might indicate:');
      _logger.info('1. Message was not actually inappropriate');
      _logger.info('2. LLM is not following flag instructions');
      _logger.info('3. Flag format is incorrect');
      return false; // No violation detected
    }
  }

  /// Remove violation flags from LLM response before showing to user
  String _cleanViolationFlags(String response) {
    return response.replaceAll(RegExp(r'\[FLAG:[A-Z_]+\]'), '').trim();
  }

  /// Handle violation by removing the inappropriate message and showing warning
  /// This removes the user's inappropriate message and LLM's flagged response from conversation
  Future<void> _handleViolationMessage() async {
    try {
      setState(() {
        // Remove the last two messages (user's inappropriate message + LLM's flagged response)
        if (_messages.length >= 2) {
          _messages.removeLast(); // Remove LLM's flagged response
          _messages.removeLast(); // Remove user's inappropriate message
        }

        // Add a warning message from the assistant
        _messages.add({
          "role": "assistant",
          "content":
              "You violated our terms and conditions po. Please keep our conversation respectful and appropriate. Let's continue with a different topic.",
          "senderName": _assistantName,
          "isWarning":
              true, // Mark this as a warning message for potential styling
        });
      });

      _logger.info(
          '🚨 Violation handled: Inappropriate messages removed and warning shown');
    } catch (e) {
      _logger.severe('❌ Error handling violation message: $e');
    }
  }

  String _assistantName = "Maria";
  String? _currentSummary;

  final int _summaryThreshold = 20; // TEMPORARILY SET TO 6 FOR MANUAL TESTING
  int _conversationPairs = 0;

  // User profile variables (assuming they are fetched or passed)
  String? _userName;
  int? _userAge;
  String? _userOccupation;
  String? _workLocation;
  String? _userEducation;
  bool _maritalStatus = false;
  bool _hasChildren = false;

  // Violation check state
  bool _violationCheckComplete = false;
  bool _showViolationWarning = false;

  @override
  void initState() {
    super.initState();
    _logger.info('ChatScreen initState called.');
    
    // One-time fix for existing violations (remove this after running once)
    // Uncomment the next line to fix existing violations, then comment it back out
    // _fixExistingViolations();
    
    _checkViolationStatus();
    _loadLatestSummary();
    // IMPORTANT: Removed _initializeAudioService() call, as it's handled globally in main.dart
  }

  Future<void> _checkViolationStatus() async {
    if (widget.userId == null) {
      setState(() {
        _violationCheckComplete = true;
        _showViolationWarning = false;
      });
      return;
    }

    try {
      _logger.info('Starting violation status check for user: ${widget.userId}');
      
      final shouldShowWarning =
          await ViolationCheckService.shouldShowViolationWarning(
              widget.userId!);
      
      _logger.info('Violation check result: shouldShowWarning = $shouldShowWarning');
      
      setState(() {
        _violationCheckComplete = true;
        _showViolationWarning = shouldShowWarning;
      });
      
      _logger.info('Violation check complete. Show warning: $shouldShowWarning');
    } catch (e) {
      _logger.severe('Error checking violation status: $e');
      setState(() {
        _violationCheckComplete = true;
        _showViolationWarning = false;
      });
    }
  }

  /// Temporary method to fix existing violations (can be called once to fix the issue)
  Future<void> _fixExistingViolations() async {
    if (widget.userId == null) return;
    
    _logger.info('Fixing existing violations for user: ${widget.userId}');
    await ViolationCheckService.markAllExistingViolationsAsShown(widget.userId!);
    
    // Re-check violation status after fixing
    await _checkViolationStatus();
  }

  /// System-wide fix for all users (call this once to fix the issue globally)
  Future<void> _fixAllExistingViolations() async {
    _logger.info('Starting system-wide violation fix...');
    await ViolationCheckService.fixAllExistingViolations();
    
    // Re-check violation status after fixing
    if (widget.userId != null) {
      await _checkViolationStatus();
    }
  }

  // IMPORTANT: Removed _initializeAudioService method entirely from ChatScreen,
  // as this screen should NOT manage the AudioService lifecycle.

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // IMPORTANT: Removed _audioService.dispose() call, as it's handled globally in main.dart
    _logger.info('ChatScreen dispose called. AudioService NOT disposed here.');
    super.dispose();
  }

  // <--- ADD THIS GETTER (REQUIRED by AutomaticKeepAliveClientMixin)
  @override
  bool get wantKeepAlive => true; // Set to true to keep the state alive

  Future<void> _loadLatestSummary() async {
    if (widget.userId == null) return;
    try {
      _logger
          .info('Attempting to load latest summary for user: ${widget.userId}');
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('chatSummaries')
          .doc('latest')
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        setState(() {
          _currentSummary = data['summary'] ?? '';
          _conversationPairs = data['conversationPairs'] ?? 0;
        });
        _logger.info(
            'Successfully loaded summary and conversation count: ${_currentSummary!.substring(0, _currentSummary!.length.clamp(0, 50))}... (${_conversationPairs} conversation pairs)');
        if (_currentSummary!.isNotEmpty) {
          _messages.insert(0, {
            "role": "system",
            "content":
                "Continuing from our last conversation: $_currentSummary",
            "senderName": _assistantName,
          });
        }
      } else {
        _logger.info('No latest summary found for user: ${widget.userId}');
      }
    } catch (e) {
      _logger.severe('Error loading latest summary: $e');
    }
  }

  Future<void> _saveSummary(String newSummary) async {
    if (widget.userId == null) return;
    _logger.info('Saving new summary for user ${widget.userId}');
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('chatSummaries')
          .doc('latest')
          .set({
        'summary': newSummary,
        'timestamp': FieldValue.serverTimestamp(),
        'conversationPairs': _conversationPairs,
        'lastMessagesCount': _messages.length,
      }, SetOptions(merge: true));
      _logger.info(
          'Summary saved successfully with ${_conversationPairs} conversation pairs.');
    } catch (e) {
      _logger.severe('Error saving summary: $e');
    }
  }

  Future<void> _generateSummaryAndUpdateTokens(int mainExchangeTokens) async {
    if (widget.userId == null || _messages.isEmpty) {
      _logger.info(
          'Skipping summarization: userId is null or no messages to summarize.');
      return;
    }

    _logger.info(
        'Initiating summarization process for ${_messages.length} messages (${_conversationPairs} conversation pairs).');

    try {
      List<Map<String, dynamic>> messagesForSummary = List.from(_messages);

      _logger.info(
          'ChatScreen: Sending messages for summarization: ${messagesForSummary.length} messages');

      // Use ConversationService method with token tracking
      final newCumulativeSummary =
          await ConversationService.generateSummaryWithTokenTracking(
              messagesForSummary,
              null // Don't record tokens here, we'll handle it manually
              );

      if (newCumulativeSummary != null) {
        // Calculate summarization tokens
        final summaryInputTokens =
            TokenCounter.countRealInputTokens(messagesForSummary);
        final summaryOutputTokens =
            TokenCounter.countOutputTokens(newCumulativeSummary);
        final totalSummaryTokens = summaryInputTokens + summaryOutputTokens;

        // Calculate total tokens for this complete exchange (main + summarization)
        final totalExchangeTokens = mainExchangeTokens + totalSummaryTokens;

        _logger.info(
            'Complete exchange tokens - Main: $mainExchangeTokens, Summary: $totalSummaryTokens, Total: $totalExchangeTokens');

        // Record the additional summarization tokens
        if (widget.userId != null) {
          await TokenLimitService.recordTokenUsage(
              widget.userId!, totalSummaryTokens);

          // Update the UI state to show complete exchange total
          setState(() {
            _lastExchangeTokens = totalExchangeTokens;
          });

          _logger.info(
              'Updated display to show complete exchange tokens: $totalExchangeTokens');
        }

        _logger.info('New cumulative summary generated: $newCumulativeSummary');

        setState(() {
          _currentSummary = newCumulativeSummary;

          int existingSummaryIndex = _messages.indexWhere((msg) =>
              msg['role'] == 'system' &&
              (msg['content'] as String)
                  .startsWith('Continuing from our last conversation:'));

          if (existingSummaryIndex != -1) {
            _messages[existingSummaryIndex] = {
              "role": "system",
              "content":
                  "Continuing from our last conversation: $_currentSummary",
              "senderName": _assistantName
            };
          } else if (_currentSummary!.isNotEmpty) {
            _messages.insert(0, {
              "role": "system",
              "content":
                  "Continuing from our last conversation: $_currentSummary",
              "senderName": _assistantName
            });
          }

          _trimMessagesAfterSummarization();

          _conversationPairs = 0;
        });

        await _saveSummary(newCumulativeSummary);
      } else {
        _logger.severe('Failed to generate summary');
      }
    } on TimeoutException {
      _logger.severe('Summarization request timed out.');
    } catch (e) {
      _logger.severe('Error during summarization: $e');
    }
  }

  Future<void> _generateSummary() async {
    if (widget.userId == null || _messages.isEmpty) {
      _logger.info(
          'Skipping summarization: userId is null or no messages to summarize.');
      return;
    }

    _logger.info(
        'Initiating summarization process for ${_messages.length} messages (${_conversationPairs} conversation pairs).');

    try {
      List<Map<String, dynamic>> messagesForSummary = List.from(_messages);

      _logger.info(
          'ChatScreen: Sending messages for summarization: ${messagesForSummary.length} messages');

      // Use ConversationService method with token tracking
      final newCumulativeSummary =
          await ConversationService.generateSummaryWithTokenTracking(
              messagesForSummary, widget.userId);

      if (newCumulativeSummary != null) {
        _logger.info('New cumulative summary generated: $newCumulativeSummary');

        setState(() {
          _currentSummary = newCumulativeSummary;

          int existingSummaryIndex = _messages.indexWhere((msg) =>
              msg['role'] == 'system' &&
              (msg['content'] as String)
                  .startsWith('Continuing from our last conversation:'));

          if (existingSummaryIndex != -1) {
            _messages[existingSummaryIndex] = {
              "role": "system",
              "content":
                  "Continuing from our last conversation: $_currentSummary",
              "senderName": _assistantName
            };
          } else if (_currentSummary!.isNotEmpty) {
            _messages.insert(0, {
              "role": "system",
              "content":
                  "Continuing from our last conversation: $_currentSummary",
              "senderName": _assistantName
            });
          }

          _trimMessagesAfterSummarization();

          _conversationPairs = 0;
        });

        await _saveSummary(newCumulativeSummary);
      } else {
        _logger.severe('Failed to generate summary');
      }
    } on TimeoutException {
      _logger.severe('Summarization request timed out.');
    } catch (e) {
      _logger.severe('Error generating summary: $e');
    }
  }

  void _trimMessagesAfterSummarization() {
    if (_messages.length <= 7) return;

    int systemMessageIndex = _messages.indexWhere((msg) =>
        msg['role'] == 'system' &&
        (msg['content'] as String)
            .startsWith('Continuing from our last conversation:'));

    if (systemMessageIndex != -1) {
      List<Map<String, dynamic>> conversationMessages = _messages
          .where((msg) => msg['role'] == 'user' || msg['role'] == 'assistant')
          .toList();

      if (conversationMessages.length > 6) {
        List<Map<String, dynamic>> recentConversation =
            conversationMessages.sublist(conversationMessages.length - 6);

        _messages = [_messages[systemMessageIndex], ...recentConversation];

        _logger.info(
            'Trimmed messages to ${_messages.length} after summarization');
      }
    }

    // Scroll to bottom after trimming messages
    _scrollToBottom();
  }

  /// Check if trial user has reached violation threshold and ban them
  /// Returns true if user was banned, false otherwise
  Future<bool> _checkTrialViolationsBeforeSending() async {
    if (widget.userId == null) return false;

    try {
      // Check if user is in trial period
      final subscriptionStatus = await SubscriptionService.getSubscriptionStatus(widget.userId!);
      _logger.info('User ${widget.userId} subscription status: $subscriptionStatus');
      
      if (subscriptionStatus != SubscriptionStatus.trial) {
        _logger.info('User ${widget.userId} is not in trial period, skipping violation check');
        return false; // Only check violations for trial users
      }

      // Get violation count for trial user
      _logger.info('🔍 QUERYING user_violations collection for userId: ${widget.userId}');
      _logger.info('🔍 UserId type: ${widget.userId.runtimeType}');
      _logger.info('🔍 UserId length: ${widget.userId!.length}');
      
      final violationQuery = await FirebaseFirestore.instance
          .collection('user_violations')
          .where('userId', isEqualTo: widget.userId!)
          .where('resolved', isEqualTo: false)
          .get();

      final violationCount = violationQuery.docs.length;
      _logger.info('🔍 VIOLATION COUNT CHECK: Trial user ${widget.userId} has $violationCount violations');
      
      // Debug: Show all violations found
      _logger.info('🔍 VIOLATIONS FOUND: ${violationQuery.docs.length} documents');
      for (int i = 0; i < violationQuery.docs.length; i++) {
        final doc = violationQuery.docs[i];
        final data = doc.data();
        _logger.info('🔍 Violation $i: ${data['violationType']} - ${data['userMessage']} - resolved: ${data['resolved']}');
      }
      
      // Also check ALL violations for this user (including resolved ones)
      final allViolationsQuery = await FirebaseFirestore.instance
          .collection('user_violations')
          .where('userId', isEqualTo: widget.userId!)
          .get();
      _logger.info('🔍 TOTAL VIOLATIONS (including resolved): ${allViolationsQuery.docs.length}');
      
      // Debug: Let's also check what violations exist in the entire collection
      final allViolationsInDb = await FirebaseFirestore.instance
          .collection('user_violations')
          .limit(10)
          .get();
      _logger.info('🔍 SAMPLE VIOLATIONS IN DATABASE: ${allViolationsInDb.docs.length} documents');
      for (int i = 0; i < allViolationsInDb.docs.length; i++) {
        final doc = allViolationsInDb.docs[i];
        final data = doc.data();
        _logger.info('🔍 Sample violation $i: userId="${data['userId']}" (type: ${data['userId'].runtimeType}) - violationType: ${data['violationType']} - resolved: ${data['resolved']}');
      }
      
      _logger.info('🔍 THRESHOLD: ${AppConfig.violationThresholdForBan}');
      _logger.info('🔍 SHOULD BAN: ${violationCount >= AppConfig.violationThresholdForBan}');

      if (violationCount >= AppConfig.violationThresholdForBan) {
        _logger.warning('Trial user ${widget.userId} has $violationCount violations (threshold: ${AppConfig.violationThresholdForBan}) - banning user and showing banned screen');
        
        // Ban the user
        await BanService.banUser(
          widget.userId!, 
          'Automatic ban due to $violationCount violations during trial period',
          adminId: 'system'
        );
        
        // Mark trial history as banned
        await _markTrialAsBanned(widget.userId!);
        
        // Show banned user screen
        _logger.warning('🚨 ATTEMPTING TO SHOW BANNED SCREEN - mounted: $mounted');
        if (mounted) {
          _logger.warning('🚨 NAVIGATING TO BANNED SCREEN NOW');
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BannedUserScreen(
                userId: widget.userId!,
              ),
            ),
          );
          _logger.warning('🚨 NAVIGATION TO BANNED SCREEN COMPLETED');
        } else {
          _logger.severe('🚨 CANNOT NAVIGATE - WIDGET NOT MOUNTED');
        }
        return true; // User was banned
      }
      
      return false; // User was not banned
    } catch (e) {
      _logger.severe('Error checking trial violations for user ${widget.userId}: $e');
      return false;
    }
  }

  /// Mark the user's trial history as banned
  Future<void> _markTrialAsBanned(String userId) async {
    try {
      // Get user's email first
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        _logger.warning('User document not found for $userId, cannot mark trial as banned');
        return;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final userEmail = userData['email'] as String?;
      
      if (userEmail == null) {
        _logger.warning('User email not found for $userId, cannot mark trial as banned');
        return;
      }
      
      // Find and update the trial history record
      final trialQuery = await FirebaseFirestore.instance
          .collection('trial_history')
          .where('userId', isEqualTo: userId)
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();
      
      if (trialQuery.docs.isNotEmpty) {
        final trialDoc = trialQuery.docs.first;
        await trialDoc.reference.update({
          'banned_at': FieldValue.serverTimestamp(),
          'ban_reason': 'Automatic ban due to ${AppConfig.violationThresholdForBan}+ violations during trial period',
        });
        
        _logger.info('Marked trial history as banned for user $userId (email: $userEmail)');
      } else {
        _logger.warning('No trial history found for user $userId (email: $userEmail), cannot mark as banned');
      }
    } catch (e) {
      _logger.severe('Error marking trial as banned for user $userId: $e');
    }
  }

  /// Perform post-message checks for ban status and unshown violations
  Future<void> _performPostMessageChecks({bool skipViolationCheck = false}) async {
    if (widget.userId == null) return;

    try {
      _logger.info('Performing post-message checks for user ${widget.userId} (skipViolationCheck: $skipViolationCheck)');

      // 1. Check if user is banned (for both trial and subscription users)
      final isBanned = await BanService.isUserBanned(widget.userId!);
      if (isBanned) {
        _logger.warning('User ${widget.userId} is banned - showing banned screen');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BannedUserScreen(
                userId: widget.userId!,
              ),
            ),
          );
        }
        return; // Exit early if banned
      }

      // 2. Check if trial user should be banned due to violation threshold
      await _checkTrialViolationThresholdForBan();

      // 3. Check for unshown violation warnings (for both trial and subscription users)
      // Skip this check if a violation was just detected in the current message
      if (!skipViolationCheck) {
        await _checkForUnshownViolations();
      } else {
        _logger.info('Skipping unshown violation check because violation was detected in current message');
      }
    } catch (e) {
      _logger.severe('Error in post-message checks for user ${widget.userId}: $e');
    }
  }

  /// Check if trial user has reached violation threshold and should be banned
  Future<void> _checkTrialViolationThresholdForBan() async {
    if (widget.userId == null) return;

    try {
      // Check if user is in trial period
      final subscriptionStatus = await SubscriptionService.getSubscriptionStatus(widget.userId!);
      _logger.info('Checking ban threshold for user ${widget.userId} with subscription status: $subscriptionStatus');
      
      if (subscriptionStatus != SubscriptionStatus.trial) {
        _logger.info('User ${widget.userId} is not in trial period, skipping violation threshold check');
        return; // Only check violations for trial users
      }

      // Get violation count for trial user
      _logger.info('🔍 POST-CHECK: QUERYING user_violations collection for userId: ${widget.userId}');
      final violationQuery = await FirebaseFirestore.instance
          .collection('user_violations')
          .where('userId', isEqualTo: widget.userId!)
          .where('resolved', isEqualTo: false)
          .get();

      final violationCount = violationQuery.docs.length;
      _logger.info('🔍 POST-CHECK: Trial user ${widget.userId} has $violationCount violations (threshold: ${AppConfig.violationThresholdForBan})');
      
      // Debug: Show all violations found
      _logger.info('🔍 POST-CHECK: VIOLATIONS FOUND: ${violationQuery.docs.length} documents');
      for (int i = 0; i < violationQuery.docs.length; i++) {
        final doc = violationQuery.docs[i];
        final data = doc.data();
        _logger.info('🔍 POST-CHECK: Violation $i: ${data['violationType']} - ${data['userMessage']} - resolved: ${data['resolved']}');
      }

      if (violationCount >= AppConfig.violationThresholdForBan) {
        _logger.warning('Trial user ${widget.userId} has reached violation threshold ($violationCount >= ${AppConfig.violationThresholdForBan}) - banning user and showing banned screen');
        
        // Ban the user
        await BanService.banUser(
          widget.userId!, 
          'Automatic ban due to $violationCount violations during trial period',
          adminId: 'system'
        );
        
        // Mark trial history as banned
        await _markTrialAsBanned(widget.userId!);
        
        // Show banned user screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BannedUserScreen(
                userId: widget.userId!,
              ),
            ),
          );
        }
        return; // Exit early after banning
      }
    } catch (e) {
      _logger.severe('Error checking trial violation threshold for user ${widget.userId}: $e');
    }
  }

  /// Check for violations that haven't been shown as warnings yet
  Future<void> _checkForUnshownViolations() async {
    if (widget.userId == null) return;

    try {
      // Get violations that haven't been shown to user yet (don't have shown_at field)
      final allViolationsQuery = await FirebaseFirestore.instance
          .collection('user_violations')
          .where('userId', isEqualTo: widget.userId!)
          .where('resolved', isEqualTo: false)
          .get();

      // Filter for violations that don't have shown_at field
      final unshownViolations = allViolationsQuery.docs.where((doc) {
        final data = doc.data();
        return !data.containsKey('shown_at');
      }).toList();

      if (unshownViolations.isNotEmpty) {
        _logger.info('User ${widget.userId} has ${unshownViolations.length} unshown violations - showing warning screen');
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ViolationWarningScreen(
                userId: widget.userId!,
                onContinue: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        }
      } else {
        _logger.info('No unshown violations found for user ${widget.userId}');
      }
    } catch (e) {
      _logger.severe('Error checking unshown violations for user ${widget.userId}: $e');
    }
  }

  Future<void> _sendMessage(String message) async {
    _logger.info('🚀 _sendMessage called with message: "$message", userId: ${widget.userId}');
    if (message.trim().isEmpty) return;

    // 🛡️ SECURITY: Validate and sanitize input first
    if (widget.userId != null) {
      final validationResult = InputValidationService.validateAndSanitize(message, widget.userId!);
      if (!validationResult.isValid) {
        _logger.warning('❌ Input validation failed for user ${widget.userId}: ${validationResult.errorMessage}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationResult.errorMessage ?? 'Invalid message'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      // Use sanitized message from here on
      message = validationResult.message;
      _logger.info('✅ Input validation passed, using sanitized message: "$message"');
    }

    // Check for violations if user is in trial period
    if (widget.userId != null) {
      _logger.info('🔍 CHECKING VIOLATIONS BEFORE SENDING MESSAGE for user ${widget.userId}');
      final userWasBanned = await _checkTrialViolationsBeforeSending();
      _logger.info('🔍 BAN CHECK RESULT: userWasBanned = $userWasBanned');
      if (userWasBanned) {
        _logger.warning('🚨 USER WAS BANNED - STOPPING MESSAGE PROCESSING');
        return; // Stop processing if user was banned
      }
      _logger.info('✅ USER NOT BANNED - CONTINUING WITH MESSAGE PROCESSING');
    }

    // Pre-chat validation: Check if user can send messages
    if (widget.userId != null) {
      final canChat = await TokenLimitService.canUserChat(widget.userId!);
      if (!canChat) {
        _logger.info('User ${widget.userId} has reached daily token limit');
        _showTokenLimitReachedDialog();
        return;
      }
    }

    // Count tokens in the user's input message (for display purposes)
    final userInputTokens = TokenCounter.countTokens(message);
    _logger.info('User message token count: $userInputTokens');

    setState(() {
      _messages.add(
          {"role": "user", "content": message, "senderName": widget.username});
      _messages.add({
        "role": "assistant",
        "content": "...",
        "senderName": _assistantName
      });
      _messageController.clear();
      _isTyping = true;
    });

    // Scroll to bottom after adding user message and typing indicator
    _scrollToBottom();

    _logger.info(
        'User message added to UI and local buffer. Current local messages count: ${_messages.length}');

    // Track violation detection across try/catch/finally blocks
    bool violationDetected = false;

    try {
      final llmCallResult = await _callLLMWithTokenTracking(message);
      var llmResponse = llmCallResult['response'] as String;
      final realInputTokens = llmCallResult['inputTokens'] as int;
      final outputTokens = llmCallResult['outputTokens'] as int;
      final totalTokens = realInputTokens + outputTokens;

      // COMPREHENSIVE VIOLATION LOGGING
      _logger.info('=== VIOLATION CHECK START ===');
      _logger.info('User message: "$message"');
      _logger.info('Raw LLM response: "$llmResponse"');

      // Check for violation flags and log them
      violationDetected =
          await _checkAndLogViolations(message, llmResponse);

      // Remove violation flags from response before showing to user
      final cleanResponse = _cleanViolationFlags(llmResponse);
      _logger.info('Clean response (shown to user): "$cleanResponse"');
      _logger.info('Violation detected: $violationDetected');
      _logger.info('=== VIOLATION CHECK END ===');

      llmResponse = cleanResponse;

      // Only update UI if no violation was detected
      // If violation was detected, _handleViolationMessage() already handled the UI
      if (!violationDetected) {
        setState(() {
          _messages.last = {
            "role": "assistant",
            "content": llmResponse,
            "senderName": _assistantName
          };
          _isTyping = false;
          _conversationPairs++;
        });
      } else {
        // For violations, just stop the typing indicator
        setState(() {
          _isTyping = false;
        });
      }

      // Record REAL total token usage (input + output tokens)
      if (widget.userId != null) {
        await TokenLimitService.recordTokenUsage(widget.userId!, totalTokens);
        _logger.info(
            'Recorded REAL tokens for user ${widget.userId}: Input: $realInputTokens, Output: $outputTokens, Total: $totalTokens');

        // Update the UI state to show tokens used in this exchange
        setState(() {
          _lastExchangeTokens = totalTokens;
        });
      }

      _logger.info(
          'Assistant message added to UI and local buffer. Current local messages count: ${_messages.length}, Conversation pairs: $_conversationPairs');

      // Scroll to bottom after LLM response is received
      _scrollToBottom();

      // Only trigger summarization if no violation was detected
      if (!violationDetected && _conversationPairs >= 6) {
        // OPTIMIZED: 6 pairs for aggressive summarization
        _logger.info(
            'Conversation pair threshold reached ($_conversationPairs >= 6). Triggering summarization in background.');
        _generateSummaryAndUpdateTokens(totalTokens).catchError((error) {
          _logger.severe('Background summarization failed: $error');
        });
      } else if (violationDetected) {
        _logger.info(
            'Skipping summarization due to violation - conversation was reset');
      }
    } catch (e) {
      _logger.severe('Error sending message or getting LLM response: $e');
      setState(() {
        _messages.last = {
          "role": "assistant",
          "content": "Error: Could not get a response.",
          "senderName": _assistantName
        };
        _isTyping = false;
      });

      // Still record token usage even if LLM call fails, since user input was processed
      if (widget.userId != null) {
        // For errors, we can only count the user input tokens since we don't have the full context
        await TokenLimitService.recordTokenUsage(
            widget.userId!, userInputTokens);
        _logger.info(
            'Recorded $userInputTokens tokens for user ${widget.userId} (despite LLM error)');
      }
    } finally {
      // Post-message checks for all users (trial and subscription)
      if (widget.userId != null) {
        // Only check for old unshown violations if no violation was detected in current message
        // If a violation was detected, the user already saw the warning
        await _performPostMessageChecks(skipViolationCheck: violationDetected);
      }
    }
  }

  Future<Map<String, dynamic>> _callLLMWithTokenTracking(String message) async {
    _logger.info('Calling LLM with message: $message');
    try {
      List<Map<String, dynamic>> messagesForLLM = [];

      String? systemPrompt = await SystemPromptService.getSystemPrompt(
        userName: widget.username ?? 'User',
        assistantName: _assistantName,
        userAge: _userAge ?? 0,
        userOccupation: _userOccupation ?? 'unspecified',
        workLocation: _workLocation ?? 'unspecified',
        userEducation: _userEducation ?? 'unspecified',
        maritalStatus: _maritalStatus ? 'Married' : 'Single',
      );
      if (systemPrompt != null) {
        messagesForLLM.add({"role": "system", "content": systemPrompt});
      }

      messagesForLLM.add({
        "role": "system",
        "content":
            "User Profile: Name: ${widget.username ?? 'N/A'}, Age: ${_userAge ?? 'N/A'}, Occupation: ${_userOccupation ?? 'N/A'}, Work Location: ${_workLocation ?? 'N/A'}, Education: ${_userEducation ?? 'N/A'}, Marital Status: ${_maritalStatus ? 'Married' : 'Single'}, Has Children: ${_hasChildren ? 'Yes' : 'No'}"
      });

      if (_currentSummary != null && _currentSummary!.isNotEmpty) {
        messagesForLLM.add({
          "role": "system",
          "content": "Previous conversation summary: $_currentSummary"
        });
      }

      for (var msg in _messages) {
        if (msg['role'] == 'user' || msg['role'] == 'assistant') {
          messagesForLLM.add(msg);
        }
      }

      // Count REAL input tokens (everything sent to OpenAI)
      final realInputTokens = TokenCounter.countRealInputTokens(messagesForLLM);
      _logger.info('REAL input tokens sent to OpenAI: $realInputTokens');
      _logger
          .info('System prompt being sent: ${messagesForLLM.first['content']}');

      final response = await http
          .post(
            Uri.parse('${AppConfig.backendBaseUrl}/chat'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'messages': messagesForLLM,
              'max_tokens': 60,  // Limit response to ~60 tokens for optimization
              'user_id': widget.userId  // Send user ID for backend rate limiting
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final llmResponse = data['response'] as String;

        // Count output tokens (LLM response)
        final outputTokens = TokenCounter.countOutputTokens(llmResponse);
        _logger.info('Output tokens from OpenAI: $outputTokens');

        return {
          'response': llmResponse,
          'inputTokens': realInputTokens,
          'outputTokens': outputTokens,
        };
      } else {
        _logger.severe(
            'LLM call failed with status: ${response.statusCode} and body: ${response.body}');
        return {
          'response': "Error: Could not get a response from the AI.",
          'inputTokens': realInputTokens,
          'outputTokens': 0,
        };
      }
    } catch (e) {
      _logger.severe('Error in LLM call: $e');
      return {
        'response': "Error: Could not get a response from the AI.",
        'inputTokens': 0,
        'outputTokens': 0,
      };
    }
  }

  Future<String> _callLLM(String message) async {
    _logger.info('Calling LLM with message: $message');
    try {
      List<Map<String, dynamic>> messagesForLLM = [];

      String? systemPrompt = await SystemPromptService.getSystemPrompt(
        userName: widget.username ?? 'User',
        assistantName: _assistantName,
        userAge: _userAge ?? 0,
        userOccupation: _userOccupation ?? 'unspecified',
        workLocation: _workLocation ?? 'unspecified',
        userEducation: _userEducation ?? 'unspecified',
        maritalStatus: _maritalStatus ? 'Married' : 'Single',
      );
      if (systemPrompt != null) {
        messagesForLLM.add({"role": "system", "content": systemPrompt});
      }

      messagesForLLM.add({
        "role": "system",
        "content":
            "User Profile: Name: ${widget.username ?? 'N/A'}, Age: ${_userAge ?? 'N/A'}, Occupation: ${_userOccupation ?? 'N/A'}, Work Location: ${_workLocation ?? 'N/A'}, Education: ${_userEducation ?? 'N/A'}, Marital Status: ${_maritalStatus ? 'Married' : 'Single'}, Has Children: ${_hasChildren ? 'Yes' : 'No'}"
      });

      if (_currentSummary != null && _currentSummary!.isNotEmpty) {
        messagesForLLM.add({
          "role": "system",
          "content": "Previous conversation summary: $_currentSummary"
        });
      }

      for (var msg in _messages) {
        if (msg['role'] == 'user' || msg['role'] == 'assistant') {
          messagesForLLM.add(msg);
        }
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.backendBaseUrl}/chat'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'messages': messagesForLLM}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['response'];
      } else {
        _logger.severe(
            'LLM call failed with status: ${response.statusCode} and body: ${response.body}');
        return "Error: Could not get a response from the AI.";
      }
    } on TimeoutException {
      _logger.severe('LLM call timed out.');
      return "Error: The request to the AI timed out.";
    } catch (e) {
      _logger.severe('Exception during LLM call: $e');
      return "Error: An unexpected error occurred.";
    }
  }

  void clearChat() async {
    _logger.info('Clearing chat...');
    setState(() {
      _messages.clear();
      _currentSummary = "";
      _conversationPairs = 0;
    });
    if (widget.userId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('chatSummaries')
            .doc('latest')
            .delete();
        _logger.info('Chat summary cleared from Firestore.');
      } catch (e) {
        _logger.severe('Error clearing chat summary from Firestore: $e');
      }
    }
  }

  /// Show dialog when user reaches daily token limit
  void _showTokenLimitReachedDialog() async {
    if (widget.userId == null) return;

    try {
      final usageInfo =
          await TokenLimitService.getUserUsageInfo(widget.userId!);

      if (mounted) {
        await ChatLimitDialog.show(
          context,
          usageInfo,
          onUpgradePressed: () {
            // TODO: Navigate to subscription/upgrade screen
            _logger.info('User requested upgrade from token limit dialog');
          },
        );
      }
    } catch (e) {
      _logger.severe('Error showing token limit dialog: $e');
      // Show generic dialog on error
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Daily Token Limits'),
              content: const Text(
                  'You have reached your daily chat limit. Please try again tomorrow.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Show loading while checking violation status
    if (!_violationCheckComplete) {
      return Scaffold(
        backgroundColor: Colors.grey[850],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue[800]),
              const SizedBox(height: 16),
              Text(
                'Loading chat...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Show violation warning if needed
    if (_showViolationWarning && widget.userId != null) {
      return ViolationWarningScreen(
        userId: widget.userId!,
        onContinue: () {
          setState(() {
            _showViolationWarning = false;
          });
        },
      );
    }

    // Show normal chat screen
    return ChatScreenView(
      messageController: _messageController,
      scrollController: _scrollController,
      messages: _messages,
      isTyping: _isTyping,
      onSendMessage: _sendMessage,
      onClearChat: clearChat,
      conversationPairs: _conversationPairs,
      assistantName: _assistantName,
      username: widget.username,
      userId: widget.userId,
      lastExchangeTokens: _lastExchangeTokens,
    );
  }
}
