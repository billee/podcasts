// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}




class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  final _scrollController = ScrollController();

  // Cached responses for common OFW concerns
  final Map<String, List<String>> _cachedResponses = {
    'homesick': [
      '💙 Alam kong mahirap malayo sa pamilya. Kaya mo yan, kabayan!',
      '📞 Gusto mo bang mag-schedule ng video call sa inyong pamilya?'
    ],
    'oec': [
      '📄 Para sa OEC renewal, kailangan ng: 1) Passport, 2) Kontrata, 3) OWWA membership. Pwede ko bang i-direct sa official website?',
    ],
    'salary': [
      '💼 Ayon sa batas, dapat bayaran kayo ng hindi bababa sa \$450 monthly. Gusto mo ng tulong para i-report ito?',
    ]
  };

  // Common OFW questions as suggestions
  final List<String> _suggestions = [
    'Paano mag-renew ng OEC?',
    'Ano ang minimum salary sa UAE?',
    'Pano labanan ang homesickness?'
  ];

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    await FirebaseAuth.instance.signInAnonymously();
  }

  void _sendMessage(String text) async {
    if (text.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(text, isUser: true));
      _textController.clear();
      _isLoading = true;
    });

    // Check cache first
    final cachedResponse = _checkCache(text);
    if (cachedResponse != null) {
      _showCachedResponse(cachedResponse);
    } else {
      // Simulate slow LLM response
      await _simulateLlamaResponse(text);
    }

    // Scroll to bottom
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  String? _checkCache(String query) {
    final key = _cachedResponses.keys.firstWhere(
          (key) => query.toLowerCase().contains(key),
      orElse: () => '',
    );
    return key.isNotEmpty ? _cachedResponses[key]!.first : null;
  }

  void _showCachedResponse(String response) {
    setState(() {
      _messages.add(ChatMessage(response));
      _isLoading = false;
    });
  }

  Future<void> _simulateLlamaResponse(String query) async {
    // In real implementation, call your Llama API here
    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      _messages.add(ChatMessage(
        '🤖 (LLM) Alam kong nahihirapan ka... ${_culturalLoadingMessages().first}',
        isLlama: true,
      ));
      _isLoading = false;
    });
  }

  List<String> _culturalLoadingMessages() => [
    'Nag-iisip ako nang mabuti, parang paghihintay ng remittance...',
    'Sandali lang, kapatid. Para to sa ikabubuti natin.',
    'Kasing bilis ng padala ng pera! Konting pasensya...',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kapwa Companion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _showCulturalAuthDialog(),
          )
        ],
      ),
      body: Column(
        children: [
          // Suggestion Chips
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _suggestions.map((text) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ActionChip(
                  label: Text(text),
                  onPressed: () => _sendMessage(text),
                ),
              )).toList(),
            ),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _messages.length) {
                  return _buildLoadingIndicator();
                }
                return _messages[index];
              },
            ),
          ),

          // Input Area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Mag-type dito...',
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          Text(
            _culturalLoadingMessages()[DateTime.now().second % 3],
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _showCulturalAuthDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mag-sign up para sa mas mabilis na tulong!'),
        content: const Text('Makakuha ng:'
            '\n✅ Unlimited na sagot'
            '\n✅ Mabilis na response'
            '\n✅ Mga eksklusibong tips'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hindi muna'),
          ),
          ElevatedButton(
            onPressed: () => _navigateToSignUp(),
            child: const Text('Mag-sign Up'),
          ),
        ],
      ),
    );
  }

  void _navigateToSignUp() {
    // Implement your sign up flow
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isLlama;

  const ChatMessage(this.text, {this.isUser = false, this.isLlama = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser
            ? Colors.blue[100]
            : (isLlama ? Colors.grey[200] : Colors.green[100]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}