// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:kapwa_companion/screens/video_conference_screen.dart';
import 'package:kapwa_companion/services/video_conference_service.dart';
import 'dart:convert';
import 'dart:async'; // Import for TimeoutException
import 'package:kapwa_companion/services/suggestion_service.dart'; 
import 'package:logging/logging.dart';
import 'package:kapwa_companion/widgets/audio_player_widget.dart';
import 'package:kapwa_companion/services/audio_service.dart';
import 'package:kapwa_companion/screens/contacts_screen.dart';
import 'package:kapwa_companion/services/system_prompt_service.dart';
import 'package:kapwa_companion/services/auth_service.dart';
import 'package:kapwa_companion/core/config.dart';

class ChatScreen extends StatefulWidget {
  final DirectVideoCallService videoService;
  const ChatScreen({
    super.key,
    required this.videoService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final Logger _logger = Logger('ChatScreen');
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages =[]; 
  final List<Map<String, String>> _chatHistory = [];

  // Define your system prompt variables here
  String _assistantName = "Tita Ai";
  String _userName = "Hilda";
  int _userAge = 26;
  String _userOccupation = "caregiver";
  String _workLocation = "Hong Kong";
  String _userEducation = "high school graduate";
  String _maritalStatus = "married";

  bool _profileLoaded = false;

  // Keep suggestion-related fields:
  List<String> _allSuggestions = [];
  List<String> _currentSuggestions = [];
  bool _suggestionsLoading = true;

  @override
  void initState() {
    super.initState();
     _loadUserProfile();
    // Keep suggestion loading:
    _loadSuggestions();
    AudioService().initialize();
  }

  // Keep suggestion loading method:
  Future<void> _loadSuggestions() async {
    try {
      setState(() {
        _suggestionsLoading = true;
      });

      List<String> suggestions = await SuggestionService.getSuggestions();
      _logger.info('suggestions: $suggestions');

      // IMPORTANT: Filter out any null or non-string suggestions, and ensure they are Strings
      final List<String> cleanSuggestions = suggestions
          // ignore: unnecessary_null_comparison
          .where((s) => s != null && s.isNotEmpty)
          .map((s) => s)
          .toList();

      setState(() {
        _allSuggestions = cleanSuggestions; // Use the cleaned list
        _suggestionsLoading = false;
        _refreshSuggestions(); // Refresh initial suggestions
      });
    } catch (e) {
      _logger.info('Error loading suggestions: $e');
      setState(() {
        _suggestionsLoading = false;
        // Use fallback suggestions if Firebase fails (or keep _allSuggestions empty)
        _allSuggestions = [
          "How are you feeling?",
          "Share your thoughts",
          "Today's highlights?",
          "Any challenges?",
          "Need support?",
          "What are you grateful for?",
          "Recent accomplishments?",
          "Something bothering you?",
        ];
        _refreshSuggestions();
      });
    }
  }

  // Keep suggestion refresh method:
  void _refreshSuggestions() {
    if (_allSuggestions.isNotEmpty) {
      _allSuggestions.shuffle();
      _currentSuggestions = _allSuggestions.length >= 3
          ? _allSuggestions.sublist(0, 3)
          : _allSuggestions;
    } else {
      _currentSuggestions =
          []; // Ensure it's empty if no suggestions are loaded
    }
  }

  // sending message from the chat UI
  void _sendMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "content": message});
      _messages.add({"role": "assistant", "content": "Generating response..."});
      _messageController.clear();
    });

    _chatHistory.add({"role": "user", "content": message});

    try {
      final response = await _callLLM(message);
      
      _chatHistory.add({"role": "assistant", "content": response});

      setState(() {
        _messages.removeLast();
        _messages.add({"role": "assistant", "content": response});
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add({
          "role": "assistant", 
          "content": "Error: ${e.toString()}"
        });
      });
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfile = await AuthService.getCurrentUserProfile();
      if (userProfile != null && mounted) {
        setState(() {
          _userName = userProfile['name'] ?? 'User';
          _userAge = (DateTime.now().year - (userProfile['birthYear'] ?? DateTime.now().year - 25)).toInt();
          _userOccupation = userProfile['occupation'] ?? 'worker';
          _workLocation = userProfile['workLocation'] ?? '';
          _userEducation = userProfile['educationalAttainment'] ?? '';
          _maritalStatus = userProfile['isMarried'] == true ? 'married' : 'single';
          _profileLoaded = true;
        });
      }
    } catch (e) {
      _logger.severe('Error loading user profile: $e');
    }
  }

  Future<String> _callLLM(String message) async {
    try {
      // await dotenv.load(fileName: '.env');
      //final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      
      final apiKey = AppConfig.openAiKey;

      if (apiKey.isEmpty) {
        throw 'API key not configured';
      }

      List<Map<String, String>> messages = [];
      
      // Add system message for context (optional)
      messages.add({
        "role": "system", 
        "content": SystemPromptService.getSystemPrompt(
          assistantName: _assistantName,
          userName: _userName,
          userAge: _userAge,
          userOccupation: _userOccupation,
          workLocation: _workLocation,
          userEducation: _userEducation,
          maritalStatus: _maritalStatus,
        ),
      });
      
      // Add chat history (keep last 10 exchanges to avoid token limits)
      if (_chatHistory.length > 20) {
        messages.addAll(_chatHistory.sublist(_chatHistory.length - 20));
      } else {
        messages.addAll(_chatHistory);
      }


      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          "model": "gpt-4.1-nano",
          "messages": messages,
          "max_tokens": 500,
        }),
      ).timeout(const Duration(seconds: 30)); // Add timeout

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['choices'][0]['message']['content'];
      } else {
        throw 'API Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      _logger.severe('LLM Error: $e');
      return "Sorry, I couldn't process that. Please try again later.";
    }
  }

  // Restore suggestion tap handler:
  void _handleSuggestionTap(String suggestion) {
    _sendMessage(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kapwa Companion'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearChatHistory,
            tooltip: 'Clear Chat',
          ),       
          IconButton(
            icon: const Icon(Icons.contacts),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContactsScreen(
                    videoService: widget.videoService,
                  ),
                ),
              );
            },
            tooltip: 'OFW',
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[850],
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return ChatBubble(
                    message: message["content"]!,
                    isUser: message["role"] == "user",
                  );
                },
              ),
            ),
            _buildSuggestionChips(),
            const AudioPlayerWidget(),
            _buildMessageInput(),
            _buildDisclaimer(),
            
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    AudioService().dispose();
    super.dispose();
  }

  void _clearChatHistory() => setState(() {
    _messages.clear();
    _chatHistory.clear();
  });


  // Restore _buildSuggestionChips() widget definition:
  Widget _buildSuggestionChips() {
    if (_suggestionsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: _currentSuggestions.map((suggestion) {
          return ActionChip(
            label: Text(
              suggestion,
              style: const TextStyle(color: Colors.white70),
            ),
            onPressed: () => _handleSuggestionTap(suggestion),
            backgroundColor: Colors.grey[700],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey[600]!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              // *** IMPORTANT: Add these properties to disable browser's autofill/autocomplete ***
              autofillHints: null, // Disables platform-specific autofill hints
              autocorrect: false, // Disables auto-correction
              enableSuggestions: false, // Disables text input suggestions

              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              style: const TextStyle(color: Colors.white),
              onSubmitted: _sendMessage, // Allow sending message on Enter key
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            // Fixed RenderFlex overflow with explicit size
            width: 48, // Standard FAB size
            height: 48, // Standard FAB size
            child: FloatingActionButton(
              onPressed: () => _sendMessage(_messageController.text),
              backgroundColor: Colors.blue[800],
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: const Text(
        'I can make mistakes, please double check.',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 12.0,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
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
        child: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
