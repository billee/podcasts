// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Import for TimeoutException
import 'package:kapwa_companion_basic/services/suggestion_service.dart';
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
  String? _currentSummary;
  String _assistantName = "Maria";
  bool _suggestionsLoading = true;
  List<String> _allSuggestions = [];
  List<String> _currentSuggestions = [];

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

  @override
  void initState() {
    super.initState();
    _logger.info('ChatScreen initState called.');
    _loadLatestSummary();
    _loadSuggestions();
    // IMPORTANT: Removed _initializeAudioService() call, as it's handled globally in main.dart
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
      final newCumulativeSummary = await ConversationService.generateSummaryWithTokenTracking(
        messagesForSummary, 
        null // Don't record tokens here, we'll handle it manually
      );

      if (newCumulativeSummary != null) {
        // Calculate summarization tokens
        final summaryInputTokens = TokenCounter.countRealInputTokens(messagesForSummary);
        final summaryOutputTokens = TokenCounter.countOutputTokens(newCumulativeSummary);
        final totalSummaryTokens = summaryInputTokens + summaryOutputTokens;
        
        // Calculate total tokens for this complete exchange (main + summarization)
        final totalExchangeTokens = mainExchangeTokens + totalSummaryTokens;
        
        _logger.info('Complete exchange tokens - Main: $mainExchangeTokens, Summary: $totalSummaryTokens, Total: $totalExchangeTokens');

        // Record the additional summarization tokens
        if (widget.userId != null) {
          await TokenLimitService.recordTokenUsage(widget.userId!, totalSummaryTokens);
          
          // Update the UI state to show complete exchange total
          setState(() {
            _lastExchangeTokens = totalExchangeTokens;
          });
          
          _logger.info('Updated display to show complete exchange tokens: $totalExchangeTokens');
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
      final newCumulativeSummary = await ConversationService.generateSummaryWithTokenTracking(
        messagesForSummary, 
        widget.userId
      );

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
    if (_messages.length <= 21) return;

    int systemMessageIndex = _messages.indexWhere((msg) =>
        msg['role'] == 'system' &&
        (msg['content'] as String)
            .startsWith('Continuing from our last conversation:'));

    if (systemMessageIndex != -1) {
      List<Map<String, dynamic>> conversationMessages = _messages
          .where((msg) => msg['role'] == 'user' || msg['role'] == 'assistant')
          .toList();

      if (conversationMessages.length > 20) {
        List<Map<String, dynamic>> recentConversation =
            conversationMessages.sublist(conversationMessages.length - 20);

        _messages = [_messages[systemMessageIndex], ...recentConversation];

        _logger.info(
            'Trimmed messages to ${_messages.length} after summarization');
      }
    }
    
    // Scroll to bottom after trimming messages
    _scrollToBottom();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _suggestionsLoading = true;
    });
    try {
      List<String> suggestions = await SuggestionService.getSuggestions();
      List<String> cleanSuggestions =
          suggestions.where((s) => s.isNotEmpty).toSet().toList();
      setState(() {
        _allSuggestions = cleanSuggestions;
        _suggestionsLoading = false;
      });
      _refreshSuggestions();
    } catch (e) {
      _logger.severe('Error loading suggestions: $e');
      setState(() {
        _suggestionsLoading = false;
        _allSuggestions = ["Hello!", "How are you?", "Tell me more."];
      });
    }
  }

  void _refreshSuggestions() {
    setState(() {
      if (_allSuggestions.isNotEmpty) {
        _allSuggestions.shuffle();
        _currentSuggestions = _allSuggestions.length >= 3
            ? _allSuggestions.sublist(0, 3)
            : _allSuggestions;
      } else {
        _currentSuggestions = [];
      }
      _logger.info('Refreshed suggestions. Current: $_currentSuggestions');
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

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

    try {
      final llmCallResult = await _callLLMWithTokenTracking(message);
      final llmResponse = llmCallResult['response'] as String;
      final realInputTokens = llmCallResult['inputTokens'] as int;
      final outputTokens = llmCallResult['outputTokens'] as int;
      final totalTokens = realInputTokens + outputTokens;
      
      setState(() {
        _messages.last = {
          "role": "assistant",
          "content": llmResponse,
          "senderName": _assistantName
        };
        _isTyping = false;
        _conversationPairs++;
      });

      // Record REAL total token usage (input + output tokens)
      if (widget.userId != null) {
        await TokenLimitService.recordTokenUsage(widget.userId!, totalTokens);
        _logger.info('Recorded REAL tokens for user ${widget.userId}: Input: $realInputTokens, Output: $outputTokens, Total: $totalTokens');
        
        // Update the UI state to show tokens used in this exchange
        setState(() {
          _lastExchangeTokens = totalTokens;
        });
      }

      _logger.info(
          'Assistant message added to UI and local buffer. Current local messages count: ${_messages.length}, Conversation pairs: $_conversationPairs');

      // Scroll to bottom after LLM response is received
      _scrollToBottom();

      if (_conversationPairs >= 10) { // TEMPORARILY SET TO 6 FOR MANUAL TESTING
        _logger.info(
            'Conversation pair threshold reached ($_conversationPairs >= 6). Triggering summarization in background.');
        _generateSummaryAndUpdateTokens(totalTokens).catchError((error) {
          _logger.severe('Background summarization failed: $error');
        });
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
        await TokenLimitService.recordTokenUsage(widget.userId!, userInputTokens);
        _logger.info('Recorded $userInputTokens tokens for user ${widget.userId} (despite LLM error)');
      }
    }
    _refreshSuggestions();
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

      final response = await http
          .post(
            Uri.parse('${AppConfig.backendBaseUrl}/chat'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'messages': messagesForLLM}),
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
      final usageInfo = await TokenLimitService.getUserUsageInfo(widget.userId!);
      
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
              content: const Text('You have reached your daily chat limit. Please try again tomorrow.'),
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
    return ChatScreenView(
      messageController: _messageController,
      scrollController: _scrollController,
      messages: _messages,
      isTyping: _isTyping,
      currentSuggestions: _currentSuggestions,
      suggestionsLoading: _suggestionsLoading,
      onSendMessage: _sendMessage,
      onClearChat: clearChat,
      conversationPairs: _conversationPairs,
      assistantName: _assistantName,
      username: widget.username,
      userId: widget.userId,
      lastExchangeTokens: _lastExchangeTokens, // Pass the real-time token count
      onSuggestionSelected: (suggestion) {
        _messageController.text = suggestion;
        _sendMessage(suggestion);
      },
    );
  }
}
