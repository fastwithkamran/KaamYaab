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
    with SingleTickerProviderStateMixin {
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
  
  // Internal logic states
  String _agentState = 'idle'; 
  final bool _isUrdu = LanguageService().isUrdu;

  late AnimationController _micPulseCtrl;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;

    _micPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

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
        "Salam $name! 👋 I'm your KaamYaab Assistant. Tell me, what kind of work do you do?",
        "اسلام علیکم $name! 👋 میں آپ کا کامیاب اسسٹنٹ ہوں۔ مجھے بتائیں، آپ کس قسم کا کام کرتے ہیں؟"
      );
    } else {
      _agentState = 'idle';
      greeting = _t(
        "Welcome back $name! 👋 How can I help with your schedule today?",
        "خوش آمدید $name! 👋 آج میں آپ کے شیڈول میں کیا مدد کر سکتا ہوں؟"
      );
    }

    _addAgentMessage(greeting, isMocked: true);
    _speak(greeting);
    
    // Add to AI history for context
    _aiHistory.add({'role': 'CHATBOT', 'message': greeting});
  }

  void _initSpeech() async {
    bool available = await _speech.initialize();
    if (mounted) setState(() {});
    if (available && _currentMode == AgentInputMode.voice) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isListening) _toggleListening();
      });
    }
  }

  void _speak(String text) async {
    try {
      final useUrdu = LanguageService().isUrdu;
      if (useUrdu) {
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
      bool available = await _speech.initialize();
      if (available) {
        HapticFeedback.mediumImpact();
        setState(() { _isListening = true; _voiceText = ''; });
        _micPulseCtrl.repeat(reverse: true);
        _speech.listen(
          onResult: (val) {
            setState(() => _voiceText = val.recognizedWords);
            if (val.finalResult) {
              _toggleListening();
              _processInput(_voiceText);
            }
          },
          localeId: _isUrdu ? 'ur_PK' : 'en_US',
        );
      }
    } else {
      HapticFeedback.lightImpact();
      setState(() => _isListening = false);
      _micPulseCtrl.stop(); _micPulseCtrl.reset();
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

      // Defensively parse values to avoid runtime type cast exceptions
      final reply = result['reply']?.toString() ?? '';
      
      bool shouldCommit = false;
      if (result['should_commit'] != null) {
        if (result['should_commit'] is bool) {
          shouldCommit = result['should_commit'] as bool;
        } else {
          shouldCommit = result['should_commit'].toString().toLowerCase() == 'true';
        }
      }

      bool isMocked = true;
      if (result['is_mock'] != null) {
        if (result['is_mock'] is bool) {
          isMocked = result['is_mock'] as bool;
        } else {
          isMocked = result['is_mock'].toString().toLowerCase() == 'true';
        }
      }

      final nextState = result['next_state']?.toString() ?? _agentState;
      
      Map<String, dynamic>? data;
      if (result['extracted_data'] != null && result['extracted_data'] is Map) {
        data = Map<String, dynamic>.from(result['extracted_data'] as Map);
      }

      // 1. Update AI History
      _aiHistory.add({'role': 'USER', 'message': userInput});
      _aiHistory.add({'role': 'CHATBOT', 'message': reply});
      if (_aiHistory.length > 10) _aiHistory.removeRange(0, 2);

      // 2. Decide whether to save (Commit) — with confirmation guard
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
          final cat = data['category']?.toString() ?? user.serviceCategory ?? 'General';
          
          List<String> skills = [];
          if (data['skills'] != null) {
            if (data['skills'] is List) {
              skills = (data['skills'] as List)
                  .map((e) => e.toString())
                  .where((s) => s.isNotEmpty)
                  .toList();
            } else {
              skills = data['skills'].toString().split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
            }
          } else {
            skills = user.skills ?? [];
          }
          await AuthService().updateWorkerService(cat, skills);
        }
        if (data.containsKey('availability_rules')) {
          List<String> rules = [];
          if (data['availability_rules'] != null) {
            if (data['availability_rules'] is List) {
              rules = (data['availability_rules'] as List)
                  .map((e) => e.toString())
                  .where((s) => s.isNotEmpty)
                  .toList();
            } else {
              rules = data['availability_rules'].toString().split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
            }
          }
          if (rules.isNotEmpty) {
            await AuthService().setAvailabilityRules(rules);
            await _saveWorkerLocation();
          }
        }
      }

      // 3. Update internal state
      _agentState = nextState;

      _addAgentMessage(reply, isMocked: isMocked);
      _speak(reply);

    } catch (e, stack) {
      debugPrint('WorkerAgentChat ProcessInput Error: $e\n$stack');
      _addAgentMessage(_isUrdu ? "معذرت، دوبارہ کہیں۔" : "Sorry, could you repeat that?", isMocked: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveWorkerLocation() async {
    final user = AuthService().currentUser;
    if (user == null) return; // Guard: no crash if session expired
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc.isSuccess && loc.data != null) {
        await LocationService().saveUserLocation(user.uid, loc.data!);
      }
    } catch (_) {
      // GPS unavailable — location will be set next time worker goes online
    }
  }

  @override
  void dispose() {
    _speech.stop(); _tts.stop();
    _textController.dispose(); _focusNode.dispose();
    _scrollController.dispose(); _micPulseCtrl.dispose();
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
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          
          Flexible(
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: AppTheme.radiusLg),
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
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(_voiceText.isEmpty ? "Listening... آپ بولیں" : _voiceText,
                   style: const TextStyle(color: AppTheme.purpleLight, fontSize: 16, fontWeight: FontWeight.w600)),
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
                  icon: Icon(Icons.send_rounded, color: _textController.text.isNotEmpty ? AppTheme.purpleLight : Colors.white24),
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
                boxShadow: _isListening ? [
                  BoxShadow(
                    color: AppTheme.redAlert.withValues(alpha: 0.4),
                    blurRadius: 10 * _micPulseCtrl.value, spreadRadius: 2 * _micPulseCtrl.value,
                  )
                ] : null,
              ),
              child: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 24),
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
                    color: msg.isAgent ? AppTheme.purpleAgent.withValues(alpha: 0.15) : AppTheme.tealPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: (msg.isAgent ? AppTheme.purpleAgent : AppTheme.tealPrimary).withValues(alpha: 0.2)),
                  ),
                  child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
                ),
              ),
            ],
          ),
          if (msg.isMocked)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'SIMULATION MODE',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.purpleLight)),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isAgent;
  final bool isMocked;
  const _ChatMessage({required this.text, required this.isAgent, this.isMocked = false});
}
