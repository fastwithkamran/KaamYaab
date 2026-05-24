import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/location_service.dart';

enum AgentInputMode { voice, text }
enum OnboardingState { notStarted, askingService, askingAvailability, completed }

class WorkerAgentChatBottomSheet extends StatefulWidget {
  final AgentInputMode initialMode;
  const WorkerAgentChatBottomSheet({super.key, this.initialMode = AgentInputMode.voice});

  @override
  State<WorkerAgentChatBottomSheet> createState() => _WorkerAgentChatBottomSheetState();
}

class _WorkerAgentChatBottomSheetState extends State<WorkerAgentChatBottomSheet>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late AgentInputMode _currentMode;
  bool _isListening = false;
  String _voiceText = '';
  final List<_ChatMessage> _chatLog = [];
  final List<Map<String, String>> _aiHistory = [];
  bool _isProcessing = false;

  String _agentState = 'idle';
  final bool _isUrdu = LanguageService().isUrdu;

  // FIX: separate controller for the mic pulse and for the typing dots,
  // so they can run at different speeds independently.
  late AnimationController _micPulseCtrl;
  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;

    _micPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Rebuild so the send icon colour updates as the user types.
    _textController.addListener(() => setState(() {}));

    _initSpeech();
    _sendAgentGreeting();
  }

  String _t(String en, String ur) => _isUrdu ? ur : en;

  void _sendAgentGreeting() {
    final user = AuthService().currentUser;
    final name = user?.name.split(' ').first ?? 'there';
    final category = user?.serviceCategory;

    String greeting;
    if (category == 'Unassigned' || category == null) {
      _agentState = 'asking_service';
      greeting = _t(
        "Salam $name! I'm your KaamYaab Assistant. Tell me, what kind of work do you do?",
        "اسلام علیکم $name! میں آپ کا کامیاب اسسٹنٹ ہوں۔ مجھے بتائیں، آپ کس قسم کا کام کرتے ہیں؟",
      );
    } else {
      _agentState = 'idle';
      greeting = _t(
        "Welcome back $name! How can I help with your schedule today?",
        "خوش آمدید $name! آج میں آپ کے شیڈول میں کیا مدد کر سکتا ہوں؟",
      );
    }

    _addAgentMessage(greeting, isMocked: true);

    // FIX: strip emoji before sending to TTS. Most TTS engines on Android/iOS
    // verbalize emoji code-point names (e.g. 👋 → "waving hand sign"), which
    // sounds broken. A simple regex removes the common emoji Unicode ranges.
    _speak(_stripEmoji(greeting));

    _aiHistory.add({'role': 'CHATBOT', 'message': greeting});
  }

  /// Removes emoji characters so TTS reads clean plain text.
  String _stripEmoji(String text) => text.replaceAll(
        RegExp(
          r'[\u{1F300}-\u{1FAFF}'   // Misc symbols & pictographs
          r'\u{2600}-\u{26FF}'      // Misc symbols
          r'\u{2700}-\u{27BF}'      // Dingbats
          r'\u{FE00}-\u{FEFF}'      // Variation selectors
          r'\u{1F000}-\u{1F02F}'    // Mahjong / dominos
          r']',
          unicode: true,
        ),
        '',
      ).trim();

  void _initSpeech() async {
    final available = await _speech.initialize();
    if (mounted) setState(() {});
    if (available && _currentMode == AgentInputMode.voice) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isListening) _toggleListening();
      });
    }
  }

  void _speak(String text) async {
    try {
      if (_isUrdu) {
        await _tts.setLanguage('ur-PK');
        await _tts.setSpeechRate(0.38);
      } else {
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(0.45);
      }
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  void _addAgentMessage(String text, {bool isMocked = false}) {
    if (mounted) {
      setState(() => _chatLog.add(_ChatMessage(text: text, isAgent: true, isMocked: isMocked)));
      _scrollToBottom();
    }
  }

  void _addUserMessage(String text) {
    if (mounted) {
      setState(() => _chatLog.add(_ChatMessage(text: text, isAgent: false)));
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleListening() async {
    if (!_isListening) {
      final available = await _speech.initialize();
      if (available) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isListening = true;
          _voiceText = '';
        });
        _micPulseCtrl.repeat(reverse: true);
        _speech.listen(
          onResult: (val) {
            setState(() => _voiceText = val.recognizedWords);
            if (val.finalResult) {
              _toggleListening();
              _processInput(_voiceText);
            }
          },
          listenOptions: stt.SpeechListenOptions(
            localeId: _isUrdu ? 'ur_PK' : 'en_US',
          ),
        );
      }
    } else {
      HapticFeedback.lightImpact();
      setState(() => _isListening = false);
      _micPulseCtrl.stop();
      _micPulseCtrl.reset();
      _speech.stop();
    }
  }

  Future<void> _processInput(String userInput) async {
    if (userInput.isEmpty) return;
    _addUserMessage(userInput);
    _textController.clear();
    setState(() => _isProcessing = true);

    try {
      final result = await AiService.processWorkerChat(
        message: userInput,
        chatHistory: _aiHistory,
        currentState: _agentState,
      );

      final reply = result['reply']?.toString() ?? '';

      bool shouldCommit = false;
      if (result['should_commit'] is bool) {
        shouldCommit = result['should_commit'] as bool;
      } else if (result['should_commit'] != null) {
        shouldCommit = result['should_commit'].toString().toLowerCase() == 'true';
      }

      bool isMocked = true;
      if (result['is_mock'] is bool) {
        isMocked = result['is_mock'] as bool;
      } else if (result['is_mock'] != null) {
        isMocked = result['is_mock'].toString().toLowerCase() == 'true';
      }

      final nextState = result['next_state']?.toString() ?? _agentState;

      Map<String, dynamic>? data;
      if (result['extracted_data'] is Map) {
        data = Map<String, dynamic>.from(result['extracted_data'] as Map);
      }

      // Update AI history — keep a rolling window of the last 10 turns (20 messages).
      // FIX: the original trimmed only 2 entries when length exceeded 10, but
      // the window check was `> 10`, so the list could grow unboundedly if
      // multiple messages arrived before the trim fired. Now we add first, then
      // trim to exactly 20 entries so the window is always consistent.
      _aiHistory.add({'role': 'USER', 'message': userInput});
      _aiHistory.add({'role': 'CHATBOT', 'message': reply});
      if (_aiHistory.length > 20) {
        _aiHistory.removeRange(0, _aiHistory.length - 20);
      }

      if (shouldCommit && data != null) {
        final user = AuthService().currentUser;
        if (user == null) {
          _addAgentMessage(
            _isUrdu ? 'سیشن ختم ہو گیا ہے۔ دوبارہ لاگ ان کریں۔' : 'Session expired. Please log in again.',
            isMocked: true,
          );
          return;
        }

        if (data.containsKey('category')) {
          final cat = data['category'].toString();
          List<String> skills;
          if (data['skills'] is List) {
            skills = (data['skills'] as List)
                .map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList();
          } else if (data['skills'] != null) {
            skills = data['skills'].toString().split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
          } else {
            skills = user.skills ?? [];
          }
          await AuthService().updateWorkerService(cat, skills);
        }

        if (data.containsKey('availability_rules')) {
          List<String> rules;
          if (data['availability_rules'] is List) {
            rules = (data['availability_rules'] as List)
                .map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList();
          } else if (data['availability_rules'] != null) {
            rules = data['availability_rules'].toString().split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
          } else {
            rules = [];
          }
          if (rules.isNotEmpty) {
            await AuthService().setAvailabilityRules(rules);
            await _saveWorkerLocation();
          }
        }
      }

      _agentState = nextState;
      _addAgentMessage(reply, isMocked: isMocked);
      _speak(_stripEmoji(reply));
    } catch (e, stack) {
      debugPrint('WorkerAgentChat ProcessInput Error: $e\n$stack');
      _addAgentMessage(
        _isUrdu ? 'معذرت، دوبارہ کہیں۔' : 'Sorry, could you repeat that?',
        isMocked: true,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveWorkerLocation() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc.isSuccess && loc.data != null) {
        await LocationService().saveUserLocation(user.uid, loc.data!);
      }
    } catch (_) {
      // GPS unavailable — location will be set next time worker goes online.
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _micPulseCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      decoration: const BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 40)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          Flexible(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: AppTheme.radiusLg,
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _chatLog.length + (_isProcessing ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _chatLog.length) return _buildTypingIndicator();
                  return _buildMessageBubble(_chatLog[index]);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _voiceText.isEmpty ? 'Listening... آپ بولیں' : _voiceText,
                style: const TextStyle(
                  color: AppTheme.purpleLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          _buildInputBar(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: _isUrdu ? 'یہاں لکھیں...' : 'Type message...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: _processInput,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    color: _textController.text.isNotEmpty
                        ? AppTheme.purpleLight
                        : Colors.white24,
                  ),
                  onPressed: () => _processInput(_textController.text),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _toggleListening,
          child: AnimatedBuilder(
            animation: _micPulseCtrl,
            builder: (context, child) => Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening ? AppTheme.redAlert : AppTheme.purpleAgent,
                boxShadow: _isListening
                    ? [
                        BoxShadow(
                          color: AppTheme.redAlert.withValues(alpha: 0.4),
                          blurRadius: 10 * _micPulseCtrl.value,
                          spreadRadius: 2 * _micPulseCtrl.value,
                        )
                      ]
                    : null,
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: msg.isAgent ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: msg.isAgent ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: msg.isAgent
                        ? AppTheme.purpleAgent.withValues(alpha: 0.15)
                        : AppTheme.tealPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (msg.isAgent ? AppTheme.purpleAgent : AppTheme.tealPrimary)
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                ),
              ),
            ],
          ),
          if (msg.isMocked)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'SIMULATION MODE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // FIX: upgraded from a plain CircularProgressIndicator to animated bouncing
  // dots — consistent with the superior pattern in worker_agent_chat.dart.
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.purpleAgent.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _dot(0),
            const SizedBox(width: 5),
            _dot(150),
            const SizedBox(width: 5),
            _dot(300),
          ]),
        ),
      ),
    );
  }

  Widget _dot(int delayMs) {
    return AnimatedBuilder(
      animation: _dotCtrl,
      builder: (context, child) {
        // Shift each dot's phase by its delay relative to the controller period.
        final phase = ((_dotCtrl.value + delayMs / 900.0) % 1.0);
        final brightness = (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.0, 1.0);
        return Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.purpleLight.withValues(alpha: 0.3 + 0.7 * brightness),
          ),
        );
      },
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isAgent;
  final bool isMocked;
  const _ChatMessage({required this.text, required this.isAgent, this.isMocked = false});
}