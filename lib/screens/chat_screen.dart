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

      final response = await http
          .post(
            Uri.parse('${AppConfig.backendBaseUrl}/summarize_chat'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'messages': messagesForSummary}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newCumulativeSummary = data['summary'];
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
        _logger.severe(
            'Failed to generate summary: ${response.statusCode} ${response.body}');
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

    // Count tokens in the user's input message
    final inputTokens = TokenCounter.countTokens(message);
    _logger.info('User message token count: $inputTokens');

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

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    _logger.info(
        'User message added to UI and local buffer. Current local messages count: ${_messages.length}');

    try {
      final llmResponse = await _callLLM(message);
      setState(() {
        _messages.last = {
          "role": "assistant",
          "content": llmResponse,
          "senderName": _assistantName
        };
        _isTyping = false;
        _conversationPairs++;
      });

      // Record token usage for the input message only
      if (widget.userId != null) {
        await TokenLimitService.recordTokenUsage(widget.userId!, inputTokens);
        _logger.info('Recorded $inputTokens tokens for user ${widget.userId}');
      }

      _logger.info(
          'Assistant message added to UI and local buffer. Current local messages count: ${_messages.length}, Conversation pairs: $_conversationPairs');

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      if (_conversationPairs >= 10) { // TEMPORARILY SET TO 6 FOR MANUAL TESTING
        _logger.info(
            'Conversation pair threshold reached ($_conversationPairs >= 6). Triggering summarization in background.');
        _generateSummary().catchError((error) {
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
        await TokenLimitService.recordTokenUsage(widget.userId!, inputTokens);
        _logger.info('Recorded $inputTokens tokens for user ${widget.userId} (despite LLM error)');
      }
    }
    _refreshSuggestions();
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
      final resetTime = usageInfo.resetTime;
      final now = DateTime.now();
      final timeUntilReset = resetTime.difference(now);
      
      String resetMessage;
      if (timeUntilReset.inHours > 0) {
        resetMessage = 'Your tokens will reset in ${timeUntilReset.inHours} hours and ${timeUntilReset.inMinutes % 60} minutes.';
      } else {
        resetMessage = 'Your tokens will reset in ${timeUntilReset.inMinutes} minutes.';
      }
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Daily Token Limit Reached'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You have used all ${usageInfo.tokenLimit} tokens for today.'),
                  const SizedBox(height: 8),
                  Text(resetMessage),
                  const SizedBox(height: 8),
                  const Text('Come back tomorrow to continue chatting!'),
                ],
              ),
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
    } catch (e) {
      _logger.severe('Error showing token limit dialog: $e');
      // Show generic dialog on error
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Daily Token Limit Reached'),
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
      onSuggestionSelected: (suggestion) {
        _messageController.text = suggestion;
        _sendMessage(suggestion);
      },
    );
  }
}
