// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Import for TimeoutException
import 'package:kapwa_companion_basic/services/suggestion_service.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/widgets/audio_player_widget.dart';
import 'package:kapwa_companion_basic/services/audio_service.dart';
import 'package:kapwa_companion_basic/screens/contacts_screen.dart';
import 'package:kapwa_companion_basic/services/system_prompt_service.dart';
import 'package:kapwa_companion_basic/services/auth_service.dart';
import 'package:kapwa_companion_basic/core/config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kapwa_companion_basic/widgets/typing_indicator.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final Logger _logger = Logger('ChatScreen');
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  // Initialize AudioService (it's a singleton, so this is fine)
  final AudioService _audioService = AudioService();

  // Chat state variables
  List<Map<String, dynamic>> _messages = [];
  String? _currentSummary;
  String _assistantName = "Maria"; // Default assistant name
  bool _suggestionsLoading = true;
  List<String> _allSuggestions = [];
  List<String> _currentSuggestions = [];

  // Changed to 20 conversations (10 user + 10 assistant = 20 total messages)
  final int _summaryThreshold = 20;

  // Track conversation pairs for more accurate counting
  int _conversationPairs = 0;

  // User profile variables (assuming they are fetched or passed)
  String? _userName; // This should be redundant if widget.username is used
  int? _userAge;
  String? _userOccupation;
  String? _workLocation;
  String? _userEducation;
  bool _maritalStatus = false;
  bool _hasChildren = false; // Assuming this might also be a user profile field

  @override
  void initState() {
    super.initState();
    _logger.info('ChatScreen initState called.');
    _loadLatestSummary();
    _loadSuggestions();
    _initializeAudioService();
  }

  Future<void> _initializeAudioService() async {
    _logger.info('Initializing AudioService in ChatScreen...');
    await _audioService.initialize(); // Initialize the audio service
    // Listen for audio playback completion to stop the player
    _audioService.audioPlayer.onPlayerComplete.listen((_) {
      _logger.info('Audio player completed playback.');
      setState(() {
        _audioService.stopAudio(); // Ensure stop is called on complete
      });
    });
    _logger.info('AudioService initialized and listeners set up.');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioService
        .dispose(); // IMPORTANT: Dispose the audio service when ChatScreen is disposed
    _logger.info('ChatScreen dispose called. AudioService disposed.');
    super.dispose();
  }

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
      // Send the ENTIRE current _messages list to the backend.
      // The backend (app.py) is designed to extract the previous summary
      // from the system message at the beginning of this list.
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
        final newCumulativeSummary =
            data['summary']; // This is the cumulative summary
        _logger.info('New cumulative summary generated: $newCumulativeSummary');

        setState(() {
          _currentSummary = newCumulativeSummary;

          // Find the index of the existing system summary message.
          // It should typically be at index 0 if it exists.
          int existingSummaryIndex = _messages.indexWhere((msg) =>
              msg['role'] == 'system' &&
              (msg['content'] as String)
                  .startsWith('Continuing from our last conversation:'));

          if (existingSummaryIndex != -1) {
            // Update the existing system summary message with the new cumulative summary
            _messages[existingSummaryIndex] = {
              "role": "system",
              "content":
                  "Continuing from our last conversation: $_currentSummary",
              "senderName": _assistantName
            };
          } else if (_currentSummary!.isNotEmpty) {
            // If no system summary message exists (e.g., first summarization), add it to the beginning
            _messages.insert(0, {
              "role": "system",
              "content":
                  "Continuing from our last conversation: $_currentSummary",
              "senderName": _assistantName
            });
          }

          // After summarization, we can optionally trim older messages to keep memory usage reasonable
          // Keep the system summary + last 10 conversation pairs (20 messages)
          _trimMessagesAfterSummarization();

          // Reset conversation pair counter after summarization
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
    if (_messages.length <= 21)
      return; // Keep all if 21 or fewer (1 system + 20 conversation)

    // Find the system message
    int systemMessageIndex = _messages.indexWhere((msg) =>
        msg['role'] == 'system' &&
        (msg['content'] as String)
            .startsWith('Continuing from our last conversation:'));

    if (systemMessageIndex != -1) {
      // Keep system message + last 20 conversation messages
      List<Map<String, dynamic>> conversationMessages = _messages
          .where((msg) => msg['role'] == 'user' || msg['role'] == 'assistant')
          .toList();

      if (conversationMessages.length > 20) {
        // Keep only the last 20 conversation messages
        List<Map<String, dynamic>> recentConversation =
            conversationMessages.sublist(conversationMessages.length - 20);

        // Rebuild messages list with system message + recent conversation
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
        _allSuggestions = [
          "Hello!",
          "How are you?",
          "Tell me more."
        ]; // Fallback suggestions
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

    setState(() {
      _messages.add(
          {"role": "user", "content": message, "senderName": widget.username});
      // Add a placeholder for the assistant response immediately
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
        // Replace the placeholder with the actual assistant response
        _messages.last = {
          "role": "assistant",
          "content": llmResponse,
          "senderName": _assistantName
        };
        _isTyping = false;

        // Increment conversation pair counter after successful exchange
        _conversationPairs++;
      });

      _logger.info(
          'Assistant message added to UI and local buffer. Current local messages count: ${_messages.length}, Conversation pairs: $_conversationPairs');

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      // Check if we should trigger summarization (every 10 conversation pairs = 20 messages)
      if (_conversationPairs >= 10) {
        _logger.info(
            'Conversation pair threshold reached ($_conversationPairs >= 10). Triggering summarization in background.');

        // Run summarization in background to avoid blocking UI
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
    }
    _refreshSuggestions(); // Refresh suggestions after each message
  }

  Future<String> _callLLM(String message) async {
    _logger.info('Calling LLM with message: $message');
    try {
      // Constructing messages for LLM, including user profile and previous summary
      List<Map<String, dynamic>> messagesForLLM = [];

      // Add system prompt from SystemPromptService
      String? systemPrompt = await SystemPromptService.getSystemPrompt(
        userName: widget.username ?? 'User', // Provide default
        assistantName: _assistantName,
        userAge: _userAge ?? 0, // Provide default
        userOccupation: _userOccupation ?? 'unspecified', // Provide default
        workLocation: _workLocation ?? 'unspecified', // Provide default
        userEducation: _userEducation ?? 'unspecified', // Provide default
        maritalStatus:
            _maritalStatus ? 'Married' : 'Single', // Convert bool to String
      );
      if (systemPrompt != null) {
        messagesForLLM.add({"role": "system", "content": systemPrompt});
      }

      // Add user profile data. These values would ideally be loaded from Firestore
      // or passed down from a user management service. For now, they are nullables.
      messagesForLLM.add({
        "role": "system",
        "content":
            "User Profile: Name: ${widget.username ?? 'N/A'}, Age: ${_userAge ?? 'N/A'}, Occupation: ${_userOccupation ?? 'N/A'}, Work Location: ${_workLocation ?? 'N/A'}, Education: ${_userEducation ?? 'N/A'}, Marital Status: ${_maritalStatus ? 'Married' : 'Single'}, Has Children: ${_hasChildren ? 'Yes' : 'No'}"
      });

      // Add previous conversation summary if available
      if (_currentSummary != null && _currentSummary!.isNotEmpty) {
        messagesForLLM.add({
          "role": "system",
          "content": "Previous conversation summary: $_currentSummary"
        });
      }

      // Add the current conversation messages
      // Filter out the "Continuing from our last conversation:" system message
      // when sending to the general chat LLM, as it's for summarization backend.
      // Only include actual conversation turns for the chat LLM.
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
          .timeout(const Duration(seconds: 30));

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

  Widget _buildSuggestionChips() {
    if (_suggestionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_currentSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: _currentSuggestions.map((suggestion) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ActionChip(
              label: Text(suggestion),
              onPressed: () {
                _sendMessage(suggestion);
              },
              backgroundColor: Colors.blue[700],
              labelStyle: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
      ),
    );
  }

  void clearChat() async {
    _logger.info('Clearing chat...');
    setState(() {
      _messages.clear();
      _currentSummary = ""; // Clear local summary
      _conversationPairs = 0; // Reset conversation counter
    });
    // Optionally, clear summary from Firestore as well
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat'),
            if (_conversationPairs > 0)
              Text(
                'Conversations: $_conversationPairs/10',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                if (message['role'] == 'user' ||
                    message['role'] == 'assistant') {
                  return ChatBubble(
                    message: message['content'],
                    isUser: message['role'] == 'user',
                    senderName: message['senderName'] as String?,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          AudioPlayerWidget(),
          _buildSuggestionChips(),
          _isTyping
              ? const TypingIndicator() // Now using the imported widget
              : const SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                    ),
                    onSubmitted: (value) => _sendMessage(value),
                  ),
                ),
                const SizedBox(width: 8.0),
                FloatingActionButton(
                  onPressed: () => _sendMessage(_messageController.text),
                  backgroundColor: Colors.blue[800],
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final String? senderName;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[800] : Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser && senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  senderName!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.0,
                    color: Colors.white70,
                  ),
                ),
              ),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16.0),
            ),
          ],
        ),
      ),
    );
  }
}
